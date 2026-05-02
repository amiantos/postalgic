/**
 * Share Routes
 *
 * Manages share destinations (webhooks today; Discourse and others later) and
 * the per-post Share action that verifies a published permalink and dispatches
 * a signed webhook.
 */

import express from 'express';
import crypto from 'crypto';
import Storage from '../utils/storage.js';
import { formatDatePath, getExcerpt } from '../utils/helpers.js';
import { getSharer, SHARER_TYPES } from '../services/sharers/index.js';

const router = express.Router({ mergeParams: true });

const URL_VERIFY_TIMEOUT_MS = 10000;

function getStorage(req) {
  return new Storage(req.app.locals.dataRoot);
}

function isValidHttpUrl(value) {
  if (typeof value !== 'string' || !value) return false;
  try {
    const u = new URL(value);
    return u.protocol === 'http:' || u.protocol === 'https:';
  } catch {
    return false;
  }
}

function joinUrl(base, ...parts) {
  const trimmedBase = (base || '').replace(/\/+$/, '');
  const tail = parts
    .filter(Boolean)
    .map(p => String(p).replace(/^\/+|\/+$/g, ''))
    .join('/');
  return `${trimmedBase}/${tail}`;
}

function buildPermalink(blog, post) {
  const datePath = formatDatePath(post.createdAt, blog.timezone || 'UTC');
  return `${joinUrl(blog.url, datePath, post.stub)}/`;
}

function absolutizeEmbed(embed, blog) {
  if (!embed) return null;

  const out = {
    type: embed.type,
    position: embed.position || null
  };

  if (embed.type === 'youtube') {
    out.url = embed.url || null;
    out.video_id = embed.videoId || null;
    out.title = embed.title || null;
    out.image_url = embed.imageFilename
      ? joinUrl(blog.url, 'images/embeds', embed.imageFilename)
      : null;
  } else if (embed.type === 'link') {
    out.url = embed.url || null;
    out.title = embed.title || null;
    out.description = embed.description || null;
    if (embed.imageFilename) {
      out.image_url = joinUrl(blog.url, 'images/embeds', embed.imageFilename);
    } else if (embed.imageUrl && !embed.imageUrl.startsWith('file://')) {
      out.image_url = embed.imageUrl;
    } else {
      out.image_url = null;
    }
  } else if (embed.type === 'image') {
    out.images = (embed.images || [])
      .slice()
      .sort((a, b) => (a.order ?? 0) - (b.order ?? 0))
      .map(img => ({
        url: joinUrl(blog.url, 'images/embeds', img.filename),
        order: img.order ?? 0
      }));
  }

  return out;
}

function buildSharePayload({ blog, post, storage, blogId, deliveryId }) {
  const permalink = buildPermalink(blog, post);

  let categoryName = null;
  if (post.categoryId) {
    const category = storage.getCategory(blogId, post.categoryId);
    if (category) categoryName = category.name;
  }

  let tags = [];
  if (post.tagIds && post.tagIds.length > 0) {
    tags = post.tagIds
      .map(tagId => storage.getTag(blogId, tagId))
      .filter(Boolean)
      .map(tag => tag.name);
  }

  return {
    event: 'post.share',
    delivery_id: deliveryId,
    blog: {
      name: blog.name || null,
      url: blog.url || null,
      tagline: blog.tagline || null
    },
    author: {
      name: blog.authorName || null,
      url: blog.authorUrl || null,
      email: blog.authorEmail || null
    },
    post: {
      id: post.id,
      title: post.title || null,
      excerpt: getExcerpt(post.content || '', 280),
      content_markdown: post.content || '',
      content_html: post.contentHtml || null,
      permalink,
      stub: post.stub,
      published_at: post.createdAt,
      category: categoryName,
      tags,
      embed: absolutizeEmbed(post.embed, blog)
    }
  };
}

// ============ Share Destination CRUD ============

