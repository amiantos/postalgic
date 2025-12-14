/**
 * Sync importer service
 * Imports a blog from a published sync URL
 */

import fs from 'fs';
import path from 'path';
import syncEncryption from './syncEncryption.js';

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
 * @param {string} password - The sync password (required if blog has drafts)
 * @param {Function} onProgress - Progress callback (optional)
 * @returns {Promise<Object>} - The imported blog
 */
export async function importBlog(storage, baseUrl, password, onProgress = () => {}) {
  const normalizedUrl = normalizeUrl(baseUrl);

  // Step 1: Fetch manifest
  onProgress({ step: 'Fetching manifest...', downloaded: 0, total: 0 });
  const manifest = await fetchManifest(normalizedUrl);

  // Check if password is required
  if (manifest.hasDrafts && !password) {
    throw new Error('This blog has drafts that require a password to import');
  }

  const totalFiles = Object.keys(manifest.files).length;
  let filesDownloaded = 0;

  // Prepare encryption key if needed
  let encryptionKey = null;
  if (manifest.hasDrafts && password && manifest.encryption) {
    const salt = syncEncryption.base64Decode(manifest.encryption.salt);
    encryptionKey = syncEncryption.deriveKey(password, salt);
  }

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

  // Enable sync and store config
  storage.saveSyncConfig(blogId, {
    syncEnabled: true,
    syncPassword: password || null,
    lastSyncedVersion: manifest.syncVersion,
    lastSyncedAt: new Date().toISOString(),
    localFileHashes: {}
  });

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
      stub: syncCategory.stub
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
      stub: syncTag.stub
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

  // Step 8: Download and create drafts (encrypted)
  if (manifest.hasDrafts && encryptionKey) {
    onProgress({ step: 'Downloading drafts...', downloaded: filesDownloaded, total: totalFiles });

    // Download encrypted draft index
    const draftIndexEncData = await downloadFile(`${normalizedUrl}/sync/drafts/index.json.enc`);
    filesDownloaded++;

    const draftIndexFileInfo = manifest.files['drafts/index.json.enc'];
    if (!draftIndexFileInfo?.iv) {
      throw new Error('Missing IV for draft index');
    }

    const draftIndexIV = syncEncryption.base64Decode(draftIndexFileInfo.iv);
    const draftIndexData = syncEncryption.decrypt(draftIndexEncData, draftIndexIV, encryptionKey);
    const draftIndex = JSON.parse(draftIndexData.toString());

    for (const entry of draftIndex.drafts) {
      const draftEncData = await downloadFile(`${normalizedUrl}/sync/drafts/${entry.id}.json.enc`);
      filesDownloaded++;

      const draftFileInfo = manifest.files[`drafts/${entry.id}.json.enc`];
      if (!draftFileInfo?.iv) {
        throw new Error(`Missing IV for draft ${entry.id}`);
      }

      const draftIV = syncEncryption.base64Decode(draftFileInfo.iv);
      const draftData = syncEncryption.decrypt(draftEncData, draftIV, encryptionKey);
      const syncDraft = JSON.parse(draftData.toString());

      createPost(storage, blogId, syncDraft, categoryMap, tagMap, true);
      onProgress({ step: 'Downloading drafts...', downloaded: filesDownloaded, total: totalFiles });
    }
  }

  // Step 9: Download and create sidebar objects
  onProgress({ step: 'Downloading sidebar content...', downloaded: filesDownloaded, total: totalFiles });
  const sidebarIndexData = await downloadFile(`${normalizedUrl}/sync/sidebar/index.json`);
  filesDownloaded++;
  const sidebarIndex = JSON.parse(sidebarIndexData.toString());

  for (const entry of sidebarIndex.sidebar) {
    const sidebarData = await downloadFile(`${normalizedUrl}/sync/sidebar/${entry.id}.json`);
    filesDownloaded++;
    const syncSidebar = JSON.parse(sidebarData.toString());

    const sidebar = storage.createSidebarObject(blogId, {
      title: syncSidebar.title,
      type: syncSidebar.type,
      content: syncSidebar.content || null,
      order: syncSidebar.order
    });

    // Create links if it's a link list
    if (syncSidebar.links) {
      for (const syncLink of syncSidebar.links) {
        storage.createSidebarLink(sidebar.id, {
          title: syncLink.title,
          url: syncLink.url,
          order: syncLink.order
        });
      }
    }
  }

  // Step 10: Download and create static files
  onProgress({ step: 'Downloading static files...', downloaded: filesDownloaded, total: totalFiles });
  const staticFilesIndexData = await downloadFile(`${normalizedUrl}/sync/static-files/index.json`);
  filesDownloaded++;
  const staticFilesIndex = JSON.parse(staticFilesIndexData.toString());

  for (const fileEntry of staticFilesIndex.files) {
    const fileData = await downloadFile(`${normalizedUrl}/sync/static-files/${fileEntry.filename}`);
    filesDownloaded++;

    storage.createStaticFile(blogId, {
      filename: fileEntry.filename,
      mimeType: fileEntry.mimeType,
      specialFileType: fileEntry.specialFileType || null,
      buffer: fileData
    });
    onProgress({ step: 'Downloading static files...', downloaded: filesDownloaded, total: totalFiles });
  }

  // Step 11: Download custom theme if present
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

  // Update local file hashes for future sync
  const localHashes = {};
  for (const [filePath, fileInfo] of Object.entries(manifest.files)) {
    localHashes[filePath] = fileInfo.hash;
  }
  storage.updateSyncVersion(blogId, manifest.syncVersion, localHashes);

  onProgress({ step: 'Import complete!', downloaded: totalFiles, total: totalFiles, complete: true });

  return storage.getBlog(blogId);
}

/**
 * Creates a post from sync data
 */
function createPost(storage, blogId, syncPost, categoryMap, tagMap, isDraft) {
  // Build embed data if present
  let embedType = null;
  let embedPosition = null;
  let embedData = null;

  if (syncPost.embed) {
    const embed = syncPost.embed;
    embedType = embed.type.toLowerCase();
    if (embedType === 'youtube') embedType = 'youtube';
    else if (embedType === 'link') embedType = 'link';
    else if (embedType === 'image') embedType = 'image';

    embedPosition = (embed.position || 'above').toLowerCase();

    if (embedType === 'youtube') {
      embedData = { url: embed.url };
    } else if (embedType === 'link') {
      embedData = {
        url: embed.url,
        title: embed.title,
        description: embed.description,
        imageUrl: embed.imageUrl,
        imageFilename: embed.imageFilename
      };
    } else if (embedType === 'image') {
      embedData = {
        images: embed.images.map(img => ({
          filename: img.filename,
          order: img.order
        }))
      };
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
    embedType: embedType,
    embedPosition: embedPosition,
    embedData: embedData,
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
