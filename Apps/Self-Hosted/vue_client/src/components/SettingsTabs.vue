<script setup>
import { computed } from 'vue';
import { useRoute } from 'vue-router';

const route = useRoute();
const blogId = computed(() => route.params.blogId);
const currentRoute = computed(() => route.name);

const tabs = [
  { name: 'Settings', route: 'blog-settings' },
  { name: 'Categories', route: 'categories' },
  { name: 'Tags', route: 'tags' },
  { name: 'Sidebar', route: 'sidebar' },
  { name: 'Files', route: 'files' },
  { name: 'Themes', route: 'themes' }
];
</script>

<template>
  <div class="flex items-center gap-1">
    <router-link
      v-for="tab in tabs"
      :key="tab.route"
      :to="{ name: tab.route, params: { blogId } }"
      :class="[
        'flex-1 px-4 py-2 text-sm font-medium rounded-lg whitespace-nowrap text-center transition-colors',
        currentRoute === tab.route
          ? 'bg-primary-600 text-white'
          : 'glass text-gray-600 dark:text-gray-400 hover:text-gray-900 dark:hover:text-white'
      ]"
    >
      {{ tab.name }}
    </router-link>
  </div>
</template>
