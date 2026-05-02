import crypto from 'crypto';

const REQUEST_TIMEOUT_MS = 15000;

function buildWebhookPayload({ post, blog, context, deliveryId }) {
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
      excerpt: context.excerpt,
      content_markdown: post.content || '',
      content_html: post.contentHtml || null,
      permalink: context.permalink,
      stub: post.stub,
      published_at: post.createdAt,
      category: context.categoryName,
      tags: context.tags,
      embed: context.embed
    }
  };
}

export class WebhookSharer {
  static type = 'webhook';

  validateConfig(config) {
    if (!config?.url) throw new Error('Webhook destination has no URL configured');
    try {
      const u = new URL(config.url);
      if (u.protocol !== 'http:' && u.protocol !== 'https:') {
        throw new Error('Webhook URL must use http or https');
      }
    } catch {
      throw new Error('Webhook URL is not a valid URL');
    }
  }

  async send({ post, blog, context, config, deliveryId }) {
    this.validateConfig(config);

    const payload = buildWebhookPayload({ post, blog, context, deliveryId });
    const body = JSON.stringify(payload);
    const headers = {
      'Content-Type': 'application/json',
      'User-Agent': 'Postalgic/1.0',
      'X-Postalgic-Event': 'post.share',
      'X-Postalgic-Delivery': deliveryId
    };

    if (config.secret) {
      const sig = crypto.createHmac('sha256', config.secret).update(body).digest('hex');
      headers['X-Postalgic-Signature'] = `sha256=${sig}`;
    }

    let response;
    try {
      response = await fetch(config.url, {
        method: 'POST',
        headers,
        body,
        signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS)
      });
    } catch (err) {
      if (err.name === 'TimeoutError' || err.name === 'AbortError') {
        throw new Error(`Webhook request timed out after ${REQUEST_TIMEOUT_MS}ms`);
      }
      throw new Error(`Webhook request failed: ${err.message}`);
    }

    if (!response.ok) {
      let detail = '';
      try {
        const text = await response.text();
        detail = text.slice(0, 500);
      } catch {
        // ignore body read errors
      }
      throw new Error(`Webhook returned ${response.status} ${response.statusText}${detail ? `: ${detail}` : ''}`);
    }

    return { status: response.status };
  }
}
