<script setup>
import { computed, useSlots } from 'vue';
import { useRoute } from 'vue-router';
import { useBlogStore } from '@/stores/blog';
import SyncBadge from '@/components/SyncBadge.vue';

defineProps({
  title: { type: String, default: '' },
  subtitle: { type: String, default: '' }
});

const route = useRoute();
const blogStore = useBlogStore();
const slots = useSlots();

const blogId = computed(() => route.params.blogId);
const hasControls = computed(() => !!slots.controls);
</script>

<template>
  <header class="sticky top-0 z-40 bg-white/90 dark:bg-gray-900/90 backdrop-blur-lg border-b border-black/5 dark:border-white/10 mb-6">
    <!-- Top row: Back link + Blog name centered + Settings link -->
    <div class="max-w-3xl mx-auto px-4 sm:px-6">
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

        <div class="flex items-center gap-3">
          <!-- Sync Badge - shows when remote changes are available -->
          <SyncBadge />

          <router-link
            :to="{ name: 'blog-settings', params: { blogId } }"
            class="text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-300"
            title="Settings"
          >
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z" />
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
            </svg>
          </router-link>
        </div>
      </div>
    </div>

    <!-- Bottom section -->
    <div class="max-w-3xl mx-auto px-4 sm:px-6 pb-4">
      <!-- Tabs (settings navigation) -->
      <div v-if="$slots.tabs" class="pt-2">
        <slot name="tabs"></slot>
      </div>
      <!-- Title + Actions -->
      <div :class="['flex items-center justify-between pt-4', hasControls ? 'pb-4' : '']">
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
