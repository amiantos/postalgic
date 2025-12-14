import express from 'express';
import Storage from '../utils/storage.js';
import { generateStub, makeStubUnique } from '../utils/helpers.js';

const router = express.Router({ mergeParams: true });

function getStorage(req) {
  return new Storage(req.app.locals.dataRoot);
}

// GET /api/blogs/:blogId/categories - List all categories
router.get('/', (req, res) => {
  try {
    const storage = getStorage(req);
    const { blogId } = req.params;

    const categories = storage.getAllCategories(blogId);

    // Enrich with post counts
    const posts = storage.getAllPosts(blogId, false);
    const enrichedCategories = categories.map(category => ({
      ...category,
      postCount: posts.filter(p => p.categoryId === category.id).length,
      urlPath: `categories/${category.stub}`
    }));

    res.json(enrichedCategories);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// GET /api/blogs/:blogId/categories/:id - Get single category
router.get('/:id', (req, res) => {
  try {
    const storage = getStorage(req);
    const { blogId, id } = req.params;

    const category = storage.getCategory(blogId, id);

    if (!category) {
      return res.status(404).json({ error: 'Category not found' });
    }

    // Enrich with post count
    const posts = storage.getAllPosts(blogId, false);
    const enriched = {
      ...category,
      postCount: posts.filter(p => p.categoryId === category.id).length,
      urlPath: `categories/${category.stub}`
    };

    res.json(enriched);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// POST /api/blogs/:blogId/categories - Create new category
router.post('/', (req, res) => {
  try {
    const storage = getStorage(req);
    const { blogId } = req.params;
    const { name, description } = req.body;

    if (!name) {
      return res.status(400).json({ error: 'Category name is required' });
    }

    // Capitalize name
    const capitalizedName = name.charAt(0).toUpperCase() + name.slice(1);

    // Generate unique stub
    const baseStub = generateStub(capitalizedName);
    const existingCategories = storage.getAllCategories(blogId);
    const existingStubs = existingCategories.map(c => c.stub);
    const stub = makeStubUnique(baseStub, existingStubs);

    const categoryData = {
      name: capitalizedName,
      description: description || '',
      stub
    };

    const category = storage.createCategory(blogId, categoryData);
    res.status(201).json({
      ...category,
      postCount: 0,
      urlPath: `categories/${category.stub}`
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// PUT /api/blogs/:blogId/categories/:id - Update category
router.put('/:id', (req, res) => {
  try {
    const storage = getStorage(req);
    const { blogId, id } = req.params;
    const { name, description } = req.body;

    const existingCategory = storage.getCategory(blogId, id);
    if (!existingCategory) {
      return res.status(404).json({ error: 'Category not found' });
    }

    const updateData = {};

    if (name !== undefined) {
      // Capitalize name
      updateData.name = name.charAt(0).toUpperCase() + name.slice(1);

      // Regenerate stub
      const baseStub = generateStub(updateData.name);
      const existingCategories = storage.getAllCategories(blogId);
      const existingStubs = existingCategories
        .filter(c => c.id !== id)
        .map(c => c.stub);
      updateData.stub = makeStubUnique(baseStub, existingStubs);
    }

    if (description !== undefined) {
      updateData.description = description;
    }

    const category = storage.updateCategory(blogId, id, updateData);

    // Enrich with post count
    const posts = storage.getAllPosts(blogId, false);
    res.json({
      ...category,
      postCount: posts.filter(p => p.categoryId === category.id).length,
      urlPath: `categories/${category.stub}`
    });
  } catch (error) {
    if (error.message.includes('not found')) {
      return res.status(404).json({ error: error.message });
    }
    res.status(500).json({ error: error.message });
  }
});

// DELETE /api/blogs/:blogId/categories/:id - Delete category
router.delete('/:id', (req, res) => {
  try {
    const storage = getStorage(req);
    const { blogId, id } = req.params;

    // Remove category from all posts
    const posts = storage.getAllPosts(blogId, true);
    for (const post of posts) {
      if (post.categoryId === id) {
        storage.updatePost(blogId, post.id, { categoryId: null });
      }
    }

    storage.deleteCategory(blogId, id);
    res.status(204).send();
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

export default router;
