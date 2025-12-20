<script setup>
import { ref, onMounted, watch, computed } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useBlogStore } from '@/stores/blog';

const route = useRoute();
const router = useRouter();
const blogStore = useBlogStore();

const mobileMenuOpen = ref(false);

const blogId = computed(() => route.params.blogId);

onMounted(async () => {
  await loadBlogData();
});

watch(blogId, async () => {
  await loadBlogData();
});

async function loadBlogData() {
  blogStore.clearBlogData();
  await blogStore.fetchBlog(blogId.value);
  await Promise.all([
    blogStore.fetchPosts(blogId.value),
    blogStore.fetchCategories(blogId.value),
    blogStore.fetchTags(blogId.value)
  ]);
}

const navItems = [
  { name: 'Posts', route: 'blog-posts', icon: 'M19 20H5a2 2 0 01-2-2V6a2 2 0 012-2h10a2 2 0 012 2v1m2 13a2 2 0 01-2-2V7m2 13a2 2 0 002-2V9a2 2 0 00-2-2h-2m-4-3H9M7 16h6M7 8h6v4H7V8z' },
  { name: 'Categories', route: 'categories', icon: 'M3 7v10a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-6l-2-2H5a2 2 0 00-2 2z' },
  { name: 'Tags', route: 'tags', icon: 'M7 7h.01M7 3h5c.512 0 1.024.195 1.414.586l7 7a2 2 0 010 2.828l-7 7a2 2 0 01-2.828 0l-7-7A2 2 0 013 12V7a4 4 0 014-4z' },
  { name: 'Sidebar', route: 'sidebar', icon: 'M4 5a1 1 0 011-1h14a1 1 0 011 1v2a1 1 0 01-1 1H5a1 1 0 01-1-1V5zM4 13a1 1 0 011-1h6a1 1 0 011 1v6a1 1 0 01-1 1H5a1 1 0 01-1-1v-6zM16 13a1 1 0 011-1h2a1 1 0 011 1v6a1 1 0 01-1 1h-2a1 1 0 01-1-1v-6z' },
  { name: 'Files', route: 'files', icon: 'M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z' },
  { name: 'Themes', route: 'themes', icon: 'M7 21a4 4 0 01-4-4V5a2 2 0 012-2h4a2 2 0 012 2v12a4 4 0 01-4 4zm0 0h12a2 2 0 002-2v-4a2 2 0 00-2-2h-2.343M11 7.343l1.657-1.657a2 2 0 012.828 0l2.829 2.829a2 2 0 010 2.828l-8.486 8.485M7 17h.01' },
  { name: 'Settings', route: 'blog-settings', icon: 'M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z' },
  { name: 'Publish', route: 'publish', icon: 'M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12' }
];

function isActive(routeName) {
  return route.name === routeName;
}
</script>

<template>
  <div class="min-h-screen bg-gray-50 dark:bg-gray-900 flex max-w-7xl mx-auto">
    <!-- Desktop Sidebar -->
    <aside class="hidden md:flex md:flex-col md:w-64 bg-white dark:bg-gray-800 border-r border-gray-200 dark:border-gray-700 xl:border-l sticky top-0 h-screen">
      <!-- Header -->
      <div class="p-4 border-b border-gray-200 dark:border-gray-700">
        <router-link to="/" class="flex items-center gap-2 text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-300 mb-3">
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
          </svg>
          <span class="text-sm">All Blogs</span>
        </router-link>
        <h1 class="font-semibold text-gray-900 dark:text-gray-100 truncate">{{ blogStore.currentBlog?.name }}</h1>
      </div>

      <!-- Navigation -->
      <nav class="flex-1 p-4 space-y-1">
        <router-link
          v-for="item in navItems"
          :key="item.route"
          :to="{ name: item.route, params: { blogId } }"
          :class="[
            'flex items-center gap-3 px-3 py-2 rounded-lg transition-colors',
            isActive(item.route)
              ? 'bg-primary-50 dark:bg-primary-900/30 text-primary-700 dark:text-primary-300'
              : 'text-gray-600 dark:text-gray-400 hover:bg-gray-100 dark:hover:bg-gray-700'
          ]"
        >
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" :d="item.icon" />
          </svg>
          {{ item.name }}
        </router-link>
      </nav>
    </aside>

    <!-- Mobile Header -->
    <div class="md:hidden fixed top-0 left-0 right-0 bg-white dark:bg-gray-800 border-b border-gray-200 dark:border-gray-700 z-40">
      <div class="flex items-center justify-between p-4">
        <div class="flex items-center gap-3">
          <router-link to="/" class="text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-300">
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
            </svg>
          </router-link>
          <h1 class="font-semibold text-gray-900 dark:text-gray-100 truncate">{{ blogStore.currentBlog?.name }}</h1>
        </div>
        <button @click="mobileMenuOpen = !mobileMenuOpen" class="p-2 text-gray-500 dark:text-gray-400">
          <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16" />
          </svg>
        </button>
      </div>

      <!-- Mobile Menu -->
      <div v-if="mobileMenuOpen" class="border-t border-gray-200 dark:border-gray-700 bg-white dark:bg-gray-800">
        <nav class="p-2">
          <router-link
            v-for="item in navItems"
            :key="item.route"
            :to="{ name: item.route, params: { blogId } }"
            :class="[
              'flex items-center gap-3 px-3 py-2 rounded-lg transition-colors',
              isActive(item.route)
                ? 'bg-primary-50 dark:bg-primary-900/30 text-primary-700 dark:text-primary-300'
                : 'text-gray-600 dark:text-gray-400 hover:bg-gray-100 dark:hover:bg-gray-700'
            ]"
            @click="mobileMenuOpen = false"
          >
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" :d="item.icon" />
            </svg>
            {{ item.name }}
          </router-link>
        </nav>
      </div>
    </div>

    <!-- Main Content -->
    <main class="flex-1 pt-16 md:pt-0">
      <router-view />
    </main>
  </div>
</template>
