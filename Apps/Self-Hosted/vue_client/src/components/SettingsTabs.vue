<script setup>
import { computed } from 'vue';
import { useRoute } from 'vue-router';

const route = useRoute();
const blogId = computed(() => route.params.blogId);
const currentRoute = computed(() => route.name);

const tabs = [
  { name: 'Basic', route: 'blog-settings' },
  { name: 'Categories', route: 'categories' },
  { name: 'Tags', route: 'tags' },
  { name: 'Sidebar', route: 'sidebar' },
  { name: 'Files', route: 'files' },
  { name: 'Themes', route: 'themes' }
];
</script>

<template>
  <div class="flex items-center">
    <router-link
      v-for="tab in tabs"
      :key="tab.route"
      :to="{ name: tab.route, params: { blogId } }"
      :class="[
        'flex-1 px-4 py-2 text-sm font-medium whitespace-nowrap text-center transition-colors border-b-2 -mb-px',
        currentRoute === tab.route
          ? 'border-primary-600 text-primary-600 dark:text-primary-400 dark:border-primary-400'
          : 'border-transparent text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-300 hover:border-gray-300 dark:hover:border-gray-600'
      ]"
    >
      {{ tab.name }}
    </router-link>
  </div>
</template>
