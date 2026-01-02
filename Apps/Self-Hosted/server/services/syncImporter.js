/**
 * Sync importer service
 * Imports a blog from a published sync URL
 */

import fs from 'fs';
import path from 'path';

/**
 * Fetches the manifest from a sync URL
 * @param {string} baseUrl - The base URL of the published site
 * @returns {Promise<Object>} - The manifest object
 */
export async function fetchManifest(baseUrl) {
  const manifestUrl = `${normalizeUrl(baseUrl)}/sync/manifest.json`;

  const response = await fetch(manifestUrl, {
    headers: {
      'Cache-Control': 'no-cache'
    }
  });

  if (!response.ok) {
    if (response.status === 404) {
      throw new Error('Sync manifest not found. Make sure the site has sync enabled.');
    }
    throw new Error(`Failed to fetch manifest: HTTP ${response.status}`);
  }

  return await response.json();
}

/**
 * Downloads a file from the sync URL
 * @param {string} url - The full URL to download
 * @returns {Promise<Buffer>} - The file data
 */
async function downloadFile(url) {
  const response = await fetch(url, {
    headers: {
      'Cache-Control': 'no-cache'
    }
  });

  if (!response.ok) {
    throw new Error(`Failed to download ${url}: HTTP ${response.status}`);
  }

  const arrayBuffer = await response.arrayBuffer();
  return Buffer.from(arrayBuffer);
}

/**
 * Imports a blog from a sync URL
 * @param {Storage} storage - Storage instance
 * @param {string} baseUrl - The base URL of the published site
 * @param {string} password - Unused (kept for API compatibility)
 * @param {Function} onProgress - Progress callback (optional)
 * @returns {Promise<Object>} - The imported blog
 */
