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
  <div class="py-8 px-6 max-w-3xl">
    <!-- Header - Clean and minimal -->
    <header class="mb-10">
      <div class="flex items-center justify-between mb-1">
        <h1 class="text-3xl font-semibold tracking-tight text-gray-900 dark:text-white">Posts</h1>
        <button
          @click="createNewPost"
          class="px-4 py-2 text-sm font-medium rounded-xl bg-white/80 dark:bg-white/10 backdrop-blur-sm border border-gray-200 dark:border-white/10 text-gray-900 dark:text-white hover:bg-white dark:hover:bg-white/15 transition-all shadow-sm"
        >
          New Post
        </button>
      </div>
      <p class="text-gray-500 dark:text-gray-500 text-sm">
        {{ postCounts.published }} published<span v-if="postCounts.drafts > 0">, {{ postCounts.drafts }} drafts</span>
      </p>
    </header>

    <!-- Controls - Understated, inline -->
    <div class="flex flex-col sm:flex-row sm:items-center gap-4 mb-16 pb-6 border-b border-gray-200 dark:border-white/10">
      <!-- Search -->
      <div class="relative flex-1">
        <svg class="absolute left-0 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
        </svg>
        <input
          v-model="searchText"
          type="text"
          placeholder="Search..."
          class="w-full pl-6 pr-8 py-1.5 bg-transparent text-gray-900 dark:text-gray-100 placeholder-gray-400 border-0 border-b border-transparent focus:border-gray-300 dark:focus:border-white/20 focus:ring-0 transition-colors text-sm"
        />
        <button
          v-if="searchText"
          @click="clearSearch"
          class="absolute right-0 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600 dark:hover:text-gray-300"
        >
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
          </svg>
        </button>
      </div>

      <!-- Filter & Sort - Compact -->
      <div class="flex items-center gap-4 text-sm">
        <div class="flex items-center gap-1 text-gray-500 dark:text-gray-400">
          <button
            v-for="f in ['all', 'published', 'draft']"
            :key="f"
            @click="filter = f"
            :class="[
              'px-2 py-1 rounded transition-colors',
              filter === f
                ? 'text-gray-900 dark:text-white font-medium'
                : 'hover:text-gray-700 dark:hover:text-gray-300'
            ]"
          >
            {{ f.charAt(0).toUpperCase() + f.slice(1) }}
          </button>
        </div>
        <span class="text-gray-300 dark:text-gray-700">|</span>
        <select
          v-model="sortOption"
          class="bg-transparent text-gray-500 dark:text-gray-400 border-0 focus:ring-0 cursor-pointer text-sm py-0 pr-6"
        >
          <option v-for="opt in sortOptions" :key="opt.value" :value="opt.value">
            {{ opt.label }}
          </option>
        </select>
      </div>
    </div>

    <p v-if="searchText && !effectiveSearchText" class="text-sm text-gray-500 dark:text-gray-400 mb-4">
      Type {{ MIN_SEARCH_LENGTH - searchText.length }} more character{{ MIN_SEARCH_LENGTH - searchText.length > 1 ? 's' : '' }} to search
    </p>

    <!-- Empty State -->
    <div v-if="filteredPosts.length === 0" class="text-center py-20">
      <p class="text-gray-400 dark:text-gray-500 mb-4">
        {{ searchText ? 'No posts match your search.' : 'No posts yet.' }}
      </p>
      <button
        v-if="!searchText"
        @click="createNewPost"
        class="text-primary-600 dark:text-primary-400 font-medium hover:text-primary-700 dark:hover:text-primary-300"
      >
        Create your first post
      </button>
      <button
        v-else
        @click="clearSearch"
        class="text-gray-600 dark:text-gray-400 hover:text-gray-800 dark:hover:text-gray-200"
      >
        Clear search
      </button>
    </div>

    <!-- Posts List - Editorial flow -->
    <div v-else class="divide-y divide-gray-200 dark:divide-white/10">
      <article
        v-for="post in filteredPosts"
        :key="post.id"
        class="py-16 first:pt-0 group cursor-pointer"
        @click="navigateToPost(post.id)"
      >
        <!-- Meta line -->
        <div class="flex items-center gap-3 mb-3 text-sm">
          <time class="text-gray-400 dark:text-gray-500">{{ formatLocalDateTime(post.createdAt) }}</time>
          <span
            v-if="post.isDraft"
            class="text-amber-600 dark:text-amber-500 font-medium"
          >
            Draft
          </span>
          <span v-if="post.category" class="text-primary-600 dark:text-primary-400">
            {{ post.category.name }}
          </span>
          <!-- Delete button - appears on hover -->
          <button
            @click.stop="confirmDelete(post)"
            class="ml-auto opacity-0 group-hover:opacity-100 text-gray-400 hover:text-red-500 transition-all"
          >
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
            </svg>
          </button>
        </div>

        <!-- Title -->
        <h2
          v-if="post.title"
          class="text-xl font-semibold text-gray-900 dark:text-white mb-3 group-hover:text-primary-600 dark:group-hover:text-primary-400 transition-colors"
        >
          {{ post.title }}
        </h2>

        <!-- Embed (above position) -->
        <div v-if="post.embed && post.embed.position === 'above'" class="mb-4">
          <!-- YouTube -->
          <div v-if="post.embed.type === 'youtube' && getYouTubeVideoId(post.embed)" class="aspect-video rounded-lg overflow-hidden">
            <iframe
              :src="`https://www.youtube.com/embed/${getYouTubeVideoId(post.embed)}`"
              class="w-full h-full"
              frameborder="0"
              allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
              allowfullscreen
            ></iframe>
          </div>

          <!-- Link -->
          <a
            v-else-if="post.embed.type === 'link'"
            :href="post.embed.url"
            @click.stop
            target="_blank"
            rel="noopener noreferrer"
            class="flex gap-4 group/link"
          >
            <img
              v-if="getLinkEmbedImageSrc(post.embed)"
              :src="getLinkEmbedImageSrc(post.embed)"
              class="w-24 h-24 object-cover rounded-lg shrink-0"
              alt=""
            />
            <div class="flex-1 min-w-0 py-1">
              <p v-if="post.embed.title" class="font-medium text-gray-900 dark:text-white group-hover/link:text-primary-600 dark:group-hover/link:text-primary-400 line-clamp-2 transition-colors">{{ post.embed.title }}</p>
              <p v-if="post.embed.description" class="text-sm text-gray-500 dark:text-gray-400 line-clamp-2 mt-1">{{ post.embed.description }}</p>
              <p class="text-xs text-gray-400 dark:text-gray-500 mt-2 truncate">{{ post.embed.url }}</p>
            </div>
          </a>

          <!-- Image -->
          <div v-else-if="post.embed.type === 'image' && post.embed.images?.length > 0">
            <img
              :src="getEmbedImageUrl(post.embed.images[0]?.filename)"
              class="w-full max-h-96 object-contain rounded-lg"
              alt=""
            />
            <p v-if="post.embed.images.length > 1" class="text-xs text-gray-400 mt-2">
              +{{ post.embed.images.length - 1 }} more
            </p>
          </div>
        </div>

        <!-- Content -->
        <div
          v-if="post.content"
          class="prose prose-sm dark:prose-invert prose-gray max-w-none"
          v-html="renderMarkdown(post.content)"
        ></div>

        <!-- Embed (below position) -->
        <div v-if="post.embed && post.embed.position === 'below'" class="mt-4">
          <!-- YouTube -->
          <div v-if="post.embed.type === 'youtube' && getYouTubeVideoId(post.embed)" class="aspect-video rounded-lg overflow-hidden">
            <iframe
              :src="`https://www.youtube.com/embed/${getYouTubeVideoId(post.embed)}`"
              class="w-full h-full"
              frameborder="0"
              allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
              allowfullscreen
            ></iframe>
          </div>

          <!-- Link -->
          <a
            v-else-if="post.embed.type === 'link'"
            :href="post.embed.url"
            @click.stop
            target="_blank"
            rel="noopener noreferrer"
            class="flex gap-4 group/link"
          >
            <img
              v-if="getLinkEmbedImageSrc(post.embed)"
              :src="getLinkEmbedImageSrc(post.embed)"
              class="w-24 h-24 object-cover rounded-lg shrink-0"
              alt=""
            />
            <div class="flex-1 min-w-0 py-1">
              <p v-if="post.embed.title" class="font-medium text-gray-900 dark:text-white group-hover/link:text-primary-600 dark:group-hover/link:text-primary-400 line-clamp-2 transition-colors">{{ post.embed.title }}</p>
              <p v-if="post.embed.description" class="text-sm text-gray-500 dark:text-gray-400 line-clamp-2 mt-1">{{ post.embed.description }}</p>
              <p class="text-xs text-gray-400 dark:text-gray-500 mt-2 truncate">{{ post.embed.url }}</p>
            </div>
          </a>

          <!-- Image -->
          <div v-else-if="post.embed.type === 'image' && post.embed.images?.length > 0">
            <img
              :src="getEmbedImageUrl(post.embed.images[0]?.filename)"
              class="w-full max-h-96 object-contain rounded-lg"
              alt=""
            />
            <p v-if="post.embed.images.length > 1" class="text-xs text-gray-400 mt-2">
              +{{ post.embed.images.length - 1 }} more
            </p>
          </div>
        </div>

        <!-- Tags -->
        <div v-if="post.tags?.length > 0" class="flex items-center gap-2 mt-4 text-sm text-gray-400 dark:text-gray-500">
          <span v-for="tag in post.tags?.slice(0, 3)" :key="tag.id">
            #{{ tag.name }}
          </span>
          <span v-if="post.tags?.length > 3">
            +{{ post.tags.length - 3 }}
          </span>
        </div>
      </article>
    </div>

    <!-- Load More -->
    <div v-if="hasMorePosts" class="pt-16 text-center border-t border-gray-200 dark:border-white/10">
      <button
        @click="loadMorePosts"
        :disabled="blogStore.loading"
        class="text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-300 font-medium disabled:opacity-50 transition-colors"
      >
        <template v-if="blogStore.loading">Loading...</template>
        <template v-else>Load more ({{ remainingPostsCount }})</template>
      </button>
    </div>

    <!-- Delete Modal -->
    <div v-if="showDeleteModal" class="fixed inset-0 bg-black/60 backdrop-blur-sm flex items-center justify-center z-50">
      <div class="bg-white dark:bg-gray-900 rounded-2xl p-6 max-w-sm w-full mx-4 shadow-2xl">
        <h3 class="text-lg font-semibold text-gray-900 dark:text-white mb-2">Delete post?</h3>
        <p class="text-gray-500 dark:text-gray-400 mb-6 text-sm">
          "{{ postToDelete?.displayTitle }}" will be permanently deleted.
        </p>
        <div class="flex gap-3">
          <button
            @click="showDeleteModal = false"
            class="flex-1 px-4 py-2.5 text-gray-700 dark:text-gray-300 font-medium rounded-xl hover:bg-gray-100 dark:hover:bg-white/5 transition-colors"
          >
            Cancel
          </button>
          <button
            @click="deletePost"
            class="flex-1 px-4 py-2.5 bg-red-500 text-white font-medium rounded-xl hover:bg-red-600 transition-colors"
          >
            Delete
          </button>
        </div>
      </div>
    </div>
  </div>
</template>
