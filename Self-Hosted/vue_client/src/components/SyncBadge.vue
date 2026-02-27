<script setup>
import { computed } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useSyncStore } from '@/stores/sync';

const route = useRoute();
const router = useRouter();
const syncStore = useSyncStore();

const blogId = computed(() => route.params.blogId);
const showBadge = computed(() => syncStore.changesAvailable);
const isChecking = computed(() => syncStore.isChecking);

function handleClick() {
  // Navigate to publish settings where sync controls are
  router.push({ name: 'publish-settings', params: { blogId: blogId.value } });
}
</script>

<template>
  <!-- Checking indicator -->
  <Transition name="fade">
    <span
      v-if="isChecking && !showBadge"
      class="font-mono text-sm text-site-medium uppercase tracking-wider"
    >
      Syncing
    </span>
  </Transition>

  <!-- Changes available badge -->
  <button
    v-if="showBadge"
    @click="handleClick"
    class="font-mono text-sm text-site-accent hover:underline uppercase tracking-wider"
    title="Remote changes available - click to sync"
  >
    Sync Available
  </button>
</template>

<style scoped>
.fade-leave-active {
  transition: opacity 1s ease;
}
.fade-leave-to {
  opacity: 0;
}
</style>
