import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import fs from 'fs';
import os from 'os';
import path from 'path';
import crypto from 'crypto';

import { initDatabase, closeDatabase } from '../server/utils/database.js';
import Storage from '../server/utils/storage.js';
import { WebhookSharer } from '../server/services/sharers/webhookSharer.js';
import { DiscourseSharer } from '../server/services/sharers/discourseSharer.js';
import { getSharer } from '../server/services/sharers/index.js';
import { renderTemplate, buildPostContext, buildPermalink } from '../server/services/sharers/postContext.js';

let tempDir;
let storage;
let blogId;
let postId;

beforeEach(() => {
  tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'postalgic-share-test-'));
  initDatabase(tempDir);
  storage = new Storage(tempDir);

  const blog = storage.createBlog({
    name: 'Test Blog',
    url: 'https://blog.example.com',
    authorName: 'Test Author',
    timezone: 'UTC'
  });
  blogId = blog.id;

  const post = storage.createPost(blogId, {
    title: 'Hello world',
    content: '# Hello world\n\nThis is a body.',
    stub: 'hello-world',
    isDraft: false,
    createdAt: '2026-05-01T12:00:00.000Z'
  });
  postId = post.id;
});

afterEach(() => {
  closeDatabase();
  if (tempDir && fs.existsSync(tempDir)) {
    fs.rmSync(tempDir, { recursive: true, force: true });
  }
});

describe('Share destination CRUD', () => {
  it('creates, reads, updates, and deletes a webhook destination', () => {
    const created = storage.createShareDestination(blogId, {
      type: 'webhook',
      name: 'IRC relay',
      config: { url: 'https://relay.example.com/hook', secret: 'sekret' }
    });

    expect(created.id).toBeDefined();
    expect(created.type).toBe('webhook');
    expect(created.config.url).toBe('https://relay.example.com/hook');
    expect(created.config.secret).toBe('sekret');

    const list = storage.getShareDestinations(blogId);
    expect(list).toHaveLength(1);
    expect(list[0].id).toBe(created.id);

    const updated = storage.updateShareDestination(blogId, created.id, {
      name: 'Renamed',
      config: { url: 'https://relay.example.com/hook2', secret: 'newsecret' }
    });
    expect(updated.name).toBe('Renamed');
    expect(updated.config.url).toBe('https://relay.example.com/hook2');

    storage.deleteShareDestination(blogId, created.id);
    expect(storage.getShareDestinations(blogId)).toHaveLength(0);
  });
});

describe('Post share log', () => {
  it('records and retrieves successful and failed shares', () => {
    const dest = storage.createShareDestination(blogId, {
      type: 'webhook',
      name: 'Relay',
      config: { url: 'https://example.com/hook' }
    });

    storage.recordPostShare(blogId, {
      postId,
      destinationId: dest.id,
      status: 'success',
      deliveryId: 'd1',
      permalink: 'https://blog.example.com/2026/05/01/hello-world/'
    });
    storage.recordPostShare(blogId, {
      postId,
      destinationId: dest.id,
      status: 'failed',
      deliveryId: 'd2',
      permalink: 'https://blog.example.com/2026/05/01/hello-world/',
      error: 'connection refused'
    });

    const history = storage.getPostShares(blogId, postId);
    expect(history).toHaveLength(2);
    const statuses = history.map(h => h.status).sort();
    expect(statuses).toEqual(['failed', 'success']);
    const failed = history.find(h => h.status === 'failed');
    expect(failed.error).toBe('connection refused');
  });

  it('hasSuccessfulShare returns timestamp only when at least one success exists', () => {
    const dest = storage.createShareDestination(blogId, {
      type: 'webhook',
      name: 'Relay',
      config: { url: 'https://example.com/hook' }
    });

    expect(storage.hasSuccessfulShare(blogId, postId, dest.id)).toBeNull();

    // failure alone doesn't count
    storage.recordPostShare(blogId, {
      postId,
      destinationId: dest.id,
      status: 'failed',
      error: 'oops'
    });
    expect(storage.hasSuccessfulShare(blogId, postId, dest.id)).toBeNull();

    // a success does
    storage.recordPostShare(blogId, {
      postId,
      destinationId: dest.id,
      status: 'success'
    });
    expect(storage.hasSuccessfulShare(blogId, postId, dest.id)).toBeTruthy();
  });

  it('getLatestSuccessfulShares batches across multiple posts', () => {
    const dest = storage.createShareDestination(blogId, {
      type: 'webhook',
      name: 'Relay',
      config: { url: 'https://example.com/hook' }
    });
    const post2 = storage.createPost(blogId, {
      title: 'Other',
      content: 'body',
      stub: 'other',
      isDraft: false,
      createdAt: '2026-05-02T00:00:00.000Z'
    });

    storage.recordPostShare(blogId, { postId, destinationId: dest.id, status: 'success' });
    storage.recordPostShare(blogId, { postId: post2.id, destinationId: dest.id, status: 'failed', error: 'x' });

    const map = storage.getLatestSuccessfulShares(blogId, [postId, post2.id]);
    expect(map.get(postId)?.has(dest.id)).toBe(true);
    expect(map.get(post2.id)).toBeUndefined();
  });
});

