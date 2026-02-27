<script setup>
import { ref, computed, watch, onMounted, onBeforeUnmount } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useBlogStore } from '@/stores/blog';
import { marked } from 'marked';

const route = useRoute();
const router = useRouter();
const blogStore = useBlogStore();

const POSTS_PER_PAGE = 10;
let searchTimeout = null;

const blogId = computed(() => route.params.blogId);

const MIN_SEARCH_LENGTH = 2;

// Fetch posts when search changes (with debounce)
watch(() => blogStore.searchText, () => {
  if (searchTimeout) clearTimeout(searchTimeout);
  searchTimeout = setTimeout(() => {
    fetchPosts();
  }, 300);
});

onMounted(() => {
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
  return blogStore.searchText.length >= MIN_SEARCH_LENGTH ? blogStore.searchText : '';
});

async function fetchPosts() {
  await blogStore.fetchPosts(blogId.value, {
    status: 'all',
    search: effectiveSearchText.value,
    sort: 'date_desc',
    limit: POSTS_PER_PAGE
  });
}

const hasMorePosts = computed(() => blogStore.postsHasMore);

const remainingPostsCount = computed(() => {
  return blogStore.postsTotal - blogStore.posts.length;
});

async function loadMorePosts() {
  await blogStore.loadMorePosts(blogId.value, {
    status: 'all',
    search: effectiveSearchText.value,
    sort: 'date_desc',
    limit: POSTS_PER_PAGE
  });
}

