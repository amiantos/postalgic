/**
 * Share Routes
 *
 * Manages share destinations (webhooks, Discourse) and the per-post Share
 * action that verifies a published permalink and dispatches to the right
 * sharer.
 */

import express from 'express';
import crypto from 'crypto';
import Storage from '../utils/storage.js';
import { getSharer, SHARER_TYPES } from '../services/sharers/index.js';
import { buildPostContext, buildPermalink } from '../services/sharers/postContext.js';
import {
  fetchDiscourseCategories,
  searchDiscourseTopics,
  fetchDiscourseTopic
} from '../services/sharers/discourseSharer.js';

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

function validateDestinationConfig(type, config) {
  if (type === 'webhook') {
    if (!isValidHttpUrl(config?.url)) {
      throw new Error('A valid http(s) URL is required for webhook destinations');
    }
  } else if (type === 'discourse') {
    if (!isValidHttpUrl(config?.url)) {
      throw new Error('A valid http(s) URL is required for Discourse destinations');
    }
    if (!config?.apiKey) throw new Error('Discourse destinations require an API key');
    if (!config?.apiUsername) throw new Error('Discourse destinations require an API username');
  }
}

// ============ Share Destination CRUD ============

router.get('/destinations', (req, res) => {
  try {
    const storage = getStorage(req);
    const { blogId } = req.params;
    res.json(storage.getShareDestinations(blogId));
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

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
    try {
      validateDestinationConfig(type, config);
    } catch (e) {
      return res.status(400).json({ error: e.message });
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
    if (config !== undefined) {
      try {
        validateDestinationConfig(existing.type, config);
      } catch (e) {
        return res.status(400).json({ error: e.message });
      }
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

// ============ Discourse helper proxies ============
// Browser can't call Discourse directly (CORS + secret on server).

// POST variants accept the config in the body so the settings UI can probe
// before the destination has been saved. They take the same config shape as
// share_destinations.config.

router.post('/discourse/test', async (req, res) => {
  try {
    const { config } = req.body || {};
    const categories = await fetchDiscourseCategories(config || {});
    res.json({ ok: true, categories });
  } catch (error) {
    res.status(502).json({ error: error.message });
  }
});

router.post('/discourse/search-topics', async (req, res) => {
  try {
    const { config, q } = req.body || {};
    const topics = await searchDiscourseTopics(config || {}, q || '');
    res.json(topics);
  } catch (error) {
    res.status(502).json({ error: error.message });
  }
});

router.post('/discourse/topic', async (req, res) => {
  try {
    const { config, topicId } = req.body || {};
    const topic = await fetchDiscourseTopic(config || {}, topicId);
    res.json(topic);
  } catch (error) {
    res.status(502).json({ error: error.message });
  }
});

router.get('/destinations/:id/discourse/categories', async (req, res) => {
  try {
    const storage = getStorage(req);
    const { blogId, id } = req.params;
    const dest = storage.getShareDestination(blogId, id);
    if (!dest || dest.type !== 'discourse') {
      return res.status(404).json({ error: 'Discourse destination not found' });
    }
    const categories = await fetchDiscourseCategories(dest.config);
    res.json(categories);
  } catch (error) {
    res.status(502).json({ error: error.message });
  }
});

router.get('/destinations/:id/discourse/search', async (req, res) => {
  try {
    const storage = getStorage(req);
    const { blogId, id } = req.params;
    const q = req.query.q || '';
    const dest = storage.getShareDestination(blogId, id);
    if (!dest || dest.type !== 'discourse') {
      return res.status(404).json({ error: 'Discourse destination not found' });
    }
    const topics = await searchDiscourseTopics(dest.config, q);
    res.json(topics);
  } catch (error) {
    res.status(502).json({ error: error.message });
  }
});

router.get('/destinations/:id/discourse/topic/:topicId', async (req, res) => {
  try {
    const storage = getStorage(req);
    const { blogId, id, topicId } = req.params;
    const dest = storage.getShareDestination(blogId, id);
    if (!dest || dest.type !== 'discourse') {
      return res.status(404).json({ error: 'Discourse destination not found' });
    }
    const topic = await fetchDiscourseTopic(dest.config, topicId);
    res.json(topic);
  } catch (error) {
    res.status(502).json({ error: error.message });
  }
});

// ============ Post share history ============

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

// ============ Share action ============

router.post('/posts/:postId', async (req, res) => {
  const storage = getStorage(req);
  const { blogId, postId } = req.params;
  const { destinationId, force, ...params } = req.body || {};

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

  const deliveryId = crypto.randomUUID();
  const permalink = buildPermalink(blog, post);

  // Live URL check — confirm the post is actually published
  try {
    const verifyResponse = await fetch(permalink, {
      method: 'GET',
      redirect: 'follow',
      signal: AbortSignal.timeout(URL_VERIFY_TIMEOUT_MS)
    });
    try { await verifyResponse.text(); } catch { /* ignore */ }

    if (!verifyResponse.ok) {
      const errMsg = `Post not found at ${permalink} (HTTP ${verifyResponse.status}). Have you published the site?`;
      storage.recordPostShare(blogId, {
        postId, destinationId, status: 'failed', deliveryId, permalink, error: errMsg
      });
      return res.status(400).json({ error: errMsg });
    }
  } catch (err) {
    const errMsg = `Could not reach ${permalink}: ${err.message}`;
    storage.recordPostShare(blogId, {
      postId, destinationId, status: 'failed', deliveryId, permalink, error: errMsg
    });
    return res.status(400).json({ error: errMsg });
  }

  const context = buildPostContext({ post, blog, storage, blogId });
  let result;
  try {
    const sharer = getSharer(destination.type);
    result = await sharer.send({
      post, blog, context, config: destination.config, params, deliveryId
    });
  } catch (err) {
    storage.recordPostShare(blogId, {
      postId, destinationId, status: 'failed', deliveryId, permalink, error: err.message
    });
    return res.status(502).json({ error: err.message });
  }

  const record = storage.recordPostShare(blogId, {
    postId, destinationId, status: 'success', deliveryId, permalink, error: null
  });

  res.json({
    success: true,
    permalink,
    deliveryId,
    sharedAt: record.sharedAt,
    destinationId,
    destinationName: destination.name,
    result
  });
});

export default router;
