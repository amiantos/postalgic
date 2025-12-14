import Database from 'better-sqlite3';
import path from 'path';
import fs from 'fs';

/**
 * SQLite database setup and schema management.
 * Database file is stored at data/postalgic.db
 */

let db = null;

/**
 * Initialize the database connection and create schema if needed.
 * @param {string} dataRoot - Root directory for data storage
 * @returns {Database} The database instance
 */
export function initDatabase(dataRoot) {
  if (db) return db;

  // Ensure data directory exists
  if (!fs.existsSync(dataRoot)) {
    fs.mkdirSync(dataRoot, { recursive: true });
  }

  const dbPath = path.join(dataRoot, 'postalgic.db');
  db = new Database(dbPath);

  // Enable foreign keys
  db.pragma('foreign_keys = ON');

  // Enable WAL mode for better concurrent performance
  db.pragma('journal_mode = WAL');

  // Create schema
  createSchema(db);

  return db;
}

/**
 * Get the database instance. Must call initDatabase first.
 * @returns {Database} The database instance
 */
export function getDatabase() {
  if (!db) {
    throw new Error('Database not initialized. Call initDatabase first.');
  }
  return db;
}

/**
 * Close the database connection.
 */
export function closeDatabase() {
  if (db) {
    db.close();
    db = null;
  }
}

/**
 * Run database migrations for existing databases.
 * @param {Database} database - The database instance
 */
function runMigrations(database) {
  // Check if timezone column exists in blogs table
  const columns = database.prepare(`PRAGMA table_info(blogs)`).all();
  const hasTimezone = columns.some(col => col.name === 'timezone');

  if (!hasTimezone) {
    console.log('[Database] Running migration: adding timezone column to blogs table');
    database.exec(`ALTER TABLE blogs ADD COLUMN timezone TEXT DEFAULT 'UTC'`);
  }
}

/**
 * Create the database schema if it doesn't exist.
 * @param {Database} database - The database instance
 */
