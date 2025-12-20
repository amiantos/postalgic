<script setup>
import { ref, computed, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useBlogStore } from '@/stores/blog';
import { marked } from 'marked';

const route = useRoute();
const router = useRouter();
const blogStore = useBlogStore();

const showDeleteModal = ref(false);
const postToDelete = ref(null);
const filter = ref('all'); // 'all', 'published', 'draft'
const searchText = ref('');
const sortOption = ref('date_desc');
const POSTS_PER_PAGE = 10;
let searchTimeout = null;

const sortOptions = [
  { value: 'date_desc', label: 'Date (newest)' },
  { value: 'date_asc', label: 'Date (oldest)' },
  { value: 'title_asc', label: 'Title (A-Z)' },
  { value: 'title_desc', label: 'Title (Z-A)' }
];

const blogId = computed(() => route.params.blogId);

const MIN_SEARCH_LENGTH = 2;

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

const effectiveSearchText = computed(() => {
  return searchText.value.length >= MIN_SEARCH_LENGTH ? searchText.value : '';
});

async function fetchPosts() {
  const includeDrafts = filter.value === 'all' || filter.value === 'draft';
  await blogStore.fetchPosts(blogId.value, {
    includeDrafts,
    search: effectiveSearchText.value,
    sort: sortOption.value,
    limit: POSTS_PER_PAGE
  });
}

const filteredPosts = computed(() => {
  // Filter drafts client-side since we fetch with includeDrafts=true for 'all' and 'draft'
  if (filter.value === 'published') {
    return blogStore.posts.filter(p => !p.isDraft);
  } else if (filter.value === 'draft') {
    return blogStore.posts.filter(p => p.isDraft);
  }
  return blogStore.posts;
});

const hasMorePosts = computed(() => blogStore.postsHasMore);

const remainingPostsCount = computed(() => {
  return blogStore.postsTotal - blogStore.posts.length;
});

async function loadMorePosts() {
  const includeDrafts = filter.value === 'all' || filter.value === 'draft';
  await blogStore.loadMorePosts(blogId.value, {
    includeDrafts,
    search: effectiveSearchText.value,
    sort: sortOption.value,
    limit: POSTS_PER_PAGE
  });
}

