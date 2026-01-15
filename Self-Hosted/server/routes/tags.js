import express from 'express';
import Storage from '../utils/storage.js';
import { generateStub, makeStubUnique } from '../utils/helpers.js';

const router = express.Router({ mergeParams: true });

function getStorage(req) {
  return new Storage(req.app.locals.dataRoot);
}

// GET /api/blogs/:blogId/tags - List all tags
router.get('/', (req, res) => {
  try {
    const storage = getStorage(req);
    const { blogId } = req.params;

    const tags = storage.getAllTags(blogId);

    // Enrich with post counts
    const posts = storage.getAllPosts(blogId, 'published');
    const enrichedTags = tags.map(tag => ({
      ...tag,
      postCount: posts.filter(p => p.tagIds && p.tagIds.includes(tag.id)).length,
      urlPath: `tags/${tag.stub}`
    }));

    res.json(enrichedTags);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// GET /api/blogs/:blogId/tags/:id - Get single tag
router.get('/:id', (req, res) => {
  try {
    const storage = getStorage(req);
    const { blogId, id } = req.params;

    const tag = storage.getTag(blogId, id);

    if (!tag) {
      return res.status(404).json({ error: 'Tag not found' });
    }

    // Enrich with post count
    const posts = storage.getAllPosts(blogId, 'published');
    const enriched = {
      ...tag,
      postCount: posts.filter(p => p.tagIds && p.tagIds.includes(tag.id)).length,
      urlPath: `tags/${tag.stub}`
    };

    res.json(enriched);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// POST /api/blogs/:blogId/tags - Create new tag
router.post('/', (req, res) => {
  try {
    const storage = getStorage(req);
    const { blogId } = req.params;
    const { name } = req.body;

    if (!name) {
      return res.status(400).json({ error: 'Tag name is required' });
    }

    // Lowercase name (tags are always lowercase)
    const lowercaseName = name.toLowerCase();

    // Check for duplicate tag name
    const existingTags = storage.getAllTags(blogId);
    const duplicate = existingTags.find(t => t.name === lowercaseName);
    if (duplicate) {
      return res.status(400).json({ error: 'Tag already exists' });
    }

    // Generate unique stub
    const baseStub = generateStub(lowercaseName);
    const existingStubs = existingTags.map(t => t.stub);
    const stub = makeStubUnique(baseStub, existingStubs);

    const tagData = {
      name: lowercaseName,
      stub
    };

    const tag = storage.createTag(blogId, tagData);
    res.status(201).json({
      ...tag,
      postCount: 0,
      urlPath: `tags/${tag.stub}`
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// PUT /api/blogs/:blogId/tags/:id - Update tag
router.put('/:id', (req, res) => {
  try {
    const storage = getStorage(req);
    const { blogId, id } = req.params;
    const { name } = req.body;

    const existingTag = storage.getTag(blogId, id);
    if (!existingTag) {
      return res.status(404).json({ error: 'Tag not found' });
    }

    if (!name) {
      return res.status(400).json({ error: 'Tag name is required' });
    }

    // Lowercase name
    const lowercaseName = name.toLowerCase();

    // Check for duplicate (excluding current tag)
    const existingTags = storage.getAllTags(blogId);
    const duplicate = existingTags.find(t => t.name === lowercaseName && t.id !== id);
    if (duplicate) {
      return res.status(400).json({ error: 'Tag already exists' });
    }

    // Regenerate stub
    const baseStub = generateStub(lowercaseName);
    const existingStubs = existingTags
      .filter(t => t.id !== id)
      .map(t => t.stub);
    const stub = makeStubUnique(baseStub, existingStubs);

    const tag = storage.updateTag(blogId, id, { name: lowercaseName, stub });

    // Enrich with post count
    const posts = storage.getAllPosts(blogId, 'published');
    res.json({
      ...tag,
      postCount: posts.filter(p => p.tagIds && p.tagIds.includes(tag.id)).length,
      urlPath: `tags/${tag.stub}`
    });
  } catch (error) {
    if (error.message.includes('not found')) {
      return res.status(404).json({ error: error.message });
    }
    res.status(500).json({ error: error.message });
  }
});

// DELETE /api/blogs/:blogId/tags/:id - Delete tag
router.delete('/:id', (req, res) => {
  try {
    const storage = getStorage(req);
    const { blogId, id } = req.params;

    // Remove tag from all posts
    const posts = storage.getAllPosts(blogId, 'all');
    for (const post of posts) {
      if (post.tagIds && post.tagIds.includes(id)) {
        const newTagIds = post.tagIds.filter(t => t !== id);
        storage.updatePost(blogId, post.id, { tagIds: newTagIds });
      }
    }

    storage.deleteTag(blogId, id);
    res.status(204).send();
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

export default router;
