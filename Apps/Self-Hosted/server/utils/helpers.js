import crypto from 'crypto';

/**
 * Generate a URL-safe slug from text.
 * Matches iOS app behavior: lowercase, alphanumeric + hyphens, max 50 chars
 */
export function generateStub(text) {
  if (!text) return null;

  let stub = text
    // Normalize unicode (convert accented chars)
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    // Lowercase
    .toLowerCase()
    // Replace non-alphanumeric with hyphens
    .replace(/[^a-z0-9]+/g, '-')
    // Collapse multiple hyphens
    .replace(/-+/g, '-')
    // Trim hyphens from start/end
    .replace(/^-|-$/g, '');

  // Limit to 50 chars at word boundary
  if (stub.length > 50) {
    stub = stub.substring(0, 50);
    const lastHyphen = stub.lastIndexOf('-');
    if (lastHyphen > 30) {
      stub = stub.substring(0, lastHyphen);
    }
  }

  return stub || null;
}

/**
 * Make a stub unique by appending -2, -3, etc. if needed
 */
export function makeStubUnique(stub, existingStubs, currentId = null) {
  if (!stub) return stub;

  // Filter out current item's stub from check
  const otherStubs = existingStubs.filter((s, id) =>
    id !== currentId && s === stub
  );

  if (!existingStubs.includes(stub)) {
    return stub;
  }

  let counter = 2;
  let uniqueStub = `${stub}-${counter}`;

  while (existingStubs.includes(uniqueStub)) {
    counter++;
    uniqueStub = `${stub}-${counter}`;
  }

  return uniqueStub;
}

/**
 * Get date parts (year, month, day) in a specific timezone
 */
export function getDatePartsInTimezone(dateString, timezone = 'UTC') {
  const date = new Date(dateString);
  const formatter = new Intl.DateTimeFormat('en-US', {
    timeZone: timezone,
    year: 'numeric',
    month: 'numeric',
    day: 'numeric'
  });
  const parts = formatter.formatToParts(date);
  return {
    year: parseInt(parts.find(p => p.type === 'year').value),
    month: parseInt(parts.find(p => p.type === 'month').value),
    day: parseInt(parts.find(p => p.type === 'day').value)
  };
}

/**
 * Format date for URL path (yyyy/MM/dd)
 */
export function formatDatePath(dateString, timezone = 'UTC') {
  const { year, month, day } = getDatePartsInTimezone(dateString, timezone);
  return `${year}/${String(month).padStart(2, '0')}/${String(day).padStart(2, '0')}`;
}

/**
 * Format date for display
 */
export function formatDate(dateString, timezone = 'UTC', options = {}) {
  const date = new Date(dateString);

  const defaultOptions = {
    timeZone: timezone,
    year: 'numeric',
    month: 'long',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit'
  };

  return date.toLocaleDateString('en-US', { ...defaultOptions, ...options });
}

/**
 * Format date for short display
 */
export function formatShortDate(dateString, timezone = 'UTC') {
  const date = new Date(dateString);
  return date.toLocaleDateString('en-US', {
    timeZone: timezone,
    year: 'numeric',
    month: 'short',
    day: 'numeric'
  });
}

/**
 * Format date for RFC 822 (RSS feeds)
 */
export function formatRFC822Date(dateString) {
  const date = new Date(dateString);
  return date.toUTCString();
}

/**
 * Format date for ISO 8601
 */
export function formatISO8601Date(dateString) {
  const date = new Date(dateString);
  return date.toISOString();
}

/**
 * Get month name from date
 */
export function getMonthName(dateString, timezone = 'UTC') {
  const date = new Date(dateString);
  return date.toLocaleDateString('en-US', { timeZone: timezone, month: 'long' });
}

/**
 * Calculate SHA256 hash of content
 */
export function calculateHash(content) {
  return crypto.createHash('sha256').update(content).digest('hex');
}

/**
 * Calculate SHA256 hash of a buffer
 */