const postCounts = computed(() => {
  return {
    all: blogStore.postsTotal,
    published: blogStore.postsPublishedCount,
    drafts: blogStore.postsDraftCount
  };
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

function getEmbedImageUrl(filename) {
  if (!filename) return '';
  return `/uploads/${blogId.value}/${filename}`;
}

function getLinkEmbedImageSrc(embed) {
  if (embed.imageData) return embed.imageData;
  if (embed.imageFilename) return `/uploads/${blogId.value}/${embed.imageFilename}`;
  if (embed.imageUrl && !embed.imageUrl.startsWith('file://')) return embed.imageUrl;
  return null;
}

function renderMarkdown(content) {
  if (!content) return '';
  return marked(content);
}

function extractYouTubeId(url) {
  if (!url) return null;
  const patterns = [
    /(?:youtube\.com\/watch\?v=|youtu\.be\/|youtube\.com\/embed\/|youtube\.com\/live\/)([^&\n?#]+)/,
    /youtube\.com\/shorts\/([^&\n?#]+)/
  ];
  for (const pattern of patterns) {
    const match = url.match(pattern);
    if (match) return match[1];
  }
  return null;
}

function getYouTubeVideoId(embed) {
  return embed.videoId || extractYouTubeId(embed.url);
}

function formatLocalDateTime(dateString) {
  const date = new Date(dateString);
  return date.toLocaleDateString('en-US', {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
    hour: 'numeric',
    minute: '2-digit'
  });
}
</script>

<template>
  <div class="p-6 max-w-4xl">
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
      <span v-if="searchText && !effectiveSearchText" class="text-sm text-gray-500 dark:text-gray-400">
        Type {{ MIN_SEARCH_LENGTH - searchText.length }} more character{{ MIN_SEARCH_LENGTH - searchText.length > 1 ? 's' : '' }} to search
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
    <div v-else class="space-y-4">
      <div
        v-for="post in filteredPosts"
        :key="post.id"
        class="bg-white dark:bg-gray-800 rounded-xl border border-gray-200 dark:border-gray-700 p-4 hover:shadow-md transition-shadow cursor-pointer"
        @click="navigateToPost(post.id)"
      >
        <!-- Date and Draft Badge -->
        <div class="flex items-center justify-between mb-2">
          <p class="text-sm text-gray-500 dark:text-gray-400">{{ formatLocalDateTime(post.createdAt) }}</p>
          <div class="flex items-center gap-2">
            <span
              v-if="post.isDraft"
              class="px-2 py-0.5 text-xs bg-yellow-100 dark:bg-yellow-900/30 text-yellow-800 dark:text-yellow-300 rounded-full"
            >
              Draft
            </span>
            <button
              @click.stop="confirmDelete(post)"
              class="p-1.5 text-gray-400 hover:text-red-600 dark:hover:text-red-400 transition-colors rounded-lg hover:bg-gray-100 dark:hover:bg-gray-700"
            >
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
              </svg>
            </button>
          </div>
        </div>

        <!-- Title (if exists) -->
        <h3 v-if="post.title" class="font-semibold text-gray-900 dark:text-gray-100 mb-2">{{ post.title }}</h3>

        <!-- Embed (above position) -->
        <div v-if="post.embed && post.embed.position === 'above'" class="mb-3">
          <!-- YouTube Embed -->
          <div v-if="post.embed.type === 'youtube' && getYouTubeVideoId(post.embed)" class="aspect-video bg-gray-100 dark:bg-gray-700 rounded-lg overflow-hidden">
            <iframe
              :src="`https://www.youtube.com/embed/${getYouTubeVideoId(post.embed)}`"
              class="w-full h-full"
              frameborder="0"
              allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
              allowfullscreen
            ></iframe>
          </div>

          <!-- Link Embed -->
          <a
            v-else-if="post.embed.type === 'link'"
            :href="post.embed.url"
            @click.stop
            target="_blank"
            rel="noopener noreferrer"
            class="flex gap-3 p-3 bg-gray-50 dark:bg-gray-700 rounded-lg border border-gray-200 dark:border-gray-600 hover:bg-gray-100 dark:hover:bg-gray-600 transition-colors"
          >
            <img
              v-if="getLinkEmbedImageSrc(post.embed)"
              :src="getLinkEmbedImageSrc(post.embed)"
              class="w-20 h-20 object-cover rounded shrink-0"
              alt=""
            />
            <div v-else class="w-20 h-20 bg-gray-200 dark:bg-gray-600 rounded shrink-0 flex items-center justify-center">
              <svg class="w-8 h-8 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1" />
              </svg>
            </div>
            <div class="flex-1 min-w-0">
              <p v-if="post.embed.title" class="font-medium text-gray-900 dark:text-gray-100 line-clamp-2">{{ post.embed.title }}</p>
              <p v-if="post.embed.description" class="text-sm text-gray-500 dark:text-gray-400 line-clamp-2 mt-1">{{ post.embed.description }}</p>
              <p class="text-xs text-primary-600 dark:text-primary-400 mt-1 truncate">{{ post.embed.url }}</p>
            </div>
          </a>

          <!-- Image Embed -->
          <div v-else-if="post.embed.type === 'image' && post.embed.images?.length > 0" class="rounded-lg overflow-hidden">
            <img
              :src="getEmbedImageUrl(post.embed.images[0]?.filename)"
              class="w-full max-h-80 object-contain bg-gray-100 dark:bg-gray-700"
              alt=""
            />
            <div v-if="post.embed.images.length > 1" class="mt-1 text-xs text-gray-500 dark:text-gray-400 text-center">
              +{{ post.embed.images.length - 1 }} more image{{ post.embed.images.length > 2 ? 's' : '' }}
            </div>
          </div>
        </div>

        <!-- Content -->
        <div v-if="post.content" class="prose prose-sm dark:prose-invert max-w-none text-gray-700 dark:text-gray-300" v-html="renderMarkdown(post.content)"></div>

        <!-- Embed (below position) -->
        <div v-if="post.embed && post.embed.position === 'below'" class="mt-3">
          <!-- YouTube Embed -->
          <div v-if="post.embed.type === 'youtube' && getYouTubeVideoId(post.embed)" class="aspect-video bg-gray-100 dark:bg-gray-700 rounded-lg overflow-hidden">
            <iframe
              :src="`https://www.youtube.com/embed/${getYouTubeVideoId(post.embed)}`"
              class="w-full h-full"
              frameborder="0"
              allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
              allowfullscreen
            ></iframe>
          </div>

          <!-- Link Embed -->
          <a
            v-else-if="post.embed.type === 'link'"
            :href="post.embed.url"
            @click.stop
            target="_blank"
            rel="noopener noreferrer"
            class="flex gap-3 p-3 bg-gray-50 dark:bg-gray-700 rounded-lg border border-gray-200 dark:border-gray-600 hover:bg-gray-100 dark:hover:bg-gray-600 transition-colors"
          >
            <img
              v-if="getLinkEmbedImageSrc(post.embed)"
              :src="getLinkEmbedImageSrc(post.embed)"
              class="w-20 h-20 object-cover rounded shrink-0"
              alt=""
            />
            <div v-else class="w-20 h-20 bg-gray-200 dark:bg-gray-600 rounded shrink-0 flex items-center justify-center">
              <svg class="w-8 h-8 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1" />
              </svg>
            </div>
            <div class="flex-1 min-w-0">
              <p v-if="post.embed.title" class="font-medium text-gray-900 dark:text-gray-100 line-clamp-2">{{ post.embed.title }}</p>
              <p v-if="post.embed.description" class="text-sm text-gray-500 dark:text-gray-400 line-clamp-2 mt-1">{{ post.embed.description }}</p>
              <p class="text-xs text-primary-600 dark:text-primary-400 mt-1 truncate">{{ post.embed.url }}</p>
            </div>
          </a>

          <!-- Image Embed -->
          <div v-else-if="post.embed.type === 'image' && post.embed.images?.length > 0" class="rounded-lg overflow-hidden">
            <img
              :src="getEmbedImageUrl(post.embed.images[0]?.filename)"
              class="w-full max-h-80 object-contain bg-gray-100 dark:bg-gray-700"
              alt=""
            />
            <div v-if="post.embed.images.length > 1" class="mt-1 text-xs text-gray-500 dark:text-gray-400 text-center">
              +{{ post.embed.images.length - 1 }} more image{{ post.embed.images.length > 2 ? 's' : '' }}
            </div>
          </div>
        </div>

        <!-- Category and Tags -->
        <div v-if="post.category || post.tags?.length > 0" class="flex items-center gap-2 mt-3 flex-wrap">
          <span
            v-if="post.category"
            class="px-2 py-0.5 text-xs bg-primary-100 dark:bg-primary-900/30 text-primary-700 dark:text-primary-300 rounded-full"
          >
            {{ post.category.name }}
          </span>
          <span
            v-for="tag in post.tags?.slice(0, 2)"
            :key="tag.id"
            class="px-2 py-0.5 text-xs bg-gray-100 dark:bg-gray-700 text-gray-600 dark:text-gray-400 rounded-full"
          >
            #{{ tag.name }}
          </span>
          <span v-if="post.tags?.length > 2" class="text-xs text-gray-400">
            +{{ post.tags.length - 2 }} more
          </span>
        </div>
      </div>

      <!-- Load More Button -->
      <div v-if="hasMorePosts" class="flex justify-center pt-4">
        <button
          @click="loadMorePosts"
          :disabled="blogStore.loading"
          class="px-6 py-2 bg-gray-100 dark:bg-gray-700 text-gray-700 dark:text-gray-300 rounded-lg hover:bg-gray-200 dark:hover:bg-gray-600 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
        >
          <template v-if="blogStore.loading">Loading...</template>
          <template v-else>Load More ({{ remainingPostsCount }} remaining)</template>
        </button>
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