function createSchema(database) {
  // Check if schema already exists
  const tableExists = database.prepare(`
    SELECT name FROM sqlite_master WHERE type='table' AND name='blogs'
  `).get();

  if (tableExists) {
    // Run migrations for existing databases
    runMigrations(database);
    return;
  }

  console.log('[Database] Creating schema...');

  database.exec(`
    -- Blogs table
    CREATE TABLE blogs (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      url TEXT,
      tagline TEXT,
      author_name TEXT,
      author_url TEXT,
      author_email TEXT,
      theme_identifier TEXT DEFAULT 'default',
      accent_color TEXT,
      background_color TEXT,
      text_color TEXT,
      light_shade TEXT,
      medium_shade TEXT,
      dark_shade TEXT,
      publisher_type TEXT DEFAULT 'manual',
      aws_region TEXT,
      aws_s3_bucket TEXT,
      aws_cloudfront_dist_id TEXT,
      aws_access_key_id TEXT,
      aws_secret_access_key TEXT,
      ftp_host TEXT,
      ftp_port INTEGER DEFAULT 22,
      ftp_username TEXT,
      ftp_password TEXT,
      ftp_private_key TEXT,
      ftp_path TEXT,
      git_repository_url TEXT,
      git_username TEXT,
      git_token TEXT,
      git_branch TEXT DEFAULT 'main',
      git_commit_message TEXT,
      timezone TEXT DEFAULT 'UTC',
      created_at TEXT NOT NULL,
      updated_at TEXT
    );

    -- Categories table (must be created before posts due to foreign key)
    CREATE TABLE categories (
      id TEXT PRIMARY KEY,
      blog_id TEXT NOT NULL REFERENCES blogs(id) ON DELETE CASCADE,
      name TEXT NOT NULL,
      description TEXT,
      stub TEXT NOT NULL,
      created_at TEXT NOT NULL,
      UNIQUE(blog_id, stub)
    );

    -- Tags table
    CREATE TABLE tags (
      id TEXT PRIMARY KEY,
      blog_id TEXT NOT NULL REFERENCES blogs(id) ON DELETE CASCADE,
      name TEXT NOT NULL,
      stub TEXT NOT NULL,
      created_at TEXT NOT NULL,
      UNIQUE(blog_id, stub),
      UNIQUE(blog_id, name)
    );

    -- Posts table
    CREATE TABLE posts (
      id TEXT PRIMARY KEY,
      blog_id TEXT NOT NULL REFERENCES blogs(id) ON DELETE CASCADE,
      title TEXT,
      content TEXT NOT NULL,
      stub TEXT NOT NULL,
      is_draft INTEGER DEFAULT 1,
      category_id TEXT REFERENCES categories(id) ON DELETE SET NULL,
      embed_type TEXT,
      embed_position TEXT,
      embed_data TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT,
      UNIQUE(blog_id, stub)
    );

    -- Post-Tags junction table
    CREATE TABLE post_tags (
      post_id TEXT NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
      tag_id TEXT NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
      PRIMARY KEY (post_id, tag_id)
    );

    -- Sidebar objects table
    CREATE TABLE sidebar_objects (
      id TEXT PRIMARY KEY,
      blog_id TEXT NOT NULL REFERENCES blogs(id) ON DELETE CASCADE,
      title TEXT NOT NULL,
      type TEXT NOT NULL,
      content TEXT,
      sort_order INTEGER DEFAULT 0,
      created_at TEXT NOT NULL
    );

    -- Sidebar links table (for linkList type)
    CREATE TABLE sidebar_links (
      id TEXT PRIMARY KEY,
      sidebar_object_id TEXT NOT NULL REFERENCES sidebar_objects(id) ON DELETE CASCADE,
      title TEXT NOT NULL,
      url TEXT NOT NULL,
      sort_order INTEGER DEFAULT 0
    );

    -- Static files table (binary data stays on disk)
    CREATE TABLE static_files (
      id TEXT PRIMARY KEY,
      blog_id TEXT NOT NULL REFERENCES blogs(id) ON DELETE CASCADE,
      filename TEXT NOT NULL,
      stored_filename TEXT NOT NULL,
      mime_type TEXT,
      size INTEGER,
      special_file_type TEXT,
      created_at TEXT NOT NULL
    );

    -- Themes table
    CREATE TABLE themes (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      identifier TEXT NOT NULL UNIQUE,
      templates TEXT NOT NULL,
      created_at TEXT NOT NULL
    );

    -- Published files tracking
    CREATE TABLE published_files (
      blog_id TEXT PRIMARY KEY REFERENCES blogs(id) ON DELETE CASCADE,
      publisher_type TEXT,
      last_published_at TEXT,
      file_hashes TEXT
    );

    -- Indexes for performance
    CREATE INDEX idx_posts_blog_id ON posts(blog_id);
    CREATE INDEX idx_posts_category_id ON posts(category_id);
    CREATE INDEX idx_posts_created_at ON posts(created_at);
    CREATE INDEX idx_posts_is_draft ON posts(is_draft);
    CREATE INDEX idx_categories_blog_id ON categories(blog_id);
    CREATE INDEX idx_tags_blog_id ON tags(blog_id);
    CREATE INDEX idx_post_tags_post_id ON post_tags(post_id);
    CREATE INDEX idx_post_tags_tag_id ON post_tags(tag_id);
    CREATE INDEX idx_sidebar_objects_blog_id ON sidebar_objects(blog_id);
    CREATE INDEX idx_static_files_blog_id ON static_files(blog_id);

    -- Full-text search for posts
    CREATE VIRTUAL TABLE posts_fts USING fts5(
      id,
      title,
      content,
      content='posts',
      content_rowid='rowid'
    );

    -- Triggers to keep FTS index in sync
    CREATE TRIGGER posts_ai AFTER INSERT ON posts BEGIN
      INSERT INTO posts_fts(rowid, id, title, content) VALUES (NEW.rowid, NEW.id, NEW.title, NEW.content);
    END;

    CREATE TRIGGER posts_ad AFTER DELETE ON posts BEGIN
      INSERT INTO posts_fts(posts_fts, rowid, id, title, content) VALUES('delete', OLD.rowid, OLD.id, OLD.title, OLD.content);
    END;

    CREATE TRIGGER posts_au AFTER UPDATE ON posts BEGIN
      INSERT INTO posts_fts(posts_fts, rowid, id, title, content) VALUES('delete', OLD.rowid, OLD.id, OLD.title, OLD.content);
      INSERT INTO posts_fts(rowid, id, title, content) VALUES (NEW.rowid, NEW.id, NEW.title, NEW.content);
    END;
  `);

  console.log('[Database] Schema created successfully');
}

export default { initDatabase, getDatabase, closeDatabase };
