<script setup>
import { ref, onMounted, onUnmounted, watch, computed } from 'vue';
import { useRoute } from 'vue-router';
import { useBlogStore } from '@/stores/blog';
import AdminSidebar from '@/components/AdminSidebar.vue';
import PublishModal from '@/components/PublishModal.vue';

const route = useRoute();
const blogStore = useBlogStore();

const blogId = computed(() => route.params.blogId);
const isFullWidthRoute = computed(() => route.meta.fullWidth === true);

const sidebarOpen = ref(false);
const showPublishModal = ref(false);

function toggleSidebar() {
  sidebarOpen.value = !sidebarOpen.value;
}

function closeSidebar() {
  sidebarOpen.value = false;
}

function handleResize() {
  if (window.innerWidth > 900 && sidebarOpen.value) {
    sidebarOpen.value = false;
  }
}

onMounted(async () => {
  window.addEventListener('resize', handleResize);
  await loadBlogData();
});

onUnmounted(() => {
  window.removeEventListener('resize', handleResize);
});

watch(blogId, async (newId, oldId) => {
  if (oldId) blogStore.clearBlogData();
  await loadBlogData();
});

// Close sidebar on route change (mobile nav)
watch(() => route.name, () => {
  sidebarOpen.value = false;
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
  <div
    v-else
    class="admin-container"
    :class="{ 'sidebar-open': sidebarOpen }"
  >
    <!-- Top Toolbar -->
    <div class="admin-toolbar">
      <router-link to="/" class="toolbar-back">&larr; All Blogs</router-link>
      <div class="toolbar-actions">
        <button
          @click="showPublishModal = true"
          class="px-4 py-1.5 bg-site-accent text-white font-semibold rounded-full hover:bg-[#e89200] transition-colors text-sm"
        >
          Deploy
        </button>
        <router-link
          :to="{ name: 'post-create', params: { blogId } }"
          class="px-4 py-1.5 bg-site-accent text-white font-semibold rounded-full hover:bg-[#e89200] transition-colors text-sm"
        >
          + New Post
        </router-link>
      </div>
    </div>

    <!-- Header -->
    <header class="admin-header">
      <button class="hamburger-menu" @click="toggleSidebar">
        <div class="hamburger-icon">
          <span></span>
          <span></span>
          <span></span>
        </div>
      </button>
      <h1>
        <router-link :to="{ name: 'blog-posts', params: { blogId } }">
          {{ blogStore.currentBlog?.name }}
        </router-link>
      </h1>
      <p v-if="blogStore.currentBlog?.tagline" class="tagline">
        {{ blogStore.currentBlog.tagline }}
      </p>
      <div class="header-separator"></div>
    </header>

    <!-- Content Wrapper -->
    <div class="content-wrapper">
      <div class="mobile-sidebar-overlay" @click="closeSidebar"></div>
      <AdminSidebar
        :blog-id="blogId"
        @close-mobile="closeSidebar"
      />
      <main>
        <router-view />
      </main>
      <div class="clearfix"></div>
    </div>

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
