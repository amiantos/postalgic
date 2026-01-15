import express from 'express';
import multer from 'multer';
import Storage from '../utils/storage.js';
import { getMimeType, isImageFile, sanitizeFilename } from '../utils/helpers.js';
import { processImage } from '../services/imageProcessor.js';

const router = express.Router({ mergeParams: true });

// Configure multer for file uploads
const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 50 * 1024 * 1024 // 50MB limit
  }
});

function getStorage(req) {
  return new Storage(req.app.locals.dataRoot);
}

// GET /api/blogs/:blogId/static-files - List all static files
router.get('/', (req, res) => {
  try {
    const storage = getStorage(req);
    const { blogId } = req.params;

    const files = storage.getAllStaticFiles(blogId);

    // Enrich with additional metadata
    const enrichedFiles = files.map(file => ({
      ...file,
      isImage: isImageFile(file.filename),
      url: `/uploads/${blogId}/${file.storedFilename}`
    }));

    res.json(enrichedFiles);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// GET /api/blogs/:blogId/static-files/:id - Get single static file metadata
router.get('/:id', (req, res) => {
  try {
    const storage = getStorage(req);
    const { blogId, id } = req.params;

    const file = storage.getStaticFile(blogId, id);

    if (!file) {
      return res.status(404).json({ error: 'File not found' });
    }

    res.json({
      ...file,
      isImage: isImageFile(file.filename),
      url: `/uploads/${blogId}/${file.storedFilename}`
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// GET /api/blogs/:blogId/static-files/:id/download - Download static file
router.get('/:id/download', (req, res) => {
  try {
    const storage = getStorage(req);
    const { blogId, id } = req.params;

    const file = storage.getStaticFile(blogId, id);
    if (!file) {
      return res.status(404).json({ error: 'File not found' });
    }

    const buffer = storage.getStaticFileBuffer(blogId, id);
    if (!buffer) {
      return res.status(404).json({ error: 'File data not found' });
    }

    res.setHeader('Content-Type', file.mimeType);
    res.setHeader('Content-Disposition', `attachment; filename="${file.filename}"`);
    res.send(buffer);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// POST /api/blogs/:blogId/static-files - Upload new static file
router.post('/', upload.single('file'), async (req, res) => {
  try {
    const storage = getStorage(req);
    const { blogId } = req.params;

    if (!req.file) {
      return res.status(400).json({ error: 'No file uploaded' });
    }

    const originalFilename = sanitizeFilename(req.file.originalname);
    const mimeType = getMimeType(originalFilename);
    let fileBuffer = req.file.buffer;

    // Process image if it's an image and optimization is requested
    if (isImageFile(originalFilename) && req.body.optimize !== 'false') {
      try {
        fileBuffer = await processImage(fileBuffer, {
          maxDimension: parseInt(req.body.maxDimension) || 1024,
          quality: parseInt(req.body.quality) || 80
        });
      } catch (err) {
        console.warn('Image optimization failed, using original:', err.message);
      }
    }

    const fileData = {
      filename: originalFilename,
      mimeType,
      isSpecialFile: req.body.isSpecialFile === 'true',
      specialFileType: req.body.specialFileType || null,
      size: fileBuffer.length
    };

    const file = storage.createStaticFile(blogId, fileData, fileBuffer);

    res.status(201).json({
      ...file,
      isImage: isImageFile(file.filename),
      url: `/uploads/${blogId}/${file.storedFilename}`
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// POST /api/blogs/:blogId/static-files/favicon - Upload favicon
router.post('/favicon', upload.single('file'), async (req, res) => {
  try {
    const storage = getStorage(req);
    const { blogId } = req.params;

    if (!req.file) {
      return res.status(400).json({ error: 'No file uploaded' });
    }

    // Remove existing favicon
    const existingFiles = storage.getAllStaticFiles(blogId);
    const existingFavicon = existingFiles.find(f => f.specialFileType === 'favicon');
    if (existingFavicon) {
      storage.deleteStaticFile(blogId, existingFavicon.id);
    }

    const originalFilename = 'favicon.png';
    let fileBuffer = req.file.buffer;

    // Process favicon to correct size
    try {
      fileBuffer = await processImage(fileBuffer, {
        resize: { width: 32, height: 32 },
        format: 'png'
      });
    } catch (err) {
      console.warn('Favicon processing failed:', err.message);
    }

    const fileData = {
      filename: originalFilename,
      mimeType: 'image/png',
      isSpecialFile: true,
      specialFileType: 'favicon',
      size: fileBuffer.length
    };

    const file = storage.createStaticFile(blogId, fileData, fileBuffer);

    res.status(201).json({
      ...file,
      isImage: true,
      url: `/uploads/${blogId}/${file.storedFilename}`
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// POST /api/blogs/:blogId/static-files/social-share - Upload social share image
router.post('/social-share', upload.single('file'), async (req, res) => {
  try {
    const storage = getStorage(req);
    const { blogId } = req.params;

    if (!req.file) {
      return res.status(400).json({ error: 'No file uploaded' });
    }

    // Remove existing social share image
    const existingFiles = storage.getAllStaticFiles(blogId);
    const existingImage = existingFiles.find(f => f.specialFileType === 'social-share');
    if (existingImage) {
      storage.deleteStaticFile(blogId, existingImage.id);
    }

    const originalFilename = 'social-share.png';
    let fileBuffer = req.file.buffer;

    // Process to recommended social share size (1200x630)
    try {
      fileBuffer = await processImage(fileBuffer, {
        resize: { width: 1200, height: 630, fit: 'cover' },
        format: 'png'
      });
    } catch (err) {
      console.warn('Social share image processing failed:', err.message);
    }

    const fileData = {
      filename: originalFilename,
      mimeType: 'image/png',
      isSpecialFile: true,
      specialFileType: 'social-share',
      size: fileBuffer.length
    };

    const file = storage.createStaticFile(blogId, fileData, fileBuffer);

    res.status(201).json({
      ...file,
      isImage: true,
      url: `/uploads/${blogId}/${file.storedFilename}`
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// DELETE /api/blogs/:blogId/static-files/:id - Delete static file
router.delete('/:id', (req, res) => {
  try {
    const storage = getStorage(req);
    const { blogId, id } = req.params;

    storage.deleteStaticFile(blogId, id);
    res.status(204).send();
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

export default router;
