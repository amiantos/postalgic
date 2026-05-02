import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import fs from 'fs';
import os from 'os';
import path from 'path';
import crypto from 'crypto';

import { initDatabase, closeDatabase } from '../server/utils/database.js';
import Storage from '../server/utils/storage.js';
import { WebhookSharer } from '../server/services/sharers/webhookSharer.js';
import { getSharer } from '../server/services/sharers/index.js';

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
  it('sends a signed POST request when a secret is configured', async () => {
    const captured = {};
    global.fetch = vi.fn(async (url, init) => {
      captured.url = url;
      captured.init = init;
      return new Response(null, { status: 200 });
    });

    const sharer = new WebhookSharer();
    const payload = {
      event: 'post.share',
      delivery_id: 'abc-123',
      post: { title: 't' }
    };
    await sharer.send({
      payload,
      config: { url: 'https://relay.example.com/hook', secret: 's3cret' }
    });

    expect(captured.url).toBe('https://relay.example.com/hook');
    expect(captured.init.method).toBe('POST');
    expect(captured.init.headers['Content-Type']).toBe('application/json');
    expect(captured.init.headers['X-Postalgic-Event']).toBe('post.share');
    expect(captured.init.headers['X-Postalgic-Delivery']).toBe('abc-123');

    const expectedSig = crypto.createHmac('sha256', 's3cret')
      .update(captured.init.body)
      .digest('hex');
    expect(captured.init.headers['X-Postalgic-Signature']).toBe(`sha256=${expectedSig}`);

    expect(JSON.parse(captured.init.body)).toEqual(payload);
  });

  it('omits the signature header when no secret is configured', async () => {
    const captured = {};
    global.fetch = vi.fn(async (url, init) => {
      captured.init = init;
      return new Response(null, { status: 200 });
    });

    const sharer = new WebhookSharer();
    await sharer.send({
      payload: { event: 'post.share' },
      config: { url: 'https://relay.example.com/hook' }
    });

    expect(captured.init.headers['X-Postalgic-Signature']).toBeUndefined();
  });

  it('throws when the webhook returns non-2xx', async () => {
    global.fetch = vi.fn(async () => new Response('boom', { status: 500, statusText: 'Server Error' }));
    const sharer = new WebhookSharer();
    await expect(sharer.send({
      payload: { event: 'post.share' },
      config: { url: 'https://relay.example.com/hook' }
    })).rejects.toThrow(/500/);
  });

  it('throws when the URL is missing', async () => {
    const sharer = new WebhookSharer();
    await expect(sharer.send({
      payload: { event: 'post.share' },
      config: {}
    })).rejects.toThrow(/no URL/i);
  });
});

describe('Sharer registry', () => {
  it('returns a WebhookSharer for type=webhook', () => {
    const s = getSharer('webhook');
    expect(s).toBeInstanceOf(WebhookSharer);
  });

  it('throws for unknown types', () => {
    expect(() => getSharer('discourse')).toThrow();
  });
});
