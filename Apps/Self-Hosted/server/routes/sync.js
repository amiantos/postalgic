/**
 * Sync API routes
 * Handles sync import and configuration
 */

import express from 'express';
import Storage from '../utils/storage.js';
import { fetchManifest, importBlog } from '../services/syncImporter.js';

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
        syncVersion: manifest.syncVersion,
        lastModified: manifest.lastModified,
        appSource: manifest.appSource,
        hasDrafts: manifest.hasDrafts,
        fileCount: Object.keys(manifest.files).length
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
 */
router.post('/import', async (req, res) => {
  try {
    const { url, password } = req.body;

    if (!url) {
      return res.status(400).json({ error: 'URL is required' });
    }

    const storage = getStorage(req);

    // First check the manifest
    const manifest = await fetchManifest(url);

    // Verify password is provided if needed
    if (manifest.hasDrafts && !password) {
      return res.status(400).json({
        error: 'Password required',
        needsPassword: true,
        manifest: {
          blogName: manifest.blogName,
          hasDrafts: manifest.hasDrafts
        }
      });
    }

    // Import the blog
    const blog = await importBlog(storage, url, password, (progress) => {
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
      enabled: syncConfig.syncEnabled,
      lastSyncedAt: syncConfig.lastSyncedAt,
      lastSyncedVersion: syncConfig.lastSyncedVersion,
      hasPassword: !!syncConfig.syncPassword
    });
  } catch (error) {
    console.error('[Sync] Get status failed:', error);
    res.status(500).json({ error: error.message });
  }
});

/**
 * POST /api/blogs/:blogId/sync/enable
 * Enables sync for a blog
 */
router.post('/blogs/:blogId/enable', (req, res) => {
  try {
    const { blogId } = req.params;
    const { password } = req.body;
    const storage = getStorage(req);

    if (!password) {
      return res.status(400).json({ error: 'Password is required' });
    }

    const existingConfig = storage.getSyncConfig(blogId);

    storage.saveSyncConfig(blogId, {
      ...existingConfig,
      syncEnabled: true,
      syncPassword: password
    });

    res.json({ success: true });
  } catch (error) {
    console.error('[Sync] Enable failed:', error);
    res.status(500).json({ error: error.message });
  }
});

/**
 * POST /api/blogs/:blogId/sync/disable
 * Disables sync for a blog
 */
router.post('/blogs/:blogId/disable', (req, res) => {
  try {
    const { blogId } = req.params;
    const storage = getStorage(req);

    const existingConfig = storage.getSyncConfig(blogId);

    storage.saveSyncConfig(blogId, {
      ...existingConfig,
      syncEnabled: false
    });

    res.json({ success: true });
  } catch (error) {
    console.error('[Sync] Disable failed:', error);
    res.status(500).json({ error: error.message });
  }
});

/**
 * POST /api/blogs/:blogId/sync/password
 * Updates the sync password for a blog
 */
router.post('/blogs/:blogId/password', (req, res) => {
  try {
    const { blogId } = req.params;
    const { password } = req.body;
    const storage = getStorage(req);

    if (!password) {
      return res.status(400).json({ error: 'Password is required' });
    }

    const existingConfig = storage.getSyncConfig(blogId);

    storage.saveSyncConfig(blogId, {
      ...existingConfig,
      syncPassword: password
    });

    res.json({ success: true });
  } catch (error) {
    console.error('[Sync] Update password failed:', error);
    res.status(500).json({ error: error.message });
  }
});

export default router;
