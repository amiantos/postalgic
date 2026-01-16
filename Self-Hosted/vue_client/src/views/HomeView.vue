<script setup>
import { ref, onMounted, watch } from 'vue';
import { useRouter } from 'vue-router';
import { useBlogStore } from '@/stores/blog';
import { blogApi } from '@/api';

const router = useRouter();
const blogStore = useBlogStore();

const showDeleteModal = ref(false);
const blogToDelete = ref(null);

// Analytics state
const analyticsData = ref({});

onMounted(() => {
  blogStore.fetchBlogs();
});

// Fetch analytics for blogs that have it enabled
async function fetchBlogAnalytics(blog) {
  if (!blog.simpleAnalyticsEnabled) return;

  try {
    const data = await blogApi.analytics(blog.id);
    analyticsData.value[blog.id] = data;
  } catch (e) {
    // Silently fail - just won't show analytics
  }
}

// Watch for blogs to load and fetch analytics
watch(() => blogStore.blogs, (blogs) => {
  for (const blog of blogs) {
    if (blog.simpleAnalyticsEnabled && !analyticsData.value[blog.id]) {
      fetchBlogAnalytics(blog);
    }
  }
}, { immediate: true });

function navigateToBlog(blogId) {
  router.push({ name: 'blog-posts', params: { blogId } });
}

function confirmDelete(blog) {
  blogToDelete.value = blog;
  showDeleteModal.value = true;
}

