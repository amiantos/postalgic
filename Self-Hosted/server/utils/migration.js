import fs from 'fs';
import path from 'path';
import { v4 as uuidv4 } from 'uuid';
import { getDatabase } from './database.js';

/**
 * Migration utility to convert file-based JSON storage to SQLite.
 * This is a one-time migration that runs on first startup if JSON data exists.
 */

/**
 * Check if migration is needed (JSON data exists but database is empty).
 * @param {string} dataRoot - Root data directory
 * @returns {boolean} True if migration is needed
 */
export function needsMigration(dataRoot) {
  const blogsDir = path.join(dataRoot, 'blogs');

  // Check if blogs directory exists with data
  if (!fs.existsSync(blogsDir)) {
    return false;
  }

  const blogDirs = fs.readdirSync(blogsDir, { withFileTypes: true })
    .filter(d => d.isDirectory());

  if (blogDirs.length === 0) {
    return false;
  }

  // Check if at least one blog has a blog.json file
  const hasBlogData = blogDirs.some(d =>
    fs.existsSync(path.join(blogsDir, d.name, 'blog.json'))
  );

  if (!hasBlogData) {
    return false;
  }

  // Check if database already has data
  const db = getDatabase();
  const blogCount = db.prepare('SELECT COUNT(*) as count FROM blogs').get();

  return blogCount.count === 0;
}

/**
 * Run the migration from JSON files to SQLite.
 * @param {string} dataRoot - Root data directory
 */
export function runMigration(dataRoot) {
  console.log('[Migration] Starting migration from JSON to SQLite...');

  const db = getDatabase();
  const blogsDir = path.join(dataRoot, 'blogs');
  const themesDir = path.join(dataRoot, 'themes');

  // Use a transaction for atomicity
  const migrate = db.transaction(() => {
    // Migrate themes first
    migrateThemes(db, themesDir);

    // Migrate blogs
    if (fs.existsSync(blogsDir)) {
      const blogDirs = fs.readdirSync(blogsDir, { withFileTypes: true })
        .filter(d => d.isDirectory())
        .map(d => d.name);

      for (const blogId of blogDirs) {
        migrateBlog(db, blogsDir, blogId);
      }
    }
  });

  try {
    migrate();
    console.log('[Migration] Migration completed successfully');

    // Create backup of old data
    backupOldData(dataRoot);
  } catch (error) {
    console.error('[Migration] Migration failed:', error);
    throw error;
  }
}

/**
 * Migrate themes from JSON files to SQLite.
 */
function migrateThemes(db, themesDir) {
  if (!fs.existsSync(themesDir)) return;

  const themeFiles = fs.readdirSync(themesDir).filter(f => f.endsWith('.json'));
  console.log(`[Migration] Migrating ${themeFiles.length} themes...`);

  const insertTheme = db.prepare(`
    INSERT INTO themes (id, name, identifier, templates, created_at)
    VALUES (?, ?, ?, ?, ?)
  `);

  for (const themeFile of themeFiles) {
    try {
      const themeId = themeFile.replace('.json', '');
      const themePath = path.join(themesDir, themeFile);
      const themeData = JSON.parse(fs.readFileSync(themePath, 'utf-8'));

      insertTheme.run(
        themeId,
        themeData.name || 'Custom Theme',
        themeData.identifier || themeId,
        JSON.stringify(themeData.templates || {}),
        themeData.createdAt || new Date().toISOString()
      );
    } catch (error) {
      console.error(`[Migration] Error migrating theme ${themeFile}:`, error);
    }
  }
}

/**
 * Migrate a single blog and all its related data.
 */
