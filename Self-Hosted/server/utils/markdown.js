/**
 * Markdown Utility Module
 *
 * Provides consistent markdown rendering across the application.
 * HTML is pre-rendered when posts/sidebar objects are created/updated,
 * stored in the database, and synced between clients.
 */

import { marked } from 'marked';

// Configure marked to not HTML-encode apostrophes and quotes
// This matches the behavior of the iOS Ink markdown parser
marked.use({
  renderer: {
    text(token) {
      // Return raw text without HTML entity encoding for quotes/apostrophes
      // This ensures cross-platform consistency with iOS
      return token.raw;
    }
  }
});

/**
 * Render markdown and normalize output to match iOS Ink parser behavior
 * - Removes newlines between HTML tags (e.g., </p>\n<p> → </p><p>)
 * - Strips trailing whitespace
 * @param {string} markdown - The markdown content to render
 * @returns {string} - Normalized HTML output
 */
export function renderMarkdown(markdown) {
  if (!markdown) return '';
  return marked(markdown)
    // Remove newlines between HTML tags to match iOS Ink behavior
    .replace(/>\s*\n\s*</g, '><')
    // Strip trailing whitespace from inside paragraph tags
    .replace(/<p>([^<]*?) <\/p>/g, '<p>$1</p>')
    // Trim trailing whitespace
    .trim();
}
