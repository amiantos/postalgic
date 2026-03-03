import fs from 'fs';
import path from 'path';
import { v4 as uuidv4 } from 'uuid';
import AdmZip from 'adm-zip';
import Storage from '../utils/storage.js';

/**
 * Service for importing blogs from Postalgic iOS export ZIP files
 */
class BlogImporter {
  constructor(dataRoot) {
    this.storage = new Storage(dataRoot);
    this.dataRoot = dataRoot;
  }

  /**
   * Import a blog from a ZIP file buffer
   * @param {Buffer} zipBuffer - The ZIP file buffer
   * @returns {Object} The created blog object
   */
  async importBlog(zipBuffer) {
    const zip = new AdmZip(zipBuffer);
    const entries = zip.getEntries();

    // Build a map of entry names to entries for easy lookup
    const entryMap = {};
    entries.forEach(entry => {
      entryMap[entry.entryName] = entry;
    });

    // Validate manifest
    const manifestEntry = entryMap['manifest.json'];
    if (!manifestEntry) {
      throw new Error('Invalid export: manifest.json not found');
    }

    const manifest = JSON.parse(manifestEntry.getData().toString('utf8'));
    console.log(`Importing blog: ${manifest.blogName} (export version: ${manifest.version})`);

    // Read blog.json
    const blogEntry = entryMap['blog.json'];
    if (!blogEntry) {
      throw new Error('Invalid export: blog.json not found');
    }

    const exportedBlog = JSON.parse(blogEntry.getData().toString('utf8'));

    // Create the blog
    const blogData = {
      name: exportedBlog.name,
      url: exportedBlog.url || '',
      tagline: exportedBlog.tagline || '',
      authorName: exportedBlog.authorName || '',
      authorUrl: exportedBlog.authorUrl || '',
      authorEmail: exportedBlog.authorEmail || '',
      themeIdentifier: exportedBlog.themeIdentifier || 'default',
      accentColor: exportedBlog.accentColor || '#FFA100',
      backgroundColor: exportedBlog.backgroundColor || '#efefef',
      textColor: exportedBlog.textColor || '#2d3748',
      lightShade: exportedBlog.lightShade || '#dedede',
      mediumShade: exportedBlog.mediumShade || '#a0aec0',
      darkShade: exportedBlog.darkShade || '#4a5568',
      // Publishing settings (if credentials were included)
      publisherType: exportedBlog.publisherType || 'manual',
      awsRegion: exportedBlog.awsRegion || '',
      awsS3Bucket: exportedBlog.awsS3Bucket || '',
      awsCloudFrontDistId: exportedBlog.awsCloudFrontDistId || '',
      awsAccessKeyId: exportedBlog.awsAccessKeyId || '',
      awsSecretAccessKey: exportedBlog.awsSecretAccessKey || '',
      ftpHost: exportedBlog.ftpHost || '',
      ftpPort: exportedBlog.ftpPort || 22,
      ftpUsername: exportedBlog.ftpUsername || '',
      ftpPassword: exportedBlog.ftpPassword || '',
      ftpPath: exportedBlog.ftpPath || '',
      gitRepositoryUrl: exportedBlog.gitRepositoryUrl || '',
      gitUsername: exportedBlog.gitUsername || '',
      gitToken: exportedBlog.gitPassword || '', // iOS uses gitPassword, web uses gitToken
      gitBranch: exportedBlog.gitBranch || 'main',
      gitCommitMessage: exportedBlog.gitCommitMessage || 'Update blog'
    };

    const blog = this.storage.createBlog(blogData);
    const blogId = blog.id;

    console.log(`Created blog with ID: ${blogId}`);

    // ID mapping tables (old export ID -> new storage ID)
    const categoryIdMap = {};
    const tagIdMap = {};

    // Import categories
    const categoryEntries = entries.filter(e => e.entryName.startsWith('categories/') && e.entryName.endsWith('.json'));
    for (const entry of categoryEntries) {
      const exportedCategory = JSON.parse(entry.getData().toString('utf8'));
      const oldId = exportedCategory.id;

      const categoryData = {
        name: exportedCategory.name,
        description: exportedCategory.description || '',
        stub: exportedCategory.stub,
        createdAt: exportedCategory.createdAt
      };

      const category = this.storage.createCategory(blogId, categoryData);
      categoryIdMap[oldId] = category.id;
      console.log(`Imported category: ${exportedCategory.name}`);
    }

    // Import tags
    const tagEntries = entries.filter(e => e.entryName.startsWith('tags/') && e.entryName.endsWith('.json'));
    for (const entry of tagEntries) {
      const exportedTag = JSON.parse(entry.getData().toString('utf8'));
      const oldId = exportedTag.id;

      const tagData = {
        name: exportedTag.name,
        stub: exportedTag.stub,
        createdAt: exportedTag.createdAt
      };

      const tag = this.storage.createTag(blogId, tagData);
      tagIdMap[oldId] = tag.id;
      console.log(`Imported tag: ${exportedTag.name}`);
    }

    // Import embed images first (so we have them available for posts)
    const embedImagesDir = this.storage.getBlogUploadsDir(blogId);
    const embedImageEntries = entries.filter(e => e.entryName.startsWith('embed-images/') && !e.isDirectory);
    for (const entry of embedImageEntries) {
      const filename = path.basename(entry.entryName);
      const imageBuffer = entry.getData();
      const targetPath = path.join(embedImagesDir, filename);

      fs.writeFileSync(targetPath, imageBuffer);
      console.log(`Imported embed image: ${filename}`);
    }

    // Import posts
    const postEntries = entries.filter(e => e.entryName.startsWith('posts/') && e.entryName.endsWith('.json'));
    for (const entry of postEntries) {
      const exportedPost = JSON.parse(entry.getData().toString('utf8'));

      // Map category ID
      let categoryId = null;
      if (exportedPost.categoryId && categoryIdMap[exportedPost.categoryId]) {
        categoryId = categoryIdMap[exportedPost.categoryId];
      }

      // Map tag IDs
      const tagIds = (exportedPost.tagIds || [])
        .map(oldId => tagIdMap[oldId])
        .filter(id => id != null);

      // Build embed object if present
      let embed = null;
      if (exportedPost.embed) {
        const e = exportedPost.embed;

        // Map iOS embed types to web app types
        // iOS: "YouTube", "Link", "Image" -> web: "youtube", "link", "image"
        let embedType = (e.type || '').toLowerCase();

        // Map iOS embed positions to web app positions
        // iOS: "Above", "Below" -> web: "above", "below"
        let embedPosition = (e.position || 'below').toLowerCase();

        embed = {
          url: e.url,
          type: embedType,
          position: embedPosition,
          title: e.title || null,
          description: e.description || null,
          imageUrl: e.imageUrl || null,
          imageFilename: e.imageFilename || null,
          images: (e.embedImages || []).map(img => ({
            filename: img.filename,
            order: img.order
          }))
        };
      }

      const postData = {
        title: exportedPost.title,
        content: exportedPost.content,
        stub: exportedPost.stub,
        isDraft: exportedPost.isDraft || false,
        createdAt: exportedPost.createdAt,
        categoryId,
        tagIds,
        embed
      };

      const post = this.storage.createPost(blogId, postData);
      console.log(`Imported post: ${exportedPost.title || exportedPost.stub || 'untitled'}`);
    }

    // Import sidebar objects
    const sidebarEntries = entries.filter(e => e.entryName.startsWith('sidebar/') && e.entryName.endsWith('.json'));
    for (const entry of sidebarEntries) {
      const exportedSidebar = JSON.parse(entry.getData().toString('utf8'));

      // Map iOS sidebar types to web app types
      // iOS: "Text" -> web: "text"
      // iOS: "Link List" -> web: "linkList"
      let sidebarType = exportedSidebar.type;
      if (sidebarType === 'Text') {
        sidebarType = 'text';
      } else if (sidebarType === 'Link List') {
        sidebarType = 'linkList';
      }

      const sidebarData = {
        title: exportedSidebar.title,
        type: sidebarType,
        order: exportedSidebar.order,
        createdAt: exportedSidebar.createdAt
      };

      // Set content or links based on type
      if (sidebarType === 'text') {
        sidebarData.content = exportedSidebar.content || '';
        sidebarData.links = [];
      } else {
        sidebarData.content = '';
        sidebarData.links = (exportedSidebar.links || []).map(link => ({
          title: link.title,
          url: link.url,
          order: link.order
        }));
      }

      this.storage.createSidebarObject(blogId, sidebarData);
      console.log(`Imported sidebar object: ${exportedSidebar.title} (type: ${sidebarType})`);
    }

    // Import static files
    const staticFileEntries = entries.filter(e => e.entryName.startsWith('static-files/') && e.entryName.endsWith('.json'));
    for (const entry of staticFileEntries) {
      const exportedFile = JSON.parse(entry.getData().toString('utf8'));

      // Find the corresponding upload file
      const uploadEntryName = `uploads/${exportedFile.filename}`;
      const uploadEntry = entryMap[uploadEntryName];

      if (uploadEntry) {
        const fileBuffer = uploadEntry.getData();

        // Map iOS special file types to web app types
        // iOS: "social-share.png" -> web: "social-share"
        // iOS: "favicon" -> web: "favicon" (no change needed)
        let specialFileType = exportedFile.specialFileType || null;
        if (specialFileType === 'social-share.png') {
          specialFileType = 'social-share';
        }

        const fileData = {
          filename: exportedFile.filename,
          mimeType: exportedFile.mimeType,
          isSpecialFile: exportedFile.isSpecialFile || false,
          specialFileType: specialFileType,
          size: fileBuffer.length
        };

        this.storage.createStaticFile(blogId, fileData, fileBuffer);
        console.log(`Imported static file: ${exportedFile.filename} (special: ${specialFileType || 'none'})`);
      } else {
        console.warn(`Warning: Upload file not found for ${exportedFile.filename}`);
      }
    }

    // Import custom themes
    const themeEntries = entries.filter(e => e.entryName.startsWith('themes/') && e.entryName.endsWith('.json'));
    for (const entry of themeEntries) {
      const exportedTheme = JSON.parse(entry.getData().toString('utf8'));

      // Check if theme already exists
      const existingTheme = this.storage.getTheme(exportedTheme.identifier);
      if (!existingTheme) {
        const themeData = {
          name: exportedTheme.name,
          identifier: exportedTheme.identifier,
          isCustomized: exportedTheme.isCustomized || false,
          templates: exportedTheme.templates || {}
        };

        this.storage.createTheme(themeData);
        console.log(`Imported custom theme: ${exportedTheme.name}`);
      } else {
        console.log(`Theme already exists, skipping: ${exportedTheme.identifier}`);
      }
    }

    console.log(`Blog import complete: ${blog.name}`);
    return blog;
  }