// GET /api/blogs/:blogId/share/destinations
router.get('/destinations', (req, res) => {
  try {
    const storage = getStorage(req);
    const { blogId } = req.params;
    res.json(storage.getShareDestinations(blogId));
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// POST /api/blogs/:blogId/share/destinations
router.post('/destinations', (req, res) => {
  try {
    const storage = getStorage(req);
    const { blogId } = req.params;
    const { type, name, config } = req.body || {};

    if (!SHARER_TYPES.includes(type)) {
      return res.status(400).json({ error: `Unsupported destination type. Allowed: ${SHARER_TYPES.join(', ')}` });
    }
    if (!name || typeof name !== 'string' || !name.trim()) {
      return res.status(400).json({ error: 'Name is required' });
    }
    if (type === 'webhook' && !isValidHttpUrl(config?.url)) {
      return res.status(400).json({ error: 'A valid http(s) URL is required for webhook destinations' });
    }

    const blog = storage.getBlog(blogId);
    if (!blog) {
      return res.status(404).json({ error: 'Blog not found' });
    }

    const created = storage.createShareDestination(blogId, {
      type,
      name: name.trim(),
      config: config || {}
    });
    res.status(201).json(created);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// PUT /api/blogs/:blogId/share/destinations/:id
router.put('/destinations/:id', (req, res) => {
  try {
    const storage = getStorage(req);
    const { blogId, id } = req.params;
    const { name, config } = req.body || {};

    const existing = storage.getShareDestination(blogId, id);
    if (!existing) {
      return res.status(404).json({ error: 'Share destination not found' });
    }

    if (name !== undefined && (typeof name !== 'string' || !name.trim())) {
      return res.status(400).json({ error: 'Name is required' });
    }
    if (existing.type === 'webhook' && config !== undefined && !isValidHttpUrl(config?.url)) {
      return res.status(400).json({ error: 'A valid http(s) URL is required for webhook destinations' });
    }

    const updated = storage.updateShareDestination(blogId, id, {
      name: name !== undefined ? name.trim() : undefined,
      config
    });
    res.json(updated);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// DELETE /api/blogs/:blogId/share/destinations/:id
router.delete('/destinations/:id', (req, res) => {
  try {
    const storage = getStorage(req);
    const { blogId, id } = req.params;

    const existing = storage.getShareDestination(blogId, id);
    if (!existing) {
      return res.status(404).json({ error: 'Share destination not found' });
    }

    storage.deleteShareDestination(blogId, id);
    res.status(204).end();
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// GET /api/blogs/:blogId/share/posts/:postId/shares - share history for a post
router.get('/posts/:postId/shares', (req, res) => {
  try {
    const storage = getStorage(req);
    const { blogId, postId } = req.params;

    const post = storage.getPost(blogId, postId);
    if (!post) {
      return res.status(404).json({ error: 'Post not found' });
    }

    res.json(storage.getPostShares(blogId, postId));
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// POST /api/blogs/:blogId/share/posts/:postId - perform a share
// Body: { destinationId: string, force?: boolean }
router.post('/posts/:postId', async (req, res) => {
  const storage = getStorage(req);
  const { blogId, postId } = req.params;
  const { destinationId, force } = req.body || {};

  if (!destinationId) {
    return res.status(400).json({ error: 'destinationId is required' });
  }

  const blog = storage.getBlog(blogId);
  if (!blog) {
    return res.status(404).json({ error: 'Blog not found' });
  }
  if (!blog.url) {
    return res.status(400).json({ error: 'Blog URL is not configured. Set the blog URL in settings before sharing.' });
  }

  const post = storage.getPost(blogId, postId);
  if (!post) {
    return res.status(404).json({ error: 'Post not found' });
  }
  if (post.isDraft) {
    return res.status(400).json({ error: 'Drafts cannot be shared. Publish the post first.' });
  }

  const destination = storage.getShareDestination(blogId, destinationId);
  if (!destination) {
    return res.status(404).json({ error: 'Share destination not found' });
  }

  // Duplicate guard — only successful prior shares trip this
  if (!force) {
    const lastSharedAt = storage.hasSuccessfulShare(blogId, postId, destinationId);
    if (lastSharedAt) {
      return res.status(409).json({
        error: `Already shared to "${destination.name}" on ${lastSharedAt}`,
        alreadyShared: true,
        lastSharedAt
      });
    }
  }

  // SSRF guard for webhook URLs
  if (destination.type === 'webhook' && !isValidHttpUrl(destination.config?.url)) {
    return res.status(400).json({ error: 'Destination has an invalid or missing URL' });
  }

  const deliveryId = crypto.randomUUID();
  const permalink = buildPermalink(blog, post);

  // Live URL check — confirm the post is actually published
  try {
    const verifyResponse = await fetch(permalink, {
      method: 'GET',
      redirect: 'follow',
      signal: AbortSignal.timeout(URL_VERIFY_TIMEOUT_MS)
    });
    // discard body
    try { await verifyResponse.text(); } catch { /* ignore */ }

    if (!verifyResponse.ok) {
      const errMsg = `Post not found at ${permalink} (HTTP ${verifyResponse.status}). Have you published the site?`;
      storage.recordPostShare(blogId, {
        postId,
        destinationId,
        status: 'failed',
        deliveryId,
        permalink,
        error: errMsg
      });
      return res.status(400).json({ error: errMsg });
    }
  } catch (err) {
    const errMsg = `Could not reach ${permalink}: ${err.message}`;
    storage.recordPostShare(blogId, {
      postId,
      destinationId,
      status: 'failed',
      deliveryId,
      permalink,
      error: errMsg
    });
    return res.status(400).json({ error: errMsg });
  }

  // Build payload and dispatch
  const payload = buildSharePayload({ blog, post, storage, blogId, deliveryId });

  try {
    const sharer = getSharer(destination.type);
    await sharer.send({ payload, config: destination.config });
  } catch (err) {
    storage.recordPostShare(blogId, {
      postId,
      destinationId,
      status: 'failed',
      deliveryId,
      permalink,
      error: err.message
    });
    return res.status(502).json({ error: err.message });
  }

  const record = storage.recordPostShare(blogId, {
    postId,
    destinationId,
    status: 'success',
    deliveryId,
    permalink,
    error: null
  });

  res.json({
    success: true,
    permalink,
    deliveryId,
    sharedAt: record.sharedAt,
    destinationId,
    destinationName: destination.name
  });
});

export default router;
