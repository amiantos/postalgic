<script setup>
import { ref, computed, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useBlogStore } from '@/stores/blog';

const route = useRoute();
const router = useRouter();
const blogStore = useBlogStore();

const showDeleteModal = ref(false);
const postToDelete = ref(null);
const filter = ref('all'); // 'all', 'published', 'draft'
const searchText = ref('');
const sortOption = ref('date_desc');
let searchTimeout = null;

const sortOptions = [
  { value: 'date_desc', label: 'Date (newest)' },
  { value: 'date_asc', label: 'Date (oldest)' },
  { value: 'title_asc', label: 'Title (A-Z)' },
  { value: 'title_desc', label: 'Title (Z-A)' }
];

const blogId = computed(() => route.params.blogId);

// Fetch posts when search/sort changes (with debounce for search)
watch([searchText, sortOption], () => {
  if (searchTimeout) clearTimeout(searchTimeout);
  searchTimeout = setTimeout(() => {
    fetchPosts();
  }, 300);
});

// Fetch posts when filter changes (immediate)
watch(filter, () => {
  fetchPosts();
});

async function fetchPosts() {
  const includeDrafts = filter.value === 'all' || filter.value === 'draft';
  await blogStore.fetchPosts(blogId.value, {
    includeDrafts,
    search: searchText.value,
    sort: sortOption.value
  });
}

const filteredPosts = computed(() => {
  // Filter is now handled server-side, but we still filter drafts client-side
  // because we fetch with includeDrafts=true for 'all' and 'draft' filters
  if (filter.value === 'published') {
    return blogStore.posts.filter(p => !p.isDraft);
  } else if (filter.value === 'draft') {
    return blogStore.posts.filter(p => p.isDraft);
  }
  return blogStore.posts;
});

const postCounts = computed(() => {
  const all = blogStore.posts.length;
  const published = blogStore.posts.filter(p => !p.isDraft).length;
  const drafts = blogStore.posts.filter(p => p.isDraft).length;
  return { all, published, drafts };
});

function navigateToPost(postId) {
  router.push({ name: 'post-edit', params: { blogId: blogId.value, postId } });
}

function createNewPost() {
  router.push({ name: 'post-create', params: { blogId: blogId.value } });
}

function confirmDelete(post) {
  postToDelete.value = post;
  showDeleteModal.value = true;
}

async function deletePost() {
  if (postToDelete.value) {
    await blogStore.deletePost(blogId.value, postToDelete.value.id);
    showDeleteModal.value = false;
    postToDelete.value = null;
  }
}

function clearSearch() {
  searchText.value = '';
}
</script>

