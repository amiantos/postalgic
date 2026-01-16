<script setup>
import { ref, computed, watch, onBeforeUnmount } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useBlogStore } from '@/stores/blog';
import { marked } from 'marked';
import PublishModal from '@/components/PublishModal.vue';
import SyncBadge from '@/components/SyncBadge.vue';

const route = useRoute();
const router = useRouter();
const blogStore = useBlogStore();

const showDeleteModal = ref(false);
const showPublishModal = ref(false);
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

// Clean up timeout when component unmounts to prevent stale API calls
onBeforeUnmount(() => {
  if (searchTimeout) {
    clearTimeout(searchTimeout);
    searchTimeout = null;
  }
});

const effectiveSearchText = computed(() => {
  return searchText.value.length >= MIN_SEARCH_LENGTH ? searchText.value : '';
});

// Map filter values to API status values
function getStatusFromFilter(filterValue) {
  if (filterValue === 'draft') return 'drafts';
  return filterValue; // 'all' and 'published' map directly
}

async function fetchPosts() {
  await blogStore.fetchPosts(blogId.value, {
    status: getStatusFromFilter(filter.value),
    search: effectiveSearchText.value,
    sort: sortOption.value,
    limit: POSTS_PER_PAGE
  });
}

const hasMorePosts = computed(() => blogStore.postsHasMore);

const remainingPostsCount = computed(() => {
  return blogStore.postsTotal - blogStore.posts.length;
});

