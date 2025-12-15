/**
 * Sync Checker Service
 *
 * Checks for changes between local and remote sync data.
 * Used for incremental sync (pull/download changes).
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
  const localContentHashes = syncConfig.localContentHashes || {};

  // Fetch remote manifest
  const manifest = await fetchManifest(syncUrl);
  const remoteVersion = manifest.syncVersion;
  const remoteFiles = manifest.files;

  // If versions match and we have hashes, no changes
  if (remoteVersion === localVersion && Object.keys(localHashes).length > 0) {
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

  // Compare file hashes
  const newFiles = [];
  const modifiedFiles = [];
  const deletedFiles = [];

  // Check for new and modified files
  for (const [filePath, fileInfo] of Object.entries(remoteFiles)) {
    if (!localHashes[filePath]) {
      // New file
      newFiles.push({
        path: filePath,
        hash: fileInfo.hash,
        contentHash: fileInfo.contentHash,
        size: fileInfo.size,
        encrypted: fileInfo.encrypted,
        iv: fileInfo.iv
      });
    } else {
      // For encrypted files (drafts), compare contentHash if available
      // This prevents false positives from random IV changes
      const localHash = localHashes[filePath];
      const localContentHash = localContentHashes?.[filePath];
      const remoteHash = fileInfo.contentHash || fileInfo.hash;
      const compareHash = localContentHash || localHash;

      if (compareHash !== remoteHash) {
        // Modified file
        modifiedFiles.push({
          path: filePath,
          hash: fileInfo.hash,
          contentHash: fileInfo.contentHash,
          size: fileInfo.size,
          encrypted: fileInfo.encrypted,
          iv: fileInfo.iv,
          oldHash: localHash,
          oldContentHash: localContentHash
        });
      }
    }
  }

  // Check for deleted files
  for (const filePath of Object.keys(localHashes)) {
    if (!remoteFiles[filePath]) {
      deletedFiles.push({
        path: filePath,
        oldHash: localHashes[filePath]
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
    drafts: { new: [], modified: [], deleted: [] },
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
    } else if (path.startsWith('drafts/') && path !== 'drafts/index.json.enc') {
      categories.drafts[list].push(file);
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
  const match = filePath.match(/\/([^/]+)\.(json|json\.enc)$/);
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