export async function importBlog(storage, baseUrl, password, onProgress = () => {}) {
  const normalizedUrl = normalizeUrl(baseUrl);

  // Step 1: Fetch manifest
  onProgress({ step: 'Fetching manifest...', downloaded: 0, total: 0 });
  const manifest = await fetchManifest(normalizedUrl);

  const totalFiles = Object.keys(manifest.files).length;
  let filesDownloaded = 0;

  // Step 2: Download blog.json
  onProgress({ step: 'Downloading blog settings...', downloaded: filesDownloaded, total: totalFiles });
  const blogData = await downloadFile(`${normalizedUrl}/sync/blog.json`);
  filesDownloaded++;
  const syncBlog = JSON.parse(blogData.toString());

  // Step 3: Create the blog
  const blog = storage.createBlog({
    name: syncBlog.name,
    url: syncBlog.url || '',
    tagline: syncBlog.tagline || '',
    authorName: syncBlog.authorName || '',
    authorUrl: syncBlog.authorUrl || '',
    authorEmail: syncBlog.authorEmail || '',
    timezone: syncBlog.timezone || 'UTC',
    themeIdentifier: syncBlog.themeIdentifier || 'default',
    accentColor: syncBlog.colors?.accent,
    backgroundColor: syncBlog.colors?.background,
    textColor: syncBlog.colors?.text,
    lightShade: syncBlog.colors?.lightShade,
    mediumShade: syncBlog.colors?.mediumShade,
    darkShade: syncBlog.colors?.darkShade
  });

  // Use the ID from the created blog
  const blogId = blog.id;

  // Update sync version with file hashes from manifest
  const fileHashes = {};
  if (manifest.files) {
    for (const [path, fileInfo] of Object.entries(manifest.files)) {
      fileHashes[path] = fileInfo.hash;
    }
  }
  storage.updateSyncVersion(blogId, manifest.contentVersion || manifest.syncVersion, fileHashes);

  // Maps for ID references
  const categoryMap = new Map();
  const tagMap = new Map();

  // Step 4: Download and create categories
  onProgress({ step: 'Downloading categories...', downloaded: filesDownloaded, total: totalFiles });
  const categoryIndexData = await downloadFile(`${normalizedUrl}/sync/categories/index.json`);
  filesDownloaded++;
  const categoryIndex = JSON.parse(categoryIndexData.toString());

  for (const entry of categoryIndex.categories) {
    const categoryData = await downloadFile(`${normalizedUrl}/sync/categories/${entry.id}.json`);
    filesDownloaded++;
    const syncCategory = JSON.parse(categoryData.toString());

    const category = storage.createCategory(blogId, {
      name: syncCategory.name,
      description: syncCategory.description || '',
      stub: syncCategory.stub,
      syncId: syncCategory.id  // Store remote ID for incremental sync matching
    });
    categoryMap.set(syncCategory.id, category.id);
  }

  // Step 5: Download and create tags
  onProgress({ step: 'Downloading tags...', downloaded: filesDownloaded, total: totalFiles });
  const tagIndexData = await downloadFile(`${normalizedUrl}/sync/tags/index.json`);
  filesDownloaded++;
  const tagIndex = JSON.parse(tagIndexData.toString());

  for (const entry of tagIndex.tags) {
    const tagData = await downloadFile(`${normalizedUrl}/sync/tags/${entry.id}.json`);
    filesDownloaded++;
    const syncTag = JSON.parse(tagData.toString());

    const tag = storage.createTag(blogId, {
      name: syncTag.name,
      stub: syncTag.stub,
      syncId: syncTag.id  // Store remote ID for incremental sync matching
    });
    tagMap.set(syncTag.id, tag.id);
  }

  // Step 6: Download embed images (needed before posts)
  onProgress({ step: 'Downloading images...', downloaded: filesDownloaded, total: totalFiles });
  const embedImagesIndexData = await downloadFile(`${normalizedUrl}/sync/embed-images/index.json`);
  filesDownloaded++;
  const embedImagesIndex = JSON.parse(embedImagesIndexData.toString());

  const uploadsDir = storage.getBlogUploadsDir(blogId);

  for (const imageEntry of embedImagesIndex.images) {
    const imageData = await downloadFile(`${normalizedUrl}/sync/embed-images/${imageEntry.filename}`);
    filesDownloaded++;
    fs.writeFileSync(path.join(uploadsDir, imageEntry.filename), imageData);
    onProgress({ step: 'Downloading images...', downloaded: filesDownloaded, total: totalFiles });
  }

  // Step 7: Download and create posts
  onProgress({ step: 'Downloading posts...', downloaded: filesDownloaded, total: totalFiles });
  const postIndexData = await downloadFile(`${normalizedUrl}/sync/posts/index.json`);
  filesDownloaded++;
  const postIndex = JSON.parse(postIndexData.toString());

  for (const entry of postIndex.posts) {
    const postData = await downloadFile(`${normalizedUrl}/sync/posts/${entry.id}.json`);
    filesDownloaded++;
    const syncPost = JSON.parse(postData.toString());

    createPost(storage, blogId, syncPost, categoryMap, tagMap, false);
    onProgress({ step: 'Downloading posts...', downloaded: filesDownloaded, total: totalFiles });
  }

  // Step 8: Download and create sidebar objects
  onProgress({ step: 'Downloading sidebar content...', downloaded: filesDownloaded, total: totalFiles });
  const sidebarIndexData = await downloadFile(`${normalizedUrl}/sync/sidebar/index.json`);
  filesDownloaded++;
  const sidebarIndex = JSON.parse(sidebarIndexData.toString());

  for (const entry of sidebarIndex.sidebar) {
    const sidebarData = await downloadFile(`${normalizedUrl}/sync/sidebar/${entry.id}.json`);
    filesDownloaded++;
    const syncSidebar = JSON.parse(sidebarData.toString());

    // Links are passed inline to createSidebarObject
    storage.createSidebarObject(blogId, {
      title: syncSidebar.title,
      type: syncSidebar.type,
      content: syncSidebar.content || null,
      order: syncSidebar.order,
      links: syncSidebar.links || [],
      syncId: syncSidebar.id  // Store remote ID for incremental sync matching
    });
  }

  // Step 9: Download and create static files
  onProgress({ step: 'Downloading static files...', downloaded: filesDownloaded, total: totalFiles });
  const staticFilesIndexData = await downloadFile(`${normalizedUrl}/sync/static-files/index.json`);
  filesDownloaded++;
  const staticFilesIndex = JSON.parse(staticFilesIndexData.toString());

  for (const fileEntry of staticFilesIndex.files) {
    const fileBuffer = await downloadFile(`${normalizedUrl}/sync/static-files/${fileEntry.filename}`);
    filesDownloaded++;

    storage.createStaticFile(blogId, {
      filename: fileEntry.filename,
      mimeType: fileEntry.mimeType,
      specialFileType: fileEntry.specialFileType || null,
      syncId: fileEntry.filename  // Use filename as sync ID for static files
    }, fileBuffer);
    onProgress({ step: 'Downloading static files...', downloaded: filesDownloaded, total: totalFiles });
  }

  // Step 10: Download custom theme if present
  if (syncBlog.themeIdentifier && syncBlog.themeIdentifier !== 'default') {
    const themePath = `themes/${syncBlog.themeIdentifier}.json`;
    if (manifest.files[themePath]) {
      onProgress({ step: 'Downloading theme...', downloaded: filesDownloaded, total: totalFiles });
      const themeData = await downloadFile(`${normalizedUrl}/sync/${themePath}`);
      filesDownloaded++;
      const syncTheme = JSON.parse(themeData.toString());

      // Check if theme already exists
      const existingTheme = storage.getTheme(syncTheme.identifier);
      if (!existingTheme) {
        storage.createTheme({
          name: syncTheme.name,
          identifier: syncTheme.identifier,
          templates: syncTheme.templates
        });
      }
    }
  }

  onProgress({ step: 'Import complete!', downloaded: totalFiles, total: totalFiles, complete: true });

  return storage.getBlog(blogId);
}

