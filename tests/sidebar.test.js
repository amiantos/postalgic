import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import fs from 'fs';
import os from 'os';
import path from 'path';

import { initDatabase, closeDatabase } from '../server/utils/database.js';
import Storage from '../server/utils/storage.js';

let tempDir;
let storage;
let blogId;

beforeEach(() => {
  tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'postalgic-sidebar-test-'));
  initDatabase(tempDir);
  storage = new Storage(tempDir);

  const blog = storage.createBlog({
    name: 'Test Blog',
    url: 'https://blog.example.com',
    authorName: 'Test Author',
    timezone: 'UTC'
  });
  blogId = blog.id;
});

afterEach(() => {
  closeDatabase();
  fs.rmSync(tempDir, { recursive: true, force: true });
});

function createLinkList(title, linkTitles) {
  return storage.createSidebarObject(blogId, {
    title,
    type: 'linkList',
    content: '',
    contentHtml: null,
    links: linkTitles.map((t, i) => ({ title: t, url: `https://example.com/${t}`, order: i }))
  });
}

describe('sidebar link ordering', () => {
  it('returns links in sort_order', () => {
    const obj = createLinkList('Blogroll', ['Alpha', 'Beta', 'Gamma']);
    expect(obj.links.map(l => l.title)).toEqual(['Alpha', 'Beta', 'Gamma']);
  });

  it('persists a reordered link array on update', () => {
    const obj = createLinkList('Blogroll', ['Alpha', 'Beta', 'Gamma']);

    // What the client sends after moving "Gamma" to the top
    const reordered = ['Gamma', 'Alpha', 'Beta'].map((t, i) => ({
      title: t,
      url: `https://example.com/${t}`,
      order: i
    }));

    const updated = storage.updateSidebarObject(blogId, obj.id, { links: reordered });
    expect(updated.links.map(l => l.title)).toEqual(['Gamma', 'Alpha', 'Beta']);

    // and it survives a re-read
    const reread = storage.getSidebarObject(blogId, obj.id);
    expect(reread.links.map(l => l.title)).toEqual(['Gamma', 'Alpha', 'Beta']);
  });
});

describe('sidebar object ordering', () => {
  it('assigns increasing order to new objects', () => {
    createLinkList('First', ['a']);
    createLinkList('Second', ['b']);

    const all = storage.getAllSidebarObjects(blogId);
    expect(all.map(o => o.title)).toEqual(['First', 'Second']);
    // Assert the values, not just the sequence — tied sort_order would still
    // come back in insertion order and mask a missing assignment.
    expect(all.map(o => o.order)).toEqual([0, 1]);
  });

  it('reorders objects via an order-only update without dropping links', () => {
    const first = createLinkList('First', ['a', 'b']);
    const second = createLinkList('Second', ['c']);

    // What the /reorder route does: order-only updates, no links key
    storage.updateSidebarObject(blogId, second.id, { order: 0 });
    storage.updateSidebarObject(blogId, first.id, { order: 1 });

    const all = storage.getAllSidebarObjects(blogId);
    expect(all.map(o => o.title)).toEqual(['Second', 'First']);

    // links must be untouched by an order-only update
    expect(all.find(o => o.title === 'First').links.map(l => l.title)).toEqual(['a', 'b']);
    expect(all.find(o => o.title === 'Second').links.map(l => l.title)).toEqual(['c']);
  });

  it('applies a reorder atomically', () => {
    const first = createLinkList('First', ['a']);
    const second = createLinkList('Second', ['b']);

    const result = storage.reorderSidebarObjects(blogId, [
      { id: second.id, order: 0 },
      { id: first.id, order: 1 }
    ]);
    expect(result.map(o => o.title)).toEqual(['Second', 'First']);
  });

  it('rolls the whole reorder back if any id is bad', () => {
    const first = createLinkList('First', ['a']);
    const second = createLinkList('Second', ['b']);

    expect(() => storage.reorderSidebarObjects(blogId, [
      { id: second.id, order: 0 },
      { id: 'does-not-exist', order: 1 }
    ])).toThrow(/not found/);

    // The valid update in the same batch must not have stuck
    const all = storage.getAllSidebarObjects(blogId);
    expect(all.map(o => o.title)).toEqual(['First', 'Second']);
    expect(all.map(o => o.order)).toEqual([0, 1]);
  });

  it('preserves text content on an order-only update', () => {
    const text = storage.createSidebarObject(blogId, {
      title: 'About',
      type: 'text',
      content: 'Hello there',
      contentHtml: '<p>Hello there</p>',
      links: []
    });

    storage.updateSidebarObject(blogId, text.id, { order: 5 });

    const reread = storage.getSidebarObject(blogId, text.id);
    expect(reread.content).toBe('Hello there');
    expect(reread.contentHtml).toBe('<p>Hello there</p>');
  });
});
