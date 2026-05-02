<script setup>
import { ref } from 'vue';
import { registerPasskey } from '@/composables/useAuth';

const busy = ref(false);
const error = ref('');

async function handleRegister() {
  busy.value = true;
  error.value = '';
  try {
    await registerPasskey();
  } catch (err) {
    error.value = err?.message || 'Failed to register passkey';
  } finally {
    busy.value = false;
  }
}
</script>

<template>
  <div class="min-h-screen bg-site-bg text-site-text flex items-center justify-center px-6 py-12">
    <div class="max-w-md w-full">
      <div class="text-center mb-8">
        <img src="/postalgic-logo.png" alt="Postalgic" class="h-16 mx-auto mb-6" />
        <h1 class="text-[1.6rem] font-bold text-site-dark mb-3">Welcome to Postalgic</h1>
        <p class="text-[0.95em] text-site-medium leading-relaxed">
          Set up a passkey to secure your install. Your password manager (1Password,
          Apple Keychain, Bitwarden, etc.) will store it and let you sign in from any device.
        </p>
      </div>

      <div class="bg-white border border-site-light rounded-lg p-6">
        <button
          @click="handleRegister"
          :disabled="busy"
          class="w-full px-5 py-3 bg-site-accent text-white font-semibold rounded-full hover:bg-[#e89200] disabled:opacity-60 disabled:cursor-not-allowed transition-colors"
        >
          {{ busy ? 'Setting up…' : 'Create passkey' }}
        </button>

        <p v-if="error" class="mt-4 text-[0.9em] text-red-600">
          {{ error }}
        </p>

        <p class="mt-6 text-[0.8em] text-site-medium leading-relaxed">
          Passkeys require an HTTPS connection (or localhost). If your install is on
          plain HTTP from another machine, set the <code>BASIC_AUTH_USERNAME</code> and
          <code>BASIC_AUTH_PASSWORD</code> environment variables to fall back to
          username + password instead.
        </p>
      </div>
    </div>
  </div>
</template>
