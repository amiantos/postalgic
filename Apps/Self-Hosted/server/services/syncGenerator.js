/**
 * Sync data generator service
 * Generates the /sync/ directory for bidirectional sync between iOS and Self-Hosted apps
 *
 * Note: Drafts are NOT synced - they remain local to each device.
 * Only published posts and other content are included in the sync directory.
 */

import fs from 'fs';
import path from 'path';
import { calculateHash, calculateBufferHash } from '../utils/helpers.js';

/**
 * Recursively sort object keys alphabetically.
 * This ensures consistent JSON output across platforms.
 * @param {any} obj - The object to sort
 * @returns {any} - Object with sorted keys
 */
function sortObjectKeys(obj) {
  if (obj === null || typeof obj !== 'object') {
    return obj;
  }
  if (Array.isArray(obj)) {
    return obj.map(sortObjectKeys);
  }
  const sorted = {};
  const keys = Object.keys(obj).sort();
  for (const key of keys) {
    sorted[key] = sortObjectKeys(obj[key]);
  }
  return sorted;
}

/**
 * Stringify object with sorted keys for cross-platform consistency.
 * iOS uses JSONEncoder with .sortedKeys which sorts alphabetically.
 * @param {any} obj - The object to stringify
 * @returns {string} - JSON string with sorted keys
 */
function stringifyWithSortedKeys(obj) {
  return JSON.stringify(sortObjectKeys(obj), null, 2);
}

/**
 * Get the stable sync ID for an entity.
 * Uses syncId if available (preserves ID from import), otherwise falls back to local id.
 * This ensures entity IDs remain stable across all copies of a synced blog.
 */
function getStableSyncId(entity) {
  return entity.syncId || entity.id;
}

/**
 * Calculate the latest modification date from all content entities.
 * Returns the most recent updatedAt/createdAt from posts, categories, tags, and sidebar objects.
 */
function getLatestModificationDate(posts, categories, tags, sidebarObjects) {
  let latest = new Date(0);

  // Check posts
  for (const post of posts) {
    const date = new Date(post.updatedAt || post.createdAt);
    if (date > latest) latest = date;
  }

  // Check categories
  for (const category of categories) {
    const date = new Date(category.createdAt);
    if (date > latest) latest = date;
  }

  // Check tags
  for (const tag of tags) {
    const date = new Date(tag.createdAt);
    if (date > latest) latest = date;
  }

  // Check sidebar objects (they don't have dates, so skip)

  // If no content exists, return current date as fallback
  if (latest.getTime() === 0) {
    return new Date().toISOString();
  }

  return latest.toISOString();
}

/**
 * Generate the sync directory for a blog
 * @param {Storage} storage - Storage instance
 * @param {string} blogId - Blog ID
 * @param {string} outputDir - Output directory (site root)
 * @returns {Promise<Object>} - Object containing fileHashes and syncVersion
 */