/**
 * Creates a post from sync data
 */
function createPost(storage, blogId, syncPost, categoryMap, tagMap, isDraft) {
  // Build embed object if present (storage.createPost expects postData.embed)
  let embed = null;

  if (syncPost.embed) {
    const srcEmbed = syncPost.embed;
    const embedType = srcEmbed.type.toLowerCase();

    embed = {
      type: embedType,
      position: (srcEmbed.position || 'above').toLowerCase()
    };

    if (embedType === 'youtube') {
      embed.url = srcEmbed.url;
    } else if (embedType === 'link') {
      embed.url = srcEmbed.url;
      embed.title = srcEmbed.title;
      embed.description = srcEmbed.description;
      embed.imageUrl = srcEmbed.imageUrl;
      embed.imageFilename = srcEmbed.imageFilename;
    } else if (embedType === 'image') {
      embed.images = srcEmbed.images.map(img => ({
        filename: img.filename,
        order: img.order
      }));
    }
  }

  // Map category ID
  const categoryId = syncPost.categoryId ? categoryMap.get(syncPost.categoryId) : null;

  // Map tag IDs
  const tagIds = (syncPost.tagIds || [])
    .map(id => tagMap.get(id))
    .filter(Boolean);

  const post = storage.createPost(blogId, {
    title: syncPost.title || null,
    content: syncPost.content,
    stub: syncPost.stub,
    isDraft: isDraft,
    categoryId: categoryId,
    tagIds: tagIds,
    embed: embed,
    syncId: syncPost.id,  // Store remote ID for incremental sync matching
    createdAt: syncPost.createdAt
  });

  return post;
}

/**
 * Normalizes a URL for sync
 */
function normalizeUrl(urlString) {
  let url = urlString.trim();

  // Add https:// if no scheme
  if (!url.startsWith('http://') && !url.startsWith('https://')) {
    url = `https://${url}`;
  }

  // Remove trailing slash
  while (url.endsWith('/')) {
    url = url.slice(0, -1);
  }

  return url;
}

export default {
  fetchManifest,
  importBlog
};
