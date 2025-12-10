import express from 'express';
import cors from 'cors';
import path from 'path';
import { fileURLToPath } from 'url';
import fs from 'fs';

// Routes
import blogRoutes from './routes/blogs.js';
import postRoutes from './routes/posts.js';
import categoryRoutes from './routes/categories.js';
import tagRoutes from './routes/tags.js';
import sidebarRoutes from './routes/sidebar.js';
import staticFileRoutes from './routes/staticFiles.js';
import publishRoutes from './routes/publish.js';
import themeRoutes from './routes/themes.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();
const PORT = process.env.PORT || 8005;

// Data root directory
const DATA_ROOT = path.resolve(__dirname, '../data');

// Ensure data directory exists
if (!fs.existsSync(DATA_ROOT)) {
  fs.mkdirSync(DATA_ROOT, { recursive: true });
}

// Middleware
app.use(cors());
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true, limit: '50mb' }));

// Make data root available to routes
app.locals.dataRoot = DATA_ROOT;

// API Routes
app.use('/api/blogs', blogRoutes);
app.use('/api/blogs/:blogId/posts', postRoutes);
app.use('/api/blogs/:blogId/categories', categoryRoutes);
app.use('/api/blogs/:blogId/tags', tagRoutes);
app.use('/api/blogs/:blogId/sidebar', sidebarRoutes);
app.use('/api/blogs/:blogId/static-files', staticFileRoutes);
app.use('/api/blogs/:blogId/publish', publishRoutes);
app.use('/api/themes', themeRoutes);

// Serve uploaded files
app.use('/uploads', express.static(path.join(DATA_ROOT, 'uploads')));

// Serve generated sites for preview
app.use('/preview', express.static(path.join(DATA_ROOT, 'generated')));

// Serve Vue app in production
if (process.env.NODE_ENV === 'production') {
  const vueDistPath = path.resolve(__dirname, '../vue_client/dist');
  app.use(express.static(vueDistPath));
  app.get('*', (req, res) => {
    if (!req.path.startsWith('/api') && !req.path.startsWith('/uploads') && !req.path.startsWith('/preview')) {
      res.sendFile(path.join(vueDistPath, 'index.html'));
    }
  });
}

// Error handling middleware
app.use((err, req, res, next) => {
  console.error('Error:', err);
  res.status(500).json({ error: err.message || 'Internal server error' });
});

app.listen(PORT, () => {
  console.log(`Postalgic server running on http://localhost:${PORT}`);
  console.log(`Data directory: ${DATA_ROOT}`);
});
