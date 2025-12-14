/**
 * Sync data generator service
 * Generates the /sync/ directory for bidirectional sync between iOS and Self-Hosted apps
 */

import fs from 'fs';
import path from 'path';
import { calculateHash, calculateBufferHash, formatISO8601Date } from '../utils/helpers.js';
import syncEncryption from './syncEncryption.js';

/**
 * Generate the sync directory for a blog
 * @param {Storage} storage - Storage instance
 * @param {string} blogId - Blog ID
 * @param {string} outputDir - Output directory (site root)
 * @param {string} password - Sync password for encrypting drafts
 * @returns {Promise<Object>} - Object containing fileHashes and syncVersion
 */
export async function generateSyncDirectory(storage, blogId, outputDir, password) {
  const blog = storage.getBlog(blogId);
  if (!blog) {
    throw new Error('Blog not found');
  }

  const syncConfig = storage.getSyncConfig(blogId);
  const newSyncVersion = (syncConfig.lastSyncedVersion || 0) + 1;

  // Get all data
  const allPosts = storage.getAllPosts(blogId, true); // Include drafts
  const publishedPosts = allPosts.filter(p => !p.isDraft);
  const drafts = allPosts.filter(p => p.isDraft);
  const categories = storage.getAllCategories(blogId);
  const tags = storage.getAllTags(blogId);
  const sidebarObjects = storage.getAllSidebarObjects(blogId);
  const staticFiles = storage.getAllStaticFiles(blogId);

  // Get theme if custom
  let theme = null;
  if (blog.themeIdentifier && blog.themeIdentifier !== 'default') {
    theme = storage.getTheme(blog.themeIdentifier);
  }

  // Create sync directory structure
  const syncDir = path.join(outputDir, 'sync');
  const dirs = [
    syncDir,
    path.join(syncDir, 'posts'),
    path.join(syncDir, 'drafts'),
    path.join(syncDir, 'categories'),
    path.join(syncDir, 'tags'),
    path.join(syncDir, 'sidebar'),
    path.join(syncDir, 'static-files'),
    path.join(syncDir, 'embed-images'),
    path.join(syncDir, 'themes')
  ];

  for (const dir of dirs) {
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }
  }

  const fileHashes = {};
  const draftIVs = {};

  // Generate encryption key from password
  const salt = syncEncryption.generateSalt();

  // === Generate blog.json ===
  const blogData = {
    name: blog.name,
    url: blog.url || '',
    tagline: blog.tagline || '',
    authorName: blog.authorName || '',
    authorUrl: blog.authorUrl || '',
    authorEmail: blog.authorEmail || '',
    timezone: blog.timezone || 'UTC',
    colors: {
      accent: blog.accentColor || '#FFA100',
      background: blog.backgroundColor || '#efefef',
      text: blog.textColor || '#2d3748',
      lightShade: blog.lightShade || '#dedede',
      mediumShade: blog.mediumShade || '#a0aec0',
      darkShade: blog.darkShade || '#4a5568'
    },
    themeIdentifier: blog.themeIdentifier || 'default'
  };
  const blogJson = JSON.stringify(blogData, null, 2);
  fs.writeFileSync(path.join(syncDir, 'blog.json'), blogJson);
  fileHashes['blog.json'] = calculateHash(blogJson);

  // === Generate categories ===
  const categoryIndex = { categories: [] };
  for (const category of categories) {
    const categoryData = {
      id: category.id,
      name: category.name,
      description: category.description || '',
      stub: category.stub,
      createdAt: category.createdAt
    };
    const categoryJson = JSON.stringify(categoryData, null, 2);
    fs.writeFileSync(path.join(syncDir, 'categories', `${category.id}.json`), categoryJson);
    const hash = calculateHash(categoryJson);
    fileHashes[`categories/${category.id}.json`] = hash;

    categoryIndex.categories.push({
      id: category.id,
      stub: category.stub,
      hash
    });
  }
  const categoryIndexJson = JSON.stringify(categoryIndex, null, 2);
  fs.writeFileSync(path.join(syncDir, 'categories', 'index.json'), categoryIndexJson);
  fileHashes['categories/index.json'] = calculateHash(categoryIndexJson);

  // === Generate tags ===
  const tagIndex = { tags: [] };
  for (const tag of tags) {
    const tagData = {
      id: tag.id,
      name: tag.name,
      stub: tag.stub,
      createdAt: tag.createdAt
    };
    const tagJson = JSON.stringify(tagData, null, 2);
    fs.writeFileSync(path.join(syncDir, 'tags', `${tag.id}.json`), tagJson);
    const hash = calculateHash(tagJson);
    fileHashes[`tags/${tag.id}.json`] = hash;

    tagIndex.tags.push({
      id: tag.id,
      stub: tag.stub,
      hash
    });
  }
  const tagIndexJson = JSON.stringify(tagIndex, null, 2);
  fs.writeFileSync(path.join(syncDir, 'tags', 'index.json'), tagIndexJson);
  fileHashes['tags/index.json'] = calculateHash(tagIndexJson);

  // === Generate published posts (unencrypted) ===
  const postIndex = { posts: [] };
  for (const post of publishedPosts) {
    const postData = createSyncPost(post, storage, blogId);
    const postJson = JSON.stringify(postData, null, 2);
    fs.writeFileSync(path.join(syncDir, 'posts', `${post.id}.json`), postJson);
    const hash = calculateHash(postJson);
    fileHashes[`posts/${post.id}.json`] = hash;

    postIndex.posts.push({
      id: post.id,
      stub: post.stub,
      hash,
      modified: post.updatedAt || post.createdAt
    });
  }
  const postIndexJson = JSON.stringify(postIndex, null, 2);
  fs.writeFileSync(path.join(syncDir, 'posts', 'index.json'), postIndexJson);
  fileHashes['posts/index.json'] = calculateHash(postIndexJson);

  // === Generate drafts (encrypted) ===
  const draftIndex = { drafts: [] };
  for (const draft of drafts) {
    const draftData = createSyncPost(draft, storage, blogId);
    const { ciphertext, iv } = syncEncryption.encryptJSON(draftData, password, salt);
    fs.writeFileSync(path.join(syncDir, 'drafts', `${draft.id}.json.enc`), ciphertext);
    const hash = calculateBufferHash(ciphertext);
    fileHashes[`drafts/${draft.id}.json.enc`] = hash;
    draftIVs[`drafts/${draft.id}.json.enc`] = syncEncryption.base64Encode(iv);

    draftIndex.drafts.push({
      id: draft.id,
      hash,
      modified: draft.updatedAt || draft.createdAt
    });
  }

  // Encrypt draft index if there are drafts
  if (drafts.length > 0) {
    const { ciphertext, iv } = syncEncryption.encryptJSON(draftIndex, password, salt);
    fs.writeFileSync(path.join(syncDir, 'drafts', 'index.json.enc'), ciphertext);
    fileHashes['drafts/index.json.enc'] = calculateBufferHash(ciphertext);
    draftIVs['drafts/index.json.enc'] = syncEncryption.base64Encode(iv);
  }

  // === Generate sidebar objects ===
  const sidebarIndex = { sidebar: [] };
  for (const sidebar of sidebarObjects) {
    const sidebarData = {
      id: sidebar.id,
      type: sidebar.type,
      title: sidebar.title,
      content: sidebar.content || null,
      order: sidebar.order,
      links: sidebar.links ? sidebar.links.map(l => ({
        title: l.title,
        url: l.url,
        order: l.order
      })) : null
    };
    const sidebarJson = JSON.stringify(sidebarData, null, 2);
    fs.writeFileSync(path.join(syncDir, 'sidebar', `${sidebar.id}.json`), sidebarJson);
    const hash = calculateHash(sidebarJson);
    fileHashes[`sidebar/${sidebar.id}.json`] = hash;

    sidebarIndex.sidebar.push({
      id: sidebar.id,
      hash
    });
  }
  const sidebarIndexJson = JSON.stringify(sidebarIndex, null, 2);
  fs.writeFileSync(path.join(syncDir, 'sidebar', 'index.json'), sidebarIndexJson);
  fileHashes['sidebar/index.json'] = calculateHash(sidebarIndexJson);

  // === Generate static files ===
  const staticFilesIndex = { files: [] };
  for (const staticFile of staticFiles) {
    // Copy the actual file
    const sourceFile = path.join(storage.getBlogUploadsDir(blogId), staticFile.storedFilename);
    if (fs.existsSync(sourceFile)) {
      const fileBuffer = fs.readFileSync(sourceFile);
      fs.writeFileSync(path.join(syncDir, 'static-files', staticFile.filename), fileBuffer);
      const hash = calculateBufferHash(fileBuffer);
      fileHashes[`static-files/${staticFile.filename}`] = hash;

      staticFilesIndex.files.push({
        filename: staticFile.filename,
        mimeType: staticFile.mimeType,
        isSpecialFile: staticFile.isSpecialFile,
        specialFileType: staticFile.specialFileType,
        hash,
        size: fileBuffer.length
      });
    }
  }
  const staticFilesIndexJson = JSON.stringify(staticFilesIndex, null, 2);
  fs.writeFileSync(path.join(syncDir, 'static-files', 'index.json'), staticFilesIndexJson);
  fileHashes['static-files/index.json'] = calculateHash(staticFilesIndexJson);

  // === Generate embed images ===
  const embedImagesIndex = { images: [] };
  const uploadsDir = storage.getBlogUploadsDir(blogId);

  for (const post of allPosts) {
    if (post.embed) {
      const embed = post.embed;

      // Handle link embed images
      if (embed.type === 'link' && embed.imageFilename) {
        const imageFilename = embed.imageFilename;
        const sourcePath = path.join(uploadsDir, imageFilename);
        if (fs.existsSync(sourcePath)) {
          const imageBuffer = fs.readFileSync(sourcePath);
          fs.writeFileSync(path.join(syncDir, 'embed-images', imageFilename), imageBuffer);
          const hash = calculateBufferHash(imageBuffer);
          fileHashes[`embed-images/${imageFilename}`] = hash;
          embedImagesIndex.images.push({ filename: imageFilename, hash });
        }
      }

      // Handle image embed images
      if (embed.type === 'image' && embed.images) {
        for (const image of embed.images) {
          const sourcePath = path.join(uploadsDir, image.filename);
          if (fs.existsSync(sourcePath)) {
            const imageBuffer = fs.readFileSync(sourcePath);
            fs.writeFileSync(path.join(syncDir, 'embed-images', image.filename), imageBuffer);
            const hash = calculateBufferHash(imageBuffer);
            fileHashes[`embed-images/${image.filename}`] = hash;
            embedImagesIndex.images.push({ filename: image.filename, hash });
          }
        }
      }
    }
  }
  const embedImagesIndexJson = JSON.stringify(embedImagesIndex, null, 2);
  fs.writeFileSync(path.join(syncDir, 'embed-images', 'index.json'), embedImagesIndexJson);
  fileHashes['embed-images/index.json'] = calculateHash(embedImagesIndexJson);

  // === Generate custom theme ===
  if (theme) {
    const themeData = {
      identifier: theme.identifier,
      name: theme.name,
      templates: theme.templates
    };
    const themeJson = JSON.stringify(themeData, null, 2);
    fs.writeFileSync(path.join(syncDir, 'themes', `${theme.identifier}.json`), themeJson);
    fileHashes[`themes/${theme.identifier}.json`] = calculateHash(themeJson);
  }

  // === Generate manifest ===
  const manifestFiles = {};
  for (const [filePath, hash] of Object.entries(fileHashes)) {
    const fullPath = path.join(syncDir, filePath);
    const stats = fs.statSync(fullPath);

    const fileInfo = {
      hash,
      size: stats.size
    };

    // Add modified date for posts and drafts
    if (filePath.startsWith('posts/') && filePath !== 'posts/index.json') {
      const postId = filePath.replace('posts/', '').replace('.json', '');
      const post = publishedPosts.find(p => p.id === postId);
      if (post) {
        fileInfo.modified = post.updatedAt || post.createdAt;
      }
    }

    // Add IV for encrypted files
    if (draftIVs[filePath]) {
      fileInfo.encrypted = true;
      fileInfo.iv = draftIVs[filePath];
    }

    manifestFiles[filePath] = fileInfo;
  }

  const manifest = {
    version: '1.0',
    syncVersion: newSyncVersion,
    lastModified: new Date().toISOString(),
    appSource: 'self-hosted',
    appVersion: '1.0.0',
    blogName: blog.name,
    hasDrafts: drafts.length > 0,
    encryption: drafts.length > 0 ? {
      method: 'aes-256-gcm',
      salt: syncEncryption.base64Encode(salt),
      iterations: syncEncryption.PBKDF2_ITERATIONS
    } : null,
    files: manifestFiles
  };

  const manifestJson = JSON.stringify(manifest, null, 2);
  fs.writeFileSync(path.join(syncDir, 'manifest.json'), manifestJson);
  fileHashes['manifest.json'] = calculateHash(manifestJson);

  return {
    fileHashes,
    syncVersion: newSyncVersion,
    fileCount: Object.keys(fileHashes).length
  };
}