async function deleteBlog() {
  if (blogToDelete.value) {
    await blogStore.deleteBlog(blogToDelete.value.id);
    showDeleteModal.value = false;
    blogToDelete.value = null;
  }
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
    <div class="lg:max-w-[700px] lg:mx-auto">

    <!-- Navigation bar -->
    <nav class="flex items-center justify-start px-6 py-4 lg:px-0">
      <div class="flex items-center gap-2">
        <span class="relative group px-3 py-1.5 border-2 border-retro-gray-light dark:border-retro-gray-darker bg-white dark:bg-black font-retro-mono text-retro-sm text-retro-gray-dark dark:text-retro-gray-medium hover:border-retro-orange hover:text-retro-orange uppercase tracking-wider cursor-pointer">
          <span class="relative -top-px">+</span> New Blog
          <span class="absolute right-0 top-full hidden group-hover:block z-20 pt-1">
            <span class="block bg-white dark:bg-black border-2 border-retro-gray-light dark:border-retro-gray-darker min-w-[160px]">
              <router-link to="/blogs/new" class="block px-3 py-2 font-retro-mono text-retro-sm text-retro-gray-darker dark:text-retro-gray-light hover:bg-retro-orange hover:text-white">
                New Blog
              </router-link>
              <router-link to="/blogs/import" class="block px-3 py-2 font-retro-mono text-retro-sm text-retro-gray-darker dark:text-retro-gray-light hover:bg-retro-orange hover:text-white">
                Import from ZIP
              </router-link>
              <router-link to="/blogs/import-from-url" class="block px-3 py-2 font-retro-mono text-retro-sm text-retro-gray-darker dark:text-retro-gray-light hover:bg-retro-orange hover:text-white">
                Import from URL
              </router-link>
            </span>
          </span>
        </span>
      </div>
    </nav>

    <!-- Hero section with giant YOUR BLOGS -->
    <header class="relative h-52 md:h-60">
      <!-- Divider that extends to the right -->
      <div class="absolute bottom-0 left-6 right-0 border-b border-retro-gray-light dark:border-retro-gray-darker lg:left-0 lg:-right-[100vw]"></div>
      <!-- Giant background text - uppercase, vertically centered for equal spacing -->
      <span class="absolute inset-0 flex items-center justify-start font-retro-serif font-bold text-[10rem] md:text-[14rem] leading-none tracking-tighter text-retro-gray-lightest dark:text-[#1a1a1a] select-none pointer-events-none whitespace-nowrap" aria-hidden="true">
        YOUR BLOGS
      </span>
      <!-- Foreground content - positioned lower -->
      <div class="absolute bottom-4 left-6 lg:left-0">
        <h1 class="font-retro-serif font-bold text-6xl md:text-7xl leading-none tracking-tight text-retro-gray-darker dark:text-retro-cream lowercase whitespace-nowrap">
          your blogs
        </h1>
        <!-- Spacer to match blog metadata height -->
        <div class="mt-2 font-retro-mono text-retro-sm text-retro-gray-medium">&nbsp;</div>
      </div>
    </header>

    <!-- Content -->
    <main>

      <!-- Loading -->
      <div v-if="blogStore.loading" class="py-24 px-6 lg:px-0">
        <p class="font-retro-mono text-retro-sm text-retro-gray-medium uppercase tracking-widest">Loading...</p>
      </div>

      <!-- Error -->
      <div v-else-if="blogStore.error" class="py-24 px-6 lg:px-0">
        <p class="font-retro-mono text-retro-sm text-red-600">{{ blogStore.error }}</p>
      </div>

      <!-- Empty state -->
      <div v-else-if="blogStore.blogs.length === 0" class="py-24 px-6 lg:px-0">
        <p class="font-retro-serif text-4xl md:text-6xl font-bold text-retro-gray-darker dark:text-retro-gray-light leading-tight">
          No blogs yet.
        </p>
        <router-link to="/blogs/new" class="inline-block mt-6 font-retro-mono text-retro-sm text-retro-orange hover:text-retro-orange-dark uppercase tracking-wider">
          Create your first blog &rarr;
        </router-link>
      </div>

      <!-- Blog list - single column, giant typography -->
      <div v-else class="space-y-0">
        <article
          v-for="blog in blogStore.blogs"
          :key="blog.id"
          class="group cursor-pointer relative h-52 md:h-60"
          @click="navigateToBlog(blog.id)"
        >
          <!-- Divider that extends to the right -->
          <div class="absolute bottom-0 left-6 right-0 border-b border-retro-gray-light dark:border-retro-gray-darker lg:left-0 lg:-right-[100vw]"></div>
          <!-- Giant background text - uppercase -->
          <span class="absolute inset-0 flex items-center font-retro-serif font-bold text-[8rem] md:text-[12rem] leading-none tracking-tighter text-retro-gray-lightest dark:text-[#1a1a1a] select-none pointer-events-none whitespace-nowrap uppercase" aria-hidden="true">
            {{ blog.name }}
          </span>

          <!-- Foreground content - positioned lower -->
          <div class="absolute bottom-4 left-6 lg:left-0">
            <!-- Lowercase blog name -->
            <h2 class="font-retro-serif font-bold text-4xl md:text-5xl leading-none tracking-tight text-retro-gray-darker dark:text-retro-cream group-hover:text-retro-orange transition-colors lowercase whitespace-nowrap">
              {{ blog.name }}
            </h2>

            <!-- Small details underneath -->
            <div class="mt-2 flex flex-wrap items-center gap-x-6 gap-y-1">
              <p v-if="blog.tagline" class="font-retro-sans text-retro-sm text-retro-gray-dark dark:text-retro-gray-medium">
                {{ blog.tagline }}
              </p>
              <p v-if="blog.url" class="font-retro-mono text-retro-xs text-retro-gray-medium dark:text-retro-gray-dark">
                {{ blog.url }}
              </p>

              <!-- Analytics inline if available -->
              <span v-if="blog.simpleAnalyticsEnabled && analyticsData[blog.id]" class="font-retro-mono text-retro-xs text-retro-orange">
                {{ analyticsData[blog.id].pageviews?.toLocaleString() || 0 }} views
              </span>
            </div>
          </div>
        </article>
      </div>

    </main>

    </div><!-- End max-width wrapper -->

    <!-- Delete Modal -->
    <div v-if="showDeleteModal" class="fixed inset-0 bg-black/90 flex items-center justify-center z-50 p-6">
      <div class="max-w-lg w-full">
        <p class="font-retro-serif text-3xl md:text-4xl font-bold text-white mb-6">
          Delete "{{ blogToDelete?.name }}"?
        </p>
        <p class="font-retro-sans text-retro-base text-retro-gray-medium mb-8">
          This cannot be undone.
        </p>
        <div class="flex gap-6">
          <button @click="showDeleteModal = false" class="font-retro-mono text-retro-sm text-retro-gray-light hover:text-white uppercase tracking-wider">
            Cancel
          </button>
          <button @click="deleteBlog" class="font-retro-mono text-retro-sm text-red-500 hover:text-red-400 uppercase tracking-wider">
            Delete
          </button>
        </div>
      </div>
    </div>
  </div>
</template>
