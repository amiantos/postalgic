import express from 'express';
import Storage from '../utils/storage.js';
import { generateStub } from '../utils/helpers.js';

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
      accentColor: rest.accentColor || '#007AFF',
      backgroundColor: rest.backgroundColor || '#FFFFFF',
      textColor: rest.textColor || '#000000',
      lightShade: rest.lightShade || '#F5F5F5',
      mediumShade: rest.mediumShade || '#E0E0E0',
      darkShade: rest.darkShade || '#333333',
      // Publisher settings (stored but not used for secrets)
      publisherType: rest.publisherType || 'manual',
      // AWS settings
      awsRegion: rest.awsRegion || '',
      awsS3Bucket: rest.awsS3Bucket || '',
      awsCloudFrontDistId: rest.awsCloudFrontDistId || '',
      awsAccessKeyId: rest.awsAccessKeyId || '',
      // FTP settings
      ftpHost: rest.ftpHost || '',
      ftpPort: rest.ftpPort || 22,
      ftpUsername: rest.ftpUsername || '',
      ftpPath: rest.ftpPath || '',
      ftpUseSFTP: rest.ftpUseSFTP !== false,
      // Git settings
      gitRepositoryUrl: rest.gitRepositoryUrl || '',
      gitUsername: rest.gitUsername || '',
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

export default router;
