import { renderTemplate } from './postContext.js';

const REQUEST_TIMEOUT_MS = 15000;

function trimSlash(url) {
  return (url || '').replace(/\/+$/, '');
}

function authHeaders(config) {
  if (!config?.apiKey || !config?.apiUsername) {
    throw new Error('Discourse destination requires apiKey and apiUsername');
  }
  return {
    'Api-Key': config.apiKey,
    'Api-Username': config.apiUsername,
    'User-Agent': 'Postalgic/1.0'
  };
}

async function discourseFetch(url, init = {}) {
  let response;
  try {
    response = await fetch(url, {
      ...init,
      signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS)
    });
  } catch (err) {
    if (err.name === 'TimeoutError' || err.name === 'AbortError') {
      throw new Error(`Discourse request timed out after ${REQUEST_TIMEOUT_MS}ms`);
    }
    throw new Error(`Discourse request failed: ${err.message}`);
  }

  if (!response.ok) {
    let detail = '';
    try {
      const text = await response.text();
      detail = text.slice(0, 500);
    } catch {
      // ignore body read errors
    }
    throw new Error(`Discourse returned ${response.status} ${response.statusText}${detail ? `: ${detail}` : ''}`);
  }

  return response;
}

export async function fetchDiscourseCategories(config) {
  this?.validateConfig?.(config);
  const baseUrl = trimSlash(config.url);
  if (!baseUrl) throw new Error('Discourse URL is required');

  const response = await discourseFetch(`${baseUrl}/categories.json?include_subcategories=true`, {
    method: 'GET',
    headers: authHeaders(config)
  });
  const data = await response.json();
  const list = data?.category_list?.categories || [];

  // Flatten subcategories one level so the picker shows them all
  const flat = [];
  for (const cat of list) {
    flat.push({ id: cat.id, name: cat.name, slug: cat.slug, parentId: null });
    if (Array.isArray(cat.subcategory_list)) {
      for (const sub of cat.subcategory_list) {
        flat.push({ id: sub.id, name: `${cat.name} / ${sub.name}`, slug: sub.slug, parentId: cat.id });
      }
    }
  }
  return flat;
}

export async function searchDiscourseTopics(config, query) {
  const baseUrl = trimSlash(config.url);
  if (!baseUrl) throw new Error('Discourse URL is required');
  if (!query || !query.trim()) return [];

  const response = await discourseFetch(
    `${baseUrl}/search.json?q=${encodeURIComponent(query.trim())}`,
    { method: 'GET', headers: authHeaders(config) }
  );
  const data = await response.json();
  const topics = Array.isArray(data?.topics) ? data.topics : [];
  return topics.slice(0, 20).map(t => ({
    id: t.id,
    title: t.title,
    slug: t.slug,
    categoryId: t.category_id,
    postsCount: t.posts_count,
    createdAt: t.created_at,
    url: `${baseUrl}/t/${t.slug}/${t.id}`
  }));
}

export async function fetchDiscourseTopic(config, topicId) {
  const baseUrl = trimSlash(config.url);
  if (!baseUrl) throw new Error('Discourse URL is required');
  if (!topicId) throw new Error('topicId is required');

  const response = await discourseFetch(`${baseUrl}/t/${encodeURIComponent(topicId)}.json`, {
    method: 'GET',
    headers: authHeaders(config)
  });
  const data = await response.json();
  return {
    id: data.id,
    title: data.title,
    slug: data.slug,
    categoryId: data.category_id,
    url: `${baseUrl}/t/${data.slug}/${data.id}`
  };
}

export class DiscourseSharer {
  static type = 'discourse';

  validateConfig(config) {
    if (!config?.url) throw new Error('Discourse destination has no URL configured');
    if (!config?.apiKey) throw new Error('Discourse destination requires an API key');
    if (!config?.apiUsername) throw new Error('Discourse destination requires an API username');
    try {
      const u = new URL(config.url);
      if (u.protocol !== 'http:' && u.protocol !== 'https:') {
        throw new Error('Discourse URL must use http or https');
      }
    } catch {
      throw new Error('Discourse URL is not a valid URL');
    }
  }

  async send({ post, blog, context, config, params, deliveryId }) {
    this.validateConfig(config);

    const mode = params?.mode || (config.defaultTopicId ? 'reply' : 'new_topic');
    const template = config.template || '{permalink}';
    const raw = renderTemplate(template, { post, blog, context }).trim();
    if (!raw) throw new Error('Rendered post body is empty — check the template');

    const baseUrl = trimSlash(config.url);
    const headers = {
      ...authHeaders(config),
      'Content-Type': 'application/json'
    };

    const body = { raw };
    let resultLabel = '';

    if (mode === 'reply') {
      const topicId = params?.topicId ?? config.defaultTopicId;
      if (!topicId) throw new Error('Reply mode requires a topicId');
      body.topic_id = Number(topicId);
      resultLabel = `reply to topic ${topicId}`;
    } else if (mode === 'new_topic') {
      const title = (params?.title || post.title || context.excerpt || '').trim();
      if (!title) throw new Error('New topic requires a title');
      body.title = title;

      const categoryId = params?.categoryId ?? config.defaultCategoryId;
      if (categoryId) body.category = Number(categoryId);

      const tags = Array.isArray(params?.tags) && params.tags.length > 0
        ? params.tags
        : (context.tags || []);
      if (tags.length > 0) body.tags = tags;

      resultLabel = `new topic "${title}"`;
    } else {
      throw new Error(`Unknown Discourse mode: ${mode}`);
    }

    const response = await discourseFetch(`${baseUrl}/posts.json`, {
      method: 'POST',
      headers,
      body: JSON.stringify(body)
    });
    const data = await response.json().catch(() => ({}));

    const topicId = data.topic_id || body.topic_id;
    const topicSlug = data.topic_slug;
    const postNumber = data.post_number;
    const postUrl = topicId && topicSlug
      ? `${baseUrl}/t/${topicSlug}/${topicId}${postNumber ? `/${postNumber}` : ''}`
      : null;

    return {
      status: response.status,
      mode,
      label: resultLabel,
      topicId,
      postId: data.id,
      postUrl
    };
  }
}
