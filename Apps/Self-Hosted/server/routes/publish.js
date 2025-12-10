import express from 'express';
import path from 'path';
import Storage from '../utils/storage.js';
import { generateSite } from '../services/siteGenerator.js';
import { createZipArchive } from '../services/archiver.js';

const router = express.Router({ mergeParams: true });

function getStorage(req) {
  return new Storage(req.app.locals.dataRoot);
}

// POST /api/blogs/:blogId/publish/generate - Generate static site
router.post('/generate', async (req, res) => {
  try {
    const storage = getStorage(req);
    const { blogId } = req.params;

    const blog = storage.getBlog(blogId);
    if (!blog) {
      return res.status(404).json({ error: 'Blog not found' });
    }

    // Generate the site
    const result = await generateSite(storage, blogId);

    res.json({
      success: true,
      message: 'Site generated successfully',
      outputDir: result.outputDir,
      fileCount: result.fileCount,
      previewUrl: `/preview/${blogId}/`
    });
  } catch (error) {
    console.error('Site generation error:', error);
    res.status(500).json({ error: error.message });
  }
});

// GET /api/blogs/:blogId/publish/preview - Get preview URL
router.get('/preview', (req, res) => {
  try {
    const storage = getStorage(req);
    const { blogId } = req.params;

    const blog = storage.getBlog(blogId);
    if (!blog) {
      return res.status(404).json({ error: 'Blog not found' });
    }

    res.json({
      previewUrl: `/preview/${blogId}/`
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// POST /api/blogs/:blogId/publish/download - Download site as ZIP
router.post('/download', async (req, res) => {
  try {
    const storage = getStorage(req);
    const { blogId } = req.params;

    const blog = storage.getBlog(blogId);
    if (!blog) {
      return res.status(404).json({ error: 'Blog not found' });
    }

    // Generate the site first
    const generateResult = await generateSite(storage, blogId);

    // Create ZIP archive
    const zipBuffer = await createZipArchive(generateResult.outputDir);

    // Generate filename with timestamp
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-').slice(0, 19);
    const filename = `${blog.name.toLowerCase().replace(/\s+/g, '-')}-${timestamp}.zip`;

    res.setHeader('Content-Type', 'application/zip');
    res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
    res.send(zipBuffer);
  } catch (error) {
    console.error('Download error:', error);
    res.status(500).json({ error: error.message });
  }
});

// GET /api/blogs/:blogId/publish/status - Get publish status
router.get('/status', (req, res) => {
  try {
    const storage = getStorage(req);
    const { blogId } = req.params;

    const blog = storage.getBlog(blogId);
    if (!blog) {
      return res.status(404).json({ error: 'Blog not found' });
    }

    const publishedFiles = storage.getPublishedFiles(blogId);

    res.json({
      publisherType: blog.publisherType || 'manual',
      lastPublishedDate: publishedFiles.lastPublishedDate,
      fileCount: Object.keys(publishedFiles.fileHashes || {}).length
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// POST /api/blogs/:blogId/publish/changes - Get list of changed files
router.post('/changes', async (req, res) => {
  try {
    const storage = getStorage(req);
    const { blogId } = req.params;

    const blog = storage.getBlog(blogId);
    if (!blog) {
      return res.status(404).json({ error: 'Blog not found' });
    }

    // Generate the site to get current file hashes
    const generateResult = await generateSite(storage, blogId);

    // Get previous published files
    const publishedFiles = storage.getPublishedFiles(blogId);
    const previousHashes = publishedFiles.fileHashes || {};

    // Compare hashes
    const currentHashes = generateResult.fileHashes;

    const modifiedFiles = [];
    const newFiles = [];
    const deletedFiles = [];

    // Find new and modified files
    for (const [filePath, hash] of Object.entries(currentHashes)) {
      if (!previousHashes[filePath]) {
        newFiles.push(filePath);
      } else if (previousHashes[filePath] !== hash) {
        // Ignore rss.xml and sitemap.xml for change detection
        if (!['rss.xml', 'sitemap.xml'].includes(filePath)) {
          modifiedFiles.push(filePath);
        }
      }
    }

    // Find deleted files
    for (const filePath of Object.keys(previousHashes)) {
      if (!currentHashes[filePath]) {
        deletedFiles.push(filePath);
      }
    }

    res.json({
      modifiedFiles,
      newFiles,
      deletedFiles,
      hasChanges: modifiedFiles.length > 0 || newFiles.length > 0 || deletedFiles.length > 0
    });
  } catch (error) {
    console.error('Changes check error:', error);
    res.status(500).json({ error: error.message });
  }
});

// POST /api/blogs/:blogId/publish/mark-published - Mark current state as published
router.post('/mark-published', async (req, res) => {
  try {
    const storage = getStorage(req);
    const { blogId } = req.params;

    const blog = storage.getBlog(blogId);
    if (!blog) {
      return res.status(404).json({ error: 'Blog not found' });
    }

    // Generate site to get current hashes
    const generateResult = await generateSite(storage, blogId);

    // Save published state
    storage.savePublishedFiles(blogId, {
      publisherType: blog.publisherType || 'manual',
      lastPublishedDate: new Date().toISOString(),
      fileHashes: generateResult.fileHashes
    });

    res.json({
      success: true,
      message: 'Published state saved',
      lastPublishedDate: new Date().toISOString()
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

export default router;