function migrateBlog(db, blogsDir, blogId) {
  const blogDir = path.join(blogsDir, blogId);
  const blogFile = path.join(blogDir, 'blog.json');

  if (!fs.existsSync(blogFile)) {
    console.log(`[Migration] Skipping blog ${blogId} - no blog.json`);
    return;
  }

  console.log(`[Migration] Migrating blog ${blogId}...`);

  // Read blog data
  const blogData = JSON.parse(fs.readFileSync(blogFile, 'utf-8'));

  // Insert blog
  const insertBlog = db.prepare(`
    INSERT INTO blogs (
      id, name, url, tagline, author_name, author_url, author_email,
      theme_identifier, accent_color, background_color, text_color,
      light_shade, medium_shade, dark_shade, publisher_type,
      aws_region, aws_s3_bucket, aws_cloudfront_dist_id,
      aws_access_key_id, aws_secret_access_key,
      ftp_host, ftp_port, ftp_username, ftp_password, ftp_private_key, ftp_path,
      git_repository_url, git_username, git_token, git_branch, git_commit_message,
      created_at, updated_at
    ) VALUES (
      ?, ?, ?, ?, ?, ?, ?,
      ?, ?, ?, ?,
      ?, ?, ?, ?,
      ?, ?, ?,
      ?, ?,
      ?, ?, ?, ?, ?, ?,
      ?, ?, ?, ?, ?,
      ?, ?
    )
  `);

  insertBlog.run(
    blogId,
    blogData.name || 'Untitled Blog',
    blogData.url || null,
    blogData.tagline || null,
    blogData.authorName || null,
    blogData.authorUrl || null,
    blogData.authorEmail || null,
    blogData.themeIdentifier || 'default',
    blogData.accentColor || null,
    blogData.backgroundColor || null,
    blogData.textColor || null,
    blogData.lightShade || null,
    blogData.mediumShade || null,
    blogData.darkShade || null,
    blogData.publisherType || 'manual',
    blogData.awsRegion || null,
    blogData.awsS3Bucket || null,
    blogData.awsCloudFrontDistId || null,
    blogData.awsAccessKeyId || null,
    blogData.awsSecretAccessKey || null,
    blogData.ftpHost || null,
    blogData.ftpPort || 22,
    blogData.ftpUsername || null,
    blogData.ftpPassword || null,
    blogData.ftpPrivateKey || null,
    blogData.ftpPath || null,
    blogData.gitRepositoryUrl || null,
    blogData.gitUsername || null,
    blogData.gitToken || null,
    blogData.gitBranch || 'main',
    blogData.gitCommitMessage || null,
    blogData.createdAt || new Date().toISOString(),
    blogData.updatedAt || null
  );

  // Migrate categories
  const categoryIdMap = migrateCategories(db, blogDir, blogId);

  // Migrate tags
  const tagIdMap = migrateTags(db, blogDir, blogId);

  // Migrate posts
  migratePosts(db, blogDir, blogId, categoryIdMap, tagIdMap);

  // Migrate sidebar objects
  migrateSidebarObjects(db, blogDir, blogId);

  // Migrate static files
  migrateStaticFiles(db, blogDir, blogId);

  // Migrate published files tracking
  migratePublishedFiles(db, blogDir, blogId);

  // Move uploads to new location (data/uploads/{blogId}/)
  moveUploads(blogDir, blogId);
}

/**
 * Move uploads from old location to new location.
 * Old: data/blogs/{blogId}/uploads/
 * New: data/uploads/{blogId}/
 */
function moveUploads(blogDir, blogId) {
  const oldUploadsDir = path.join(blogDir, 'uploads');
  const dataRoot = path.dirname(path.dirname(blogDir)); // Go up from blogs/{blogId}
  const newUploadsDir = path.join(dataRoot, 'uploads', blogId);

  if (!fs.existsSync(oldUploadsDir)) return;

  // Create new uploads directory
  if (!fs.existsSync(newUploadsDir)) {
    fs.mkdirSync(newUploadsDir, { recursive: true });
  }

  // Move all files
  const files = fs.readdirSync(oldUploadsDir);
  for (const file of files) {
    const oldPath = path.join(oldUploadsDir, file);
    const newPath = path.join(newUploadsDir, file);

    // Only move files, not directories
    if (fs.statSync(oldPath).isFile()) {
      fs.renameSync(oldPath, newPath);
    }
  }

  console.log(`[Migration] Moved ${files.length} uploads for blog ${blogId}`);
}

/**
 * Migrate categories for a blog.
 * Returns a map of old category IDs to new IDs.
 */
function migrateCategories(db, blogDir, blogId) {
  const categoriesDir = path.join(blogDir, 'categories');
  const idMap = new Map();

  if (!fs.existsSync(categoriesDir)) return idMap;

  const categoryFiles = fs.readdirSync(categoriesDir).filter(f => f.endsWith('.json'));

  const insertCategory = db.prepare(`
    INSERT INTO categories (id, blog_id, name, description, stub, created_at)
    VALUES (?, ?, ?, ?, ?, ?)
  `);

  for (const categoryFile of categoryFiles) {
    try {
      const oldId = categoryFile.replace('.json', '');
      const categoryPath = path.join(categoriesDir, categoryFile);
      const categoryData = JSON.parse(fs.readFileSync(categoryPath, 'utf-8'));

      // Keep the same ID
      insertCategory.run(
        oldId,
        blogId,
        categoryData.name || 'Untitled',
        categoryData.description || null,
        categoryData.stub || oldId,
        categoryData.createdAt || new Date().toISOString()
      );

      idMap.set(oldId, oldId);
    } catch (error) {
      console.error(`[Migration] Error migrating category ${categoryFile}:`, error);
    }
  }

  return idMap;
}

