/**
 * Sync API routes
 * Handles sync import and configuration
 */

import express from 'express';
import Storage from '../utils/storage.js';
import { fetchManifest, importBlog } from '../services/syncImporter.js';
import { checkForChanges, categorizeChanges, extractEntityId } from '../services/syncChecker.js';
import { pullChanges } from '../services/incrementalSync.js';

const router = express.Router();

// Get storage instance
function getStorage(req) {
  return new Storage(req.app.locals.dataRoot);
}

/**
 * POST /api/sync/check
 * Checks a URL for sync capability and returns manifest info
 */
router.post('/check', async (req, res) => {
  try {
    const { url } = req.body;

    if (!url) {
      return res.status(400).json({ error: 'URL is required' });
    }

    const manifest = await fetchManifest(url);

    res.json({
      success: true,
      manifest: {
        blogName: manifest.blogName,
        contentVersion: manifest.contentVersion || manifest.syncVersion,
        lastModified: manifest.lastModified,
        appSource: manifest.appSource,
        fileCount: manifest.fileCount || Object.keys(manifest.files).length
      }
    });
  } catch (error) {
    console.error('[Sync] Check failed:', error);
    res.status(400).json({ error: error.message });
  }
});

/**
 * POST /api/sync/import
 * Imports a blog from a sync URL
 * Note: Drafts are no longer synced - only published content is imported
 */
router.post('/import', async (req, res) => {
  try {
    const { url } = req.body;

    if (!url) {
      return res.status(400).json({ error: 'URL is required' });
    }

    const storage = getStorage(req);

    // First check the manifest
    const manifest = await fetchManifest(url);

    // Import the blog (no password needed - drafts are not synced)
    const blog = await importBlog(storage, url, null, (progress) => {
      console.log(`[Sync Import] ${progress.step} (${progress.downloaded}/${progress.total})`);
    });

    res.json({
      success: true,
      blogId: blog.id,
      blogName: blog.name,
      message: 'Blog imported successfully'
    });
  } catch (error) {
    console.error('[Sync] Import failed:', error);
    res.status(400).json({ error: error.message });
  }
});

/**
 * GET /api/blogs/:blogId/sync/status
 * Gets sync status for a blog
 */
router.get('/blogs/:blogId/status', (req, res) => {
  try {
    const { blogId } = req.params;
    const storage = getStorage(req);

    const syncConfig = storage.getSyncConfig(blogId);

    res.json({
      lastSyncedAt: syncConfig.lastSyncedAt,
      lastSyncedVersion: syncConfig.lastSyncedVersion
    });
  } catch (error) {
    console.error('[Sync] Get status failed:', error);
    res.status(500).json({ error: error.message });
  }
});

/**
 * POST /api/blogs/:blogId/sync/check-changes
 * Checks for remote changes that need to be synced
 */
router.post('/blogs/:blogId/check-changes', async (req, res) => {
  try {
    const { blogId } = req.params;
    const storage = getStorage(req);

    const blog = storage.getBlog(blogId);
    if (!blog) {
      return res.status(404).json({ error: 'Blog not found' });
    }

    if (!blog.url) {
      return res.status(400).json({ error: 'Blog URL is not configured' });
    }

    console.log('[Sync Check] Starting change check for blog:', blogId);
    console.log('[Sync Check] Blog URL:', blog.url);

    const changeSet = await checkForChanges(storage, blogId, blog.url);

    console.log('[Sync Check] Local version:', changeSet.localVersion);
    console.log('[Sync Check] Remote version:', changeSet.remoteVersion);
    console.log('[Sync Check] Has changes:', changeSet.hasChanges);

    // Categorize changes by entity type
    const categorized = categorizeChanges(changeSet);

    // Build detailed change info with entity IDs
    const buildDetailedChanges = (category, entityType) => {
      const result = { new: [], modified: [], deleted: [] };

      for (const file of category.new) {
        const id = extractEntityId(file.path);
        result.new.push({ id, path: file.path, hash: file.hash });
        console.log(`[Sync Check] NEW ${entityType}: ${file.path} (hash: ${file.hash?.substring(0, 8)}...)`);
      }

      for (const file of category.modified) {
        const id = extractEntityId(file.path);
        result.modified.push({ id, path: file.path, hash: file.hash, oldHash: file.oldHash });
        console.log(`[Sync Check] MODIFIED ${entityType}: ${file.path} (hash: ${file.hash?.substring(0, 8)}... <- ${file.oldHash?.substring(0, 8)}...)`);
      }

      for (const file of category.deleted) {
        const id = extractEntityId(file.path);
        result.deleted.push({ id, path: file.path });
        console.log(`[Sync Check] DELETED ${entityType}: ${file.path}`);
      }

      return result;
    };

    const details = {
      blog: buildDetailedChanges(categorized.blog, 'blog'),
      categories: buildDetailedChanges(categorized.categories, 'category'),
      tags: buildDetailedChanges(categorized.tags, 'tag'),
      posts: buildDetailedChanges(categorized.posts, 'post'),
      drafts: buildDetailedChanges(categorized.drafts, 'draft'),
      sidebar: buildDetailedChanges(categorized.sidebar, 'sidebar'),
      staticFiles: buildDetailedChanges(categorized.staticFiles, 'staticFile'),
      embedImages: buildDetailedChanges(categorized.embedImages, 'embedImage'),
      themes: buildDetailedChanges(categorized.themes, 'theme')
    };

    // Log local file hashes for debugging
    const syncConfig = storage.getSyncConfig(blogId);
    console.log('[Sync Check] Local hashes count:', Object.keys(syncConfig.localFileHashes || {}).length);
    if (syncConfig.localFileHashes) {
      console.log('[Sync Check] Local hashes sample:');
      const entries = Object.entries(syncConfig.localFileHashes).slice(0, 5);
      for (const [path, hash] of entries) {
        console.log(`  ${path}: ${hash?.substring(0, 8)}...`);
      }
    }

    res.json({
      hasChanges: changeSet.hasChanges,
      localVersion: changeSet.localVersion,
      remoteVersion: changeSet.remoteVersion,
      summary: {
        new: changeSet.newFiles.length,
        modified: changeSet.modifiedFiles.length,
        deleted: changeSet.deletedFiles.length
      },
      details,
      blogName: changeSet.manifest?.blogName,
      lastModified: changeSet.manifest?.lastModified
    });
  } catch (error) {
    console.error('[Sync] Check changes failed:', error);
    res.status(400).json({ error: error.message });
  }
});

/**
 * POST /api/blogs/:blogId/sync/pull
 * Pulls (downloads) changes from remote to local
 * Note: Drafts are no longer synced - only published content is pulled
 */
router.post('/blogs/:blogId/pull', async (req, res) => {
  try {
    const { blogId } = req.params;
    const storage = getStorage(req);

    const blog = storage.getBlog(blogId);
    if (!blog) {
      return res.status(404).json({ error: 'Blog not found' });
    }

    if (!blog.url) {
      return res.status(400).json({ error: 'Blog URL is not configured' });
    }

    // No password needed - drafts are not synced
    const result = await pullChanges(storage, blogId, blog.url, null, (progress) => {
      console.log(`[Sync Pull] ${progress.step} (${progress.phase})`);
    });

    res.json(result);
  } catch (error) {
    console.error('[Sync] Pull failed:', error);
    res.status(400).json({ error: error.message });
  }
});

export default router;
