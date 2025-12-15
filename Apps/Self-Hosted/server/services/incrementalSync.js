/**
 * Incremental Sync Service
 *
 * Downloads and applies changes from remote sync data to local blog.
 * Uses syncId to match entities between local and remote.
 */

import fs from 'fs';
import path from 'path';
import syncEncryption from './syncEncryption.js';
import { checkForChanges, categorizeChanges, extractEntityId } from './syncChecker.js';

/**
 * Download a file from the sync URL
 * @param {string} url - The full URL to download
 * @returns {Promise<Buffer>} - The file data
 */
async function downloadFile(url) {
  const response = await fetch(url, {
    headers: { 'Cache-Control': 'no-cache' }
  });

  if (!response.ok) {
    throw new Error(`Failed to download ${url}: HTTP ${response.status}`);
  }

  const arrayBuffer = await response.arrayBuffer();
  return Buffer.from(arrayBuffer);
}

/**
 * Normalize a URL for sync
 */
function normalizeUrl(urlString) {
  let url = urlString.trim();
  if (!url.startsWith('http://') && !url.startsWith('https://')) {
    url = `https://${url}`;
  }
  while (url.endsWith('/')) {
    url = url.slice(0, -1);
  }
  return url;
}

/**
 * Perform incremental sync (pull changes from remote)
 * @param {Storage} storage - Storage instance
 * @param {string} blogId - The blog ID
 * @param {string} syncUrl - The remote sync URL
 * @param {string} password - The sync password (for encrypted drafts)
 * @param {Function} onProgress - Progress callback
 * @returns {Promise<Object>} Sync result
 */