/**
 * Migrate tags for a blog.
 * Returns a map of old tag IDs to new IDs.
 */
function migrateTags(db, blogDir, blogId) {
  const tagsDir = path.join(blogDir, 'tags');
  const idMap = new Map();

  if (!fs.existsSync(tagsDir)) return idMap;

  const tagFiles = fs.readdirSync(tagsDir).filter(f => f.endsWith('.json'));

  const insertTag = db.prepare(`
    INSERT INTO tags (id, blog_id, name, stub, created_at)
    VALUES (?, ?, ?, ?, ?)
  `);

  for (const tagFile of tagFiles) {
    try {
      const oldId = tagFile.replace('.json', '');
      const tagPath = path.join(tagsDir, tagFile);
      const tagData = JSON.parse(fs.readFileSync(tagPath, 'utf-8'));

      // Keep the same ID
      insertTag.run(
        oldId,
        blogId,
        tagData.name || 'untitled',
        tagData.stub || oldId,
        tagData.createdAt || new Date().toISOString()
      );

      idMap.set(oldId, oldId);
    } catch (error) {
      console.error(`[Migration] Error migrating tag ${tagFile}:`, error);
    }
  }

  return idMap;
}

/**
 * Migrate posts for a blog.
 */
function migratePosts(db, blogDir, blogId, categoryIdMap, tagIdMap) {
  const postsDir = path.join(blogDir, 'posts');

  if (!fs.existsSync(postsDir)) return;

  const postFiles = fs.readdirSync(postsDir).filter(f => f.endsWith('.json'));

  const insertPost = db.prepare(`
    INSERT INTO posts (
      id, blog_id, title, content, stub, is_draft, category_id,
      embed_type, embed_position, embed_data, created_at, updated_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  `);

  const insertPostTag = db.prepare(`
    INSERT INTO post_tags (post_id, tag_id) VALUES (?, ?)
  `);

  for (const postFile of postFiles) {
    try {
      const postId = postFile.replace('.json', '');
      const postPath = path.join(postsDir, postFile);
      const postData = JSON.parse(fs.readFileSync(postPath, 'utf-8'));

      // Handle embed data
      let embedType = null;
      let embedPosition = null;
      let embedData = null;

      if (postData.embed) {
        embedType = postData.embed.type || null;
        embedPosition = postData.embed.position || 'below';
        embedData = JSON.stringify(postData.embed);
      }

      // Map category ID
      let categoryId = null;
      if (postData.categoryId && categoryIdMap.has(postData.categoryId)) {
        categoryId = categoryIdMap.get(postData.categoryId);
      }

      insertPost.run(
        postId,
        blogId,
        postData.title || null,
        postData.content || '',
        postData.stub || postId,
        postData.isDraft ? 1 : 0,
        categoryId,
        embedType,
        embedPosition,
        embedData,
        postData.createdAt || new Date().toISOString(),
        postData.updatedAt || null
      );

      // Insert post-tag relationships
      if (postData.tagIds && Array.isArray(postData.tagIds)) {
        for (const tagId of postData.tagIds) {
          if (tagIdMap.has(tagId)) {
            try {
              insertPostTag.run(postId, tagIdMap.get(tagId));
            } catch (e) {
              // Ignore duplicate key errors
            }
          }
        }
      }
    } catch (error) {
      console.error(`[Migration] Error migrating post ${postFile}:`, error);
    }
  }
}

/**
 * Migrate sidebar objects for a blog.
 */
function migrateSidebarObjects(db, blogDir, blogId) {
  const sidebarDir = path.join(blogDir, 'sidebar');

  if (!fs.existsSync(sidebarDir)) return;

  const sidebarFiles = fs.readdirSync(sidebarDir).filter(f => f.endsWith('.json'));

  const insertSidebarObject = db.prepare(`
    INSERT INTO sidebar_objects (id, blog_id, title, type, content, sort_order, created_at)
    VALUES (?, ?, ?, ?, ?, ?, ?)
  `);

  const insertSidebarLink = db.prepare(`
    INSERT INTO sidebar_links (id, sidebar_object_id, title, url, sort_order)
    VALUES (?, ?, ?, ?, ?)
  `);

  for (const sidebarFile of sidebarFiles) {
    try {
      const objectId = sidebarFile.replace('.json', '');
      const sidebarPath = path.join(sidebarDir, sidebarFile);
      const sidebarData = JSON.parse(fs.readFileSync(sidebarPath, 'utf-8'));

      insertSidebarObject.run(
        objectId,
        blogId,
        sidebarData.title || 'Untitled',
        sidebarData.type || 'text',
        sidebarData.content || null,
        sidebarData.order || 0,
        sidebarData.createdAt || new Date().toISOString()
      );

      // Insert links for linkList type
      if (sidebarData.type === 'linkList' && Array.isArray(sidebarData.links)) {
        for (let i = 0; i < sidebarData.links.length; i++) {
          const link = sidebarData.links[i];
          insertSidebarLink.run(
            uuidv4(),
            objectId,
            link.title || 'Untitled',
            link.url || '',
            link.order ?? i
          );
        }
      }
    } catch (error) {
      console.error(`[Migration] Error migrating sidebar object ${sidebarFile}:`, error);
    }
  }
}

