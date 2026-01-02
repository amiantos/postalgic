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
  <!-- Checking indicator (subtle) -->
  <div
    v-if="isChecking && !showBadge"
    class="text-gray-400 dark:text-gray-500"
    title="Checking for sync changes..."
  >
    <svg class="w-5 h-5 animate-spin" fill="none" viewBox="0 0 24 24">
      <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
      <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
    </svg>
  </div>

  <!-- Changes available badge -->
  <button
    v-else-if="showBadge"
    @click="handleClick"
    class="relative text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-300 transition-colors"
    title="Remote changes available - click to sync"
  >
    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
            d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
    </svg>
    <!-- Pulsing badge dot -->
    <span class="absolute -top-1 -right-1 w-3 h-3 bg-blue-500 rounded-full animate-pulse"></span>
  </button>
</template>