async function loadMorePosts() {
  await blogStore.loadMorePosts(blogId.value, {
    status: getStatusFromFilter(filter.value),
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
  const timezone = blogStore.currentBlog?.timezone || 'UTC';
  return date.toLocaleDateString('en-US', {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
    hour: 'numeric',
    minute: '2-digit',
    timeZone: timezone
  });
}

// Get truncated title for background text (first 3 words or 20 chars)
function getBackgroundTitle(title) {
  if (!title) return 'UNTITLED';
  return title.toUpperCase();
}
</script>

<template>
  <div class="min-h-screen bg-white dark:bg-black overflow-x-hidden">

    <!-- Navigation bar -->
    <nav class="flex items-center justify-between px-6 py-4">
      <router-link to="/" class="font-retro-mono text-retro-sm text-retro-gray-dark dark:text-retro-gray-medium hover:text-retro-orange uppercase tracking-wider">
        &larr; All Blogs
      </router-link>

      <div class="flex items-center gap-4">
        <SyncBadge />
        <router-link
          :to="{ name: 'post-create', params: { blogId } }"
          class="font-retro-mono text-retro-sm text-retro-gray-dark dark:text-retro-gray-medium hover:text-retro-orange uppercase tracking-wider"
        >
          + New Post
        </router-link>
        <button
          @click="showPublishModal = true"
          class="font-retro-mono text-retro-sm text-retro-gray-dark dark:text-retro-gray-medium hover:text-retro-orange uppercase tracking-wider"
        >
          Deploy
        </button>
        <router-link
          :to="{ name: 'blog-settings', params: { blogId } }"
          class="font-retro-mono text-retro-sm text-retro-gray-dark dark:text-retro-gray-medium hover:text-retro-orange uppercase tracking-wider"
        >
          Settings
        </router-link>
      </div>
    </nav>

    <!-- Hero section with giant blog name -->
    <header class="relative h-64 md:h-72 overflow-hidden">
      <!-- Divider with left padding -->
      <div class="absolute bottom-0 left-6 right-0 border-b border-retro-gray-light dark:border-retro-gray-darker"></div>
      <!-- Giant background text - uppercase -->
      <span class="absolute inset-0 flex items-center font-retro-serif font-bold text-[10rem] md:text-[14rem] leading-none tracking-tighter text-retro-gray-lightest dark:text-[#1a1a1a] select-none pointer-events-none whitespace-nowrap uppercase" aria-hidden="true">
        {{ blogStore.currentBlog?.name }}
      </span>
      <!-- Foreground content - positioned lower -->
      <div class="absolute bottom-4 left-6">
        <h1 class="font-retro-serif font-bold text-6xl md:text-7xl leading-none tracking-tight text-retro-gray-darker dark:text-retro-cream lowercase">
          {{ blogStore.currentBlog?.name }}
        </h1>
        <!-- Stats line -->
        <div class="mt-2 font-retro-mono text-retro-sm text-retro-gray-medium">
          {{ postCounts.published }} published<span v-if="postCounts.drafts > 0">, {{ postCounts.drafts }} drafts</span>
        </div>
      </div>
    </header>

    <!-- Controls bar -->
    <div class="relative px-6 py-4">
      <div class="absolute bottom-0 left-6 right-6 border-b border-retro-gray-light dark:border-retro-gray-darker"></div>
      <div class="flex flex-col sm:flex-row sm:items-center gap-3">
        <!-- Search -->
        <div class="flex-1 flex items-center border-2 border-retro-gray-light dark:border-retro-gray-darker bg-white dark:bg-black">
          <input
            v-model="searchText"
            type="text"
            placeholder="Search..."
            class="flex-1 px-3 py-2 font-retro-mono text-retro-sm bg-transparent text-retro-gray-darker dark:text-retro-cream placeholder-retro-gray-medium focus:outline-none"
          />
          <button
            v-if="searchText"
            @click="clearSearch"
            class="px-3 text-retro-gray-medium hover:text-retro-gray-darker dark:hover:text-retro-cream"
          >
            &times;
          </button>
        </div>

        <!-- Filter and Sort row -->
        <div class="flex items-center gap-3">
          <!-- Filter toggles -->
          <div class="flex items-center border-2 border-retro-gray-light dark:border-retro-gray-darker">
            <button
              v-for="f in ['all', 'published', 'draft']"
              :key="f"
              @click="filter = f"
              :class="[
                'px-3 py-2 font-retro-mono text-retro-sm uppercase tracking-wider transition-colors',
                filter === f
                  ? 'bg-retro-gray-darker text-white dark:bg-retro-cream dark:text-black'
                  : 'text-retro-gray-dark dark:text-retro-gray-medium hover:bg-retro-gray-light dark:hover:bg-retro-gray-darker'
              ]"
            >
              {{ f }}
            </button>
          </div>

          <!-- Sort dropdown -->
          <div class="relative border-2 border-retro-gray-light dark:border-retro-gray-darker">
            <select
              v-model="sortOption"
              class="appearance-none px-3 py-2 pr-8 font-retro-mono text-retro-sm bg-white dark:bg-black text-retro-gray-darker dark:text-retro-cream focus:outline-none cursor-pointer"
            >
              <option v-for="opt in sortOptions" :key="opt.value" :value="opt.value">
                {{ opt.label }}
              </option>
            </select>
            <span class="absolute right-2 top-1/2 -translate-y-1/2 pointer-events-none text-retro-gray-medium">&darr;</span>
          </div>
        </div>
      </div>

      <p v-if="searchText && !effectiveSearchText" class="mt-2 font-retro-mono text-retro-xs text-retro-gray-medium">
        Type {{ MIN_SEARCH_LENGTH - searchText.length }} more character{{ MIN_SEARCH_LENGTH - searchText.length > 1 ? 's' : '' }} to search
      </p>
    </div>

    <!-- Content -->
    <main>
      <!-- Empty State -->
      <div v-if="blogStore.posts.length === 0" class="py-24 px-6">
        <p class="font-retro-serif text-4xl md:text-6xl font-bold text-retro-gray-darker dark:text-retro-gray-light leading-tight">
          {{ searchText ? 'No posts match your search.' : 'No posts yet.' }}
        </p>
        <router-link
          v-if="!searchText"
          :to="{ name: 'post-create', params: { blogId } }"
          class="inline-block mt-6 font-retro-mono text-retro-sm text-retro-orange hover:text-retro-orange-dark uppercase tracking-wider"
        >
          Create your first post &rarr;
        </router-link>
        <button
          v-else
          @click="clearSearch"
          class="inline-block mt-6 font-retro-mono text-retro-sm text-retro-orange hover:text-retro-orange-dark uppercase tracking-wider"
        >
          Clear search &rarr;
        </button>
      </div>

      <!-- Posts List -->
      <div v-else class="space-y-0">
        <article
          v-for="post in blogStore.posts"
          :key="post.id"
          class="group cursor-pointer relative overflow-hidden border-b border-retro-gray-light dark:border-retro-gray-darker ml-6"
          @click="navigateToPost(post.id)"
        >
          <!-- Giant background text - post title uppercase -->
          <span class="absolute top-0 left-0 right-0 h-24 md:h-32 flex items-center font-retro-serif font-bold text-[6rem] md:text-[8rem] leading-none tracking-tighter text-retro-gray-lightest dark:text-[#1a1a1a] select-none pointer-events-none whitespace-nowrap uppercase overflow-hidden" aria-hidden="true">
            {{ post.title || post.content?.replace(/[#*_`>\[\]]/g, '').substring(0, 200) || 'UNTITLED' }}
          </span>

          <!-- Foreground content - flows naturally with padding -->
          <div class="relative pt-16 md:pt-20 pb-4">
            <!-- Post title -->
            <h2 class="font-retro-serif font-bold text-3xl md:text-4xl leading-none tracking-tight text-retro-gray-darker dark:text-retro-cream group-hover:text-retro-orange transition-colors lowercase whitespace-nowrap overflow-hidden">
              {{ post.title || post.content?.replace(/[#*_`>\[\]]/g, '').substring(0, 200) || 'untitled' }}
            </h2>

            <!-- Meta line -->
            <div class="mt-2 flex flex-wrap items-center gap-x-4 gap-y-1 pr-6">
              <time class="font-retro-mono text-retro-xs text-retro-gray-medium">{{ formatLocalDateTime(post.createdAt) }}</time>
              <span
                v-if="post.isDraft"
                class="font-retro-mono text-retro-xs text-retro-orange uppercase"
              >
                Draft
              </span>
              <span v-if="post.category" class="font-retro-mono text-retro-xs text-retro-gray-dark dark:text-retro-gray-medium">
                {{ post.category.name }}
              </span>
              <template v-if="post.tags?.length > 0">
                <span v-for="tag in post.tags?.slice(0, 3)" :key="tag.id" class="font-retro-mono text-retro-xs text-retro-gray-medium">
                  #{{ tag.name }}
                </span>
                <span v-if="post.tags?.length > 3" class="font-retro-mono text-retro-xs text-retro-gray-medium">
                  +{{ post.tags.length - 3 }}
                </span>
              </template>
              <!-- Delete button - appears on hover -->
              <button
                @click.stop="confirmDelete(post)"
                class="ml-auto opacity-0 group-hover:opacity-100 font-retro-mono text-retro-xs text-retro-gray-medium hover:text-red-500 uppercase transition-opacity"
              >
                Delete
              </button>
            </div>

            <!-- Content -->
            <div
              v-if="post.content"
              class="mt-4 pr-6 prose prose-sm dark:prose-invert prose-gray max-w-none font-retro-sans text-retro-sm"
              v-html="renderMarkdown(post.content)"
            ></div>
          </div>
        </article>
      </div>

      <!-- Load More -->
      <div v-if="hasMorePosts" class="py-8 px-6">
        <button
          @click="loadMorePosts"
          :disabled="blogStore.loading"
          class="font-retro-mono text-retro-sm text-retro-gray-darker dark:text-retro-gray-light hover:text-retro-orange uppercase tracking-wider disabled:opacity-50"
        >
          <template v-if="blogStore.loading">Loading...</template>
          <template v-else>Load more ({{ remainingPostsCount }}) &darr;</template>
        </button>
      </div>
    </main>

    <!-- Delete Modal -->
    <div v-if="showDeleteModal" class="fixed inset-0 bg-black/90 flex items-center justify-center z-50 p-6">
      <div class="max-w-lg w-full">
        <p class="font-retro-serif text-3xl md:text-4xl font-bold text-white mb-6">
          Delete "{{ postToDelete?.displayTitle }}"?
        </p>
        <p class="font-retro-sans text-retro-base text-retro-gray-medium mb-8">
          This cannot be undone.
        </p>
        <div class="flex gap-6">
          <button @click="showDeleteModal = false" class="font-retro-mono text-retro-sm text-retro-gray-light hover:text-white uppercase tracking-wider">
            Cancel
          </button>
          <button @click="deletePost" class="font-retro-mono text-retro-sm text-red-500 hover:text-red-400 uppercase tracking-wider">
            Delete
          </button>
        </div>
      </div>
    </div>

    <!-- Publish Modal -->
    <PublishModal
      v-if="showPublishModal"
      :blog-id="blogId"
      :show="showPublishModal"
      @close="showPublishModal = false"
    />
  </div>
</template>