/**
 * Migrate static files metadata for a blog.
 * Note: The actual binary files in uploads/ are not moved.
 */
function migrateStaticFiles(db, blogDir, blogId) {
  const staticFilesDir = path.join(blogDir, 'static-files');

  if (!fs.existsSync(staticFilesDir)) return;

  const staticFiles = fs.readdirSync(staticFilesDir).filter(f => f.endsWith('.json'));

  const insertStaticFile = db.prepare(`
    INSERT INTO static_files (
      id, blog_id, filename, stored_filename, mime_type, size, special_file_type, created_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
  `);

  for (const staticFile of staticFiles) {
    try {
      const fileId = staticFile.replace('.json', '');
      const filePath = path.join(staticFilesDir, staticFile);
      const fileData = JSON.parse(fs.readFileSync(filePath, 'utf-8'));

      insertStaticFile.run(
        fileId,
        blogId,
        fileData.filename || 'unknown',
        fileData.storedFilename || fileId,
        fileData.mimeType || null,
        fileData.size || 0,
        fileData.specialFileType || null,
        fileData.createdAt || new Date().toISOString()
      );
    } catch (error) {
      console.error(`[Migration] Error migrating static file ${staticFile}:`, error);
    }
  }
}

/**
 * Migrate published files tracking for a blog.
 */
function migratePublishedFiles(db, blogDir, blogId) {
  const publishedFilesPath = path.join(blogDir, 'published-files.json');

  if (!fs.existsSync(publishedFilesPath)) return;

  try {
    const publishedData = JSON.parse(fs.readFileSync(publishedFilesPath, 'utf-8'));

    const insertPublishedFiles = db.prepare(`
      INSERT INTO published_files (blog_id, publisher_type, last_published_at, file_hashes)
      VALUES (?, ?, ?, ?)
    `);

    insertPublishedFiles.run(
      blogId,
      publishedData.publisherType || null,
      publishedData.lastPublishedDate || null,
      JSON.stringify(publishedData.fileHashes || {})
    );
  } catch (error) {
    console.error(`[Migration] Error migrating published files:`, error);
  }
}

/**
 * Create a backup of the old JSON data by renaming directories.
 */
function backupOldData(dataRoot) {
  const blogsDir = path.join(dataRoot, 'blogs');
  const themesDir = path.join(dataRoot, 'themes');
  const backupDir = path.join(dataRoot, 'backup-json');

  console.log('[Migration] Creating backup of old JSON data...');

  // Create backup directory
  if (!fs.existsSync(backupDir)) {
    fs.mkdirSync(backupDir, { recursive: true });
  }

  // Move blogs JSON files to backup (keep uploads directory)
  if (fs.existsSync(blogsDir)) {
    const blogDirs = fs.readdirSync(blogsDir, { withFileTypes: true })
      .filter(d => d.isDirectory())
      .map(d => d.name);

    for (const blogId of blogDirs) {
      const blogDir = path.join(blogsDir, blogId);
      const backupBlogDir = path.join(backupDir, 'blogs', blogId);

      // Create backup directory for this blog
      fs.mkdirSync(backupBlogDir, { recursive: true });

      // Move JSON files and directories (except uploads)
      const items = ['blog.json', 'posts', 'categories', 'tags', 'sidebar', 'static-files', 'published-files.json'];
      for (const item of items) {
        const srcPath = path.join(blogDir, item);
        const destPath = path.join(backupBlogDir, item);

        if (fs.existsSync(srcPath)) {
          fs.renameSync(srcPath, destPath);
        }
      }
    }
  }

  // Move themes to backup
  if (fs.existsSync(themesDir)) {
    const backupThemesDir = path.join(backupDir, 'themes');
    fs.renameSync(themesDir, backupThemesDir);
    // Recreate themes dir (it may be needed)
    fs.mkdirSync(themesDir, { recursive: true });
  }

  console.log('[Migration] Backup created at:', backupDir);
}

export default { needsMigration, runMigration };