export function calculateBufferHash(buffer) {
  return crypto.createHash('sha256').update(buffer).digest('hex');
}

/**
 * Extract YouTube video ID from URL
 */
export function extractYouTubeId(url) {
  if (!url) return null;

  const patterns = [
    /(?:youtube\.com\/watch\?v=|youtu\.be\/|youtube\.com\/embed\/|youtube\.com\/live\/)([^&\n?#]+)/,
    /youtube\.com\/shorts\/([^&\n?#]+)/
  ];

  for (const pattern of patterns) {
    const match = url.match(pattern);
    if (match) return match[1];
  }

  return null;
}

/**
 * Get MIME type from filename
 */
export function getMimeType(filename) {
  const ext = filename.toLowerCase().split('.').pop();
  const mimeTypes = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'gif': 'image/gif',
    'webp': 'image/webp',
    'svg': 'image/svg+xml',
    'ico': 'image/x-icon',
    'css': 'text/css',
    'js': 'application/javascript',
    'json': 'application/json',
    'html': 'text/html',
    'txt': 'text/plain',
    'xml': 'application/xml',
    'pdf': 'application/pdf'
  };

  return mimeTypes[ext] || 'application/octet-stream';
}

/**
 * Check if file is an image
 */
export function isImageFile(filename) {
  const ext = filename.toLowerCase().split('.').pop();
  return ['jpg', 'jpeg', 'png', 'gif', 'webp', 'svg'].includes(ext);
}

/**
 * Strip markdown formatting from text
 */
export function stripMarkdown(text) {
  if (!text) return '';

  return text
    // Remove headers
    .replace(/^#{1,6}\s+/gm, '')
    // Remove emphasis
    .replace(/(\*\*|__)(.*?)\1/g, '$2')
    .replace(/(\*|_)(.*?)\1/g, '$2')
    // Remove strikethrough
    .replace(/~~(.*?)~~/g, '$1')
    // Remove inline code
    .replace(/`([^`]+)`/g, '$1')
    // Remove code blocks
    .replace(/```[\s\S]*?```/g, '')
    // Remove links, keep text
    .replace(/\[([^\]]+)\]\([^)]+\)/g, '$1')
    // Remove images
    .replace(/!\[([^\]]*)\]\([^)]+\)/g, '$1')
    // Remove blockquotes
    .replace(/^>\s+/gm, '')
    // Remove horizontal rules
    .replace(/^[-*_]{3,}\s*$/gm, '')
    // Remove list markers
    .replace(/^[\s]*[-*+]\s+/gm, '')
    .replace(/^[\s]*\d+\.\s+/gm, '')
    // Clean up whitespace
    .replace(/\n{3,}/g, '\n\n')
    .trim();
}

/**
 * Get excerpt from content
 */
export function getExcerpt(content, maxLength = 150) {
  const plain = stripMarkdown(content);
  if (plain.length <= maxLength) return plain;

  const truncated = plain.substring(0, maxLength);
  const lastSpace = truncated.lastIndexOf(' ');

  return (lastSpace > maxLength * 0.7 ? truncated.substring(0, lastSpace) : truncated) + '...';
}

/**
 * Sanitize filename for storage
 */
export function sanitizeFilename(filename) {
  return filename
    .replace(/[^a-zA-Z0-9._-]/g, '_')
    .replace(/_+/g, '_')
    .toLowerCase();
}

/**
 * Get file extension
 */
export function getFileExtension(filename) {
  const parts = filename.split('.');
  return parts.length > 1 ? parts.pop().toLowerCase() : '';
}

/**
 * Generate a unique filename for embed images
 * Matches iOS format: embed-{timestamp}-{random}-{index}.{ext}
 */
export function generateEmbedFilename(ext, index = 0) {
  const timestamp = Math.floor(Date.now() / 1000);
  const random = crypto.randomBytes(4).toString('hex').toUpperCase();
  const paddedIndex = String(index).padStart(2, '0');
  return `embed-${timestamp}-${random}-${paddedIndex}.${ext}`;
}