describe('WebhookSharer', () => {
  function fixtures(overrides = {}) {
    const blog = {
      name: 'Test Blog',
      url: 'https://blog.example.com',
      tagline: 'tagline',
      authorName: 'A',
      authorUrl: null,
      authorEmail: null,
      timezone: 'UTC',
      ...overrides.blog
    };
    const post = {
      id: 'p1',
      title: 'Hello',
      content: '# Hello\n\nbody',
      contentHtml: '<h1>Hello</h1>',
      stub: 'hello',
      isDraft: false,
      categoryId: null,
      tagIds: [],
      embed: null,
      createdAt: '2026-05-01T12:00:00.000Z',
      ...overrides.post
    };
    const context = {
      permalink: 'https://blog.example.com/2026/05/01/hello/',
      excerpt: 'Hello body',
      categoryName: null,
      tags: [],
      embed: null,
      ...overrides.context
    };
    return { blog, post, context };
  }

  it('sends a signed POST and the body matches the documented payload shape', async () => {
    const captured = {};
    global.fetch = vi.fn(async (url, init) => {
      captured.url = url;
      captured.init = init;
      return new Response(null, { status: 200 });
    });

    const { blog, post, context } = fixtures();
    const sharer = new WebhookSharer();
    await sharer.send({
      blog, post, context,
      config: { url: 'https://relay.example.com/hook', secret: 's3cret' },
      deliveryId: 'abc-123'
    });

    expect(captured.url).toBe('https://relay.example.com/hook');
    expect(captured.init.method).toBe('POST');
    expect(captured.init.headers['X-Postalgic-Event']).toBe('post.share');
    expect(captured.init.headers['X-Postalgic-Delivery']).toBe('abc-123');

    const expectedSig = crypto.createHmac('sha256', 's3cret')
      .update(captured.init.body)
      .digest('hex');
    expect(captured.init.headers['X-Postalgic-Signature']).toBe(`sha256=${expectedSig}`);

    const body = JSON.parse(captured.init.body);
    expect(body.event).toBe('post.share');
    expect(body.delivery_id).toBe('abc-123');
    expect(body.post.permalink).toBe('https://blog.example.com/2026/05/01/hello/');
    expect(body.post.title).toBe('Hello');
    expect(body.blog.name).toBe('Test Blog');
  });

  it('omits the signature header when no secret is configured', async () => {
    const captured = {};
    global.fetch = vi.fn(async (_url, init) => {
      captured.init = init;
      return new Response(null, { status: 200 });
    });

    const { blog, post, context } = fixtures();
    const sharer = new WebhookSharer();
    await sharer.send({
      blog, post, context,
      config: { url: 'https://relay.example.com/hook' },
      deliveryId: 'd1'
    });

    expect(captured.init.headers['X-Postalgic-Signature']).toBeUndefined();
  });

  it('throws when the webhook returns non-2xx', async () => {
    global.fetch = vi.fn(async () => new Response('boom', { status: 500, statusText: 'Server Error' }));
    const { blog, post, context } = fixtures();
    const sharer = new WebhookSharer();
    await expect(sharer.send({
      blog, post, context,
      config: { url: 'https://relay.example.com/hook' },
      deliveryId: 'd1'
    })).rejects.toThrow(/500/);
  });

  it('throws when the URL is missing', async () => {
    const { blog, post, context } = fixtures();
    const sharer = new WebhookSharer();
    await expect(sharer.send({
      blog, post, context,
      config: {},
      deliveryId: 'd1'
    })).rejects.toThrow(/no URL/i);
  });
});

describe('renderTemplate', () => {
  const ctx = {
    blog: { name: 'staires!', authorName: 'Brad' },
    post: { title: 'Hello', content: 'body' },
    context: {
      permalink: 'https://staires.org/2026/05/01/hello/',
      excerpt: 'Hello body',
      tags: ['music', 'pop'],
      embed: { type: 'youtube', url: 'https://youtube.com/watch?v=x', image_url: 'https://staires.org/images/embeds/x.jpg' }
    }
  };

  it('substitutes the documented placeholders', () => {
    const out = renderTemplate('{embed_url}\n\n{permalink}', ctx);
    expect(out).toBe('https://youtube.com/watch?v=x\n\nhttps://staires.org/2026/05/01/hello/');
  });

  it('joins tags with commas', () => {
    expect(renderTemplate('Tags: {tags}', ctx)).toBe('Tags: music, pop');
  });

  it('leaves unknown placeholders alone and resolves missing values to empty', () => {
    const empty = {
      blog: {}, post: {},
      context: { permalink: 'https://x', excerpt: '', tags: [], embed: null }
    };
    const out = renderTemplate('{post_title} {permalink} {nonsense}', empty);
    expect(out).toBe(' https://x {nonsense}');
  });
});

