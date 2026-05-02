import { reactive } from 'vue';
import {
  startRegistration,
  startAuthentication
} from '@simplewebauthn/browser';

const state = reactive({
  loaded: false,
  hasPasskey: false,
  authenticated: false,
  basicAuth: false
});

async function fetchJson(url, options = {}) {
  const res = await fetch(url, {
    credentials: 'same-origin',
    headers: { 'Content-Type': 'application/json', ...(options.headers || {}) },
    ...options
  });
  let body = null;
  try {
    body = await res.json();
  } catch {
    body = null;
  }
  if (!res.ok) {
    throw new Error(body?.error || `HTTP ${res.status}`);
  }
  return body;
}

export async function refreshAuthStatus() {
  try {
    const data = await fetchJson('/api/auth/status');
    state.hasPasskey = !!data.hasPasskey;
    state.authenticated = !!data.authenticated;
    state.basicAuth = false;
  } catch (err) {
    // If /api/auth/status itself returns 404, basic auth mode is in effect
    // and the browser handled it transparently — we're authenticated.
    state.hasPasskey = false;
    state.authenticated = true;
    state.basicAuth = true;
  } finally {
    state.loaded = true;
  }
}

export async function registerPasskey() {
  const options = await fetchJson('/api/auth/register/options', {
    method: 'POST',
    body: JSON.stringify({})
  });
  const attResp = await startRegistration({ optionsJSON: options });
  await fetchJson('/api/auth/register/verify', {
    method: 'POST',
    body: JSON.stringify(attResp)
  });
  await refreshAuthStatus();
}

export async function loginWithPasskey() {
  const options = await fetchJson('/api/auth/authenticate/options', {
    method: 'POST',
    body: JSON.stringify({})
  });
  const authResp = await startAuthentication({ optionsJSON: options });
  await fetchJson('/api/auth/authenticate/verify', {
    method: 'POST',
    body: JSON.stringify(authResp)
  });
  await refreshAuthStatus();
}

export async function logout() {
  try {
    await fetchJson('/api/auth/logout', { method: 'POST', body: JSON.stringify({}) });
  } finally {
    await refreshAuthStatus();
  }
}

export function useAuth() {
  return state;
}

/** Mark the session as expired (e.g., when an API call returns 401). */
export function onSessionExpired() {
  state.authenticated = false;
}
