<script setup>
import { ref, onMounted } from 'vue';
import { loginWithPasskey } from '@/composables/useAuth';

const busy = ref(false);
const error = ref('');

async function handleLogin() {
  busy.value = true;
  error.value = '';
  try {
    await loginWithPasskey();
  } catch (err) {
    // Browser cancellations look like NotAllowedError or AbortError — keep
    // the message friendly so it doesn't read like a real failure.
    const name = err?.name || '';
    if (name === 'NotAllowedError' || name === 'AbortError') {
      error.value = 'Sign-in was cancelled.';
    } else {
      error.value = err?.message || 'Sign-in failed';
    }
  } finally {
    busy.value = false;
  }
}

onMounted(() => {
  // Auto-trigger the passkey prompt so the user lands straight in the
  // password-manager dialog instead of having to click twice.
  handleLogin();
});
</script>

<template>
  <div class="min-h-screen bg-site-bg text-site-text flex items-center justify-center px-6 py-12">
    <div class="max-w-md w-full">
      <div class="text-center mb-8">
        <img src="/postalgic-logo.png" alt="Postalgic" class="h-16 mx-auto mb-6" />
        <h1 class="text-[1.6rem] font-bold text-site-dark mb-3">Sign in</h1>
        <p class="text-[0.95em] text-site-medium leading-relaxed">
          Use your passkey to continue.
        </p>
      </div>

      <div class="bg-white border border-site-light rounded-lg p-6">
        <button
          @click="handleLogin"
          :disabled="busy"
          class="w-full px-5 py-3 bg-site-accent text-white font-semibold rounded-full hover:bg-[#e89200] disabled:opacity-60 disabled:cursor-not-allowed transition-colors"
        >
          {{ busy ? 'Signing in…' : 'Sign in with passkey' }}
        </button>

        <p v-if="error" class="mt-4 text-[0.9em] text-red-600">
          {{ error }}
        </p>
      </div>
    </div>
  </div>
</template>
