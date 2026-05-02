/**
 * Auth Routes
 *
 * Single-admin passkey auth. The first time the app is launched no credential
 * exists, so the registration endpoints are open. Once a passkey is registered,
 * registration requires an existing valid session (so a logged-in user can
 * replace their passkey without going through the manual reset path).
 *
 * Recovery: delete the row in `auth_credentials` via sqlite3 to allow the
 * setup wizard to run again.
 */

import express from 'express';
import crypto from 'crypto';
import {
  generateRegistrationOptions,
  verifyRegistrationResponse,
  generateAuthenticationOptions,
  verifyAuthenticationResponse
} from '@simplewebauthn/server';
import {
  hasAnyCredential,
  listCredentials,
  getCredentialByCredentialId,
  saveCredential,
  updateCredentialCounter,
  deleteCredential,
  deleteAllCredentials,
  signValue,
  unsignValue
} from '../utils/authStore.js';
import { isAuthenticated, SESSION_COOKIE_NAME } from '../middleware/auth.js';

const router = express.Router();

const RP_NAME = 'Postalgic';
const CHALLENGE_COOKIE = 'postalgic_challenge';
const CHALLENGE_TTL_SECONDS = 5 * 60;
const SESSION_TTL_SECONDS = 365 * 24 * 60 * 60;

function getRpId(req) {
  // req.hostname uses X-Forwarded-Host when trust proxy is enabled, so this
  // matches the host the browser saw during the ceremony.
  return req.hostname;
}

function getOrigin(req) {
  // Prefer X-Forwarded-Host so we match the browser-facing origin when sitting
  // behind a reverse proxy (or the Vite dev proxy). Fall back to Host.
  const host = req.get('x-forwarded-host') || req.get('host');
  return `${req.protocol}://${host}`;
}

function setChallengeCookie(res, payload) {
  const value = signValue(JSON.stringify(payload));
  res.cookie(CHALLENGE_COOKIE, value, {
    httpOnly: true,
    sameSite: 'lax',
    secure: false,
    maxAge: CHALLENGE_TTL_SECONDS * 1000,
    path: '/api/auth'
  });
}

function readChallengeCookie(req) {
  const raw = req.cookies?.[CHALLENGE_COOKIE];
  if (!raw) return null;
  const value = unsignValue(raw);
  if (!value) return null;
  try {
    return JSON.parse(value);
  } catch {
    return null;
  }
}

function clearChallengeCookie(res) {
  res.clearCookie(CHALLENGE_COOKIE, { path: '/api/auth' });
}

function setSessionCookie(res) {
  const value = signValue(String(Date.now()));
  res.cookie(SESSION_COOKIE_NAME, value, {
    httpOnly: true,
    sameSite: 'lax',
    secure: false,
    maxAge: SESSION_TTL_SECONDS * 1000,
    path: '/'
  });
}

function clearSessionCookie(res) {
  res.clearCookie(SESSION_COOKIE_NAME, { path: '/' });
}

/**
 * GET /api/auth/status
 * Public. Tells the SPA whether to show the setup wizard, login, or app.
 */
router.get('/status', (req, res) => {
  res.json({
    hasPasskey: hasAnyCredential(),
    authenticated: isAuthenticated(req)
  });
});

/**
 * POST /api/auth/register/options
 * Open if no passkey exists; otherwise requires an active session (used to
 * replace the existing passkey).
 */
router.post('/register/options', async (req, res, next) => {
  try {
    const existing = hasAnyCredential();
    if (existing && !isAuthenticated(req)) {
      return res.status(401).json({ error: 'Authentication required to replace passkey' });
    }

    const userId = crypto.randomBytes(16);
    const rpID = getRpId(req);

    const options = await generateRegistrationOptions({
      rpName: RP_NAME,
      rpID,
      userID: userId,
      userName: 'admin',
      userDisplayName: 'Postalgic Admin',
      attestationType: 'none',
      authenticatorSelection: {
        residentKey: 'preferred',
        userVerification: 'preferred'
      }
    });

    setChallengeCookie(res, { type: 'register', challenge: options.challenge });
    res.json(options);
  } catch (err) {
    next(err);
  }
});

/**
 * POST /api/auth/register/verify
 * Verifies the registration ceremony and stores the credential. Replaces any
 * existing credential (single-passkey design).
 */
