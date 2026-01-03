<script setup>
import { ref, computed, watch, onBeforeUnmount } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useBlogStore } from '@/stores/blog';
import { marked } from 'marked';
import PageToolbar from '@/components/PageToolbar.vue';

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
</script>

<template>
  <div>
    <PageToolbar
      title="Posts"
      :subtitle="`${postCounts.published} published${postCounts.drafts > 0 ? `, ${postCounts.drafts} drafts` : ''}`"
    >
      <template #actions>
        <router-link
          :to="{ name: 'post-create', params: { blogId } }"
          class="glass px-3 py-2 text-sm font-medium text-gray-700 dark:text-gray-300 flex items-center gap-1"
        >
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
          </svg>
          New Post
        </router-link>
      </template>

      <template #controls>
        <div class="flex flex-col sm:flex-row sm:items-center gap-3 pb-4">
          <!-- Search -->
          <div class="glass flex-1 flex items-center h-10 min-h-[2.5rem]">
            <svg class="ml-3 w-4 h-4 text-gray-400 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
            </svg>
            <input
              v-model="searchText"
              type="text"
              placeholder="Search..."
              class="flex-1 h-full px-2 text-sm bg-transparent text-gray-900 dark:text-gray-100 placeholder-gray-400 focus:outline-none"
            />
            <button
              v-if="searchText"
              @click="clearSearch"
              class="mr-3 text-gray-400 hover:text-gray-600 dark:hover:text-gray-300"
            >
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
          </div>

          <!-- Filter and Sort row -->
          <div class="flex items-center gap-3">
            <!-- Filter toggles -->
            <div class="glass flex items-center h-10 p-1">
              <button
                v-for="f in ['all', 'published', 'draft']"
                :key="f"
                @click="filter = f"
                :class="[
                  'px-3 h-full text-sm font-medium rounded-lg transition-all flex items-center',
                  filter === f
                    ? 'bg-white/80 dark:bg-white/20 text-gray-900 dark:text-white shadow-sm'
                    : 'text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-300'
                ]"
              >
                {{ f.charAt(0).toUpperCase() + f.slice(1) }}
              </button>
            </div>

            <!-- Sort dropdown -->
            <div class="glass relative h-10 flex items-center flex-1">
              <select
                v-model="sortOption"
                class="appearance-none w-full h-full pl-3 pr-8 text-sm font-medium bg-transparent text-gray-700 dark:text-gray-300 focus:outline-none cursor-pointer"
              >
                <option v-for="opt in sortOptions" :key="opt.value" :value="opt.value">
                  {{ opt.label }}
                </option>
              </select>
              <svg class="absolute right-2.5 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400 pointer-events-none" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
              </svg>
            </div>
          </div>
        </div>
      </template>
    </PageToolbar>

    <div class="px-6 pb-8">

    <p v-if="searchText && !effectiveSearchText" class="text-sm text-gray-500 dark:text-gray-400 mb-4">
      Type {{ MIN_SEARCH_LENGTH - searchText.length }} more character{{ MIN_SEARCH_LENGTH - searchText.length > 1 ? 's' : '' }} to search
    </p>

    <!-- Empty State -->
    <div v-if="blogStore.posts.length === 0" class="text-center py-20">
      <p class="text-gray-400 dark:text-gray-500 mb-4">
        {{ searchText ? 'No posts match your search.' : 'No posts yet.' }}
      </p>
      <router-link
        v-if="!searchText"
        :to="{ name: 'post-create', params: { blogId } }"
        class="text-primary-600 dark:text-primary-400 font-medium hover:text-primary-700 dark:hover:text-primary-300"
      >
        Create your first post
      </router-link>
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
        v-for="post in blogStore.posts"
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
          <!-- Category & Tags -->
          <span v-if="post.category" class="text-primary-600 dark:text-primary-400">
            {{ post.category.name }}
          </span>
          <template v-if="post.tags?.length > 0">
            <span v-for="tag in post.tags?.slice(0, 3)" :key="tag.id" class="text-gray-400 dark:text-gray-500">
              #{{ tag.name }}
            </span>
            <span v-if="post.tags?.length > 3" class="text-gray-400 dark:text-gray-500">
              +{{ post.tags.length - 3 }}
            </span>
          </template>
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
  </div>
</template>
