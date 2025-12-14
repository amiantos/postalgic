/**
 * Sync encryption utilities using AES-256-GCM
 * Compatible with iOS SyncEncryption.swift implementation
 */

import crypto from 'crypto';

// Constants matching iOS implementation
const PBKDF2_ITERATIONS = 100000;
const SALT_SIZE = 16;
const IV_SIZE = 12;
const KEY_SIZE = 32; // 256 bits
const TAG_SIZE = 16; // 128 bits

/**
 * Derives a key from a password using PBKDF2
 * @param {string} password - The password to derive the key from
 * @param {Buffer} salt - The salt to use (16 bytes)
 * @returns {Buffer} The derived 256-bit key
 */
export function deriveKey(password, salt) {
  return crypto.pbkdf2Sync(password, salt, PBKDF2_ITERATIONS, KEY_SIZE, 'sha256');
}

/**
 * Generates a random salt for key derivation
 * @returns {Buffer} 16 random bytes
 */
export function generateSalt() {
  return crypto.randomBytes(SALT_SIZE);
}

/**
 * Generates a random IV/nonce for encryption
 * @returns {Buffer} 12 random bytes
 */
export function generateIV() {
  return crypto.randomBytes(IV_SIZE);
}

/**
 * Encrypts data using AES-256-GCM
 * @param {Buffer|string} data - The data to encrypt
 * @param {Buffer} key - The encryption key
 * @param {Buffer} [iv] - Optional IV (will be generated if not provided)
 * @returns {{ ciphertext: Buffer, iv: Buffer }} The ciphertext (including auth tag) and IV
 */
export function encrypt(data, key, iv = null) {
  if (!iv) {
    iv = generateIV();
  }

  const cipher = crypto.createCipheriv('aes-256-gcm', key, iv);

  // Convert string to buffer if needed
  const dataBuffer = Buffer.isBuffer(data) ? data : Buffer.from(data, 'utf8');

  const encrypted = Buffer.concat([cipher.update(dataBuffer), cipher.final()]);
  const tag = cipher.getAuthTag();

  // Combine ciphertext and tag (matches iOS format)
  const ciphertext = Buffer.concat([encrypted, tag]);

  return { ciphertext, iv };
}

/**
 * Decrypts data using AES-256-GCM
 * @param {Buffer} ciphertext - The encrypted data (ciphertext + auth tag)
 * @param {Buffer} iv - The IV that was used for encryption
 * @param {Buffer} key - The decryption key
 * @returns {Buffer} The decrypted data
 * @throws {Error} If decryption fails (wrong key, corrupted data, etc.)
 */
export function decrypt(ciphertext, iv, key) {
  if (ciphertext.length <= TAG_SIZE) {
    throw new Error('Invalid ciphertext: too short');
  }

  // Separate ciphertext and tag (tag is last 16 bytes)
  const encrypted = ciphertext.slice(0, -TAG_SIZE);
  const tag = ciphertext.slice(-TAG_SIZE);

  const decipher = crypto.createDecipheriv('aes-256-gcm', key, iv);
  decipher.setAuthTag(tag);

  return Buffer.concat([decipher.update(encrypted), decipher.final()]);
}

/**
 * Encrypts a JSON object
 * @param {Object} obj - The object to encrypt
 * @param {string} password - The password to use
 * @param {Buffer} salt - The salt for key derivation
 * @returns {{ ciphertext: Buffer, iv: Buffer }} The encrypted data and IV
 */
export function encryptJSON(obj, password, salt) {
  const key = deriveKey(password, salt);
  const jsonData = JSON.stringify(obj);
  return encrypt(jsonData, key);
}

/**
 * Decrypts data to a JSON object
 * @param {Buffer} ciphertext - The encrypted data
 * @param {Buffer} iv - The IV used for encryption
 * @param {string} password - The password to use
 * @param {Buffer} salt - The salt for key derivation
 * @returns {Object} The decrypted JSON object
 */
export function decryptJSON(ciphertext, iv, password, salt) {
  const key = deriveKey(password, salt);
  const jsonData = decrypt(ciphertext, iv, key);
  return JSON.parse(jsonData.toString('utf8'));
}

/**
 * Encodes data to base64
 * @param {Buffer} data - The data to encode
 * @returns {string} Base64-encoded string
 */
export function base64Encode(data) {
  return data.toString('base64');
}

/**
 * Decodes base64 to data
 * @param {string} str - The base64 string to decode
 * @returns {Buffer} Decoded data
 */
export function base64Decode(str) {
  return Buffer.from(str, 'base64');
}

export default {
  deriveKey,
  generateSalt,
  generateIV,
  encrypt,
  decrypt,
  encryptJSON,
  decryptJSON,
  base64Encode,
  base64Decode,
  PBKDF2_ITERATIONS,
  SALT_SIZE,
  IV_SIZE,
  KEY_SIZE,
  TAG_SIZE
};
