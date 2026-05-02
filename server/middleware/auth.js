import crypto from 'crypto';
import { unsignValue } from '../utils/authStore.js';

const SESSION_COOKIE = 'postalgic_session';

/**
 * True when basic auth env vars are configured. In that mode the legacy basic
 * auth check is used and passkey auth is disabled.
 */
export function basicAuthConfigured() {
  return Boolean(process.env.BASIC_AUTH_USERNAME && process.env.BASIC_AUTH_PASSWORD);
}

/**
 * Returns the basic-auth middleware (only call when basicAuthConfigured() is true).
 */
export function basicAuthMiddleware() {
  const username = process.env.BASIC_AUTH_USERNAME;
  const password = process.env.BASIC_AUTH_PASSWORD;
  return (req, res, next) => {
    const authHeader = req.headers.authorization;
    if (authHeader && authHeader.startsWith('Basic ')) {
      const decoded = Buffer.from(authHeader.slice(6), 'base64').toString();
      const colonIndex = decoded.indexOf(':');
      if (colonIndex !== -1) {
        const user = decoded.slice(0, colonIndex);
        const pass = decoded.slice(colonIndex + 1);
        const userBuf = Buffer.from(user);
        const passBuf = Buffer.from(pass);
        const expectedUserBuf = Buffer.from(username);
        const expectedPassBuf = Buffer.from(password);
        if (
          userBuf.length === expectedUserBuf.length &&
          passBuf.length === expectedPassBuf.length &&
          crypto.timingSafeEqual(userBuf, expectedUserBuf) &&
          crypto.timingSafeEqual(passBuf, expectedPassBuf)
        ) {
          return next();
        }
      }
    }
    res.set('WWW-Authenticate', 'Basic realm="Postalgic"');
    res.status(401).send('Authentication required');
  };
}

/**
 * Read the parsed session cookie and return true if it has a valid signature.
 */
export function isAuthenticated(req) {
  const raw = req.cookies?.[SESSION_COOKIE];
  if (!raw) return false;
  return unsignValue(raw) !== null;
}

/**
 * Passkey gate. /api/auth/* is always public so the SPA can drive the login
 * and setup flows. All other API requests, plus /preview and /uploads (admin-
 * only resources), require a valid signed session cookie. The SPA shell itself
 * is served without auth so the login UI can load.
 */
export function passkeyGate() {
  return (req, res, next) => {
    if (req.path.startsWith('/api/auth/')) return next();
    const needsAuth =
      req.path.startsWith('/api/') ||
      req.path.startsWith('/preview/') ||
      req.path.startsWith('/uploads/');
    if (!needsAuth) return next();
    if (isAuthenticated(req)) return next();
    if (req.path.startsWith('/api/')) {
      return res.status(401).json({ error: 'Authentication required' });
    }
    return res.status(401).send('Authentication required');
  };
}

export const SESSION_COOKIE_NAME = SESSION_COOKIE;
