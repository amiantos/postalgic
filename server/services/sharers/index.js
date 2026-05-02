import { WebhookSharer } from './webhookSharer.js';

const REGISTRY = {
  webhook: WebhookSharer
};

export const SHARER_TYPES = Object.keys(REGISTRY);

export function getSharer(type) {
  const Sharer = REGISTRY[type];
  if (!Sharer) {
    throw new Error(`Unknown share destination type: ${type}`);
  }
  return new Sharer();
}

export { WebhookSharer };