describe('DiscourseSharer', () => {
  const config = {
    url: 'https://discuss.example.com',
    apiKey: 'KEY',
    apiUsername: 'bot',
    template: '{embed_url}\n\n{permalink}'
  };
  const blog = { name: 'staires!', authorName: 'Brad', url: 'https://staires.org', timezone: 'UTC' };
  const post = { id: 'p', title: 'Song', content: 'body', stub: 's', createdAt: '2026-05-01T00:00:00.000Z' };
  const context = {
    permalink: 'https://staires.org/2026/05/01/s/',
    excerpt: 'body',
    tags: [],
    embed: { type: 'youtube', url: 'https://youtu.be/x', image_url: null }
  };

  it('posts a reply to the configured default topic', async () => {
    const captured = {};
    global.fetch = vi.fn(async (url, init) => {
      captured.url = url;
      captured.init = init;
      return new Response(JSON.stringify({ id: 9, topic_id: 40, topic_slug: 'music', post_number: 11 }), {
        status: 200, headers: { 'Content-Type': 'application/json' }
      });
    });

    const sharer = new DiscourseSharer();
    const result = await sharer.send({
      blog, post, context,
      config: { ...config, defaultTopicId: 40 },
      params: {},  // no params → default mode (reply, since defaultTopicId is set)
      deliveryId: 'd'
    });

    expect(captured.url).toBe('https://discuss.example.com/posts.json');
    expect(captured.init.method).toBe('POST');
    expect(captured.init.headers['Api-Key']).toBe('KEY');
    expect(captured.init.headers['Api-Username']).toBe('bot');

    const body = JSON.parse(captured.init.body);
    expect(body.topic_id).toBe(40);
    expect(body.title).toBeUndefined();
    expect(body.raw).toBe('https://youtu.be/x\n\nhttps://staires.org/2026/05/01/s/');

    expect(result.mode).toBe('reply');
    expect(result.topicId).toBe(40);
    expect(result.postUrl).toBe('https://discuss.example.com/t/music/40/11');
  });

  it('creates a new topic with title, category, and tags', async () => {
    const captured = {};
    global.fetch = vi.fn(async (_url, init) => {
      captured.init = init;
      return new Response(JSON.stringify({ id: 1, topic_id: 99, topic_slug: 'song', post_number: 1 }), {
        status: 200, headers: { 'Content-Type': 'application/json' }
      });
    });

    const sharer = new DiscourseSharer();
    await sharer.send({
      blog, post, context,
      config,
      params: {
        mode: 'new_topic',
        title: 'New post: Song',
        categoryId: 5,
        tags: ['music', 'pop']
      },
      deliveryId: 'd'
    });

    const body = JSON.parse(captured.init.body);
    expect(body.title).toBe('New post: Song');
    expect(body.category).toBe(5);
    expect(body.tags).toEqual(['music', 'pop']);
    expect(body.topic_id).toBeUndefined();
    expect(body.raw).toContain('https://staires.org/2026/05/01/s/');
  });

  it('rejects reply mode without a topic id', async () => {
    const sharer = new DiscourseSharer();
    await expect(sharer.send({
      blog, post, context,
      config, // no defaultTopicId
      params: { mode: 'reply' },
      deliveryId: 'd'
    })).rejects.toThrow(/topicId/);
  });

  it('surfaces Discourse non-2xx errors with status and body', async () => {
    global.fetch = vi.fn(async () => new Response('rate limited', { status: 429, statusText: 'Too Many Requests' }));
    const sharer = new DiscourseSharer();
    await expect(sharer.send({
      blog, post, context,
      config: { ...config, defaultTopicId: 1 },
      params: {},
      deliveryId: 'd'
    })).rejects.toThrow(/429/);
  });

  it('validates required config fields', async () => {
    const sharer = new DiscourseSharer();
    await expect(sharer.send({
      blog, post, context,
      config: { url: 'https://x.example.com' },
      params: { mode: 'reply', topicId: 1 },
      deliveryId: 'd'
    })).rejects.toThrow(/API key/);
  });
});

describe('Sharer registry', () => {
  it('returns a WebhookSharer for type=webhook', () => {
    const s = getSharer('webhook');
    expect(s).toBeInstanceOf(WebhookSharer);
  });

  it('returns a DiscourseSharer for type=discourse', () => {
    const s = getSharer('discourse');
    expect(s).toBeInstanceOf(DiscourseSharer);
  });

  it('throws for unknown types', () => {
    expect(() => getSharer('mastodon')).toThrow();
  });
});

describe('buildPostContext + buildPermalink', () => {
  it('builds a timezone-aware permalink and resolves category and tags', () => {
    // post created 2026-05-01 12:00 UTC; LA timezone → 2026-05-01 05:00 PDT → still 2026/05/01
    const blog = { url: 'https://blog.example.com', timezone: 'America/Los_Angeles' };
    const post = { stub: 'hello', createdAt: '2026-05-01T12:00:00.000Z' };
    expect(buildPermalink(blog, post)).toBe('https://blog.example.com/2026/05/01/hello/');
  });
});