function navigateToPost(postId) {
  router.push({ name: 'post-edit', params: { blogId: blogId.value, postId } });
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

function getYouTubeThumbSrc(embed) {
  if (embed.imageFilename) return `/uploads/${blogId.value}/${embed.imageFilename}`;
  const vid = getYouTubeVideoId(embed);
  if (vid) return `https://img.youtube.com/vi/${vid}/hqdefault.jpg`;
  return null;
}

const activeYouTubePostIds = ref(new Set());

function activateYouTube(postId) {
  activeYouTubePostIds.value = new Set([...activeYouTubePostIds.value, postId]);
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
    <!-- Search + New Post -->
    <div class="mb-8">
      <div class="flex items-center gap-4">
        <div class="relative flex-1">
          <input
            v-model="blogStore.searchText"
            type="text"
            placeholder="Search posts..."
            class="admin-input"
          />
          <button
            v-if="blogStore.searchText"
            @click="blogStore.clearSearch()"
            class="absolute right-2 top-1/2 -translate-y-1/2 text-site-medium hover:text-site-text bg-transparent border-none cursor-pointer text-lg leading-none"
          >
            &times;
          </button>
        </div>
        <router-link
          :to="{ name: 'post-create', params: { blogId } }"
          class="h-10 px-3 font-mono text-sm uppercase tracking-wider bg-site-accent text-white hover:bg-[#e89200] transition-colors whitespace-nowrap inline-flex items-center"
        >
          New Post
        </router-link>
      </div>

      <p v-if="blogStore.searchText && !effectiveSearchText" class="mt-2 text-[0.8em] text-site-medium">
        Type {{ MIN_SEARCH_LENGTH - blogStore.searchText.length }} more character{{ MIN_SEARCH_LENGTH - blogStore.searchText.length > 1 ? 's' : '' }} to search
      </p>
    </div>

    <!-- Empty State -->
    <div v-if="blogStore.posts.length === 0" class="py-24 text-center">
      <p class="text-[1.2rem] font-bold text-site-dark mb-2">
        {{ blogStore.searchText ? 'No posts match your search' : 'No posts yet' }}
      </p>
      <router-link
        v-if="!blogStore.searchText"
        :to="{ name: 'post-create', params: { blogId } }"
        class="inline-block mt-4 px-5 py-2 bg-site-accent text-white font-semibold rounded-full hover:bg-[#e89200] transition-colors"
      >
        Create your first post
      </router-link>
      <button
        v-else
        @click="blogStore.clearSearch()"
        class="inline-block mt-4 text-site-accent hover:underline"
      >
        Clear search &rarr;
      </button>
    </div>

    <!-- Posts List -->
    <div v-else>
      <template v-for="(post, index) in blogStore.posts" :key="post.id">
        <article
          class="group cursor-pointer"
          @click="navigateToPost(post.id)"
        >
          <!-- Post title -->
          <h2 v-if="post.title" class="font-bold text-site-dark leading-snug group-hover:text-site-accent transition-colors">
            {{ post.title }}
          </h2>

          <!-- Post date -->
          <div class="text-[0.9em] text-site-medium mt-1">
            {{ formatLocalDateTime(post.createdAt) }}
            <span
              v-if="post.isDraft"
              class="ml-2 text-site-accent font-semibold"
            >
              Draft
            </span>
          </div>

          <!-- Embed (above position) -->
          <div v-if="post.embed && post.embed.position === 'above'" class="mt-[1.5em]">
            <!-- YouTube -->
            <div v-if="post.embed.type === 'youtube' && getYouTubeVideoId(post.embed)" class="aspect-video max-h-96">
              <iframe
                v-if="activeYouTubePostIds.has(post.id)"
                :src="`https://www.youtube.com/embed/${getYouTubeVideoId(post.embed)}?autoplay=1`"
                class="w-full h-full"
                frameborder="0"
                allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
                allowfullscreen
              ></iframe>
              <div v-else class="relative w-full h-full cursor-pointer" @click.stop="activateYouTube(post.id)">
                <img
                  v-if="getYouTubeThumbSrc(post.embed)"
                  :src="getYouTubeThumbSrc(post.embed)"
                  class="w-full h-full object-cover"
                  alt=""
                />
                <div class="absolute inset-0 flex items-center justify-center">
                  <svg class="w-16 h-auto drop-shadow-lg" viewBox="0 0 28.57 20" xmlns="http://www.w3.org/2000/svg">
                    <path d="M27.9727 3.12324C27.6435 1.89323 26.6768 0.926623 25.4468 0.597366C23.2197 0 14.285 0 14.285 0S5.35042 0 3.12323 0.597366C1.89323 0.926623 0.926623 1.89323 0.597366 3.12324 0 5.35042 0 10 0 10S0 14.6496 0.597366 16.8768C0.926623 18.1068 1.89323 19.0734 3.12323 19.4026 5.35042 20 14.285 20 14.285 20S23.2197 20 25.4468 19.4026C26.6768 19.0734 27.6435 18.1068 27.9727 16.8768 28.5701 14.6496 28.5701 10 28.5701 10S28.5677 5.35042 27.9727 3.12324Z" fill="#FF0000"/>
                    <path d="M11.4253 14.2854L18.8477 10.0004 11.4253 5.71533V14.2854Z" fill="white"/>
                  </svg>
                </div>
              </div>
            </div>

            <!-- Link -->
            <a
              v-else-if="post.embed.type === 'link'"
              :href="post.embed.url"
              @click.stop
              target="_blank"
              rel="noopener noreferrer"
              class="flex gap-4 max-w-xl border border-site-light p-3 hover:border-site-accent transition-colors"
            >
              <img
                v-if="getLinkEmbedImageSrc(post.embed)"
                :src="getLinkEmbedImageSrc(post.embed)"
                class="w-20 h-20 object-cover shrink-0"
                alt=""
              />
              <div class="flex-1 min-w-0">
                <p v-if="post.embed.title" class="font-medium text-site-dark line-clamp-2">{{ post.embed.title }}</p>
                <p v-if="post.embed.description" class="text-[0.9em] text-site-medium line-clamp-2 mt-1">{{ post.embed.description }}</p>
                <p class="text-[0.8em] text-site-medium mt-2 truncate">{{ post.embed.url }}</p>
              </div>
            </a>

            <!-- Image -->
            <div v-else-if="post.embed.type === 'image' && post.embed.images?.length > 0">
              <img
                :src="getEmbedImageUrl(post.embed.images[0]?.filename)"
                class="max-w-full max-h-96 object-contain"
                alt=""
              />
              <p v-if="post.embed.images.length > 1" class="text-[0.8em] text-site-medium mt-2">
                +{{ post.embed.images.length - 1 }} more
              </p>
            </div>
          </div>

          <!-- Content -->
          <div
            v-if="post.content"
            class="mt-[1.5em] prose max-w-none leading-[1.8]"
            v-html="renderMarkdown(post.content)"
          ></div>

          <!-- Embed (below position) -->
          <div v-if="post.embed && post.embed.position === 'below'" class="mt-[1.5em]">
            <!-- YouTube -->
            <div v-if="post.embed.type === 'youtube' && getYouTubeVideoId(post.embed)" class="aspect-video max-h-96">
              <iframe
                v-if="activeYouTubePostIds.has(post.id)"
                :src="`https://www.youtube.com/embed/${getYouTubeVideoId(post.embed)}?autoplay=1`"
                class="w-full h-full"
                frameborder="0"
                allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
                allowfullscreen
              ></iframe>
              <div v-else class="relative w-full h-full cursor-pointer" @click.stop="activateYouTube(post.id)">
                <img
                  v-if="getYouTubeThumbSrc(post.embed)"
                  :src="getYouTubeThumbSrc(post.embed)"
                  class="w-full h-full object-cover"
                  alt=""
                />
                <div class="absolute inset-0 flex items-center justify-center">
                  <svg class="w-16 h-auto drop-shadow-lg" viewBox="0 0 28.57 20" xmlns="http://www.w3.org/2000/svg">
                    <path d="M27.9727 3.12324C27.6435 1.89323 26.6768 0.926623 25.4468 0.597366C23.2197 0 14.285 0 14.285 0S5.35042 0 3.12323 0.597366C1.89323 0.926623 0.926623 1.89323 0.597366 3.12324 0 5.35042 0 10 0 10S0 14.6496 0.597366 16.8768C0.926623 18.1068 1.89323 19.0734 3.12323 19.4026 5.35042 20 14.285 20 14.285 20S23.2197 20 25.4468 19.4026C26.6768 19.0734 27.6435 18.1068 27.9727 16.8768 28.5701 14.6496 28.5701 10 28.5701 10S28.5677 5.35042 27.9727 3.12324Z" fill="#FF0000"/>
                    <path d="M11.4253 14.2854L18.8477 10.0004 11.4253 5.71533V14.2854Z" fill="white"/>
                  </svg>
                </div>
              </div>
            </div>

            <!-- Link -->
            <a
              v-else-if="post.embed.type === 'link'"
              :href="post.embed.url"
              @click.stop
              target="_blank"
              rel="noopener noreferrer"
              class="flex gap-4 max-w-xl border border-site-light p-3 hover:border-site-accent transition-colors"
            >
              <img
                v-if="getLinkEmbedImageSrc(post.embed)"
                :src="getLinkEmbedImageSrc(post.embed)"
                class="w-20 h-20 object-cover shrink-0"
                alt=""
              />
              <div class="flex-1 min-w-0">
                <p v-if="post.embed.title" class="font-medium text-site-dark line-clamp-2">{{ post.embed.title }}</p>
                <p v-if="post.embed.description" class="text-[0.9em] text-site-medium line-clamp-2 mt-1">{{ post.embed.description }}</p>
                <p class="text-[0.8em] text-site-medium mt-2 truncate">{{ post.embed.url }}</p>
              </div>
            </a>

            <!-- Image -->
            <div v-else-if="post.embed.type === 'image' && post.embed.images?.length > 0">
              <img
                :src="getEmbedImageUrl(post.embed.images[0]?.filename)"
                class="max-w-full max-h-96 object-contain"
                alt=""
              />
              <p v-if="post.embed.images.length > 1" class="text-[0.8em] text-site-medium mt-2">
                +{{ post.embed.images.length - 1 }} more
              </p>
            </div>
          </div>

          <!-- Tags & Category -->
          <div v-if="post.category || post.tags?.length > 0" class="mt-[3em] text-[0.6em] flex flex-wrap items-center gap-2">
            <span v-if="post.category" class="inline-block text-white bg-site-accent border border-site-accent px-2 py-0.5 rounded-full hover:bg-site-bg hover:text-site-accent transition-colors">
              {{ post.category.name }}
            </span>
            <template v-if="post.tags?.length > 0">
              <span v-for="tag in post.tags?.slice(0, 3)" :key="tag.id" class="inline-block text-site-accent bg-site-bg border border-site-accent px-2 py-0.5 rounded-full hover:bg-site-accent hover:text-white transition-colors">
                #{{ tag.name }}
              </span>
              <span v-if="post.tags?.length > 3" class="text-site-medium">
                +{{ post.tags.length - 3 }}
              </span>
            </template>
          </div>
        </article>

        <!-- Wavy separator -->
        <div class="wavy-separator my-[3em]"></div>
      </template>
    </div>

    <!-- Load More -->
    <div v-if="hasMorePosts" class="py-8 text-center">
      <button
        @click="loadMorePosts"
        :disabled="blogStore.loading"
        class="text-site-accent hover:underline disabled:opacity-50"
      >
        <template v-if="blogStore.loading">Loading...</template>
        <template v-else>Load more ({{ remainingPostsCount }}) &darr;</template>
      </button>
    </div>
  </div>
</template>