export async function pullChanges(storage, blogId, syncUrl, password, onProgress = () => {}) {
  const normalizedUrl = normalizeUrl(syncUrl);
  const blog = storage.getBlog(blogId);

  if (!blog) {
    throw new Error('Blog not found');
  }

  // Step 1: Check for changes
  onProgress({ step: 'Checking for changes...', phase: 'checking' });
  const changeSet = await checkForChanges(storage, blogId, normalizedUrl);

  if (!changeSet.hasChanges) {
    onProgress({ step: 'Already up to date', phase: 'complete' });
    return {
      success: true,
      updated: false,
      message: 'Already up to date',
      changes: { new: 0, modified: 0, deleted: 0 }
    };
  }

  const categorized = categorizeChanges(changeSet);
  const { manifest } = changeSet;

  // Prepare encryption key if needed
  let encryptionKey = null;
  if (manifest.hasDrafts && password && manifest.encryption) {
    const salt = syncEncryption.base64Decode(manifest.encryption.salt);
    encryptionKey = syncEncryption.deriveKey(password, salt);
  }

  let totalChanges = 0;
  let appliedChanges = 0;

  // Count total changes
  for (const category of Object.values(categorized)) {
    totalChanges += category.new.length + category.modified.length + category.deleted.length;
  }

  // Step 2: Process blog changes
  if (categorized.blog.modified.length > 0) {
    onProgress({ step: 'Updating blog settings...', phase: 'applying', progress: appliedChanges / totalChanges });
    const blogData = await downloadFile(`${normalizedUrl}/sync/blog.json`);
    const syncBlog = JSON.parse(blogData.toString());

    storage.updateBlog(blogId, {
      name: syncBlog.name,
      url: syncBlog.url,
      tagline: syncBlog.tagline,
      authorName: syncBlog.authorName,
      authorUrl: syncBlog.authorUrl,
      authorEmail: syncBlog.authorEmail,
      timezone: syncBlog.timezone,
      themeIdentifier: syncBlog.themeIdentifier,
      accentColor: syncBlog.colors?.accent,
      backgroundColor: syncBlog.colors?.background,
      textColor: syncBlog.colors?.text,
      lightShade: syncBlog.colors?.lightShade,
      mediumShade: syncBlog.colors?.mediumShade,
      darkShade: syncBlog.colors?.darkShade
    });
    appliedChanges++;
  }

  // Step 3: Process category changes
  for (const file of categorized.categories.new) {
    onProgress({ step: 'Adding new categories...', phase: 'applying', progress: appliedChanges / totalChanges });
    const entityId = extractEntityId(file.path);
    if (entityId) {
      const categoryData = await downloadFile(`${normalizedUrl}/sync/${file.path}`);
      const syncCategory = JSON.parse(categoryData.toString());

      storage.createCategory(blogId, {
        name: syncCategory.name,
        description: syncCategory.description,
        stub: syncCategory.stub,
        syncId: syncCategory.id
      });
    }
    appliedChanges++;
  }

  for (const file of categorized.categories.modified) {
    onProgress({ step: 'Updating categories...', phase: 'applying', progress: appliedChanges / totalChanges });
    const entityId = extractEntityId(file.path);
    if (entityId) {
      const categoryData = await downloadFile(`${normalizedUrl}/sync/${file.path}`);
      const syncCategory = JSON.parse(categoryData.toString());

      // Find local category by syncId
      const localCategory = storage.getCategoryBySyncId(blogId, syncCategory.id);
      if (localCategory) {
        storage.updateCategory(blogId, localCategory.id, {
          name: syncCategory.name,
          description: syncCategory.description,
          stub: syncCategory.stub
        });
      } else {
        // If not found, create new
        storage.createCategory(blogId, {
          name: syncCategory.name,
          description: syncCategory.description,
          stub: syncCategory.stub,
          syncId: syncCategory.id
        });
      }
    }
    appliedChanges++;
  }

  for (const file of categorized.categories.deleted) {
    onProgress({ step: 'Removing deleted categories...', phase: 'applying', progress: appliedChanges / totalChanges });
    const entityId = extractEntityId(file.path);
    if (entityId) {
      const localCategory = storage.getCategoryBySyncId(blogId, entityId);
      if (localCategory) {
        storage.deleteCategory(blogId, localCategory.id);
      }
    }
    appliedChanges++;
  }

  // Step 4: Process tag changes
  for (const file of categorized.tags.new) {
    onProgress({ step: 'Adding new tags...', phase: 'applying', progress: appliedChanges / totalChanges });
    const entityId = extractEntityId(file.path);
    if (entityId) {
      const tagData = await downloadFile(`${normalizedUrl}/sync/${file.path}`);
      const syncTag = JSON.parse(tagData.toString());

      storage.createTag(blogId, {
        name: syncTag.name,
        stub: syncTag.stub,
        syncId: syncTag.id
      });
    }
    appliedChanges++;
  }

  for (const file of categorized.tags.modified) {
    onProgress({ step: 'Updating tags...', phase: 'applying', progress: appliedChanges / totalChanges });
    const entityId = extractEntityId(file.path);
    if (entityId) {
      const tagData = await downloadFile(`${normalizedUrl}/sync/${file.path}`);
      const syncTag = JSON.parse(tagData.toString());

      const localTag = storage.getTagBySyncId(blogId, syncTag.id);
      if (localTag) {
        storage.updateTag(blogId, localTag.id, {
          name: syncTag.name,
          stub: syncTag.stub
        });
      } else {
        storage.createTag(blogId, {
          name: syncTag.name,
          stub: syncTag.stub,
          syncId: syncTag.id
        });
      }
    }
    appliedChanges++;
  }

  for (const file of categorized.tags.deleted) {
    onProgress({ step: 'Removing deleted tags...', phase: 'applying', progress: appliedChanges / totalChanges });
    const entityId = extractEntityId(file.path);
    if (entityId) {
      const localTag = storage.getTagBySyncId(blogId, entityId);
      if (localTag) {
        storage.deleteTag(blogId, localTag.id);
      }
    }
    appliedChanges++;
  }

  // Step 5: Process embed images (before posts)
  const uploadsDir = storage.getBlogUploadsDir(blogId);
  for (const file of [...categorized.embedImages.new, ...categorized.embedImages.modified]) {
    onProgress({ step: 'Downloading images...', phase: 'applying', progress: appliedChanges / totalChanges });
    const filename = file.path.replace('embed-images/', '');
    const imageData = await downloadFile(`${normalizedUrl}/sync/${file.path}`);
    fs.writeFileSync(path.join(uploadsDir, filename), imageData);
    appliedChanges++;
  }

  // Build category and tag maps for post references
  const categoryMap = new Map();
  const tagMap = new Map();
  for (const category of storage.getAllCategories(blogId)) {
    if (category.syncId) {
      categoryMap.set(category.syncId, category.id);
    }
  }
  for (const tag of storage.getAllTags(blogId)) {
    if (tag.syncId) {
      tagMap.set(tag.syncId, tag.id);
    }
  }

  // Step 6: Process post changes
  for (const file of categorized.posts.new) {
    onProgress({ step: 'Adding new posts...', phase: 'applying', progress: appliedChanges / totalChanges });
    const entityId = extractEntityId(file.path);
    if (entityId) {
      const postData = await downloadFile(`${normalizedUrl}/sync/${file.path}`);
      const syncPost = JSON.parse(postData.toString());
      createOrUpdatePost(storage, blogId, syncPost, categoryMap, tagMap, false);
    }
    appliedChanges++;
  }

  for (const file of categorized.posts.modified) {
    onProgress({ step: 'Updating posts...', phase: 'applying', progress: appliedChanges / totalChanges });
    const entityId = extractEntityId(file.path);
    if (entityId) {
      const postData = await downloadFile(`${normalizedUrl}/sync/${file.path}`);
      const syncPost = JSON.parse(postData.toString());
      createOrUpdatePost(storage, blogId, syncPost, categoryMap, tagMap, false);
    }
    appliedChanges++;
  }

  for (const file of categorized.posts.deleted) {
    onProgress({ step: 'Removing deleted posts...', phase: 'applying', progress: appliedChanges / totalChanges });
    const entityId = extractEntityId(file.path);
    if (entityId) {
      const localPost = storage.getPostBySyncId(blogId, entityId);
      if (localPost) {
        storage.deletePost(blogId, localPost.id);
      }
    }
    appliedChanges++;
  }

  // Step 7: Process draft changes (encrypted)
  if (encryptionKey) {
    for (const file of categorized.drafts.new) {
      onProgress({ step: 'Adding new drafts...', phase: 'applying', progress: appliedChanges / totalChanges });
      const entityId = extractEntityId(file.path);
      if (entityId && file.iv) {
        const draftEncData = await downloadFile(`${normalizedUrl}/sync/${file.path}`);
        const iv = syncEncryption.base64Decode(file.iv);
        const draftData = syncEncryption.decrypt(draftEncData, iv, encryptionKey);
        const syncDraft = JSON.parse(draftData.toString());
        createOrUpdatePost(storage, blogId, syncDraft, categoryMap, tagMap, true);
      }
      appliedChanges++;
    }

    for (const file of categorized.drafts.modified) {
      onProgress({ step: 'Updating drafts...', phase: 'applying', progress: appliedChanges / totalChanges });
      const entityId = extractEntityId(file.path);
      if (entityId && file.iv) {
        const draftEncData = await downloadFile(`${normalizedUrl}/sync/${file.path}`);
        const iv = syncEncryption.base64Decode(file.iv);
        const draftData = syncEncryption.decrypt(draftEncData, iv, encryptionKey);
        const syncDraft = JSON.parse(draftData.toString());
        createOrUpdatePost(storage, blogId, syncDraft, categoryMap, tagMap, true);
      }
      appliedChanges++;
    }

    for (const file of categorized.drafts.deleted) {
      onProgress({ step: 'Removing deleted drafts...', phase: 'applying', progress: appliedChanges / totalChanges });
      const entityId = extractEntityId(file.path);
      if (entityId) {
        const localDraft = storage.getPostBySyncId(blogId, entityId);
        if (localDraft) {
          storage.deletePost(blogId, localDraft.id);
        }
      }
      appliedChanges++;
    }
  }

  // Step 8: Process sidebar changes
  for (const file of categorized.sidebar.new) {
    onProgress({ step: 'Adding sidebar content...', phase: 'applying', progress: appliedChanges / totalChanges });
    const entityId = extractEntityId(file.path);
    if (entityId) {
      const sidebarData = await downloadFile(`${normalizedUrl}/sync/${file.path}`);
      const syncSidebar = JSON.parse(sidebarData.toString());
      storage.createSidebarObject(blogId, {
        title: syncSidebar.title,
        type: syncSidebar.type,
        content: syncSidebar.content,
        order: syncSidebar.order,
        links: syncSidebar.links || [],
        syncId: syncSidebar.id
      });
    }
    appliedChanges++;
  }

  for (const file of categorized.sidebar.modified) {
    onProgress({ step: 'Updating sidebar content...', phase: 'applying', progress: appliedChanges / totalChanges });
    const entityId = extractEntityId(file.path);
    if (entityId) {
      const sidebarData = await downloadFile(`${normalizedUrl}/sync/${file.path}`);
      const syncSidebar = JSON.parse(sidebarData.toString());
      const localSidebar = storage.getSidebarObjectBySyncId(blogId, syncSidebar.id);
      if (localSidebar) {
        storage.updateSidebarObject(blogId, localSidebar.id, {
          title: syncSidebar.title,
          type: syncSidebar.type,
          content: syncSidebar.content,
          order: syncSidebar.order,
          links: syncSidebar.links || []
        });
      } else {
        storage.createSidebarObject(blogId, {
          title: syncSidebar.title,
          type: syncSidebar.type,
          content: syncSidebar.content,
          order: syncSidebar.order,
          links: syncSidebar.links || [],
          syncId: syncSidebar.id
        });
      }
    }
    appliedChanges++;
  }

  for (const file of categorized.sidebar.deleted) {
    onProgress({ step: 'Removing deleted sidebar content...', phase: 'applying', progress: appliedChanges / totalChanges });
    const entityId = extractEntityId(file.path);
    if (entityId) {
      const localSidebar = storage.getSidebarObjectBySyncId(blogId, entityId);
      if (localSidebar) {
        storage.deleteSidebarObject(blogId, localSidebar.id);
      }
    }
    appliedChanges++;
  }

  // Step 9: Process static file changes
  for (const file of categorized.staticFiles.new) {
    onProgress({ step: 'Downloading static files...', phase: 'applying', progress: appliedChanges / totalChanges });
    const filename = file.path.replace('static-files/', '');
    const fileBuffer = await downloadFile(`${normalizedUrl}/sync/${file.path}`);

    // Get file info from static-files index
    const staticIndexData = await downloadFile(`${normalizedUrl}/sync/static-files/index.json`);
    const staticIndex = JSON.parse(staticIndexData.toString());
    const fileEntry = staticIndex.files.find(f => f.filename === filename);

    storage.createStaticFile(blogId, {
      filename: filename,
      mimeType: fileEntry?.mimeType || 'application/octet-stream',
      specialFileType: fileEntry?.specialFileType || null,
      syncId: filename
    }, fileBuffer);
    appliedChanges++;
  }

  for (const file of categorized.staticFiles.deleted) {
    onProgress({ step: 'Removing deleted static files...', phase: 'applying', progress: appliedChanges / totalChanges });
    const filename = file.path.replace('static-files/', '');
    const localFile = storage.getStaticFileBySyncId(blogId, filename);
    if (localFile) {
      storage.deleteStaticFile(blogId, localFile.id);
    }
    appliedChanges++;
  }

  // Step 10: Update sync state
  const newHashes = {};
  const newContentHashes = {};
  for (const [filePath, fileInfo] of Object.entries(manifest.files)) {
    newHashes[filePath] = fileInfo.hash;
    // Store content hashes for encrypted files (for consistent comparison)
    if (fileInfo.contentHash) {
      newContentHashes[filePath] = fileInfo.contentHash;
    }
  }
  storage.updateSyncVersion(blogId, manifest.syncVersion, newHashes, newContentHashes);

  onProgress({ step: 'Sync complete!', phase: 'complete', progress: 1 });

  return {
    success: true,
    updated: true,
    message: `Synced ${appliedChanges} changes`,
    changes: {
      new: changeSet.newFiles.length,
      modified: changeSet.modifiedFiles.length,
      deleted: changeSet.deletedFiles.length
    }
  };
}

