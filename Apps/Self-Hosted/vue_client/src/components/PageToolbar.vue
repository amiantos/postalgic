<script setup>
import { computed } from 'vue';
import { useRoute } from 'vue-router';
import { useBlogStore } from '@/stores/blog';

defineProps({
  title: { type: String, default: '' },
  subtitle: { type: String, default: '' }
});

const route = useRoute();
const blogStore = useBlogStore();

const blogId = computed(() => route.params.blogId);
</script>

<template>
  <header class="sticky top-0 z-40 bg-white/90 dark:bg-gray-900/90 backdrop-blur-lg border-b border-black/5 dark:border-white/10 mb-6">
    <div class="max-w-3xl mx-auto px-4 sm:px-6 pb-4">
      <!-- Top row: Back link + Blog name centered + Settings link -->
      <div class="flex items-center justify-between py-2">
        <router-link to="/" class="flex items-center gap-2 text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-300 text-sm">
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
          </svg>
          <span>All Blogs</span>
        </router-link>

        <router-link
          :to="{ name: 'blog-posts', params: { blogId } }"
          class="absolute left-1/2 -translate-x-1/2 text-sm font-medium text-gray-900 dark:text-gray-100 hover:text-primary-600 dark:hover:text-primary-400 transition-colors"
        >
          {{ blogStore.currentBlog?.name }}
        </router-link>

        <router-link
          :to="{ name: 'blog-settings', params: { blogId } }"
          class="text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-300 text-sm"
        >
          Settings
        </router-link>
      </div>

      <!-- Tabs (settings navigation, appears right under top nav) -->
      <slot name="tabs"></slot>

      <!-- Bottom row: Title + Actions -->
      <div class="flex items-center justify-between pt-4 pb-4">
        <div class="min-h-[3rem] flex flex-col justify-center">
          <h1 class="text-xl font-semibold text-gray-900 dark:text-gray-100">{{ title }}</h1>
          <p v-if="subtitle" class="text-gray-500 dark:text-gray-400 text-sm">{{ subtitle }}</p>
        </div>

        <!-- Action buttons -->
        <div class="flex items-center gap-2">
          <slot name="actions"></slot>
        </div>
      </div>

      <!-- Controls (search bars, filters, etc.) -->
      <slot name="controls"></slot>
    </div>
  </header>
</template>
