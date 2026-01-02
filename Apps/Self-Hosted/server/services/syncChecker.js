/**
 * Sync Checker Service
 *
 * Checks for changes between local and remote sync data.
 * Used for incremental sync (pull/download changes).
 *
 * IMPORTANT: This is part of the CROSS-PLATFORM SYNC SYSTEM, not the smart publishing system.
 * - Compares sync data hashes (blog.json, posts/*.json, etc.) NOT full site hashes
 * - localFileHashes should contain paths like: `blog.json`, `posts/xxx.json` (no sync/ prefix)
 * - Remote manifest at /sync/manifest.json contains the same path format
 * - See siteGenerator.js header for full explanation of the two hash systems
 */

import { fetchManifest } from './syncImporter.js';

/**
 * Check for remote changes that need to be synced
 * @param {Storage} storage - Storage instance
 * @param {string} blogId - The blog ID
 * @param {string} syncUrl - The remote sync URL
 * @returns {Promise<Object>} Change set with new, modified, and deleted files
 */
export async function checkForChanges(storage, blogId, syncUrl) {
  // Get local sync state
  const syncConfig = storage.getSyncConfig(blogId);
  const localVersion = syncConfig.lastSyncedVersion || 0;
  const localHashes = syncConfig.localFileHashes || {};

  // Fetch remote manifest
  const manifest = await fetchManifest(syncUrl);
  const remoteVersion = manifest.contentVersion || manifest.syncVersion;  // Support both old and new format
  const remoteFiles = manifest.files;

  // If versions match, no changes needed
  if (remoteVersion === localVersion) {
    return {
      hasChanges: false,
      localVersion,
      remoteVersion,
      newFiles: [],
      modifiedFiles: [],
      deletedFiles: [],
      manifest
    };
  }

  // Compare individual file hashes to determine actual changes
  const newFiles = [];
  const modifiedFiles = [];
  const deletedFiles = [];

  // Check each remote file against local hashes
  for (const [filePath, fileInfo] of Object.entries(remoteFiles)) {
    const localHash = localHashes[filePath];

    if (!localHash) {
      // File doesn't exist locally - it's new
      newFiles.push({
        path: filePath,
        hash: fileInfo.hash,
        size: fileInfo.size
      });
    } else if (localHash !== fileInfo.hash) {
      // File exists but hash differs - it's modified
      modifiedFiles.push({
        path: filePath,
        hash: fileInfo.hash,
        oldHash: localHash,
        size: fileInfo.size
      });
    }
    // If hashes match, file is unchanged - don't include it
  }

  // Check for deleted files (exist locally but not in remote)
  for (const [filePath, localHash] of Object.entries(localHashes)) {
    if (!remoteFiles[filePath]) {
      deletedFiles.push({
        path: filePath,
        hash: localHash
      });
    }
  }

  const hasChanges = newFiles.length > 0 || modifiedFiles.length > 0 || deletedFiles.length > 0;

  return {
    hasChanges,
    localVersion,
    remoteVersion,
    newFiles,
    modifiedFiles,
    deletedFiles,
    manifest
  };
}

/**
 * Categorize changed files by type
 * @param {Object} changeSet - The change set from checkForChanges
 * @returns {Object} Changes categorized by entity type
 */
export function categorizeChanges(changeSet) {
  const categories = {
    blog: { new: [], modified: [], deleted: [] },
    categories: { new: [], modified: [], deleted: [] },
    tags: { new: [], modified: [], deleted: [] },
    posts: { new: [], modified: [], deleted: [] },
    sidebar: { new: [], modified: [], deleted: [] },
    staticFiles: { new: [], modified: [], deleted: [] },
    embedImages: { new: [], modified: [], deleted: [] },
    themes: { new: [], modified: [], deleted: [] }
  };

  const categorizeFile = (file, list) => {
    const { path } = file;

    if (path === 'blog.json') {
      categories.blog[list].push(file);
    } else if (path.startsWith('categories/') && path !== 'categories/index.json') {
      categories.categories[list].push(file);
    } else if (path.startsWith('tags/') && path !== 'tags/index.json') {
      categories.tags[list].push(file);
    } else if (path.startsWith('posts/') && path !== 'posts/index.json') {
      categories.posts[list].push(file);
    } else if (path.startsWith('sidebar/') && path !== 'sidebar/index.json') {
      categories.sidebar[list].push(file);
    } else if (path.startsWith('static-files/') && path !== 'static-files/index.json') {
      categories.staticFiles[list].push(file);
    } else if (path.startsWith('embed-images/') && path !== 'embed-images/index.json') {
      categories.embedImages[list].push(file);
    } else if (path.startsWith('themes/')) {
      categories.themes[list].push(file);
    }
  };

  for (const file of changeSet.newFiles) {
    categorizeFile(file, 'new');
  }

  for (const file of changeSet.modifiedFiles) {
    categorizeFile(file, 'modified');
  }

  for (const file of changeSet.deletedFiles) {
    categorizeFile(file, 'deleted');
  }

  return categories;
}

/**
 * Extract entity ID from file path
 * @param {string} filePath - The file path (e.g., 'posts/abc-123.json')
 * @returns {string|null} The entity ID or null
 */
export function extractEntityId(filePath) {
  const match = filePath.match(/\/([^/]+)\.json$/);
  if (match && match[1] !== 'index') {
    return match[1];
  }
  return null;
}

export default {
  checkForChanges,
  categorizeChanges,
  extractEntityId
};
