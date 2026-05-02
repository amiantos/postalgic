import crypto from 'crypto';
import { getDatabase } from './database.js';

const SESSION_SECRET_KEY = 'session_secret';

let cachedSessionSecret = null;

/**
 * Get the session signing secret, generating and persisting one on first use.
 */
export function getSessionSecret() {
  if (cachedSessionSecret) return cachedSessionSecret;
  const db = getDatabase();
  let row = db
    .prepare('SELECT value FROM auth_settings WHERE key = ?')
    .get(SESSION_SECRET_KEY);
  if (!row) {
    const secret = crypto.randomBytes(32).toString('base64url');
    db.prepare('INSERT INTO auth_settings (key, value) VALUES (?, ?)').run(
      SESSION_SECRET_KEY,
      secret
    );
    row = { value: secret };
  }
  cachedSessionSecret = row.value;
  return cachedSessionSecret;
}

/**
 * HMAC-sign a value with the session secret. Returns "value.signature".
 */
export function signValue(value) {
  const secret = getSessionSecret();
  const sig = crypto.createHmac('sha256', secret).update(value).digest('base64url');
  return `${value}.${sig}`;
}

/**
 * Verify a signed value. Returns the original value or null if invalid.
 */
export function unsignValue(signed) {
  if (typeof signed !== 'string') return null;
  const idx = signed.lastIndexOf('.');
  if (idx === -1) return null;
  const value = signed.slice(0, idx);
  const sig = signed.slice(idx + 1);
  const secret = getSessionSecret();
  const expected = crypto.createHmac('sha256', secret).update(value).digest('base64url');
  if (sig.length !== expected.length) return null;
  try {
    if (!crypto.timingSafeEqual(Buffer.from(sig), Buffer.from(expected))) return null;
  } catch {
    return null;
  }
  return value;
}

export function listCredentials() {
  const db = getDatabase();
  return db
    .prepare(
      `SELECT id, credential_id, public_key, counter, transports, label, created_at, last_used_at
       FROM auth_credentials ORDER BY created_at ASC`
    )
    .all()
    .map(rowToCredential);
}

export function hasAnyCredential() {
  const db = getDatabase();
  const row = db.prepare('SELECT COUNT(*) as count FROM auth_credentials').get();
  return row.count > 0;
}

export function getCredentialByCredentialId(credentialId) {
  const db = getDatabase();
  const row = db
    .prepare(
      `SELECT id, credential_id, public_key, counter, transports, label, created_at, last_used_at
       FROM auth_credentials WHERE credential_id = ?`
    )
    .get(credentialId);
  return row ? rowToCredential(row) : null;
}

export function saveCredential({ id, credentialId, publicKey, counter, transports, label }) {
  const db = getDatabase();
  const transportsJson = transports ? JSON.stringify(transports) : null;
  db.prepare(
    `INSERT INTO auth_credentials (id, credential_id, public_key, counter, transports, label, created_at)
     VALUES (?, ?, ?, ?, ?, ?, ?)`
  ).run(id, credentialId, publicKey, counter, transportsJson, label || null, new Date().toISOString());
}

export function updateCredentialCounter(credentialId, counter) {
  const db = getDatabase();
  db.prepare(
    `UPDATE auth_credentials SET counter = ?, last_used_at = ? WHERE credential_id = ?`
  ).run(counter, new Date().toISOString(), credentialId);
}

export function deleteCredential(id) {
  const db = getDatabase();
  const result = db.prepare('DELETE FROM auth_credentials WHERE id = ?').run(id);
  return result.changes > 0;
}

export function deleteAllCredentials() {
  const db = getDatabase();
  db.prepare('DELETE FROM auth_credentials').run();
}

function rowToCredential(row) {
  return {
    id: row.id,
    credentialId: row.credential_id,
    publicKey: row.public_key,
    counter: row.counter,
    transports: row.transports ? JSON.parse(row.transports) : undefined,
    label: row.label,
    createdAt: row.created_at,
    lastUsedAt: row.last_used_at
  };
}
