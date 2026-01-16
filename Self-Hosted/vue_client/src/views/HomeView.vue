<script setup>
import { ref, computed, onMounted, watch, nextTick } from 'vue';
import { useRouter } from 'vue-router';
import { useBlogStore } from '@/stores/blog';
import { blogApi } from '@/api';
import { Chart, registerables } from 'chart.js';

Chart.register(...registerables);

const router = useRouter();
const blogStore = useBlogStore();

const showDeleteModal = ref(false);
const blogToDelete = ref(null);

// Analytics state
const analyticsData = ref({});
const analyticsLoading = ref({});
const analyticsError = ref({});
const chartInstances = ref({});

// Computed properties to separate blogs with and without analytics
const blogsWithStats = computed(() =>
  blogStore.blogs.filter(blog => blog.simpleAnalyticsEnabled)
);
const blogsWithoutStats = computed(() =>
  blogStore.blogs.filter(blog => !blog.simpleAnalyticsEnabled)
);

onMounted(() => {
  blogStore.fetchBlogs();
});

// Fetch analytics for blogs that have it enabled
async function fetchBlogAnalytics(blog) {
  if (!blog.simpleAnalyticsEnabled) return;

  analyticsLoading.value[blog.id] = true;
  analyticsError.value[blog.id] = null;

  try {
    const data = await blogApi.analytics(blog.id);
    analyticsData.value[blog.id] = data;
  } catch (e) {
    analyticsError.value[blog.id] = e.message;
  } finally {
    analyticsLoading.value[blog.id] = false;
  }
}

// Watch analytics data and render charts when data arrives
watch(analyticsData, async () => {
  await nextTick();
  // Small delay to ensure canvas elements are in DOM
  setTimeout(() => {
    for (const blogId of Object.keys(analyticsData.value)) {
      if (analyticsData.value[blogId]?.histogram && !chartInstances.value[blogId]) {
        renderChart(blogId);
      }
    }
  }, 100);
}, { deep: true });

// Render chart for a blog
function renderChart(blogId) {
  const data = analyticsData.value[blogId];
  if (!data?.histogram) return;

  const canvas = document.getElementById(`chart-${blogId}`);
  if (!canvas) return;

  // Destroy existing chart if any
  if (chartInstances.value[blogId]) {
    chartInstances.value[blogId].destroy();
  }

  chartInstances.value[blogId] = new Chart(canvas, {
    type: 'line',
    data: {
      labels: data.histogram.map(h => h.date),
      datasets: [
        {
          label: 'Pageviews',
          data: data.histogram.map(h => h.pageviews),
          borderColor: 'rgb(59, 130, 246)',
          backgroundColor: 'rgba(59, 130, 246, 0.1)',
          fill: true,
          tension: 0.3,
          borderWidth: 2,
          pointRadius: 0
        },
        {
          label: 'Visitors',
          data: data.histogram.map(h => h.visitors),
          borderColor: 'rgb(16, 185, 129)',
          backgroundColor: 'rgba(16, 185, 129, 0.1)',
          fill: true,
          tension: 0.3,
          borderWidth: 2,
          pointRadius: 0
        }
      ]
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      interaction: {
        intersect: false,
        mode: 'index'
      },
      plugins: {
        legend: { display: false },
        tooltip: {
          backgroundColor: 'rgba(0, 0, 0, 0.8)',
          padding: 8,
          cornerRadius: 8
        }
      },
      scales: {
        x: { display: false },
        y: { display: false, beginAtZero: true }
      }
    }
  });
}

