<script setup>
import { onMounted } from 'vue';
import { RouterView } from 'vue-router';
import { useAuth, refreshAuthStatus } from '@/composables/useAuth';
import AuthSetupView from '@/views/AuthSetupView.vue';
import AuthLoginView from '@/views/AuthLoginView.vue';

const auth = useAuth();

onMounted(() => {
  refreshAuthStatus();
});
</script>

<template>
  <div class="min-h-screen bg-site-bg">
    <template v-if="!auth.loaded">
      <div class="min-h-screen flex items-center justify-center text-site-medium text-[0.9em]">
        Loading…
      </div>
    </template>
    <template v-else-if="!auth.hasPasskey">
      <AuthSetupView />
    </template>
    <template v-else-if="!auth.authenticated">
      <AuthLoginView />
    </template>
    <template v-else>
      <RouterView />
    </template>
  </div>
</template>
