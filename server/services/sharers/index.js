import { WebhookSharer } from './webhookSharer.js';
import { DiscourseSharer } from './discourseSharer.js';

const REGISTRY = {
  webhook: WebhookSharer,
  discourse: DiscourseSharer
};

export const SHARER_TYPES = Object.keys(REGISTRY);

export function getSharer(type) {
  const Sharer = REGISTRY[type];
  if (!Sharer) {
    throw new Error(`Unknown share destination type: ${type}`);
  }
  return new Sharer();
}

export { WebhookSharer, DiscourseSharer };