// Watch for blogs to load and fetch analytics
watch(() => blogStore.blogs, (blogs) => {
  for (const blog of blogs) {
    if (blog.simpleAnalyticsEnabled && !analyticsData.value[blog.id] && !analyticsLoading.value[blog.id]) {
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
  <div class="min-h-screen bg-gray-50 dark:bg-gray-900">
    <!-- Header -->
    <header class="bg-white/80 dark:bg-white/5 backdrop-blur-lg border-b border-black/5 dark:border-white/10">
      <div class="max-w-4xl mx-auto px-4 py-6">
        <div class="flex items-center justify-between">
          <h1 class="text-2xl font-bold text-gray-900 dark:text-gray-100">Postalgic</h1>
          <div class="flex gap-2">
            <div class="relative group">
              <button
                class="px-4 py-2.5 bg-black/5 dark:bg-white/10 text-gray-700 dark:text-gray-300 rounded-xl font-medium hover:bg-black/10 dark:hover:bg-white/15 transition-colors inline-flex items-center gap-1"
              >
                Import Blog
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
                </svg>
              </button>
              <div class="absolute right-0 w-48 pt-2 hidden group-hover:block z-10">
                <div class="surface py-1">
                  <router-link
                    to="/blogs/import"
                    class="block px-4 py-2.5 text-gray-700 dark:text-gray-300 hover:bg-black/5 dark:hover:bg-white/10 transition-colors"
                  >
                    From ZIP File
                  </router-link>
                  <router-link
                    to="/blogs/import-from-url"
                    class="block px-4 py-2.5 text-gray-700 dark:text-gray-300 hover:bg-black/5 dark:hover:bg-white/10 transition-colors"
                  >
                    From URL
                  </router-link>
                </div>
              </div>
            </div>
            <router-link
              to="/blogs/new"
              class="px-5 py-2.5 bg-primary-500 text-white rounded-xl font-medium hover:bg-primary-600 transition-colors shadow-sm"
            >
              New Blog
            </router-link>
          </div>
        </div>
      </div>
    </header>

    <!-- Content -->
    <main class="max-w-4xl mx-auto px-4 py-8">
      <!-- Loading -->
      <div v-if="blogStore.loading" class="text-center py-12">
        <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-primary-600 mx-auto"></div>
        <p class="mt-4 text-gray-500 dark:text-gray-400">Loading blogs...</p>
      </div>

      <!-- Error -->
      <div v-else-if="blogStore.error" class="bg-red-500/10 rounded-xl p-4">
        <p class="text-red-600 dark:text-red-400">{{ blogStore.error }}</p>
      </div>

      <!-- Empty State -->
      <div v-else-if="blogStore.blogs.length === 0" class="text-center py-12 surface">
        <div class="w-16 h-16 bg-black/5 dark:bg-white/5 rounded-full flex items-center justify-center mx-auto mb-4">
          <svg class="w-8 h-8 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 20H5a2 2 0 01-2-2V6a2 2 0 012-2h10a2 2 0 012 2v1m2 13a2 2 0 01-2-2V7m2 13a2 2 0 002-2V9a2 2 0 00-2-2h-2m-4-3H9M7 16h6M7 8h6v4H7V8z" />
          </svg>
        </div>
        <h2 class="text-lg font-medium text-gray-900 dark:text-gray-100 mb-2">No blogs yet</h2>
        <p class="text-gray-500 dark:text-gray-400 mb-6">Create your first blog to get started.</p>
        <router-link
          to="/blogs/new"
          class="inline-flex items-center px-5 py-2.5 bg-primary-500 text-white rounded-xl font-medium hover:bg-primary-600 transition-colors shadow-sm"
        >
          Create Blog
        </router-link>
      </div>

      <!-- Blog List -->
      <div v-else class="space-y-8">
        <!-- Blogs with Stats -->
        <div v-if="blogsWithStats.length > 0" class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div
            v-for="blog in blogsWithStats"
            :key="blog.id"
            class="surface-interactive p-5 cursor-pointer"
            @click="navigateToBlog(blog.id)"
          >
            <div class="flex items-start gap-3">
              <img
                :src="`/api/blogs/${blog.id}/favicon`"
                @error="$event.target.style.display = 'none'"
                class="w-11 h-11 rounded flex-shrink-0"
              />
              <div class="min-w-0">
                <h2 class="text-lg font-semibold text-gray-900 dark:text-gray-100 truncate">{{ blog.name }}</h2>
                <p v-if="blog.tagline" class="text-gray-500 dark:text-gray-400 text-sm truncate">{{ blog.tagline }}</p>
              </div>
            </div>
            <p v-if="blog.url" class="text-primary-600 dark:text-primary-400 text-xs mt-2 truncate">{{ blog.url }}</p>

            <!-- Analytics Section - Fixed height to prevent jumping -->
            <div class="mt-4 pt-4 border-t border-gray-200 dark:border-gray-700 h-[116px]">
              <div v-if="analyticsLoading[blog.id]" class="flex items-center justify-center h-full text-sm text-gray-500 dark:text-gray-400">
                <div class="animate-spin rounded-full h-5 w-5 border-b-2 border-primary-600 mr-2"></div>
                Loading analytics...
              </div>
              <div v-else-if="analyticsError[blog.id]" class="text-sm text-red-500 dark:text-red-400">
                {{ analyticsError[blog.id] }}
              </div>
              <div v-else-if="analyticsData[blog.id]">
                <div class="flex items-center justify-start gap-3 text-sm text-gray-600 dark:text-gray-400 mb-2">
                  <span class="flex items-center gap-1.5">
                    <span class="w-2 h-2 rounded-full bg-blue-500"></span>
                    <strong class="text-gray-900 dark:text-gray-100">{{ analyticsData[blog.id].pageviews?.toLocaleString() || 0 }}</strong> views
                  </span>
                  <span class="flex items-center gap-1.5">
                    <span class="w-2 h-2 rounded-full bg-emerald-500"></span>
                    <strong class="text-gray-900 dark:text-gray-100">{{ analyticsData[blog.id].visitors?.toLocaleString() || 0 }}</strong> visitors
                  </span>
                </div>
                <div class="h-16 w-full relative">
                  <canvas :id="'chart-' + blog.id" class="absolute inset-0 w-full h-full"></canvas>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Blogs without Stats -->
        <div v-if="blogsWithoutStats.length > 0">
          <h3 v-if="blogsWithStats.length > 0" class="text-sm font-medium text-gray-500 dark:text-gray-400 mb-3">Other Blogs</h3>
          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div
              v-for="blog in blogsWithoutStats"
              :key="blog.id"
              class="surface-interactive p-5 cursor-pointer"
              @click="navigateToBlog(blog.id)"
            >
              <div class="flex items-start gap-3">
                <img
                  :src="`/api/blogs/${blog.id}/favicon`"
                  @error="$event.target.style.display = 'none'"
                  class="w-11 h-11 rounded flex-shrink-0"
                />
                <div class="min-w-0">
                  <h2 class="text-lg font-semibold text-gray-900 dark:text-gray-100 truncate">{{ blog.name }}</h2>
                  <p v-if="blog.tagline" class="text-gray-500 dark:text-gray-400 text-sm truncate">{{ blog.tagline }}</p>
                </div>
              </div>
              <p v-if="blog.url" class="text-primary-600 dark:text-primary-400 text-xs mt-2 truncate">{{ blog.url }}</p>
            </div>
          </div>
        </div>
      </div>
    </main>

    <!-- Delete Modal -->
    <div v-if="showDeleteModal" class="fixed inset-0 bg-black/60 backdrop-blur-sm flex items-center justify-center z-50">
      <div class="surface p-6 max-w-md w-full mx-4">
        <h3 class="text-lg font-semibold text-gray-900 dark:text-gray-100 mb-2">Delete Blog</h3>
        <p class="text-gray-600 dark:text-gray-400 mb-6">
          Are you sure you want to delete "{{ blogToDelete?.name }}"? This action cannot be undone.
        </p>
        <div class="flex justify-end gap-3">
          <button
            @click="showDeleteModal = false"
            class="px-4 py-2.5 text-gray-700 dark:text-gray-300 hover:bg-black/5 dark:hover:bg-white/10 rounded-xl font-medium transition-colors"
          >
            Cancel
          </button>
          <button
            @click="deleteBlog"
            class="px-4 py-2.5 bg-red-500 text-white rounded-xl font-medium hover:bg-red-600 transition-colors"
          >
            Delete
          </button>
        </div>
      </div>
    </div>
  </div>
</template>
