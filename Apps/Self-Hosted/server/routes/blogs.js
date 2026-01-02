import express from 'express';
import fs from 'fs';
import path from 'path';
import os from 'os';
import archiver from 'archiver';
import Storage from '../utils/storage.js';
import { generateStub } from '../utils/helpers.js';
import { generateSite } from '../services/siteGenerator.js';

const router = express.Router();

// Get storage instance
function getStorage(req) {
  return new Storage(req.app.locals.dataRoot);
}

// GET /api/blogs - List all blogs
router.get('/', (req, res) => {
  try {
    const storage = getStorage(req);
    const blogs = storage.getAllBlogs();
    res.json(blogs);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// GET /api/blogs/:id - Get single blog
router.get('/:id', (req, res) => {
  try {
    const storage = getStorage(req);
    const blog = storage.getBlog(req.params.id);

    if (!blog) {
      return res.status(404).json({ error: 'Blog not found' });
    }

    res.json(blog);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// POST /api/blogs - Create new blog
router.post('/', (req, res) => {
  try {
    const storage = getStorage(req);
    const { name, url, ...rest } = req.body;

    if (!name) {
      return res.status(400).json({ error: 'Blog name is required' });
    }

    const blogData = {
      name,
      url: url || '',
      tagline: rest.tagline || '',
      authorName: rest.authorName || '',
      authorUrl: rest.authorUrl || '',
      authorEmail: rest.authorEmail || '',
      // Theme settings
      themeIdentifier: rest.themeIdentifier || 'default',
      accentColor: rest.accentColor || '#FFA100',
      backgroundColor: rest.backgroundColor || '#efefef',
      textColor: rest.textColor || '#2d3748',
      lightShade: rest.lightShade || '#dedede',
      mediumShade: rest.mediumShade || '#a0aec0',
      darkShade: rest.darkShade || '#4a5568',
      // Publisher settings
      publisherType: rest.publisherType || 'manual',
      // AWS settings
      awsRegion: rest.awsRegion || '',
      awsS3Bucket: rest.awsS3Bucket || '',
      awsCloudFrontDistId: rest.awsCloudFrontDistId || '',
      awsAccessKeyId: rest.awsAccessKeyId || '',
      awsSecretAccessKey: rest.awsSecretAccessKey || '',
      // SFTP settings
      ftpHost: rest.ftpHost || '',
      ftpPort: rest.ftpPort || 22,
      ftpUsername: rest.ftpUsername || '',
      ftpPassword: rest.ftpPassword || '',
      ftpPrivateKey: rest.ftpPrivateKey || '',
      ftpPath: rest.ftpPath || '',
      // Git settings
      gitRepositoryUrl: rest.gitRepositoryUrl || '',
      gitUsername: rest.gitUsername || '',
      gitToken: rest.gitToken || '',
      gitBranch: rest.gitBranch || 'main',
      gitCommitMessage: rest.gitCommitMessage || 'Update blog'
    };

    const blog = storage.createBlog(blogData);
    res.status(201).json(blog);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// PUT /api/blogs/:id - Update blog
router.put('/:id', (req, res) => {
  try {
    const storage = getStorage(req);
    const blog = storage.updateBlog(req.params.id, req.body);
    res.json(blog);
  } catch (error) {
    if (error.message.includes('not found')) {
      return res.status(404).json({ error: error.message });
    }
    res.status(500).json({ error: error.message });
  }
});

// DELETE /api/blogs/:id - Delete blog
router.delete('/:id', (req, res) => {
  try {
    const storage = getStorage(req);
    storage.deleteBlog(req.params.id);
    res.status(204).send();
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// GET /api/blogs/:id/stats - Get blog statistics
router.get('/:id/stats', (req, res) => {
  try {
    const storage = getStorage(req);
    const blog = storage.getBlog(req.params.id);

    if (!blog) {
      return res.status(404).json({ error: 'Blog not found' });
    }

    const posts = storage.getAllPosts(req.params.id, true);
    const categories = storage.getAllCategories(req.params.id);
    const tags = storage.getAllTags(req.params.id);

    res.json({
      totalPosts: posts.length,
      publishedPosts: posts.filter(p => !p.isDraft).length,
      draftPosts: posts.filter(p => p.isDraft).length,
      totalCategories: categories.length,
      totalTags: tags.length
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// GET /api/blogs/:id/debug-export - Export full site bundle for debugging
router.get('/:id/debug-export', async (req, res) => {
  try {
    const storage = getStorage(req);
    const blog = storage.getBlog(req.params.id);

    if (!blog) {
      return res.status(404).json({ error: 'Blog not found' });
    }

    // Generate the full site (includes sync directory)
    await generateSite(storage, req.params.id);

    // Get the generated site directory
    const siteDir = storage.getGeneratedSiteDir(req.params.id);

    // Create temp directory for the zip
    const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'postalgic-debug-'));
    const zipPath = path.join(tempDir, `debug-export-${blog.id}.zip`);
    const output = fs.createWriteStream(zipPath);
    const archive = archiver('zip', { zlib: { level: 9 } });

    output.on('close', () => {
      // Send the zip file
      res.download(zipPath, `postalgic-debug-${blog.id}.zip`, (err) => {
        // Cleanup temp directory
        fs.rmSync(tempDir, { recursive: true, force: true });
        if (err && !res.headersSent) {
          res.status(500).json({ error: 'Failed to send zip file' });
        }
      });
    });

    archive.on('error', (err) => {
      fs.rmSync(tempDir, { recursive: true, force: true });
      res.status(500).json({ error: err.message });
    });

    archive.pipe(output);
    archive.directory(siteDir, false);
    await archive.finalize();

  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

export default router;
