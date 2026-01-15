/**
 * Default Mustache templates for the static site generator.
 * Templates are loaded from the templates/default directory.
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const TEMPLATES_DIR = path.join(__dirname, '../templates/default');

/**
 * Load a template file from disk
 * @param {string} filename - The template filename
 * @returns {string} The template content
 */
function loadTemplate(filename) {
  const filepath = path.join(TEMPLATES_DIR, filename);
  return fs.readFileSync(filepath, 'utf-8');
}

/**
 * Get the default templates by loading them from template files.
 * This makes templates easier to edit with proper syntax highlighting.
 * @returns {Object} Object containing all template strings
 */
export function getDefaultTemplates() {
  return {
    layout: loadTemplate('layout.mustache'),
    post: loadTemplate('post.mustache'),
    index: loadTemplate('index.mustache'),
    archives: loadTemplate('archives.mustache'),
    'monthly-archive': loadTemplate('monthly-archive.mustache'),
    tags: loadTemplate('tags.mustache'),
    tag: loadTemplate('tag.mustache'),
    categories: loadTemplate('categories.mustache'),
    category: loadTemplate('category.mustache'),
    css: loadTemplate('style.css'),
    rss: loadTemplate('rss.xml'),
    robots: loadTemplate('robots.txt'),
    sitemap: loadTemplate('sitemap.xml')
  };
}