export async function generateSyncDirectory(storage, blogId, outputDir) {
  const blog = storage.getBlog(blogId);
  if (!blog) {
    throw new Error('Blog not found');
  }

  // Get all data (published posts only - drafts stay local to each device)
  const publishedPosts = storage.getAllPosts(blogId, false);
  const categories = storage.getAllCategories(blogId);
  const tags = storage.getAllTags(blogId);
  const sidebarObjects = storage.getAllSidebarObjects(blogId);
  const staticFiles = storage.getAllStaticFiles(blogId);

  // Get theme if custom
  let theme = null;
  if (blog.themeIdentifier && blog.themeIdentifier !== 'default') {
    theme = storage.getTheme(blog.themeIdentifier);
  }

  // Create sync directory structure (no drafts directory)
  const syncDir = path.join(outputDir, 'sync');
  const dirs = [
    syncDir,
    path.join(syncDir, 'posts'),
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

  // === Generate blog.json ===
  const blogData = {
    name: blog.name,
    url: blog.url || null,
    tagline: blog.tagline || null,
    authorName: blog.authorName || null,
    authorUrl: blog.authorUrl || null,
    authorEmail: blog.authorEmail || null,
    timezone: blog.timezone || 'UTC',
    colors: {
      accent: blog.accentColor || null,
      background: blog.backgroundColor || null,
      text: blog.textColor || null,
      lightShade: blog.lightShade || null,
      mediumShade: blog.mediumShade || null,
      darkShade: blog.darkShade || null
    },
    themeIdentifier: blog.themeIdentifier || null
  };
  const blogJson = stringifyWithSortedKeys(blogData);
  fs.writeFileSync(path.join(syncDir, 'blog.json'), blogJson);
  fileHashes['blog.json'] = calculateHash(blogJson);

  // === Generate categories ===
  const categoryIndex = { categories: [] };
  for (const category of categories) {
    const stableId = getStableSyncId(category);
    const categoryData = {
      id: stableId,
      name: category.name,
      description: category.description || null,
      stub: category.stub,
      createdAt: category.createdAt
    };
    const categoryJson = stringifyWithSortedKeys(categoryData);
    fs.writeFileSync(path.join(syncDir, 'categories', `${stableId}.json`), categoryJson);
    const hash = calculateHash(categoryJson);
    fileHashes[`categories/${stableId}.json`] = hash;

    categoryIndex.categories.push({
      id: stableId,
      stub: category.stub,
      hash
    });
  }
  // Sort by id for deterministic output
  categoryIndex.categories.sort((a, b) => a.id.localeCompare(b.id));
  const categoryIndexJson = stringifyWithSortedKeys(categoryIndex);
  fs.writeFileSync(path.join(syncDir, 'categories', 'index.json'), categoryIndexJson);
  fileHashes['categories/index.json'] = calculateHash(categoryIndexJson);

  // === Generate tags ===
  const tagIndex = { tags: [] };
  for (const tag of tags) {
    const stableId = getStableSyncId(tag);
    const tagData = {
      id: stableId,
      name: tag.name,
      stub: tag.stub,
      createdAt: tag.createdAt
    };
    const tagJson = stringifyWithSortedKeys(tagData);
    fs.writeFileSync(path.join(syncDir, 'tags', `${stableId}.json`), tagJson);
    const hash = calculateHash(tagJson);
    fileHashes[`tags/${stableId}.json`] = hash;

    tagIndex.tags.push({
      id: stableId,
      stub: tag.stub,
      hash
    });
  }
  // Sort by id for deterministic output
  tagIndex.tags.sort((a, b) => a.id.localeCompare(b.id));
  const tagIndexJson = stringifyWithSortedKeys(tagIndex);
  fs.writeFileSync(path.join(syncDir, 'tags', 'index.json'), tagIndexJson);
  fileHashes['tags/index.json'] = calculateHash(tagIndexJson);

  // Build maps of local ID -> stable sync ID for categories and tags
  const categoryIdMap = new Map();
  for (const category of categories) {
    categoryIdMap.set(category.id, getStableSyncId(category));
  }
  const tagIdMap = new Map();
  for (const tag of tags) {
    tagIdMap.set(tag.id, getStableSyncId(tag));
  }

  // === Generate published posts (unencrypted) ===
  const postIndex = { posts: [] };
  for (const post of publishedPosts) {
    const stableId = getStableSyncId(post);
    const postData = createSyncPost(post, stableId, categoryIdMap, tagIdMap);
    const postJson = stringifyWithSortedKeys(postData);
    fs.writeFileSync(path.join(syncDir, 'posts', `${stableId}.json`), postJson);
    const hash = calculateHash(postJson);
    fileHashes[`posts/${stableId}.json`] = hash;

    postIndex.posts.push({
      id: stableId,
      stub: post.stub,
      hash,
      modified: post.updatedAt || post.createdAt
    });
  }
  // Sort by id for deterministic output
  postIndex.posts.sort((a, b) => a.id.localeCompare(b.id));
  const postIndexJson = stringifyWithSortedKeys(postIndex);
  fs.writeFileSync(path.join(syncDir, 'posts', 'index.json'), postIndexJson);
  fileHashes['posts/index.json'] = calculateHash(postIndexJson);

  // === Generate sidebar objects ===
  const sidebarIndex = { sidebar: [] };
  for (const sidebar of sidebarObjects) {
    const stableId = getStableSyncId(sidebar);
    const sidebarData = {
      id: stableId,
      type: sidebar.type,
      title: sidebar.title,
      content: sidebar.content || null,
      order: sidebar.order,
      // Sort links by order for deterministic output
      links: sidebar.links ? [...sidebar.links].sort((a, b) => a.order - b.order).map(l => ({
        title: l.title,
        url: l.url,
        order: l.order
      })) : null
    };
    const sidebarJson = stringifyWithSortedKeys(sidebarData);
    fs.writeFileSync(path.join(syncDir, 'sidebar', `${stableId}.json`), sidebarJson);
    const hash = calculateHash(sidebarJson);
    fileHashes[`sidebar/${stableId}.json`] = hash;

    sidebarIndex.sidebar.push({
      id: stableId,
      hash
    });
  }
  // Sort by id for deterministic output
  sidebarIndex.sidebar.sort((a, b) => a.id.localeCompare(b.id));
  const sidebarIndexJson = stringifyWithSortedKeys(sidebarIndex);
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
  // Sort by filename for deterministic output
  staticFilesIndex.files.sort((a, b) => a.filename.localeCompare(b.filename));
  const staticFilesIndexJson = stringifyWithSortedKeys(staticFilesIndex);
  fs.writeFileSync(path.join(syncDir, 'static-files', 'index.json'), staticFilesIndexJson);
  fileHashes['static-files/index.json'] = calculateHash(staticFilesIndexJson);

  // === Generate embed images (only from published posts) ===
  const embedImagesIndex = { images: [] };
  const uploadsDir = storage.getBlogUploadsDir(blogId);

  for (const post of publishedPosts) {
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
  // Sort by filename for deterministic output
  embedImagesIndex.images.sort((a, b) => a.filename.localeCompare(b.filename));
  const embedImagesIndexJson = stringifyWithSortedKeys(embedImagesIndex);
  fs.writeFileSync(path.join(syncDir, 'embed-images', 'index.json'), embedImagesIndexJson);
  fileHashes['embed-images/index.json'] = calculateHash(embedImagesIndexJson);

  // === Generate custom theme ===
  if (theme) {
    const themeData = {
      identifier: theme.identifier,
      name: theme.name,
      templates: theme.templates
    };
    const themeJson = stringifyWithSortedKeys(themeData);
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

    // Add modified date for posts
    if (filePath.startsWith('posts/') && filePath !== 'posts/index.json') {
      const postId = filePath.replace('posts/', '').replace('.json', '');
      // Find post by stable sync ID (matches either syncId or id)
      const post = publishedPosts.find(p => getStableSyncId(p) === postId);
      if (post) {
        fileInfo.modified = post.updatedAt || post.createdAt;
      }
    }

    manifestFiles[filePath] = fileInfo;
  }

  // Calculate a stable content version from all file hashes
  // This only changes when actual content changes (not on every generation)
  const sortedHashes = Object.entries(fileHashes)
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([filePath, hash]) => `${filePath}:${hash}`)
    .join('\n');
  const contentVersion = calculateHash(sortedHashes);

  const manifest = {
    version: '1.0',
    contentVersion,
    lastModified: getLatestModificationDate(publishedPosts, categories, tags, sidebarObjects),
    appSource: 'self-hosted',
    appVersion: '1.0.0',
    blogName: blog.name,
    fileCount: Object.keys(manifestFiles).length,
    files: manifestFiles
  };

  const manifestJson = stringifyWithSortedKeys(manifest);
  fs.writeFileSync(path.join(syncDir, 'manifest.json'), manifestJson);
  fileHashes['manifest.json'] = calculateHash(manifestJson);

  return {
    fileHashes,
    syncVersion: contentVersion,  // Use content-based version for stability
    fileCount: Object.keys(fileHashes).length
  };
}

/**
 * Create a sync post object from a post
 * @param {Object} post - The post object
 * @param {string} stableId - The stable sync ID to use for this post
 * @param {Map} categoryIdMap - Map of local category ID to stable sync ID
 * @param {Map} tagIdMap - Map of local tag ID to stable sync ID
 */
function createSyncPost(post, stableId, categoryIdMap, tagIdMap) {
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
        // Sort by order for deterministic output
        images: [...(srcEmbed.images || [])].sort((a, b) => (a.order || 0) - (b.order || 0)).map(img => ({
          filename: img.filename,
          order: img.order || 0
        }))
      };
    }
  }

  // Map category ID to stable sync ID
  let syncCategoryId = null;
  if (post.categoryId) {
    syncCategoryId = categoryIdMap.get(post.categoryId) || post.categoryId;
  }

  // Map tag IDs to stable sync IDs and sort for deterministic output
  const syncTagIds = (post.tagIds || []).map(tagId => tagIdMap.get(tagId) || tagId).sort();

  return {
    id: stableId,
    title: post.title || null,
    content: post.content,
    stub: post.stub,
    createdAt: post.createdAt,
    updatedAt: post.updatedAt || post.createdAt,
    categoryId: syncCategoryId,
    tagIds: syncTagIds,
    embed
  };
}

export default { generateSyncDirectory };
