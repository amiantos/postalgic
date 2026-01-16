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
          borderColor: '#0066CC',
          backgroundColor: 'rgba(0, 102, 204, 0.15)',
          fill: true,
          tension: 0, // Straight lines - retro feel
          borderWidth: 1,
          pointRadius: 2,
          pointBackgroundColor: '#0066CC'
        },
        {
          label: 'Visitors',
          data: data.histogram.map(h => h.visitors),
          borderColor: '#009900',
          backgroundColor: 'rgba(0, 153, 0, 0.15)',
          fill: true,
          tension: 0,
          borderWidth: 1,
          pointRadius: 2,
          pointBackgroundColor: '#009900'
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
          backgroundColor: '#333333',
          titleColor: '#FFFFFF',
          bodyColor: '#CCCCCC',
          borderColor: '#666666',
          borderWidth: 1,
          cornerRadius: 0, // Square corners - retro
          padding: 6,
          titleFont: { family: 'Verdana', size: 10 },
          bodyFont: { family: 'Verdana', size: 10 }
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
  <div class="min-h-screen bg-white dark:bg-black overflow-x-hidden">

    <!-- Hero section with giant POSTALGIC -->
    <header class="relative h-48 md:h-64 overflow-hidden">
      <!-- Giant background text -->
      <h1 class="absolute inset-0 flex items-center font-retro-serif font-bold text-[12rem] md:text-[18rem] leading-none tracking-tighter text-retro-gray-light dark:text-retro-gray-darker select-none pointer-events-none whitespace-nowrap">
        POSTALGIC
      </h1>

      <!-- Overlay controls -->
      <div class="relative z-10 h-full flex items-start justify-end pt-6 px-6">
        <div class="relative group">
          <span class="font-retro-mono text-retro-sm text-retro-gray-darker dark:text-retro-gray-light hover:text-retro-orange uppercase tracking-wider cursor-pointer">+ New Blog</span>
          <div class="absolute right-0 top-full hidden group-hover:block z-20 pt-1">
            <div class="bg-white dark:bg-retro-dark-surface border border-retro-gray-dark dark:border-retro-dark-border min-w-[160px]">
              <router-link to="/blogs/new" class="block px-3 py-2 font-retro-mono text-retro-sm text-retro-gray-darker dark:text-retro-gray-light hover:bg-retro-orange hover:text-white">
                New Blog
              </router-link>
              <router-link to="/blogs/import" class="block px-3 py-2 font-retro-mono text-retro-sm text-retro-gray-darker dark:text-retro-gray-light hover:bg-retro-orange hover:text-white">
                Import from ZIP
              </router-link>
              <router-link to="/blogs/import-from-url" class="block px-3 py-2 font-retro-mono text-retro-sm text-retro-gray-darker dark:text-retro-gray-light hover:bg-retro-orange hover:text-white">
                Import from URL
              </router-link>
            </div>
          </div>
        </div>
      </div>
    </header>

    <!-- Content -->
    <main class="px-6">

      <!-- Loading -->
      <div v-if="blogStore.loading" class="py-24">
        <p class="font-retro-mono text-retro-sm text-retro-gray-medium uppercase tracking-widest">Loading...</p>
      </div>

      <!-- Error -->
      <div v-else-if="blogStore.error" class="py-24">
        <p class="font-retro-mono text-retro-sm text-red-600">{{ blogStore.error }}</p>
      </div>

      <!-- Empty state -->
      <div v-else-if="blogStore.blogs.length === 0" class="py-24">
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
          class="group cursor-pointer py-6 border-b border-retro-gray-light dark:border-retro-gray-darker"
          @click="navigateToBlog(blog.id)"
        >
          <!-- Giant blog name -->
          <h2 class="font-retro-serif font-bold text-6xl md:text-8xl lg:text-9xl leading-[0.85] tracking-tight text-retro-gray-darker dark:text-retro-cream group-hover:text-retro-orange transition-colors whitespace-nowrap">
            {{ blog.name }}
          </h2>

          <!-- Small details underneath -->
          <div class="mt-3 flex flex-wrap items-center gap-x-6 gap-y-1">
            <p v-if="blog.tagline" class="font-retro-sans text-retro-sm text-retro-gray-dark dark:text-retro-gray-medium">
              {{ blog.tagline }}
            </p>
            <p v-if="blog.url" class="font-retro-mono text-retro-xs text-retro-gray-medium dark:text-retro-gray-dark">
              {{ blog.url }}
            </p>

            <!-- Analytics inline if available -->
            <template v-if="blog.simpleAnalyticsEnabled && analyticsData[blog.id]">
              <span class="font-retro-mono text-retro-xs text-retro-gray-medium">
                {{ analyticsData[blog.id].pageviews?.toLocaleString() || 0 }} views
              </span>
              <span class="font-retro-mono text-retro-xs text-retro-gray-medium">
                {{ analyticsData[blog.id].visitors?.toLocaleString() || 0 }} visitors
              </span>
            </template>
          </div>
        </article>
      </div>

    </main>

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
