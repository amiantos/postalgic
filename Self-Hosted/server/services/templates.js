/**
 * Mustache templates for the static site generator.
 * Templates are loaded from the templates directory.
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const TEMPLATES_BASE_DIR = path.join(__dirname, '../templates');

/**
 * Load a template file from disk
 * @param {string} themeDir - The theme directory name
 * @param {string} filename - The template filename
 * @returns {string} The template content
 */
function loadTemplate(themeDir, filename) {
  const filepath = path.join(TEMPLATES_BASE_DIR, themeDir, filename);
  return fs.readFileSync(filepath, 'utf-8');
}

/**
 * Load all templates for a given theme directory
 * @param {string} themeDir - The theme directory name
 * @returns {Object} Object containing all template strings
 */
function loadThemeTemplates(themeDir) {
  return {
    layout: loadTemplate(themeDir, 'layout.mustache'),
    post: loadTemplate(themeDir, 'post.mustache'),
    index: loadTemplate(themeDir, 'index.mustache'),
    archives: loadTemplate(themeDir, 'archives.mustache'),
    'monthly-archive': loadTemplate(themeDir, 'monthly-archive.mustache'),
    tags: loadTemplate(themeDir, 'tags.mustache'),
    tag: loadTemplate(themeDir, 'tag.mustache'),
    categories: loadTemplate(themeDir, 'categories.mustache'),
    category: loadTemplate(themeDir, 'category.mustache'),
    css: loadTemplate(themeDir, 'style.css'),
    rss: loadTemplate(themeDir, 'rss.xml'),
    robots: loadTemplate(themeDir, 'robots.txt'),
    sitemap: loadTemplate(themeDir, 'sitemap.xml')
  };
}

/**
 * Get the default templates by loading them from template files.
 * This makes templates easier to edit with proper syntax highlighting.
 * @returns {Object} Object containing all template strings
 */
export function getDefaultTemplates() {
  return loadThemeTemplates('default');
}

/**
 * Get the brutalist templates by loading them from template files.
 * @returns {Object} Object containing all template strings
 */
export function getBrutalistTemplates() {
  return loadThemeTemplates('brutalist');
}

/**
 * Get templates for a built-in theme by identifier
 * @param {string} identifier - The theme identifier
 * @returns {Object|null} Object containing all template strings, or null if not found
 */
export function getBuiltInTemplates(identifier) {
  switch (identifier) {
    case 'default':
      return getDefaultTemplates();
    case 'brutalist':
      return getBrutalistTemplates();
    default:
      return null;
  }
}