/**
 * Create a sync post object from a post
 */
function createSyncPost(post, storage, blogId) {
  let embed = null;

  if (post.embed) {
    const srcEmbed = post.embed;
    const embedType = (srcEmbed.type || '').toLowerCase();

    if (embedType === 'youtube') {
      embed = {
        type: 'YouTube',
        position: srcEmbed.position || 'above',
        url: srcEmbed.url || '',
        title: null,
        description: null,
        imageUrl: null,
        imageFilename: null,
        images: []
      };
    } else if (embedType === 'link') {
      embed = {
        type: 'Link',
        position: srcEmbed.position || 'above',
        url: srcEmbed.url || '',
        title: srcEmbed.title || null,
        description: srcEmbed.description || null,
        imageUrl: srcEmbed.imageUrl || null,
        imageFilename: srcEmbed.imageFilename || null,
        images: []
      };
    } else if (embedType === 'image') {
      embed = {
        type: 'Image',
        position: srcEmbed.position || 'above',
        url: '',
        title: null,
        description: null,
        imageUrl: null,
        imageFilename: null,
        images: (srcEmbed.images || []).map(img => ({
          filename: img.filename,
          order: img.order || 0
        }))
      };
    }
  }

  return {
    id: post.id,
    title: post.title || null,
    content: post.content,
    stub: post.stub,
    createdAt: post.createdAt,
    updatedAt: post.updatedAt || post.createdAt,
    categoryId: post.categoryId || null,
    tagIds: post.tagIds || [],
    embed
  };
}

export default { generateSyncDirectory };
