<script setup>
import { computed } from 'vue';
import { useRoute } from 'vue-router';
import { useBlogStore } from '@/stores/blog';
import SyncBadge from '@/components/SyncBadge.vue';

const props = defineProps({
  blogId: { type: String, required: true }
});

const emit = defineEmits(['deploy', 'close-mobile']);

const route = useRoute();
const blogStore = useBlogStore();

const isPostsRoute = computed(() => route.name === 'blog-posts');

const navLinks = [
  { name: 'Posts', route: 'blog-posts' },
  { name: 'Settings', route: 'blog-settings' },
  { name: 'Categories', route: 'categories' },
  { name: 'Tags', route: 'tags' },
  { name: 'Sidebar', route: 'sidebar' },
  { name: 'Files', route: 'files' },
  { name: 'Themes', route: 'themes' },
  { name: 'Publishing', route: 'publish-settings' }
];

const postCounts = computed(() => ({
  published: blogStore.postsPublishedCount,
  drafts: blogStore.postsDraftCount
}));

function handleNavClick() {
  emit('close-mobile');
}

function handleDeploy() {
  emit('deploy');
  emit('close-mobile');
}
</script>

<template>
  <aside class="sidebar">
    <!-- Search (posts route only) -->
    <div v-if="isPostsRoute" class="sidebar-section sidebar-search">
      <div class="relative">
        <input
          v-model="blogStore.searchText"
          type="text"
          placeholder="Search posts..."
        />
        <button
          v-if="blogStore.searchText"
          @click="blogStore.clearSearch()"
          class="absolute right-2 top-1/2 -translate-y-1/2 text-[var(--admin-medium)] hover:text-[var(--admin-text)] bg-transparent border-none cursor-pointer text-lg leading-none"
        >
          &times;
        </button>
      </div>
    </div>

    <!-- Deploy -->
    <div class="sidebar-section">
      <button
        @click="handleDeploy"
        class="w-full px-4 py-2 bg-site-accent text-white font-semibold rounded-full hover:bg-[#e89200] transition-colors text-center"
      >
        Deploy
      </button>
      <div class="mt-2 flex justify-center">
        <SyncBadge />
      </div>
    </div>

    <!-- Stats -->
    <div class="sidebar-section">
      <h2>Stats</h2>
      <div class="sidebar-stats">
        {{ postCounts.published }} published<span v-if="postCounts.drafts > 0"> / {{ postCounts.drafts }} drafts</span>
      </div>
    </div>

    <!-- Navigation -->
    <div class="sidebar-section">
      <nav class="sidebar-nav">
        <ul>
          <li v-for="link in navLinks" :key="link.route">
            <router-link
              :to="{ name: link.route, params: { blogId } }"
              @click="handleNavClick"
            >
              {{ link.name }}
            </router-link>
          </li>
        </ul>
      </nav>
    </div>
  </aside>
</template>