router.post('/register/verify', async (req, res, next) => {
  try {
    const existing = hasAnyCredential();
    if (existing && !isAuthenticated(req)) {
      return res.status(401).json({ error: 'Authentication required to replace passkey' });
    }

    const stored = readChallengeCookie(req);
    if (!stored || stored.type !== 'register') {
      return res.status(400).json({ error: 'Missing or invalid challenge — please retry' });
    }

    const verification = await verifyRegistrationResponse({
      response: req.body,
      expectedChallenge: stored.challenge,
      expectedOrigin: getOrigin(req),
      expectedRPID: getRpId(req),
      // Match the "preferred" UV setting on the options side: if the
      // authenticator performed UV great, but don't reject when it didn't
      // (e.g. desktop password managers without biometrics enabled).
      requireUserVerification: false
    });

    if (!verification.verified || !verification.registrationInfo) {
      clearChallengeCookie(res);
      return res.status(400).json({ error: 'Passkey registration failed' });
    }

    const { credential } = verification.registrationInfo;
    // Replace any existing credential (single-passkey design)
    deleteAllCredentials();
    saveCredential({
      id: crypto.randomUUID(),
      credentialId: credential.id,
      publicKey: Buffer.from(credential.publicKey),
      counter: credential.counter,
      transports: credential.transports,
      label: req.body?.label || null
    });

    clearChallengeCookie(res);
    setSessionCookie(res);
    res.json({ verified: true });
  } catch (err) {
    next(err);
  }
});

/**
 * POST /api/auth/authenticate/options
 * Public. Returns options for the auth ceremony.
 */
router.post('/authenticate/options', async (req, res, next) => {
  try {
    if (!hasAnyCredential()) {
      return res.status(409).json({ error: 'No passkey is registered' });
    }
    const credentials = listCredentials();
    const options = await generateAuthenticationOptions({
      rpID: getRpId(req),
      allowCredentials: credentials.map((c) => ({
        id: c.credentialId,
        transports: c.transports
      })),
      userVerification: 'preferred'
    });

    setChallengeCookie(res, { type: 'auth', challenge: options.challenge });
    res.json(options);
  } catch (err) {
    next(err);
  }
});

/**
 * POST /api/auth/authenticate/verify
 * Verifies the auth ceremony and sets the session cookie.
 */
router.post('/authenticate/verify', async (req, res, next) => {
  try {
    const stored = readChallengeCookie(req);
    if (!stored || stored.type !== 'auth') {
      return res.status(400).json({ error: 'Missing or invalid challenge — please retry' });
    }

    const credentialId = req.body?.id;
    if (!credentialId) {
      return res.status(400).json({ error: 'Missing credential id' });
    }
    const stored_credential = getCredentialByCredentialId(credentialId);
    if (!stored_credential) {
      return res.status(404).json({ error: 'Unknown credential' });
    }

    const verification = await verifyAuthenticationResponse({
      response: req.body,
      expectedChallenge: stored.challenge,
      expectedOrigin: getOrigin(req),
      expectedRPID: getRpId(req),
      requireUserVerification: false,
      credential: {
        id: stored_credential.credentialId,
        publicKey: stored_credential.publicKey,
        counter: stored_credential.counter,
        transports: stored_credential.transports
      }
    });

    if (!verification.verified) {
      clearChallengeCookie(res);
      return res.status(400).json({ error: 'Authentication failed' });
    }

    updateCredentialCounter(stored_credential.credentialId, verification.authenticationInfo.newCounter);
    clearChallengeCookie(res);
    setSessionCookie(res);
    res.json({ verified: true });
  } catch (err) {
    next(err);
  }
});

/**
 * POST /api/auth/logout
 */
router.post('/logout', (req, res) => {
  clearSessionCookie(res);
  res.json({ ok: true });
});

/**
 * GET /api/auth/passkey
 * Authenticated. Returns the registered passkey (without keying material).
 */
router.get('/passkey', (req, res) => {
  if (!isAuthenticated(req)) return res.status(401).json({ error: 'Authentication required' });
  const credentials = listCredentials();
  const c = credentials[0];
  if (!c) return res.json({ passkey: null });
  res.json({
    passkey: {
      id: c.id,
      label: c.label,
      createdAt: c.createdAt,
      lastUsedAt: c.lastUsedAt
    }
  });
});

/**
 * DELETE /api/auth/passkey
 * Authenticated. Removes the registered passkey and ends the session.
 * After this the next visit will land on the setup wizard.
 */
router.delete('/passkey', (req, res) => {
  if (!isAuthenticated(req)) return res.status(401).json({ error: 'Authentication required' });
  deleteAllCredentials();
  clearSessionCookie(res);
  res.json({ ok: true });
});

export default router;
