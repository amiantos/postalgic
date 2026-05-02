import crypto from 'crypto';

const REQUEST_TIMEOUT_MS = 15000;

export class WebhookSharer {
  static type = 'webhook';

  async send({ payload, config }) {
    const url = config?.url;
    if (!url) {
      throw new Error('Webhook destination has no URL configured');
    }

    const body = JSON.stringify(payload);
    const headers = {
      'Content-Type': 'application/json',
      'User-Agent': 'Postalgic/1.0',
      'X-Postalgic-Event': payload.event || 'post.share',
      'X-Postalgic-Delivery': payload.delivery_id || crypto.randomUUID()
    };

    if (config.secret) {
      const sig = crypto.createHmac('sha256', config.secret).update(body).digest('hex');
      headers['X-Postalgic-Signature'] = `sha256=${sig}`;
    }

    let response;
    try {
      response = await fetch(url, {
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
