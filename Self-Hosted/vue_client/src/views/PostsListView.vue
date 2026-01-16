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

const showPublishModal = ref(false);
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
    <!-- Right edge fade - covers overflow on desktop (light mode) -->
    <div
      class="hidden lg:block dark:lg:hidden fixed right-0 top-0 h-full z-10 w-24"
      style="background: linear-gradient(to right, transparent, white);"
    ></div>
    <!-- Right edge fade - covers overflow on desktop (dark mode) -->
    <div
      class="hidden dark:lg:block fixed right-0 top-0 h-full z-10 w-24"
      style="background: linear-gradient(to right, transparent, black);"
    ></div>

    <!-- Max-width content wrapper for desktop -->
    <div class="lg:max-w-[700px] lg:ml-8">

    <!-- Navigation bar -->
    <nav class="flex items-center justify-between px-6 py-4 lg:px-0">
      <router-link to="/" class="px-3 py-1.5 border-2 border-retro-gray-light dark:border-retro-gray-darker bg-white dark:bg-black font-retro-mono text-retro-sm text-retro-gray-dark dark:text-retro-gray-medium hover:border-retro-orange hover:text-retro-orange uppercase tracking-wider">
        <span class="relative -top-px">&lt;</span> All Blogs
      </router-link>

      <div class="flex items-center gap-2">
        <SyncBadge />
        <router-link
          :to="{ name: 'post-create', params: { blogId } }"
          class="px-3 py-1.5 border-2 border-retro-gray-light dark:border-retro-gray-darker bg-white dark:bg-black font-retro-mono text-retro-sm text-retro-gray-dark dark:text-retro-gray-medium hover:border-retro-orange hover:text-retro-orange uppercase tracking-wider"
        >
          <span class="relative -top-px">+</span> New Post
        </router-link>
        <button
          @click="showPublishModal = true"
          class="px-3 py-1.5 border-2 border-retro-gray-light dark:border-retro-gray-darker bg-white dark:bg-black font-retro-mono text-retro-sm text-retro-gray-dark dark:text-retro-gray-medium hover:border-retro-orange hover:text-retro-orange uppercase tracking-wider"
        >
          Deploy
        </button>
        <router-link
          :to="{ name: 'blog-settings', params: { blogId } }"
          class="px-3 py-1.5 border-2 border-retro-gray-light dark:border-retro-gray-darker bg-white dark:bg-black font-retro-mono text-retro-sm text-retro-gray-dark dark:text-retro-gray-medium hover:border-retro-orange hover:text-retro-orange uppercase tracking-wider"
        >
          Settings
        </router-link>
      </div>
    </nav>

    <!-- Hero section with giant blog name -->
    <header class="relative h-52 md:h-60">
      <!-- Divider with left padding -->
      <div class="absolute bottom-0 left-6 right-0 border-b border-retro-gray-light dark:border-retro-gray-darker lg:left-0 lg:-right-[100vw]"></div>
      <!-- Giant background text - uppercase, vertically centered for equal spacing -->
      <span class="absolute inset-0 flex items-center justify-start font-retro-serif font-bold text-[10rem] md:text-[14rem] leading-none tracking-tighter text-retro-gray-lightest dark:text-[#1a1a1a] select-none pointer-events-none whitespace-nowrap uppercase" aria-hidden="true">
        {{ blogStore.currentBlog?.name }}
      </span>
      <!-- Foreground content - positioned lower -->
      <div class="absolute bottom-4 left-6 lg:left-0">
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
    <div class="relative px-6 py-4 lg:px-0">
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
      <div v-if="blogStore.posts.length === 0" class="py-24 px-6 lg:px-0">
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
          class="group cursor-pointer relative ml-6 lg:ml-0 pt-6 pb-6"
          @click="navigateToPost(post.id)"
        >
          <!-- Divider that extends to the right -->
          <div class="absolute bottom-0 left-0 right-0 border-b border-retro-gray-light dark:border-retro-gray-darker lg:-right-[100vw]"></div>
          <!-- Giant background text - post title uppercase -->
          <span class="absolute top-6 left-0 h-24 md:h-32 flex items-center font-retro-serif font-bold text-[6rem] md:text-[8rem] leading-none tracking-tighter text-retro-gray-lightest dark:text-[#1a1a1a] select-none pointer-events-none whitespace-nowrap uppercase" aria-hidden="true">
            {{ post.title || post.content?.replace(/[#*_`>\[\]]/g, '').substring(0, 200) || 'UNTITLED' }}
          </span>

          <!-- Foreground content - flows naturally with padding -->
          <div class="relative pt-16 md:pt-20 pb-4">
            <!-- Post title -->
            <h2 class="font-retro-serif font-bold text-3xl md:text-4xl leading-none tracking-tight text-retro-gray-darker dark:text-retro-cream group-hover:text-retro-orange transition-colors lowercase whitespace-nowrap">
              {{ post.title || post.content?.replace(/[#*_`>\[\]]/g, '').substring(0, 200) || 'untitled' }}
            </h2>

            <!-- Meta line -->
            <div class="mt-2 flex flex-wrap items-center gap-x-4 gap-y-1 pr-6 lg:pr-0">
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
            </div>

            <!-- Embed (above position) -->
            <div v-if="post.embed && post.embed.position === 'above'" class="mt-4 pr-6 lg:pr-0">
              <!-- YouTube -->
              <div v-if="post.embed.type === 'youtube' && getYouTubeVideoId(post.embed)" class="aspect-video max-h-96 border-2 border-retro-gray-light dark:border-retro-gray-darker">
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
                class="flex gap-4 max-w-xl border-2 border-retro-gray-light dark:border-retro-gray-darker p-3 hover:border-retro-orange transition-colors"
              >
                <img
                  v-if="getLinkEmbedImageSrc(post.embed)"
                  :src="getLinkEmbedImageSrc(post.embed)"
                  class="w-20 h-20 object-cover shrink-0"
                  alt=""
                />
                <div class="flex-1 min-w-0">
                  <p v-if="post.embed.title" class="font-retro-sans text-retro-sm font-medium text-retro-gray-darker dark:text-retro-cream line-clamp-2">{{ post.embed.title }}</p>
                  <p v-if="post.embed.description" class="font-retro-sans text-retro-xs text-retro-gray-dark dark:text-retro-gray-medium line-clamp-2 mt-1">{{ post.embed.description }}</p>
                  <p class="font-retro-mono text-retro-xs text-retro-gray-medium mt-2 truncate">{{ post.embed.url }}</p>
                </div>
              </a>

              <!-- Image -->
              <div v-else-if="post.embed.type === 'image' && post.embed.images?.length > 0">
                <img
                  :src="getEmbedImageUrl(post.embed.images[0]?.filename)"
                  class="max-w-full max-h-96 object-contain border-2 border-retro-gray-light dark:border-retro-gray-darker"
                  alt=""
                />
                <p v-if="post.embed.images.length > 1" class="font-retro-mono text-retro-xs text-retro-gray-medium mt-2">
                  +{{ post.embed.images.length - 1 }} more
                </p>
              </div>
            </div>

            <!-- Content -->
            <div
              v-if="post.content"
              class="mt-4 pr-6 lg:pr-0 prose prose-sm dark:prose-invert prose-gray max-w-3xl font-retro-sans text-retro-sm"
              v-html="renderMarkdown(post.content)"
            ></div>

            <!-- Embed (below position) -->
            <div v-if="post.embed && post.embed.position === 'below'" class="mt-4 pr-6 lg:pr-0">
              <!-- YouTube -->
              <div v-if="post.embed.type === 'youtube' && getYouTubeVideoId(post.embed)" class="aspect-video max-h-96 border-2 border-retro-gray-light dark:border-retro-gray-darker">
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
                class="flex gap-4 max-w-xl border-2 border-retro-gray-light dark:border-retro-gray-darker p-3 hover:border-retro-orange transition-colors"
              >
                <img
                  v-if="getLinkEmbedImageSrc(post.embed)"
                  :src="getLinkEmbedImageSrc(post.embed)"
                  class="w-20 h-20 object-cover shrink-0"
                  alt=""
                />
                <div class="flex-1 min-w-0">
                  <p v-if="post.embed.title" class="font-retro-sans text-retro-sm font-medium text-retro-gray-darker dark:text-retro-cream line-clamp-2">{{ post.embed.title }}</p>
                  <p v-if="post.embed.description" class="font-retro-sans text-retro-xs text-retro-gray-dark dark:text-retro-gray-medium line-clamp-2 mt-1">{{ post.embed.description }}</p>
                  <p class="font-retro-mono text-retro-xs text-retro-gray-medium mt-2 truncate">{{ post.embed.url }}</p>
                </div>
              </a>

              <!-- Image -->
              <div v-else-if="post.embed.type === 'image' && post.embed.images?.length > 0">
                <img
                  :src="getEmbedImageUrl(post.embed.images[0]?.filename)"
                  class="max-w-full max-h-96 object-contain border-2 border-retro-gray-light dark:border-retro-gray-darker"
                  alt=""
                />
                <p v-if="post.embed.images.length > 1" class="font-retro-mono text-retro-xs text-retro-gray-medium mt-2">
                  +{{ post.embed.images.length - 1 }} more
                </p>
              </div>
            </div>
          </div>
        </article>
      </div>

      <!-- Load More -->
      <div v-if="hasMorePosts" class="py-8 px-6 lg:px-0">
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

    </div><!-- End max-width wrapper -->

    <!-- Publish Modal -->
    <PublishModal
      v-if="showPublishModal"
      :blog-id="blogId"
      :show="showPublishModal"
      @close="showPublishModal = false"
    />
  </div>
</template>
