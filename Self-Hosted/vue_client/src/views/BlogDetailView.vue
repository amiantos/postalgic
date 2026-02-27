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

// Clear blog data SYNCHRONOUSLY during setup to prevent stale data from
// being rendered by child components before onMounted completes
blogStore.clearBlogData();

onMounted(async () => {
  window.addEventListener('resize', handleResize);
  await loadBlogData();
});

onUnmounted(() => {
  window.removeEventListener('resize', handleResize);
});

watch(blogId, async () => {
  // Also clear synchronously when blogId changes (component reuse)
  blogStore.clearBlogData();
  await loadBlogData();
});

// Close sidebar on route change (mobile nav)
watch(() => route.name, () => {
  sidebarOpen.value = false;
});

async function loadBlogData() {
  await blogStore.fetchBlog(blogId.value);
  await Promise.all([
    blogStore.fetchPosts(blogId.value),
    blogStore.fetchCategories(blogId.value),
    blogStore.fetchTags(blogId.value)
  ]);
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
    <!-- Header -->
    <header class="admin-header">
      <button class="hamburger-menu" @click="toggleSidebar">
        <div class="hamburger-icon">
          <span></span>
          <span></span>
          <span></span>
        </div>
      </button>
      <nav class="back-nav">
        <router-link to="/">&larr; All Blogs</router-link>
      </nav>
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
        @deploy="showPublishModal = true"
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
