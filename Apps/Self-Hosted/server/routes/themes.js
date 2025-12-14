import express from 'express';
import Storage from '../utils/storage.js';
import { getDefaultTemplates } from '../services/templates.js';

const router = express.Router();

function getStorage(req) {
  return new Storage(req.app.locals.dataRoot);
}

// GET /api/themes - List all themes (including default)
router.get('/', (req, res) => {
  try {
    const storage = getStorage(req);
    const customThemes = storage.getAllThemes();

    // Include default theme
    const themes = [
      {
        id: 'default',
        name: 'Default',
        identifier: 'default',
        isCustomized: false,
        isDefault: true
      },
      ...customThemes.map(t => ({ ...t, isDefault: false }))
    ];

    res.json(themes);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// GET /api/themes/:id - Get theme with templates
router.get('/:id', (req, res) => {
  try {
    const storage = getStorage(req);
    const { id } = req.params;

    if (id === 'default') {
      return res.json({
        id: 'default',
        name: 'Default',
        identifier: 'default',
        isCustomized: false,
        isDefault: true,
        templates: getDefaultTemplates()
      });
    }

    const theme = storage.getTheme(id);

    if (!theme) {
      return res.status(404).json({ error: 'Theme not found' });
    }

    res.json({ ...theme, isDefault: false });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// POST /api/themes - Create new custom theme
router.post('/', (req, res) => {
  try {
    const storage = getStorage(req);
    const { name, templates } = req.body;

    if (!name) {
      return res.status(400).json({ error: 'Theme name is required' });
    }

    // Start with default templates and merge custom ones
    const defaultTemplates = getDefaultTemplates();
    const mergedTemplates = { ...defaultTemplates, ...templates };

    const themeData = {
      name,
      identifier: `custom-${Date.now()}`,
      isCustomized: true,
      templates: mergedTemplates
    };

    const theme = storage.createTheme(themeData);
    res.status(201).json({ ...theme, isDefault: false });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// PUT /api/themes/:id - Update theme
router.put('/:id', (req, res) => {
  try {
    const storage = getStorage(req);
    const { id } = req.params;

    if (id === 'default') {
      return res.status(400).json({ error: 'Cannot modify default theme' });
    }

    const existingTheme = storage.getTheme(id);
    if (!existingTheme) {
      return res.status(404).json({ error: 'Theme not found' });
    }

    const updateData = {};

    if (req.body.name !== undefined) {
      updateData.name = req.body.name;
    }

    if (req.body.templates !== undefined) {
      // Merge with existing templates
      updateData.templates = { ...existingTheme.templates, ...req.body.templates };
    }

    const theme = storage.updateTheme(id, updateData);
    res.json({ ...theme, isDefault: false });
  } catch (error) {
    if (error.message.includes('not found')) {
      return res.status(404).json({ error: error.message });
    }
    res.status(500).json({ error: error.message });
  }
});

// DELETE /api/themes/:id - Delete theme
router.delete('/:id', (req, res) => {
  try {
    const storage = getStorage(req);
    const { id } = req.params;

    if (id === 'default') {
      return res.status(400).json({ error: 'Cannot delete default theme' });
    }

    storage.deleteTheme(id);
    res.status(204).send();
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// POST /api/themes/:id/duplicate - Duplicate a theme
router.post('/:id/duplicate', (req, res) => {
  try {
    const storage = getStorage(req);
    const { id } = req.params;
    const { name } = req.body;

    let sourceTemplates;

    if (id === 'default') {
      sourceTemplates = getDefaultTemplates();
    } else {
      const sourceTheme = storage.getTheme(id);
      if (!sourceTheme) {
        return res.status(404).json({ error: 'Theme not found' });
      }
      sourceTemplates = sourceTheme.templates;
    }

    const themeData = {
      name: name || `Copy of ${id === 'default' ? 'Default' : storage.getTheme(id)?.name}`,
      identifier: `custom-${Date.now()}`,
      isCustomized: true,
      templates: { ...sourceTemplates }
    };

    const theme = storage.createTheme(themeData);
    res.status(201).json({ ...theme, isDefault: false });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// GET /api/themes/:id/template/:templateName - Get specific template
router.get('/:id/template/:templateName', (req, res) => {
  try {
    const storage = getStorage(req);
    const { id, templateName } = req.params;

    let templates;

    if (id === 'default') {
      templates = getDefaultTemplates();
    } else {
      const theme = storage.getTheme(id);
      if (!theme) {
        return res.status(404).json({ error: 'Theme not found' });
      }
      templates = theme.templates;
    }

    if (!templates[templateName]) {
      return res.status(404).json({ error: 'Template not found' });
    }

    res.json({
      name: templateName,
      content: templates[templateName]
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

export default router;
