import express from 'express';
import crypto from 'crypto';
import Storage from '../utils/storage.js';
import { renderMarkdown } from '../utils/markdown.js';
import {
  generateStub,
  makeStubUnique,
  formatDatePath,
  formatDate,
  formatShortDate,
  getExcerpt,
  extractYouTubeId,
  generateEmbedFilename
} from '../utils/helpers.js';

const router = express.Router({ mergeParams: true });

function getStorage(req) {
  return new Storage(req.app.locals.dataRoot);
}

// GET /api/blogs/:blogId/posts - List posts with pagination
// Query params:
//   - status: 'all' (default), 'published', or 'drafts'
//   - search: search term for title, content, category, tags (min 2 chars)
//   - sort: 'date_desc' (default), 'date_asc', 'title_asc', 'title_desc'
//   - page: page number (default 1)
//   - limit: posts per page (default 10, max 100)
router.get('/', (req, res) => {
  try {
    const storage = getStorage(req);
    const { blogId } = req.params;
    const status = req.query.status || 'all'; // 'all', 'published', or 'drafts'
    const search = req.query.search || '';
    const sort = req.query.sort || 'date_desc';
    const page = Math.max(1, parseInt(req.query.page) || 1);
    const limit = Math.min(100, Math.max(1, parseInt(req.query.limit) || 10));

    let posts;

    // Only search if term is at least 2 characters
    if (search.trim() && search.trim().length >= 2) {
      posts = storage.searchPosts(blogId, search, { status, sort });
    } else {
      posts = storage.getAllPosts(blogId, status);
      posts = sortPosts(posts, sort);
    }

    // Calculate pagination
    const total = posts.length;
    const publishedCount = posts.filter(p => !p.isDraft).length;
    const draftCount = posts.filter(p => p.isDraft).length;
    const startIndex = (page - 1) * limit;
    const endIndex = startIndex + limit;
    const paginatedPosts = posts.slice(startIndex, endIndex);

    // Enrich posts with computed properties
    const enrichedPosts = paginatedPosts.map(post => enrichPost(post, storage, blogId));

    res.json({
      posts: enrichedPosts,
      total,
      publishedCount,
      draftCount,
      page,
      limit,
      hasMore: endIndex < total
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Helper: Sort posts
function sortPosts(posts, sort) {
  switch (sort) {
    case 'date_asc':
      return posts.sort((a, b) => new Date(a.createdAt) - new Date(b.createdAt));
    case 'title_asc':
      return posts.sort((a, b) => {
        const titleA = a.title || a.content;
        const titleB = b.title || b.content;
        return titleA.localeCompare(titleB);
      });
    case 'title_desc':
      return posts.sort((a, b) => {
        const titleA = a.title || a.content;
        const titleB = b.title || b.content;
        return titleB.localeCompare(titleA);
      });
    case 'date_desc':
    default:
      return posts.sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));
  }
}

// GET /api/blogs/:blogId/posts/:id - Get single post
router.get('/:id', (req, res) => {
  try {
    const storage = getStorage(req);
    const { blogId, id } = req.params;

    const post = storage.getPost(blogId, id);

    if (!post) {
      return res.status(404).json({ error: 'Post not found' });
    }

    res.json(enrichPost(post, storage, blogId));
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// POST /api/blogs/:blogId/posts - Create new post
router.post('/', (req, res) => {
  try {
    const storage = getStorage(req);
    const { blogId } = req.params;
    const { title, content, isDraft, categoryId, tagIds, embed, createdAt } = req.body;

    if (!content) {
      return res.status(400).json({ error: 'Post content is required' });
    }

    // Generate stub from title or content
    const baseStub = generateStub(title || content);
    const existingPosts = storage.getAllPosts(blogId, 'all');
    const existingStubs = existingPosts.map(p => p.stub);
    const stub = makeStubUnique(baseStub, existingStubs);

    const postData = {
      title: title || null,
      content,
      contentHtml: renderMarkdown(content),
      stub,
      isDraft: isDraft !== false,
      categoryId: categoryId || null,
      tagIds: tagIds || [],
      embed: processEmbed(embed, storage, blogId),
      createdAt: createdAt || new Date().toISOString()
    };

    const post = storage.createPost(blogId, postData);
    res.status(201).json(enrichPost(post, storage, blogId));
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// PUT /api/blogs/:blogId/posts/:id - Update post
router.put('/:id', (req, res) => {
  try {
    const storage = getStorage(req);
    const { blogId, id } = req.params;
    const { title, content, ...rest } = req.body;

    const existingPost = storage.getPost(blogId, id);
    if (!existingPost) {
      return res.status(404).json({ error: 'Post not found' });
    }

    // Regenerate stub if title or content changed
    let stub = existingPost.stub;
    const newTitle = title !== undefined ? title : existingPost.title;
    const newContent = content !== undefined ? content : existingPost.content;

    if (title !== undefined || content !== undefined) {
      const baseStub = generateStub(newTitle || newContent);
      const existingPosts = storage.getAllPosts(blogId, 'all');
      const existingStubs = existingPosts
        .filter(p => p.id !== id)
        .map(p => p.stub);
      stub = makeStubUnique(baseStub, existingStubs);
    }

    const updateData = {
      ...rest,
      title: newTitle,
      content: newContent,
      stub
    };

    // Re-render HTML if content changed
    if (content !== undefined) {
      updateData.contentHtml = renderMarkdown(newContent);
    }

    if (rest.embed !== undefined) {
      updateData.embed = processEmbed(rest.embed, storage, blogId);
    }

    const post = storage.updatePost(blogId, id, updateData);
    res.json(enrichPost(post, storage, blogId));
  } catch (error) {
    if (error.message.includes('not found')) {
      return res.status(404).json({ error: error.message });
    }
    res.status(500).json({ error: error.message });
  }
});

// DELETE /api/blogs/:blogId/posts/:id - Delete post
router.delete('/:id', (req, res) => {
  try {
    const storage = getStorage(req);
    const { blogId, id } = req.params;

    storage.deletePost(blogId, id);
    res.status(204).send();
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Helper: Process embed data
function processEmbed(embed, storage, blogId) {
  if (!embed) return null;

  const processed = {
    type: embed.type,
    url: embed.url || '',
    position: embed.position || 'below'
  };

  if (embed.type === 'youtube') {
    processed.videoId = extractYouTubeId(embed.url);
  } else if (embed.type === 'link') {
    processed.title = embed.title || '';
    processed.description = embed.description || '';
    processed.imageUrl = embed.imageUrl || '';

    // Handle link embed image - generate deterministic filename and save to disk
    if (embed.imageData && embed.imageData.startsWith('data:')) {
      // Generate deterministic filename from URL hash (first 16 chars of SHA256)
      const urlHash = crypto.createHash('sha256').update(embed.url || '').digest('hex').substring(0, 16);
      const imageFilename = `embed-${urlHash}.jpg`;

      // Parse and save the base64 image data
      const matches = embed.imageData.match(/^data:([^;]+);base64,(.+)$/);
      if (matches) {
        const base64Data = matches[2];
        const buffer = Buffer.from(base64Data, 'base64');
        storage.saveEmbedImage(blogId, imageFilename, buffer);
        processed.imageFilename = imageFilename;
      }
    } else if (embed.imageFilename) {
      // Keep existing imageFilename if already set (from sync or previous edit)
      processed.imageFilename = embed.imageFilename;
    }
  } else if (embed.type === 'image') {
    // Process images - save base64 data to disk if present
    processed.images = (embed.images || []).map((img, index) => {
      // If image has base64 data, save it to disk
      if (img.data && img.data.startsWith('data:')) {
        const savedFilename = saveEmbedImageFromBase64(storage, blogId, img.data, img.filename, index);
        return {
          filename: savedFilename,
          order: img.order ?? index
        };
      }
      // Otherwise, use existing filename (already saved or imported)
      return {
        filename: img.filename,
        order: img.order ?? index
      };
    });
  }

  return processed;
}

// Helper: Save base64 image data to disk and return the saved filename
function saveEmbedImageFromBase64(storage, blogId, dataUrl, originalFilename, index) {
  // Parse the data URL to get the mime type and data
  const matches = dataUrl.match(/^data:([^;]+);base64,(.+)$/);
  if (!matches) {
    console.warn('Invalid data URL format for embed image');
    return originalFilename;
  }

  const mimeType = matches[1];
  const base64Data = matches[2];
  const buffer = Buffer.from(base64Data, 'base64');

  // Determine file extension from mime type
  let ext = 'jpg';
  if (mimeType === 'image/png') ext = 'png';
  else if (mimeType === 'image/gif') ext = 'gif';
  else if (mimeType === 'image/webp') ext = 'webp';

  // Generate a unique filename for the embed image
  const filename = generateEmbedFilename(ext, index);

  // Save to disk
  storage.saveEmbedImage(blogId, filename, buffer);

  return filename;
}

// Helper: Enrich post with computed properties
function enrichPost(post, storage, blogId) {
  const enriched = {
    ...post,
    urlPath: `${formatDatePath(post.createdAt)}/${post.stub}`,
    displayTitle: post.title || getExcerpt(post.content, 50),
    excerpt: getExcerpt(post.content, 280),
    formattedDate: formatDate(post.createdAt),
    shortFormattedDate: formatShortDate(post.createdAt)
  };

  // Add category info
  if (post.categoryId) {
    const category = storage.getCategory(blogId, post.categoryId);
    if (category) {
      enriched.category = {
        id: category.id,
        name: category.name,
        stub: category.stub
      };
    }
  }

  // Add tags info
  if (post.tagIds && post.tagIds.length > 0) {
    enriched.tags = post.tagIds
      .map(tagId => storage.getTag(blogId, tagId))
      .filter(tag => tag !== null)
      .map(tag => ({
        id: tag.id,
        name: tag.name,
        stub: tag.stub
      }));
  } else {
    enriched.tags = [];
  }

  return enriched;
}

export default router;
