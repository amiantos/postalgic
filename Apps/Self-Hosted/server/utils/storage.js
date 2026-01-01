import fs from 'fs';
import path from 'path';
import { v4 as uuidv4 } from 'uuid';
import { getDatabase } from './database.js';

/**
 * SQLite-based storage utility for managing blog data.
 * Binary files (uploads) remain on disk, metadata is stored in SQLite.
 *
 * Directory structure for binary files:
 * data/
 *   uploads/
 *     {blogId}/
 *       {storedFilename}     - Actual file data
 *   generated/
 *     {blogId}/              - Generated site files for preview
 */

class Storage {
  constructor(dataRoot) {
    this.dataRoot = dataRoot;
    this.uploadsDir = path.join(dataRoot, 'uploads');
    this.generatedDir = path.join(dataRoot, 'generated');

    // Ensure directories exist
    this.ensureDir(this.uploadsDir);
    this.ensureDir(this.generatedDir);
  }

  ensureDir(dir) {
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }
  }

  // ============ Blog Operations ============

  getBlogUploadsDir(blogId) {
    return path.join(this.uploadsDir, blogId);
  }

  getAllBlogs() {
    const db = getDatabase();
    const rows = db.prepare(`
      SELECT * FROM blogs ORDER BY created_at DESC
    `).all();

    return rows.map(row => this.mapBlogRow(row));
  }

  getBlog(blogId) {
    const db = getDatabase();
    const row = db.prepare('SELECT * FROM blogs WHERE id = ?').get(blogId);
    return row ? this.mapBlogRow(row) : null;
  }

  createBlog(blogData) {
    const db = getDatabase();
    const blogId = uuidv4();
    const now = new Date().toISOString();

    // Ensure uploads directory for this blog
    this.ensureDir(this.getBlogUploadsDir(blogId));

    const stmt = db.prepare(`
      INSERT INTO blogs (
        id, name, url, tagline, author_name, author_url, author_email,
        theme_identifier, accent_color, background_color, text_color,
        light_shade, medium_shade, dark_shade, publisher_type,
        aws_region, aws_s3_bucket, aws_cloudfront_dist_id,
        aws_access_key_id, aws_secret_access_key,
        ftp_host, ftp_port, ftp_username, ftp_password, ftp_private_key, ftp_path,
        git_repository_url, git_username, git_token, git_branch, git_commit_message,
        timezone, created_at, updated_at
      ) VALUES (
        ?, ?, ?, ?, ?, ?, ?,
        ?, ?, ?, ?,
        ?, ?, ?, ?,
        ?, ?, ?,
        ?, ?,
        ?, ?, ?, ?, ?, ?,
        ?, ?, ?, ?, ?,
        ?, ?, ?
      )
    `);

    stmt.run(
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
      blogData.timezone || 'UTC',
      now,
      now
    );

    return this.getBlog(blogId);
  }

  updateBlog(blogId, blogData) {
    const db = getDatabase();
    const existing = this.getBlog(blogId);
    if (!existing) {
      throw new Error(`Blog ${blogId} not found`);
    }

    const now = new Date().toISOString();
    const merged = { ...existing, ...blogData, updatedAt: now };

    const stmt = db.prepare(`
      UPDATE blogs SET
        name = ?, url = ?, tagline = ?,
        author_name = ?, author_url = ?, author_email = ?,
        theme_identifier = ?, accent_color = ?, background_color = ?,
        text_color = ?, light_shade = ?, medium_shade = ?, dark_shade = ?,
        publisher_type = ?,
        aws_region = ?, aws_s3_bucket = ?, aws_cloudfront_dist_id = ?,
        aws_access_key_id = ?, aws_secret_access_key = ?,
        ftp_host = ?, ftp_port = ?, ftp_username = ?, ftp_password = ?,
        ftp_private_key = ?, ftp_path = ?,
        git_repository_url = ?, git_username = ?, git_token = ?,
        git_branch = ?, git_commit_message = ?,
        timezone = ?, updated_at = ?
      WHERE id = ?
    `);

    stmt.run(
      merged.name,
      merged.url,
      merged.tagline,
      merged.authorName,
      merged.authorUrl,
      merged.authorEmail,
      merged.themeIdentifier,
      merged.accentColor,
      merged.backgroundColor,
      merged.textColor,
      merged.lightShade,
      merged.mediumShade,
      merged.darkShade,
      merged.publisherType,
      merged.awsRegion,
      merged.awsS3Bucket,
      merged.awsCloudFrontDistId,
      merged.awsAccessKeyId,
      merged.awsSecretAccessKey,
      merged.ftpHost,
      merged.ftpPort,
      merged.ftpUsername,
      merged.ftpPassword,
      merged.ftpPrivateKey,
      merged.ftpPath,
      merged.gitRepositoryUrl,
      merged.gitUsername,
      merged.gitToken,
      merged.gitBranch,
      merged.gitCommitMessage,
      merged.timezone || 'UTC',
      now,
      blogId
    );

    return this.getBlog(blogId);
  }

  deleteBlog(blogId) {
    const db = getDatabase();

    // Delete from database (cascades to related tables)
    db.prepare('DELETE FROM blogs WHERE id = ?').run(blogId);

    // Delete uploads directory
    const uploadsDir = this.getBlogUploadsDir(blogId);
    if (fs.existsSync(uploadsDir)) {
      fs.rmSync(uploadsDir, { recursive: true });
    }

    // Delete generated site
    const generatedDir = this.getGeneratedSiteDir(blogId);
    if (fs.existsSync(generatedDir)) {
      fs.rmSync(generatedDir, { recursive: true });
    }
  }

  mapBlogRow(row) {
    return {
      id: row.id,
      name: row.name,
      url: row.url,
      tagline: row.tagline,
      authorName: row.author_name,
      authorUrl: row.author_url,
      authorEmail: row.author_email,
      themeIdentifier: row.theme_identifier,
      accentColor: row.accent_color,
      backgroundColor: row.background_color,
      textColor: row.text_color,
      lightShade: row.light_shade,
      mediumShade: row.medium_shade,
      darkShade: row.dark_shade,
      publisherType: row.publisher_type,
      awsRegion: row.aws_region,
      awsS3Bucket: row.aws_s3_bucket,
      awsCloudFrontDistId: row.aws_cloudfront_dist_id,
      awsAccessKeyId: row.aws_access_key_id,
      awsSecretAccessKey: row.aws_secret_access_key,
      ftpHost: row.ftp_host,
      ftpPort: row.ftp_port,
      ftpUsername: row.ftp_username,
      ftpPassword: row.ftp_password,
      ftpPrivateKey: row.ftp_private_key,
      ftpPath: row.ftp_path,
      gitRepositoryUrl: row.git_repository_url,
      gitUsername: row.git_username,
      gitToken: row.git_token,
      gitBranch: row.git_branch,
      gitCommitMessage: row.git_commit_message,
      timezone: row.timezone || 'UTC',
      createdAt: row.created_at,
      updatedAt: row.updated_at
    };
  }

  // ============ Post Operations ============

  getAllPosts(blogId, includeDrafts = false) {
    const db = getDatabase();
    let query = 'SELECT * FROM posts WHERE blog_id = ?';
    if (!includeDrafts) {
      query += ' AND is_draft = 0';
    }
    query += ' ORDER BY created_at DESC';

    const rows = db.prepare(query).all(blogId);
    return rows.map(row => this.mapPostRow(row));
  }

  getPost(blogId, postId) {
    const db = getDatabase();
    const row = db.prepare('SELECT * FROM posts WHERE id = ? AND blog_id = ?').get(postId, blogId);
    return row ? this.mapPostRow(row) : null;
  }

  createPost(blogId, postData) {
    const db = getDatabase();
    const postId = uuidv4();
    const now = new Date().toISOString();

    // Handle embed data
    let embedType = null;
    let embedPosition = null;
    let embedData = null;

    if (postData.embed) {
      embedType = postData.embed.type || null;
      embedPosition = postData.embed.position || 'below';
      embedData = JSON.stringify(postData.embed);
    }

    const stmt = db.prepare(`
      INSERT INTO posts (
        id, blog_id, title, content, stub, is_draft, category_id,
        embed_type, embed_position, embed_data, sync_id, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `);

    stmt.run(
      postId,
      blogId,
      postData.title || null,
      postData.content || '',
      postData.stub || postId,
      postData.isDraft ? 1 : 0,
      postData.categoryId || null,
      embedType,
      embedPosition,
      embedData,
      postData.syncId || null,
      postData.createdAt || now,
      now
    );

    // Handle tags
    if (postData.tagIds && Array.isArray(postData.tagIds)) {
      const insertPostTag = db.prepare('INSERT OR IGNORE INTO post_tags (post_id, tag_id) VALUES (?, ?)');
      for (const tagId of postData.tagIds) {
        insertPostTag.run(postId, tagId);
      }
    }

    return this.getPost(blogId, postId);
  }

  updatePost(blogId, postId, postData) {
    const db = getDatabase();
    const existing = this.getPost(blogId, postId);
    if (!existing) {
      throw new Error(`Post ${postId} not found`);
    }

    const now = new Date().toISOString();

    // Handle embed data
    let embedType = null;
    let embedPosition = null;
    let embedData = null;

    if (postData.embed) {
      embedType = postData.embed.type || null;
      embedPosition = postData.embed.position || 'below';
      embedData = JSON.stringify(postData.embed);
    } else if (postData.embed === null) {
      // Explicitly removing embed
      embedType = null;
      embedPosition = null;
      embedData = null;
    } else if (existing.embed) {
      // Keep existing embed if not provided
      embedType = existing.embed.type || null;
      embedPosition = existing.embed.position || 'below';
      embedData = JSON.stringify(existing.embed);
    }

    const stmt = db.prepare(`
      UPDATE posts SET
        title = ?, content = ?, stub = ?, is_draft = ?, category_id = ?,
        embed_type = ?, embed_position = ?, embed_data = ?, created_at = ?, updated_at = ?
      WHERE id = ? AND blog_id = ?
    `);

    stmt.run(
      postData.title !== undefined ? postData.title : existing.title,
      postData.content !== undefined ? postData.content : existing.content,
      postData.stub !== undefined ? postData.stub : existing.stub,
      postData.isDraft !== undefined ? (postData.isDraft ? 1 : 0) : (existing.isDraft ? 1 : 0),
      postData.categoryId !== undefined ? postData.categoryId : existing.categoryId,
      embedType,
      embedPosition,
      embedData,
      postData.createdAt !== undefined ? postData.createdAt : existing.createdAt,
      now,
      postId,
      blogId
    );

    // Update tags if provided
    if (postData.tagIds !== undefined) {
      // Remove existing tags
      db.prepare('DELETE FROM post_tags WHERE post_id = ?').run(postId);

      // Add new tags
      if (Array.isArray(postData.tagIds)) {
        const insertPostTag = db.prepare('INSERT OR IGNORE INTO post_tags (post_id, tag_id) VALUES (?, ?)');
        for (const tagId of postData.tagIds) {
          insertPostTag.run(postId, tagId);
        }
      }
    }

    return this.getPost(blogId, postId);
  }

  deletePost(blogId, postId) {
    const db = getDatabase();
    db.prepare('DELETE FROM posts WHERE id = ? AND blog_id = ?').run(postId, blogId);
  }

  mapPostRow(row) {
    const db = getDatabase();

    // Get tag IDs for this post
    const tagRows = db.prepare('SELECT tag_id FROM post_tags WHERE post_id = ?').all(row.id);
    const tagIds = tagRows.map(r => r.tag_id);

    // Parse embed data
    let embed = null;
    if (row.embed_data) {
      try {
        embed = JSON.parse(row.embed_data);
      } catch (e) {
        console.error('Error parsing embed data:', e);
      }
    }

    return {
      id: row.id,
      title: row.title,
      content: row.content,
      stub: row.stub,
      isDraft: row.is_draft === 1,
      categoryId: row.category_id,
      tagIds: tagIds,
      embed: embed,
      syncId: row.sync_id,
      createdAt: row.created_at,
      updatedAt: row.updated_at
    };
  }

  // ============ Post Search (for FTS) ============

  searchPosts(blogId, searchTerm, options = {}) {
    const db = getDatabase();
    const { includeDrafts = true, sort = 'date_desc' } = options;

    // Build the search query using FTS5
    // Also search in category names and tag names
    let query = `
      SELECT DISTINCT p.* FROM posts p
      LEFT JOIN categories c ON p.category_id = c.id
      LEFT JOIN post_tags pt ON p.id = pt.post_id
      LEFT JOIN tags t ON pt.tag_id = t.id
      WHERE p.blog_id = ?
    `;

    const params = [blogId];

    if (!includeDrafts) {
      query += ' AND p.is_draft = 0';
    }

    if (searchTerm && searchTerm.trim()) {
      const term = `%${searchTerm.trim()}%`;
      query += ` AND (
        p.title LIKE ? COLLATE NOCASE
        OR p.content LIKE ? COLLATE NOCASE
        OR c.name LIKE ? COLLATE NOCASE
        OR t.name LIKE ? COLLATE NOCASE
      )`;
      params.push(term, term, term, term);
    }

    // Add sorting
    switch (sort) {
      case 'date_asc':
        query += ' ORDER BY p.created_at ASC';
        break;
      case 'title_asc':
        query += ' ORDER BY COALESCE(p.title, p.content) ASC';
        break;
      case 'title_desc':
        query += ' ORDER BY COALESCE(p.title, p.content) DESC';
        break;
      case 'date_desc':
      default:
        query += ' ORDER BY p.created_at DESC';
    }

    const rows = db.prepare(query).all(...params);
    return rows.map(row => this.mapPostRow(row));
  }

  // ============ Category Operations ============

  getAllCategories(blogId) {
    const db = getDatabase();
    const rows = db.prepare(`
      SELECT * FROM categories WHERE blog_id = ? ORDER BY name ASC
    `).all(blogId);

    return rows.map(row => this.mapCategoryRow(row));
  }

  getCategory(blogId, categoryId) {
    const db = getDatabase();
    const row = db.prepare('SELECT * FROM categories WHERE id = ? AND blog_id = ?').get(categoryId, blogId);
    return row ? this.mapCategoryRow(row) : null;
  }

  createCategory(blogId, categoryData) {
    const db = getDatabase();
    const categoryId = uuidv4();
    const now = new Date().toISOString();

    const stmt = db.prepare(`
      INSERT INTO categories (id, blog_id, name, description, stub, sync_id, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?)
    `);

    stmt.run(
      categoryId,
      blogId,
      categoryData.name || 'Untitled',
      categoryData.description || null,
      categoryData.stub || categoryId,
      categoryData.syncId || null,
      now
    );

    return this.getCategory(blogId, categoryId);
  }

  updateCategory(blogId, categoryId, categoryData) {
    const db = getDatabase();
    const existing = this.getCategory(blogId, categoryId);
    if (!existing) {
      throw new Error(`Category ${categoryId} not found`);
    }

    const stmt = db.prepare(`
      UPDATE categories SET name = ?, description = ?, stub = ?
      WHERE id = ? AND blog_id = ?
    `);

    stmt.run(
      categoryData.name !== undefined ? categoryData.name : existing.name,
      categoryData.description !== undefined ? categoryData.description : existing.description,
      categoryData.stub !== undefined ? categoryData.stub : existing.stub,
      categoryId,
      blogId
    );

    return this.getCategory(blogId, categoryId);
  }

  deleteCategory(blogId, categoryId) {
    const db = getDatabase();
    // Note: Posts with this category will have category_id set to NULL due to ON DELETE SET NULL
    db.prepare('DELETE FROM categories WHERE id = ? AND blog_id = ?').run(categoryId, blogId);
  }

  getCategoryPostCount(blogId, categoryId) {
    const db = getDatabase();
    const result = db.prepare(`
      SELECT COUNT(*) as count FROM posts WHERE blog_id = ? AND category_id = ? AND is_draft = 0
    `).get(blogId, categoryId);
    return result.count;
  }

  mapCategoryRow(row) {
    return {
      id: row.id,
      name: row.name,
      description: row.description,
      stub: row.stub,
      syncId: row.sync_id,
      createdAt: row.created_at
    };
  }

  // ============ Tag Operations ============

  getAllTags(blogId) {
    const db = getDatabase();
    const rows = db.prepare(`
      SELECT * FROM tags WHERE blog_id = ? ORDER BY name ASC
    `).all(blogId);

    return rows.map(row => this.mapTagRow(row));
  }

  getTag(blogId, tagId) {
    const db = getDatabase();
    const row = db.prepare('SELECT * FROM tags WHERE id = ? AND blog_id = ?').get(tagId, blogId);
    return row ? this.mapTagRow(row) : null;
  }

  createTag(blogId, tagData) {
    const db = getDatabase();
    const tagId = uuidv4();
    const now = new Date().toISOString();

    const stmt = db.prepare(`
      INSERT INTO tags (id, blog_id, name, stub, sync_id, created_at)
      VALUES (?, ?, ?, ?, ?, ?)
    `);

    stmt.run(
      tagId,
      blogId,
      (tagData.name || 'untitled').toLowerCase(),
      tagData.stub || tagId,
      tagData.syncId || null,
      now
    );

    return this.getTag(blogId, tagId);
  }

  updateTag(blogId, tagId, tagData) {
    const db = getDatabase();
    const existing = this.getTag(blogId, tagId);
    if (!existing) {
      throw new Error(`Tag ${tagId} not found`);
    }

    const stmt = db.prepare(`
      UPDATE tags SET name = ?, stub = ?
      WHERE id = ? AND blog_id = ?
    `);

    stmt.run(
      tagData.name !== undefined ? tagData.name.toLowerCase() : existing.name,
      tagData.stub !== undefined ? tagData.stub : existing.stub,
      tagId,
      blogId
    );

    return this.getTag(blogId, tagId);
  }

  deleteTag(blogId, tagId) {
    const db = getDatabase();
    // Note: post_tags entries will be deleted due to ON DELETE CASCADE
    db.prepare('DELETE FROM tags WHERE id = ? AND blog_id = ?').run(tagId, blogId);
  }

  getTagPostCount(blogId, tagId) {
    const db = getDatabase();
    const result = db.prepare(`
      SELECT COUNT(*) as count FROM post_tags pt
      JOIN posts p ON pt.post_id = p.id
      WHERE pt.tag_id = ? AND p.blog_id = ? AND p.is_draft = 0
    `).get(tagId, blogId);
    return result.count;
  }

  mapTagRow(row) {
    return {
      id: row.id,
      name: row.name,
      stub: row.stub,
      syncId: row.sync_id,
      createdAt: row.created_at
    };
  }

  // ============ Sidebar Object Operations ============

  getAllSidebarObjects(blogId) {
    const db = getDatabase();
    const rows = db.prepare(`
      SELECT * FROM sidebar_objects WHERE blog_id = ? ORDER BY sort_order ASC
    `).all(blogId);

    return rows.map(row => this.mapSidebarObjectRow(row));
  }

  getSidebarObject(blogId, objectId) {
    const db = getDatabase();
    const row = db.prepare('SELECT * FROM sidebar_objects WHERE id = ? AND blog_id = ?').get(objectId, blogId);
    return row ? this.mapSidebarObjectRow(row) : null;
  }

  createSidebarObject(blogId, objectData) {
    const db = getDatabase();
    const objectId = uuidv4();
    const now = new Date().toISOString();

    // Get max order
    const maxOrder = db.prepare(`
      SELECT COALESCE(MAX(sort_order), -1) as max_order FROM sidebar_objects WHERE blog_id = ?
    `).get(blogId).max_order;

    const stmt = db.prepare(`
      INSERT INTO sidebar_objects (id, blog_id, title, type, content, sort_order, sync_id, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    `);

    stmt.run(
      objectId,
      blogId,
      objectData.title || 'Untitled',
      objectData.type || 'text',
      objectData.content || null,
      objectData.order ?? maxOrder + 1,
      objectData.syncId || null,
      now
    );

    // Handle links for linkList type
    if (objectData.type === 'linkList' && Array.isArray(objectData.links)) {
      const insertLink = db.prepare(`
        INSERT INTO sidebar_links (id, sidebar_object_id, title, url, sort_order)
        VALUES (?, ?, ?, ?, ?)
      `);

      for (let i = 0; i < objectData.links.length; i++) {
        const link = objectData.links[i];
        insertLink.run(
          uuidv4(),
          objectId,
          link.title || 'Untitled',
          link.url || '',
          link.order ?? i
        );
      }
    }

    return this.getSidebarObject(blogId, objectId);
  }

  updateSidebarObject(blogId, objectId, objectData) {
    const db = getDatabase();
    const existing = this.getSidebarObject(blogId, objectId);
    if (!existing) {
      throw new Error(`Sidebar object ${objectId} not found`);
    }

    const stmt = db.prepare(`
      UPDATE sidebar_objects SET title = ?, type = ?, content = ?, sort_order = ?
      WHERE id = ? AND blog_id = ?
    `);

    stmt.run(
      objectData.title !== undefined ? objectData.title : existing.title,
      objectData.type !== undefined ? objectData.type : existing.type,
      objectData.content !== undefined ? objectData.content : existing.content,
      objectData.order !== undefined ? objectData.order : existing.order,
      objectId,
      blogId
    );

    // Update links if provided
    if (objectData.links !== undefined) {
      // Remove existing links
      db.prepare('DELETE FROM sidebar_links WHERE sidebar_object_id = ?').run(objectId);

      // Add new links
      if (Array.isArray(objectData.links)) {
        const insertLink = db.prepare(`
          INSERT INTO sidebar_links (id, sidebar_object_id, title, url, sort_order)
          VALUES (?, ?, ?, ?, ?)
        `);

        for (let i = 0; i < objectData.links.length; i++) {
          const link = objectData.links[i];
          insertLink.run(
            uuidv4(),
            objectId,
            link.title || 'Untitled',
            link.url || '',
            link.order ?? i
          );
        }
      }
    }

    return this.getSidebarObject(blogId, objectId);
  }

  deleteSidebarObject(blogId, objectId) {
    const db = getDatabase();
    // Links will be deleted due to ON DELETE CASCADE
    db.prepare('DELETE FROM sidebar_objects WHERE id = ? AND blog_id = ?').run(objectId, blogId);
  }

  mapSidebarObjectRow(row) {
    const db = getDatabase();

    // Get links for linkList type
    let links = [];
    if (row.type === 'linkList') {
      const linkRows = db.prepare(`
        SELECT * FROM sidebar_links WHERE sidebar_object_id = ? ORDER BY sort_order ASC
      `).all(row.id);

      links = linkRows.map(l => ({
        title: l.title,
        url: l.url,
        order: l.sort_order
      }));
    }

    return {
      id: row.id,
      title: row.title,
      type: row.type,
      content: row.content,
      order: row.sort_order,
      links: links,
      syncId: row.sync_id,
      createdAt: row.created_at
    };
  }

  // ============ Static File Operations ============

  getAllStaticFiles(blogId) {
    const db = getDatabase();
    const rows = db.prepare('SELECT * FROM static_files WHERE blog_id = ?').all(blogId);
    return rows.map(row => this.mapStaticFileRow(row));
  }

  getStaticFile(blogId, fileId) {
    const db = getDatabase();
    const row = db.prepare('SELECT * FROM static_files WHERE id = ? AND blog_id = ?').get(fileId, blogId);
    return row ? this.mapStaticFileRow(row) : null;
  }

  createStaticFile(blogId, fileData, fileBuffer) {
    const db = getDatabase();
    const fileId = uuidv4();
    const now = new Date().toISOString();
    const uploadsDir = this.getBlogUploadsDir(blogId);

    this.ensureDir(uploadsDir);

    // Save file data
    const storedFilename = `${fileId}-${fileData.filename}`;
    fs.writeFileSync(path.join(uploadsDir, storedFilename), fileBuffer);

    // Save metadata
    const stmt = db.prepare(`
      INSERT INTO static_files (id, blog_id, filename, stored_filename, mime_type, size, special_file_type, sync_id, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    `);

    stmt.run(
      fileId,
      blogId,
      fileData.filename || 'unknown',
      storedFilename,
      fileData.mimeType || null,
      fileData.size || fileBuffer.length,
      fileData.specialFileType || null,
      fileData.syncId || null,
      now
    );

    return this.getStaticFile(blogId, fileId);
  }

  deleteStaticFile(blogId, fileId) {
    const db = getDatabase();
    const staticFile = this.getStaticFile(blogId, fileId);

    if (staticFile) {
      // Delete actual file
      const filePath = path.join(this.getBlogUploadsDir(blogId), staticFile.storedFilename);
      if (fs.existsSync(filePath)) {
        fs.unlinkSync(filePath);
      }

      // Delete metadata
      db.prepare('DELETE FROM static_files WHERE id = ? AND blog_id = ?').run(fileId, blogId);
    }
  }

  getStaticFileBuffer(blogId, fileId) {
    const staticFile = this.getStaticFile(blogId, fileId);
    if (!staticFile) return null;

    const filePath = path.join(this.getBlogUploadsDir(blogId), staticFile.storedFilename);
    if (!fs.existsSync(filePath)) return null;

    return fs.readFileSync(filePath);
  }

  getEmbedImageBuffer(blogId, filename) {
    const filePath = path.join(this.getBlogUploadsDir(blogId), filename);
    if (!fs.existsSync(filePath)) return null;

    return fs.readFileSync(filePath);
  }

  // Save embed image to disk (for image embeds)
  saveEmbedImage(blogId, filename, buffer) {
    const uploadsDir = this.getBlogUploadsDir(blogId);
    this.ensureDir(uploadsDir);

    const filePath = path.join(uploadsDir, filename);
    fs.writeFileSync(filePath, buffer);
    return filename;
  }

  mapStaticFileRow(row) {
    return {
      id: row.id,
      filename: row.filename,
      storedFilename: row.stored_filename,
      mimeType: row.mime_type,
      size: row.size,
      isSpecialFile: !!row.special_file_type,
      specialFileType: row.special_file_type,
      syncId: row.sync_id,
      createdAt: row.created_at
    };
  }

  // ============ Published Files Tracking ============

  getPublishedFiles(blogId) {
    const db = getDatabase();
    const row = db.prepare('SELECT * FROM published_files WHERE blog_id = ?').get(blogId);

    if (!row) {
      return { fileHashes: {}, lastPublishedDate: null };
    }

    return {
      publisherType: row.publisher_type,
      lastPublishedDate: row.last_published_at,
      fileHashes: row.file_hashes ? JSON.parse(row.file_hashes) : {}
    };
  }

  savePublishedFiles(blogId, publishedData) {
    const db = getDatabase();

    const stmt = db.prepare(`
      INSERT OR REPLACE INTO published_files (blog_id, publisher_type, last_published_at, file_hashes)
      VALUES (?, ?, ?, ?)
    `);

    stmt.run(
      blogId,
      publishedData.publisherType || null,
      publishedData.lastPublishedDate || new Date().toISOString(),
      JSON.stringify(publishedData.fileHashes || {})
    );
  }

  // ============ Theme Operations ============

  getAllThemes() {
    const db = getDatabase();
    const rows = db.prepare('SELECT * FROM themes').all();
    return rows.map(row => this.mapThemeRow(row));
  }

  getTheme(themeId) {
    const db = getDatabase();
    const row = db.prepare('SELECT * FROM themes WHERE id = ? OR identifier = ?').get(themeId, themeId);
    return row ? this.mapThemeRow(row) : null;
  }

  createTheme(themeData) {
    const db = getDatabase();
    const themeId = uuidv4();
    const now = new Date().toISOString();

    const stmt = db.prepare(`
      INSERT INTO themes (id, name, identifier, templates, created_at)
      VALUES (?, ?, ?, ?, ?)
    `);

    stmt.run(
      themeId,
      themeData.name || 'Custom Theme',
      themeData.identifier || themeId,
      JSON.stringify(themeData.templates || {}),
      now
    );

    return this.getTheme(themeId);
  }

  updateTheme(themeId, themeData) {
    const db = getDatabase();
    const existing = this.getTheme(themeId);
    if (!existing) {
      throw new Error(`Theme ${themeId} not found`);
    }

    const stmt = db.prepare(`
      UPDATE themes SET name = ?, identifier = ?, templates = ?
      WHERE id = ?
    `);

    stmt.run(
      themeData.name !== undefined ? themeData.name : existing.name,
      themeData.identifier !== undefined ? themeData.identifier : existing.identifier,
      themeData.templates !== undefined ? JSON.stringify(themeData.templates) : JSON.stringify(existing.templates),
      existing.id
    );

    return this.getTheme(existing.id);
  }

  deleteTheme(themeId) {
    const db = getDatabase();
    db.prepare('DELETE FROM themes WHERE id = ?').run(themeId);
  }

  mapThemeRow(row) {
    return {
      id: row.id,
      name: row.name,
      identifier: row.identifier,
      templates: row.templates ? JSON.parse(row.templates) : {},
      createdAt: row.created_at
    };
  }

  // ============ Sync Configuration ============

  getSyncConfig(blogId) {
    const db = getDatabase();
    const row = db.prepare('SELECT * FROM sync_config WHERE blog_id = ?').get(blogId);

    if (!row) {
      return {
        lastSyncedVersion: 0,
        lastSyncedAt: null
      };
    }

    return {
      blogId: row.blog_id,
      lastSyncedVersion: row.last_synced_version || 0,
      lastSyncedAt: row.last_synced_at,
      createdAt: row.created_at
    };
  }

  saveSyncConfig(blogId, syncConfig) {
    const db = getDatabase();

    const stmt = db.prepare(`
      INSERT OR REPLACE INTO sync_config
        (blog_id, sync_enabled, sync_password, last_synced_version, last_synced_at, local_file_hashes, local_content_hashes, encryption_salt, created_at)
      VALUES (?, 1, NULL, ?, ?, '{}', '{}', NULL, COALESCE((SELECT created_at FROM sync_config WHERE blog_id = ?), datetime('now')))
    `);

    stmt.run(
      blogId,
      syncConfig.lastSyncedVersion || 0,
      syncConfig.lastSyncedAt || null,
      blogId
    );
  }

  updateSyncVersion(blogId, version) {
    const db = getDatabase();

    const stmt = db.prepare(`
      INSERT OR REPLACE INTO sync_config
        (blog_id, sync_enabled, sync_password, last_synced_version, last_synced_at, local_file_hashes, local_content_hashes, encryption_salt, created_at)
      VALUES (?, 1, NULL, ?, ?, '{}', '{}', NULL, COALESCE((SELECT created_at FROM sync_config WHERE blog_id = ?), datetime('now')))
    `);

    stmt.run(
      blogId,
      version,
      new Date().toISOString(),
      blogId
    );
  }

  deleteSyncConfig(blogId) {
    const db = getDatabase();
    db.prepare('DELETE FROM sync_config WHERE blog_id = ?').run(blogId);
  }

  // ============ Generated Site Directory ============

  getGeneratedSiteDir(blogId) {
    return path.join(this.generatedDir, blogId);
  }

  clearGeneratedSite(blogId) {
    const siteDir = this.getGeneratedSiteDir(blogId);
    if (fs.existsSync(siteDir)) {
      fs.rmSync(siteDir, { recursive: true });
    }
    this.ensureDir(siteDir);
    return siteDir;
  }

  // ============ Sync ID Lookup Methods (for incremental sync) ============

  getCategoryBySyncId(blogId, syncId) {
    const db = getDatabase();
    const row = db.prepare('SELECT * FROM categories WHERE blog_id = ? AND sync_id = ?').get(blogId, syncId);
    return row ? this.mapCategoryRow(row) : null;
  }

  getTagBySyncId(blogId, syncId) {
    const db = getDatabase();
    const row = db.prepare('SELECT * FROM tags WHERE blog_id = ? AND sync_id = ?').get(blogId, syncId);
    return row ? this.mapTagRow(row) : null;
  }

  getPostBySyncId(blogId, syncId) {
    const db = getDatabase();
    const row = db.prepare('SELECT * FROM posts WHERE blog_id = ? AND sync_id = ?').get(blogId, syncId);
    return row ? this.mapPostRow(row) : null;
  }

  getSidebarObjectBySyncId(blogId, syncId) {
    const db = getDatabase();
    const row = db.prepare('SELECT * FROM sidebar_objects WHERE blog_id = ? AND sync_id = ?').get(blogId, syncId);
    return row ? this.mapSidebarObjectRow(row) : null;
  }

  getStaticFileBySyncId(blogId, syncId) {
    const db = getDatabase();
    const row = db.prepare('SELECT * FROM static_files WHERE blog_id = ? AND sync_id = ?').get(blogId, syncId);
    return row ? this.mapStaticFileRow(row) : null;
  }

  // Update syncId on an existing entity
  updateCategorySyncId(blogId, categoryId, syncId) {
    const db = getDatabase();
    db.prepare('UPDATE categories SET sync_id = ? WHERE id = ? AND blog_id = ?').run(syncId, categoryId, blogId);
  }

  updateTagSyncId(blogId, tagId, syncId) {
    const db = getDatabase();
    db.prepare('UPDATE tags SET sync_id = ? WHERE id = ? AND blog_id = ?').run(syncId, tagId, blogId);
  }

  updatePostSyncId(blogId, postId, syncId) {
    const db = getDatabase();
    db.prepare('UPDATE posts SET sync_id = ? WHERE id = ? AND blog_id = ?').run(syncId, postId, blogId);
  }

  updateSidebarObjectSyncId(blogId, objectId, syncId) {
    const db = getDatabase();
    db.prepare('UPDATE sidebar_objects SET sync_id = ? WHERE id = ? AND blog_id = ?').run(syncId, objectId, blogId);
  }

  updateStaticFileSyncId(blogId, fileId, syncId) {
    const db = getDatabase();
    db.prepare('UPDATE static_files SET sync_id = ? WHERE id = ? AND blog_id = ?').run(syncId, fileId, blogId);
  }
}

export default Storage;
