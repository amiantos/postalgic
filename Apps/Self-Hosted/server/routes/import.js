import express from 'express';
import multer from 'multer';
import BlogImporter from '../services/importer.js';

const router = express.Router();

// Configure multer for ZIP file uploads
const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 500 * 1024 * 1024 // 500MB limit for large blog exports
  },
  fileFilter: (req, file, cb) => {
    // Only accept ZIP files
    if (file.mimetype === 'application/zip' ||
        file.mimetype === 'application/x-zip-compressed' ||
        file.originalname.toLowerCase().endsWith('.zip')) {
      cb(null, true);
    } else {
      cb(new Error('Only ZIP files are allowed'));
    }
  }
});

function getDataRoot(req) {
  return req.app.locals.dataRoot;
}

// POST /api/import/validate - Validate an export ZIP without importing
router.post('/validate', upload.single('file'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: 'No file uploaded' });
    }

    const importer = new BlogImporter(getDataRoot(req));
    const validation = importer.validateExport(req.file.buffer);

    res.json(validation);
  } catch (error) {
    console.error('Validation error:', error);
    res.status(500).json({ error: error.message });
  }
});

// POST /api/import - Import a blog from an export ZIP
router.post('/', upload.single('file'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: 'No file uploaded' });
    }

    const importer = new BlogImporter(getDataRoot(req));

    // First validate
    const validation = importer.validateExport(req.file.buffer);
    if (!validation.valid) {
      return res.status(400).json({ error: `Invalid export file: ${validation.error}` });
    }

    // Then import
    const blog = await importer.importBlog(req.file.buffer);

    res.status(201).json({
      success: true,
      blog,
      message: `Successfully imported blog "${blog.name}"`
    });
  } catch (error) {
    console.error('Import error:', error);
    res.status(500).json({ error: error.message });
  }
});

export default router;