/**
 * Create or update a post from sync data
 */
function createOrUpdatePost(storage, blogId, syncPost, categoryMap, tagMap, isDraft) {
  // Build embed object if present
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
      embed.images = srcEmbed.images?.map(img => ({
        filename: img.filename,
        order: img.order
      })) || [];
    }
  }

  // Map category ID
  const categoryId = syncPost.categoryId ? categoryMap.get(syncPost.categoryId) : null;

  // Map tag IDs
  const tagIds = (syncPost.tagIds || [])
    .map(id => tagMap.get(id))
    .filter(Boolean);

  // Check if post exists
  const existingPost = storage.getPostBySyncId(blogId, syncPost.id);

  if (existingPost) {
    // Update existing post
    storage.updatePost(blogId, existingPost.id, {
      title: syncPost.title || null,
      content: syncPost.content,
      stub: syncPost.stub,
      isDraft: isDraft,
      categoryId: categoryId,
      tagIds: tagIds,
      embed: embed
    });
  } else {
    // Create new post
    storage.createPost(blogId, {
      title: syncPost.title || null,
      content: syncPost.content,
      stub: syncPost.stub,
      isDraft: isDraft,
      categoryId: categoryId,
      tagIds: tagIds,
      embed: embed,
      syncId: syncPost.id,
      createdAt: syncPost.createdAt
    });
  }
}

export default {
  pullChanges
};
