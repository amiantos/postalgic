<script setup>
import { ref, onMounted, watch, nextTick } from 'vue';
import { useRouter } from 'vue-router';
import { useBlogStore } from '@/stores/blog';
import { blogApi } from '@/api';
import { Chart, LineController, LineElement, PointElement, LinearScale, CategoryScale, Filler, Tooltip } from 'chart.js';

Chart.register(LineController, LineElement, PointElement, LinearScale, CategoryScale, Filler, Tooltip);

const router = useRouter();
const blogStore = useBlogStore();

const showDeleteModal = ref(false);
const blogToDelete = ref(null);

// Analytics state
const analyticsData = ref({});
const chartInstances = ref({});

onMounted(() => {
  blogStore.fetchBlogs();
});

// Fetch analytics for blogs that have it enabled
async function fetchBlogAnalytics(blog) {
  if (!blog.simpleAnalyticsEnabled) return;

  try {
    const data = await blogApi.analytics(blog.id);
    analyticsData.value[blog.id] = data;
    await nextTick();
    renderChart(blog.id, data);
  } catch (e) {
    // Silently fail - just won't show analytics
  }
}

function renderChart(blogId, data) {
  const canvas = document.getElementById(`chart-${blogId}`);
  if (!canvas || !data.histogram) return;

  // Destroy existing chart if any
  if (chartInstances.value[blogId]) {
    chartInstances.value[blogId].destroy();
  }

  const labels = data.histogram.map(d => d.date);
  const pageviews = data.histogram.map(d => d.pageviews || 0);
  const visitors = data.histogram.map(d => d.visitors || 0);

  chartInstances.value[blogId] = new Chart(canvas, {
    type: 'line',
    data: {
      labels,
      datasets: [
        {
          label: 'Pageviews',
          data: pageviews,
          borderColor: '#FFA100',
          backgroundColor: 'rgba(255, 161, 0, 0.12)',
          fill: true,
          tension: 0,
          pointRadius: 0,
          pointHoverRadius: 3,
          borderWidth: 1.5,
        },
        {
          label: 'Visitors',
          data: visitors,
          borderColor: '#a0aec0',
          backgroundColor: 'rgba(160, 174, 192, 0.1)',
          fill: true,
          tension: 0,
          pointRadius: 0,
          pointHoverRadius: 3,
          borderWidth: 1.5,
        }
      ]
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      interaction: {
        intersect: false,
        mode: 'index',
      },
      plugins: {
        legend: { display: false },
        tooltip: {
          backgroundColor: '#ffffff',
          titleColor: '#2d3748',
          bodyColor: '#4a5568',
          borderColor: '#dedede',
          borderWidth: 1,
          cornerRadius: 6,
          titleFont: { family: 'system-ui, sans-serif', size: 11 },
          bodyFont: { family: 'system-ui, sans-serif', size: 11 },
          padding: 8,
          displayColors: true,
          boxWidth: 8,
          boxHeight: 8,
        }
      },
      scales: {
        x: { display: false },
        y: {
          display: false,
          beginAtZero: true,
        }
      }
    }
  });
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
  <div class="min-h-screen bg-site-bg text-site-text leading-[1.6]">
    <!-- Header -->
    <header class="max-w-[1000px] mx-auto px-8 pt-8 pb-4">
      <div class="flex items-center justify-between mb-4">
        <h1 class="font-bold text-site-dark">
          Your Blogs
        </h1>
        <div class="relative group">
          <button class="px-5 py-2 bg-site-accent text-white font-semibold rounded-full hover:bg-[#e89200] transition-colors">
            + New Blog
          </button>
          <div class="absolute right-0 top-full hidden group-hover:block z-20 pt-1">
            <div class="bg-white border border-site-light rounded-lg min-w-[200px] shadow-lg overflow-hidden">
              <router-link to="/blogs/new" class="block px-4 py-3 text-site-text hover:bg-site-accent hover:text-white transition-colors">
                New Blog
              </router-link>
              <router-link to="/blogs/import" class="block px-4 py-3 text-site-text hover:bg-site-accent hover:text-white transition-colors border-t border-site-light">
                Import from ZIP
              </router-link>
              <router-link to="/blogs/import-from-url" class="block px-4 py-3 text-site-text hover:bg-site-accent hover:text-white transition-colors border-t border-site-light">
                Import from URL
              </router-link>
            </div>
          </div>
        </div>
      </div>
      <div class="wavy-separator"></div>
    </header>

    <!-- Content -->
    <main class="max-w-[1000px] mx-auto px-8 pb-12 pt-6">

      <!-- Loading -->
      <div v-if="blogStore.loading" class="py-24 text-center">
        <p class="text-[0.9em] text-site-medium">Loading...</p>
      </div>

      <!-- Error -->
      <div v-else-if="blogStore.error" class="py-24 text-center">
        <p class="text-[0.9em] text-red-600">{{ blogStore.error }}</p>
      </div>

      <!-- Empty state -->
      <div v-else-if="blogStore.blogs.length === 0" class="py-24 text-center">
        <svg class="w-12 h-12 text-site-medium mx-auto mb-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1">
          <path stroke-linecap="round" stroke-linejoin="round" d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.247 18 16.5 18c-1.746 0-3.332.477-4.5 1.253" />
        </svg>
        <p class="text-[1.2rem] font-bold text-site-dark mb-2">
          No blogs yet
        </p>
        <p class="text-[0.9em] text-site-medium mb-6">
          Create your first blog to get started.
        </p>
        <router-link to="/blogs/new" class="inline-block px-5 py-2 bg-site-accent text-white font-semibold rounded-full hover:bg-[#e89200] transition-colors">
          Create your first blog
        </router-link>
      </div>

      <!-- Blog grid -->
      <div v-else class="grid grid-cols-1 md:grid-cols-2 gap-5">
        <article
          v-for="blog in blogStore.blogs"
          :key="blog.id"
          class="cursor-pointer bg-white border border-site-light rounded-lg p-5 hover:border-site-accent transition-colors"
          @click="navigateToBlog(blog.id)"
        >
          <!-- Blog info -->
          <div class="flex items-start gap-3 mb-3">
            <img
              v-if="blog.faviconFilename"
              :src="`/uploads/${blog.id}/${blog.faviconFilename}`"
              class="w-8 h-8 flex-shrink-0 mt-0.5 rounded"
              alt=""
            />
            <div class="min-w-0 flex-1">
              <h2 class="font-bold text-[1.2rem] text-site-dark leading-tight truncate hover:text-site-accent transition-colors">
                {{ blog.name }}
              </h2>
              <p v-if="blog.tagline" class="text-[0.9em] text-site-medium italic mt-0.5 truncate">
                {{ blog.tagline }}
              </p>
            </div>
          </div>

          <!-- URL -->
          <p v-if="blog.url" class="text-[0.8em] text-site-accent truncate mb-3">
            {{ blog.url }}
          </p>

          <!-- Chart -->
          <div v-if="blog.simpleAnalyticsEnabled && analyticsData[blog.id]?.histogram" class="mb-2">
            <!-- Legend -->
            <div class="flex items-center gap-4 mb-1.5">
              <span class="flex items-center gap-1.5 text-[0.8em] text-site-medium">
                <span class="inline-block w-2 h-2 rounded-full bg-site-accent"></span>
                {{ analyticsData[blog.id].pageviews?.toLocaleString() || 0 }} views
              </span>
              <span class="flex items-center gap-1.5 text-[0.8em] text-site-medium">
                <span class="inline-block w-2 h-2 rounded-full bg-site-medium"></span>
                {{ analyticsData[blog.id].visitors?.toLocaleString() || 0 }} visitors
              </span>
            </div>
            <!-- Chart canvas -->
            <div class="h-16 w-full border border-site-light rounded bg-white p-1">
              <canvas :id="`chart-${blog.id}`"></canvas>
            </div>
          </div>

          <!-- Analytics without histogram -->
          <div v-else-if="blog.simpleAnalyticsEnabled && analyticsData[blog.id]" class="mb-2">
            <span class="text-[0.8em] text-site-accent">
              {{ analyticsData[blog.id].pageviews?.toLocaleString() || 0 }} views
            </span>
          </div>
        </article>
      </div>

    </main>

    <!-- Delete Modal -->
    <div v-if="showDeleteModal" class="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-6">
      <div class="max-w-md w-full bg-white border border-site-light rounded-lg p-6 shadow-xl">
        <h3 class="font-bold text-site-dark mb-2">
          Delete "{{ blogToDelete?.name }}"?
        </h3>
        <p class="text-[0.9em] text-site-medium mb-6">
          This cannot be undone.
        </p>
        <div class="flex justify-end gap-3">
          <button @click="showDeleteModal = false" class="px-4 py-2 border border-site-light rounded-lg text-site-text hover:bg-site-bg transition-colors">
            Cancel
          </button>
          <button @click="deleteBlog" class="px-4 py-2 bg-red-600 text-white rounded-lg font-semibold hover:bg-red-700 transition-colors">
            Delete
          </button>
        </div>
      </div>
    </div>
  </div>
</template>