  /**
   * Validate a ZIP file without importing
   * @param {Buffer} zipBuffer - The ZIP file buffer
   * @returns {Object} Validation result with manifest info and counts
   */
  validateExport(zipBuffer) {
    try {
      const zip = new AdmZip(zipBuffer);
      const entries = zip.getEntries();

      // Build entry map
      const entryMap = {};
      entries.forEach(entry => {
        entryMap[entry.entryName] = entry;
      });

      // Check for manifest
      const manifestEntry = entryMap['manifest.json'];
      if (!manifestEntry) {
        return { valid: false, error: 'manifest.json not found' };
      }

      const manifest = JSON.parse(manifestEntry.getData().toString('utf8'));

      // Check for blog.json
      const blogEntry = entryMap['blog.json'];
      if (!blogEntry) {
        return { valid: false, error: 'blog.json not found' };
      }

      const blog = JSON.parse(blogEntry.getData().toString('utf8'));

      // Count items
      const counts = {
        posts: entries.filter(e => e.entryName.startsWith('posts/') && e.entryName.endsWith('.json')).length,
        categories: entries.filter(e => e.entryName.startsWith('categories/') && e.entryName.endsWith('.json')).length,
        tags: entries.filter(e => e.entryName.startsWith('tags/') && e.entryName.endsWith('.json')).length,
        sidebarObjects: entries.filter(e => e.entryName.startsWith('sidebar/') && e.entryName.endsWith('.json')).length,
        staticFiles: entries.filter(e => e.entryName.startsWith('static-files/') && e.entryName.endsWith('.json')).length,
        embedImages: entries.filter(e => e.entryName.startsWith('embed-images/') && !e.isDirectory).length,
        themes: entries.filter(e => e.entryName.startsWith('themes/') && e.entryName.endsWith('.json')).length
      };

      return {
        valid: true,
        manifest,
        blogName: blog.name,
        blogUrl: blog.url,
        includesCredentials: manifest.includesCredentials || false,
        counts
      };
    } catch (error) {
      return { valid: false, error: error.message };
    }
  }
}

export default BlogImporter;
