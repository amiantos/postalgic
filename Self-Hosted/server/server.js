import express from 'express';
import cors from 'cors';
import crypto from 'crypto';
import path from 'path';
import { fileURLToPath } from 'url';
import fs from 'fs';

// Database
import { initDatabase } from './utils/database.js';
import { needsMigration, runMigration } from './utils/migration.js';

// Routes
import blogRoutes from './routes/blogs.js';
import postRoutes from './routes/posts.js';
import categoryRoutes from './routes/categories.js';
import tagRoutes from './routes/tags.js';
import sidebarRoutes from './routes/sidebar.js';
import staticFileRoutes from './routes/staticFiles.js';
import publishRoutes from './routes/publish.js';
import themeRoutes from './routes/themes.js';
import metadataRoutes from './routes/metadata.js';
import importRoutes from './routes/import.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();
const PORT = process.env.PORT || 8010;

// Data root directory
const DATA_ROOT = path.resolve(__dirname, '../data');

// Ensure data directory exists
if (!fs.existsSync(DATA_ROOT)) {
  fs.mkdirSync(DATA_ROOT, { recursive: true });
}

// Initialize SQLite database
console.log('Initializing database...');
initDatabase(DATA_ROOT);

// Check for and run migration from JSON to SQLite
if (needsMigration(DATA_ROOT)) {
  console.log('Migrating existing data from JSON to SQLite...');
  runMigration(DATA_ROOT);
}

// Middleware
app.use(cors());
app.use(express.json({ limit: '100mb' }));
app.use(express.urlencoded({ extended: true, limit: '100mb' }));

// Basic auth middleware (enabled via environment variables)
const BASIC_AUTH_USERNAME = process.env.BASIC_AUTH_USERNAME;
const BASIC_AUTH_PASSWORD = process.env.BASIC_AUTH_PASSWORD;

if (BASIC_AUTH_USERNAME && BASIC_AUTH_PASSWORD) {
  app.use((req, res, next) => {
    const authHeader = req.headers.authorization;
    if (authHeader && authHeader.startsWith('Basic ')) {
      const decoded = Buffer.from(authHeader.slice(6), 'base64').toString();
      const colonIndex = decoded.indexOf(':');
      if (colonIndex !== -1) {
        const user = decoded.slice(0, colonIndex);
        const pass = decoded.slice(colonIndex + 1);
        const userBuf = Buffer.from(user);
        const passBuf = Buffer.from(pass);
        const expectedUserBuf = Buffer.from(BASIC_AUTH_USERNAME);
        const expectedPassBuf = Buffer.from(BASIC_AUTH_PASSWORD);
        if (
          userBuf.length === expectedUserBuf.length &&
          passBuf.length === expectedPassBuf.length &&
          crypto.timingSafeEqual(userBuf, expectedUserBuf) &&
          crypto.timingSafeEqual(passBuf, expectedPassBuf)
        ) {
          return next();
        }
      }
    }
    res.set('WWW-Authenticate', 'Basic realm="Postalgic"');
    res.status(401).send('Authentication required');
  });
}

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
app.use('/api/metadata', metadataRoutes);
app.use('/api/import', importRoutes);

// Serve uploaded files from blog-specific directories
// Files are stored at data/uploads/{blogId}/ and served at /uploads/{blogId}/
app.use('/uploads', express.static(path.join(DATA_ROOT, 'uploads')));

// Serve generated sites for preview
// Note: Preview sites are generated with basePath set to /preview/{blogId} so all asset
// paths are already correct and no redirect middleware is needed
app.use('/preview', express.static(path.join(DATA_ROOT, 'generated')));

// Serve Vue app in production
if (process.env.NODE_ENV === 'production') {
  const vueDistPath = path.resolve(__dirname, '../vue_client/dist');
  app.use(express.static(vueDistPath));

  // SPA fallback - serve index.html for client-side routing
  // Exclude API routes, uploads, and preview which are handled above
  app.get('*', (req, res, next) => {
    if (req.path.startsWith('/api') || req.path.startsWith('/uploads') || req.path.startsWith('/preview')) {
      // These routes should have been handled already - return 404
      return res.status(404).json({ error: 'Not found' });
    }
    res.sendFile(path.join(vueDistPath, 'index.html'));
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
  console.log(`Basic auth: ${BASIC_AUTH_USERNAME && BASIC_AUTH_PASSWORD ? 'enabled' : 'disabled'}`);
});