<template>
  <div class="p-6">
    <!-- Header -->
    <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 mb-6">
      <div>
        <h2 class="text-xl font-bold text-gray-900 dark:text-gray-100">Posts</h2>
        <p class="text-gray-500 dark:text-gray-400 text-sm">
          {{ postCounts.all }} total
          ({{ postCounts.published }} published, {{ postCounts.drafts }} drafts)
        </p>
      </div>
      <button
        @click="createNewPost"
        class="px-4 py-2 bg-primary-600 text-white rounded-lg hover:bg-primary-700 transition-colors"
      >
        New Post
      </button>
    </div>

    <!-- Search and Sort Bar -->
    <div class="flex flex-col sm:flex-row gap-4 mb-4">
      <!-- Search Input -->
      <div class="relative flex-1">
        <svg class="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
        </svg>
        <input
          v-model="searchText"
          type="text"
          placeholder="Search posts..."
          class="w-full pl-10 pr-10 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100 focus:ring-2 focus:ring-primary-500 focus:border-primary-500"
        />
        <button
          v-if="searchText"
          @click="clearSearch"
          class="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600 dark:hover:text-gray-300"
        >
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
          </svg>
        </button>
      </div>

      <!-- Sort Dropdown -->
      <div class="relative">
        <select
          v-model="sortOption"
          class="appearance-none px-4 py-2 pr-10 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100 focus:ring-2 focus:ring-primary-500 focus:border-primary-500 cursor-pointer"
        >
          <option v-for="opt in sortOptions" :key="opt.value" :value="opt.value">
            {{ opt.label }}
          </option>
        </select>
        <svg class="absolute right-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400 pointer-events-none" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
        </svg>
      </div>
    </div>

    <!-- Filters -->
    <div class="flex items-center justify-between mb-6">
      <div class="flex gap-2">
        <button
          v-for="f in ['all', 'published', 'draft']"
          :key="f"
          @click="filter = f"
          :class="[
            'px-3 py-1 rounded-full text-sm transition-colors',
            filter === f
              ? 'bg-primary-100 dark:bg-primary-900/30 text-primary-700 dark:text-primary-300'
              : 'bg-gray-100 dark:bg-gray-700 text-gray-600 dark:text-gray-400 hover:bg-gray-200 dark:hover:bg-gray-600'
          ]"
        >
          {{ f.charAt(0).toUpperCase() + f.slice(1) }}
        </button>
      </div>
      <span class="text-sm text-gray-500 dark:text-gray-400">
        {{ filteredPosts.length }} posts
      </span>
    </div>

    <!-- Empty State -->
    <div v-if="filteredPosts.length === 0" class="text-center py-12 bg-white dark:bg-gray-800 rounded-lg border border-gray-200 dark:border-gray-700">
      <div class="w-16 h-16 bg-gray-100 dark:bg-gray-700 rounded-full flex items-center justify-center mx-auto mb-4">
        <svg class="w-8 h-8 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path v-if="searchText" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
          <path v-else stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
        </svg>
      </div>
      <h3 class="text-lg font-medium text-gray-900 dark:text-gray-100 mb-2">
        {{ searchText ? 'No matching posts' : 'No posts yet' }}
      </h3>
      <p class="text-gray-500 dark:text-gray-400 mb-6">
        {{ searchText ? 'Try a different search term' : 'Create your first post to get started.' }}
      </p>
      <button
        v-if="!searchText"
        @click="createNewPost"
        class="inline-flex items-center px-4 py-2 bg-primary-600 text-white rounded-lg hover:bg-primary-700"
      >
        Create Post
      </button>
      <button
        v-else
        @click="clearSearch"
        class="inline-flex items-center px-4 py-2 bg-gray-100 dark:bg-gray-700 text-gray-700 dark:text-gray-300 rounded-lg hover:bg-gray-200 dark:hover:bg-gray-600"
      >
        Clear Search
      </button>
    </div>

    <!-- Posts List -->
    <div v-else class="space-y-3">
      <div
        v-for="post in filteredPosts"
        :key="post.id"
        class="bg-white dark:bg-gray-800 rounded-lg border border-gray-200 dark:border-gray-700 p-4 hover:shadow-md transition-shadow cursor-pointer"
        @click="navigateToPost(post.id)"
      >
        <div class="flex items-start justify-between">
          <div class="flex-1 min-w-0">
            <div class="flex items-center gap-2 mb-1">
              <h3 class="font-medium text-gray-900 dark:text-gray-100 truncate">{{ post.displayTitle }}</h3>
              <span
                v-if="post.isDraft"
                class="px-2 py-0.5 text-xs bg-yellow-100 dark:bg-yellow-900/30 text-yellow-800 dark:text-yellow-300 rounded-full"
              >
                Draft
              </span>
            </div>
            <p class="text-sm text-gray-500 dark:text-gray-400">{{ post.shortFormattedDate }}</p>
            <div class="flex items-center gap-2 mt-2">
              <span
                v-if="post.category"
                class="px-2 py-0.5 text-xs bg-primary-100 dark:bg-primary-900/30 text-primary-700 dark:text-primary-300 rounded-full"
              >
                {{ post.category.name }}
              </span>
              <span
                v-for="tag in post.tags?.slice(0, 3)"
                :key="tag.id"
                class="px-2 py-0.5 text-xs bg-gray-100 dark:bg-gray-700 text-gray-600 dark:text-gray-400 rounded-full"
              >
                #{{ tag.name }}
              </span>
              <span v-if="post.tags?.length > 3" class="text-xs text-gray-400">
                +{{ post.tags.length - 3 }} more
              </span>
            </div>
          </div>
          <button
            @click.stop="confirmDelete(post)"
            class="p-2 text-gray-400 hover:text-red-600 dark:hover:text-red-400 transition-colors"
          >
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
            </svg>
          </button>
        </div>
      </div>
    </div>

    <!-- Delete Modal -->
    <div v-if="showDeleteModal" class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div class="bg-white dark:bg-gray-800 rounded-lg p-6 max-w-md w-full mx-4">
        <h3 class="text-lg font-semibold text-gray-900 dark:text-gray-100 mb-2">Delete Post</h3>
        <p class="text-gray-600 dark:text-gray-400 mb-6">
          Are you sure you want to delete "{{ postToDelete?.displayTitle }}"? This action cannot be undone.
        </p>
        <div class="flex justify-end gap-3">
          <button
            @click="showDeleteModal = false"
            class="px-4 py-2 text-gray-700 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-700 rounded-lg transition-colors"
          >
            Cancel
          </button>
          <button
            @click="deletePost"
            class="px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 transition-colors"
          >
            Delete
          </button>
        </div>
      </div>
    </div>
  </div>
</template>
