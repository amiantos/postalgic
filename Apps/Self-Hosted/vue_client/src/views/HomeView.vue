<script setup>
import { ref, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { useBlogStore } from '@/stores/blog';

const router = useRouter();
const blogStore = useBlogStore();

const showDeleteModal = ref(false);
const blogToDelete = ref(null);

onMounted(() => {
  blogStore.fetchBlogs();
});

function navigateToBlog(blogId) {
  router.push({ name: 'blog-posts', params: { blogId } });
}

function confirmDelete(blog) {
  blogToDelete.value = blog;
  showDeleteModal.value = true;
}

async function deleteBlog() {
  if (blogToDelete.value) {
    await blogStore.deleteBlog(blogToDelete.value.id);
    showDeleteModal.value = false;
    blogToDelete.value = null;
  }
}
</script>

<template>
  <div class="min-h-screen bg-gray-50 dark:bg-gray-900">
    <!-- Header -->
    <header class="bg-white dark:bg-gray-800 shadow-sm">
      <div class="max-w-4xl mx-auto px-4 py-6">
        <div class="flex items-center justify-between">
          <div>
            <h1 class="text-2xl font-bold text-gray-900 dark:text-gray-100">Postalgic</h1>
            <p class="text-gray-500 dark:text-gray-400 text-sm">Self-hosted static blog generator</p>
          </div>
          <div class="flex gap-2">
            <router-link
              to="/blogs/import"
              class="px-4 py-2 border border-gray-300 dark:border-gray-600 text-gray-700 dark:text-gray-300 rounded-lg hover:bg-gray-50 dark:hover:bg-gray-700 transition-colors"
            >
              Import Blog
            </router-link>
            <router-link
              to="/blogs/new"
              class="px-4 py-2 bg-primary-600 text-white rounded-lg hover:bg-primary-700 transition-colors"
            >
              New Blog
            </router-link>
          </div>
        </div>
      </div>
    </header>

    <!-- Content -->
    <main class="max-w-4xl mx-auto px-4 py-8">
      <!-- Loading -->
      <div v-if="blogStore.loading" class="text-center py-12">
        <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-primary-600 mx-auto"></div>
        <p class="mt-4 text-gray-500 dark:text-gray-400">Loading blogs...</p>
      </div>

      <!-- Error -->
      <div v-else-if="blogStore.error" class="bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded-lg p-4">
        <p class="text-red-800 dark:text-red-400">{{ blogStore.error }}</p>
      </div>

      <!-- Empty State -->
      <div v-else-if="blogStore.blogs.length === 0" class="text-center py-12">
        <div class="w-16 h-16 bg-gray-100 dark:bg-gray-800 rounded-full flex items-center justify-center mx-auto mb-4">
          <svg class="w-8 h-8 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 20H5a2 2 0 01-2-2V6a2 2 0 012-2h10a2 2 0 012 2v1m2 13a2 2 0 01-2-2V7m2 13a2 2 0 002-2V9a2 2 0 00-2-2h-2m-4-3H9M7 16h6M7 8h6v4H7V8z" />
          </svg>
        </div>
        <h2 class="text-lg font-medium text-gray-900 dark:text-gray-100 mb-2">No blogs yet</h2>
        <p class="text-gray-500 dark:text-gray-400 mb-6">Create your first blog to get started.</p>
        <router-link
          to="/blogs/new"
          class="inline-flex items-center px-4 py-2 bg-primary-600 text-white rounded-lg hover:bg-primary-700"
        >
          Create Blog
        </router-link>
      </div>

      <!-- Blog List -->
      <div v-else class="space-y-4">
        <div
          v-for="blog in blogStore.blogs"
          :key="blog.id"
          class="bg-white dark:bg-gray-800 rounded-lg shadow-sm border border-gray-200 dark:border-gray-700 p-6 hover:shadow-md transition-shadow cursor-pointer"
          @click="navigateToBlog(blog.id)"
        >
          <div class="flex items-start justify-between">
            <div class="flex-1">
              <h2 class="text-xl font-semibold text-gray-900 dark:text-gray-100">{{ blog.name }}</h2>
              <p v-if="blog.tagline" class="text-gray-500 dark:text-gray-400 mt-1">{{ blog.tagline }}</p>
              <p v-if="blog.url" class="text-primary-600 dark:text-primary-400 text-sm mt-2">{{ blog.url }}</p>
            </div>
            <button
              @click.stop="confirmDelete(blog)"
              class="p-2 text-gray-400 hover:text-red-600 dark:hover:text-red-400 transition-colors"
            >
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
              </svg>
            </button>
          </div>
          <div class="flex items-center gap-4 mt-4 text-sm text-gray-500 dark:text-gray-400">
            <span>Created {{ new Date(blog.createdAt).toLocaleDateString() }}</span>
          </div>
        </div>
      </div>
    </main>

    <!-- Delete Modal -->
    <div v-if="showDeleteModal" class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div class="bg-white dark:bg-gray-800 rounded-lg p-6 max-w-md w-full mx-4">
        <h3 class="text-lg font-semibold text-gray-900 dark:text-gray-100 mb-2">Delete Blog</h3>
        <p class="text-gray-600 dark:text-gray-400 mb-6">
          Are you sure you want to delete "{{ blogToDelete?.name }}"? This action cannot be undone.
        </p>
        <div class="flex justify-end gap-3">
          <button
            @click="showDeleteModal = false"
            class="px-4 py-2 text-gray-700 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-700 rounded-lg transition-colors"
          >
            Cancel
          </button>
          <button
            @click="deleteBlog"
            class="px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 transition-colors"
          >
            Delete
          </button>
        </div>
      </div>
    </div>
  </div>
</template>
