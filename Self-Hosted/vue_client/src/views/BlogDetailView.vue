<script setup>
import { onMounted, watch, computed } from 'vue';
import { useRoute } from 'vue-router';
import { useBlogStore } from '@/stores/blog';

const route = useRoute();
const blogStore = useBlogStore();

const blogId = computed(() => route.params.blogId);

// Clear blog data SYNCHRONOUSLY during setup to prevent stale data from
// being rendered by child components before onMounted completes
blogStore.clearBlogData();

onMounted(async () => {
  await loadBlogData();
});

watch(blogId, async () => {
  // Also clear synchronously when blogId changes (component reuse)
  blogStore.clearBlogData();
  await loadBlogData();
});

async function loadBlogData() {
  await blogStore.fetchBlog(blogId.value);
  await Promise.all([
    blogStore.fetchPosts(blogId.value),
    blogStore.fetchCategories(blogId.value),
    blogStore.fetchTags(blogId.value)
  ]);
}
</script>

<template>
  <div class="min-h-screen bg-gray-50 dark:bg-gray-900">
    <main class="max-w-3xl mx-auto">
      <router-view />
    </main>
  </div>
</template>
