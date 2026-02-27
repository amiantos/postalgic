<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useBlogStore } from '@/stores/blog';
import PublishModal from '@/components/PublishModal.vue';

const route = useRoute();
const router = useRouter();
const blogStore = useBlogStore();

const blogId = computed(() => route.params.blogId);
const isFullWidthRoute = computed(() => route.meta.fullWidth === true);

const showPublishModal = ref(false);

const navLinks = [
  { name: 'Posts', route: 'blog-posts' },
  { name: 'Metadata', route: 'blog-settings' },
  { name: 'Categories', route: 'categories' },
  { name: 'Tags', route: 'tags' },
  { name: 'Sidebar', route: 'sidebar' },
  { name: 'Files', route: 'files' },
  { name: 'Themes', route: 'themes' },
  { name: 'Publishing', route: 'publish-settings' }
];

const currentRouteName = computed(() => route.name);

function onNavSelect(event) {
  router.push({ name: event.target.value, params: { blogId: blogId.value } });
}

onMounted(async () => {
  await loadBlogData();
});

watch(blogId, async (newId, oldId) => {
  if (oldId) blogStore.clearBlogData();
  await loadBlogData();
});

async function loadBlogData() {
  await blogStore.fetchBlog(blogId.value);
  blogStore.fetchCategories(blogId.value);
  blogStore.fetchTags(blogId.value);
}
</script>

<template>
  <!-- Full-width mode: no shell, just render child -->
  <div v-if="isFullWidthRoute" class="min-h-screen">
    <router-view />
  </div>

  <!-- Normal mode: layout shell mirroring the blog template -->
  <div v-else class="admin-container">
    <!-- Top Toolbar -->
    <div class="admin-toolbar">
      <router-link to="/" class="toolbar-back">&larr; All Blogs</router-link>
      <h1 v-if="blogStore.currentBlog?.name" class="toolbar-title">
        <router-link :to="{ name: 'blog-posts', params: { blogId } }">
          {{ blogStore.currentBlog.name }}
        </router-link>
      </h1>
      <div class="toolbar-actions">
        <button
          @click="showPublishModal = true"
          class="h-10 px-3 font-mono text-sm uppercase tracking-wider bg-site-accent text-white hover:bg-[#e89200] transition-colors"
        >
          Deploy
        </button>
      </div>
    </div>

    <!-- Wavy Separator -->
    <div class="wavy-separator"></div>

    <!-- Main Content -->
    <main>
      <!-- Horizontal Nav (desktop) -->
      <nav class="admin-nav-links">
        <router-link
          v-for="link in navLinks"
          :key="link.route"
          :to="{ name: link.route, params: { blogId } }"
        >
          {{ link.name }}
        </router-link>
      </nav>

      <!-- Nav Dropdown (mobile) -->
      <div class="admin-nav-select">
        <select
          :value="currentRouteName"
          @change="onNavSelect"
          class="admin-input"
        >
          <option
            v-for="link in navLinks"
            :key="link.route"
            :value="link.route"
          >
            {{ link.name }}
          </option>
        </select>
      </div>

      <router-view />
    </main>

    <!-- Footer -->
    <footer class="admin-footer">
      <p>Powered by <a href="https://postalgic.app" target="_blank" rel="noopener">Postalgic</a></p>
    </footer>

    <!-- Publish Modal -->
    <PublishModal
      v-if="showPublishModal"
      :blog-id="blogId"
      :show="showPublishModal"
      @close="showPublishModal = false"
    />
  </div>
</template>
