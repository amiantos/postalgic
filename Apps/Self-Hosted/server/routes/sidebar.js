import express from 'express';
import Storage from '../utils/storage.js';

const router = express.Router({ mergeParams: true });

function getStorage(req) {
  return new Storage(req.app.locals.dataRoot);
}

// GET /api/blogs/:blogId/sidebar - List all sidebar objects
router.get('/', (req, res) => {
  try {
    const storage = getStorage(req);
    const { blogId } = req.params;

    const sidebarObjects = storage.getAllSidebarObjects(blogId);
    res.json(sidebarObjects);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// GET /api/blogs/:blogId/sidebar/:id - Get single sidebar object
router.get('/:id', (req, res) => {
  try {
    const storage = getStorage(req);
    const { blogId, id } = req.params;

    const sidebarObject = storage.getSidebarObject(blogId, id);

    if (!sidebarObject) {
      return res.status(404).json({ error: 'Sidebar object not found' });
    }

    res.json(sidebarObject);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// POST /api/blogs/:blogId/sidebar - Create new sidebar object
router.post('/', (req, res) => {
  try {
    const storage = getStorage(req);
    const { blogId } = req.params;
    const { title, type, content, links, order } = req.body;

    if (!title) {
      return res.status(400).json({ error: 'Sidebar object title is required' });
    }

    if (!type || !['text', 'linkList'].includes(type)) {
      return res.status(400).json({ error: 'Valid type (text or linkList) is required' });
    }

    const objectData = {
      title,
      type,
      order
    };

    if (type === 'text') {
      objectData.content = content || '';
      objectData.links = [];
    } else {
      objectData.content = '';
      objectData.links = (links || []).map((link, index) => ({
        title: link.title || '',
        url: link.url || '',
        order: link.order ?? index
      }));
    }

    const sidebarObject = storage.createSidebarObject(blogId, objectData);
    res.status(201).json(sidebarObject);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// PUT /api/blogs/:blogId/sidebar/:id - Update sidebar object
router.put('/:id', (req, res) => {
  try {
    const storage = getStorage(req);
    const { blogId, id } = req.params;

    const existingObject = storage.getSidebarObject(blogId, id);
    if (!existingObject) {
      return res.status(404).json({ error: 'Sidebar object not found' });
    }

    const updateData = {};

    if (req.body.title !== undefined) {
      updateData.title = req.body.title;
    }

    if (req.body.order !== undefined) {
      updateData.order = req.body.order;
    }

    if (req.body.type !== undefined) {
      if (!['text', 'linkList'].includes(req.body.type)) {
        return res.status(400).json({ error: 'Valid type (text or linkList) is required' });
      }
      updateData.type = req.body.type;
    }

    const type = updateData.type || existingObject.type;

    if (type === 'text' && req.body.content !== undefined) {
      updateData.content = req.body.content;
    }

    if (type === 'linkList' && req.body.links !== undefined) {
      updateData.links = req.body.links.map((link, index) => ({
        title: link.title || '',
        url: link.url || '',
        order: link.order ?? index
      }));
    }

    const sidebarObject = storage.updateSidebarObject(blogId, id, updateData);
    res.json(sidebarObject);
  } catch (error) {
    if (error.message.includes('not found')) {
      return res.status(404).json({ error: error.message });
    }
    res.status(500).json({ error: error.message });
  }
});

// DELETE /api/blogs/:blogId/sidebar/:id - Delete sidebar object
router.delete('/:id', (req, res) => {
  try {
    const storage = getStorage(req);
    const { blogId, id } = req.params;

    storage.deleteSidebarObject(blogId, id);
    res.status(204).send();
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// POST /api/blogs/:blogId/sidebar/reorder - Reorder sidebar objects
router.post('/reorder', (req, res) => {
  try {
    const storage = getStorage(req);
    const { blogId } = req.params;
    const { order } = req.body; // Array of { id, order }

    if (!Array.isArray(order)) {
      return res.status(400).json({ error: 'Order must be an array of { id, order }' });
    }

    for (const item of order) {
      storage.updateSidebarObject(blogId, item.id, { order: item.order });
    }

    const sidebarObjects = storage.getAllSidebarObjects(blogId);
    res.json(sidebarObjects);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

export default router;
