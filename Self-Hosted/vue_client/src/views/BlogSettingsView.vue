<script setup>
import { ref, computed, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useBlogStore } from '@/stores/blog';
import { blogApi } from '@/api';

const route = useRoute();
const router = useRouter();
const blogStore = useBlogStore();

const blogId = computed(() => route.params.blogId);
const currentRouteName = computed(() => route.name);

const settingsTabs = [
  { name: 'Basic', route: 'blog-settings' },
  { name: 'Categories', route: 'categories' },
  { name: 'Tags', route: 'tags' },
  { name: 'Sidebar', route: 'sidebar' },
  { name: 'Files', route: 'files' },
  { name: 'Themes', route: 'themes' },
  { name: 'Publishing', route: 'publish-settings' }
];

const form = ref({});
const saving = ref(false);
const error = ref(null);
const success = ref(false);
const exporting = ref(false);

watch(() => blogStore.currentBlog, (blog) => {
  if (blog) {
    form.value = { ...blog };
  }
}, { immediate: true });

async function saveSettings() {
  saving.value = true;
  error.value = null;
  success.value = false;

  try {
    await blogStore.updateBlog(blogId.value, form.value);
    success.value = true;
    setTimeout(() => success.value = false, 3000);
  } catch (e) {
    error.value = e.message;
  } finally {
    saving.value = false;
  }
}

async function deleteBlog() {
  if (confirm(`Are you sure you want to delete "${blogStore.currentBlog?.name}"? This cannot be undone.`)) {
    await blogStore.deleteBlog(blogId.value);
    router.push('/');
  }
}

async function downloadDebugExport() {
  exporting.value = true;
  error.value = null;

  try {
    const { blob, filename } = await blogApi.debugExport(blogId.value);

    // Create download link
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  } catch (e) {
    error.value = e.message;
  } finally {
    exporting.value = false;
  }
}
</script>

<template>
  <div class="min-h-screen bg-white dark:bg-black overflow-x-hidden">
    <!-- Max-width content wrapper for desktop -->
    <div class="lg:max-w-[700px] lg:ml-8">

    <!-- Navigation bar -->
    <nav class="flex items-center justify-between px-6 py-4 lg:px-0">
      <router-link
        :to="{ name: 'blog-posts', params: { blogId } }"
        class="px-3 py-1.5 border-2 border-retro-gray-light dark:border-retro-gray-darker bg-white dark:bg-black font-retro-mono text-retro-sm text-retro-gray-dark dark:text-retro-gray-medium hover:border-retro-orange hover:text-retro-orange uppercase tracking-wider"
      >
        <span class="relative -top-px">&lt;</span> {{ blogStore.currentBlog?.name || 'Posts' }}
      </router-link>
    </nav>

    <!-- Hero section -->
    <header class="relative h-52 md:h-60">
      <!-- Divider that extends to the right -->
      <div class="absolute bottom-0 left-6 right-0 border-b border-retro-gray-light dark:border-retro-gray-darker lg:left-0 lg:-right-[100vw]"></div>
      <!-- Giant background text -->
      <span class="absolute inset-0 flex items-center justify-start font-retro-serif font-bold text-[10rem] md:text-[14rem] leading-none tracking-tighter text-retro-gray-lightest dark:text-[#1a1a1a] select-none pointer-events-none whitespace-nowrap uppercase" aria-hidden="true">
        SETTINGS
      </span>
      <!-- Foreground content -->
      <div class="absolute bottom-4 left-6 lg:left-0">
        <h1 class="font-retro-serif font-bold text-6xl md:text-7xl leading-none tracking-tight text-retro-gray-darker dark:text-retro-cream lowercase whitespace-nowrap">
          settings
        </h1>
        <!-- Spacer to match other views -->
        <div class="mt-2 font-retro-mono text-retro-sm text-retro-gray-medium">&nbsp;</div>
      </div>
    </header>

    <!-- Settings tabs -->
    <nav class="flex flex-wrap gap-x-4 gap-y-2 px-6 lg:px-0 py-4 border-b border-retro-gray-light dark:border-retro-gray-darker">
      <router-link
        v-for="tab in settingsTabs"
        :key="tab.route"
        :to="{ name: tab.route, params: { blogId } }"
        :class="[
          'font-retro-mono text-retro-sm uppercase tracking-wider',
          currentRouteName === tab.route
            ? 'text-retro-orange'
            : 'text-retro-gray-dark dark:text-retro-gray-medium hover:text-retro-orange'
        ]"
      >
        {{ tab.name }}
      </router-link>
    </nav>

    <!-- Content -->
    <main class="px-6 lg:px-0 py-6">
      <!-- Messages -->
      <div v-if="error" class="mb-6 p-4 border-2 border-red-500 font-retro-mono text-retro-sm text-red-600 dark:text-red-400">
        {{ error }}
      </div>
      <div v-if="success" class="mb-6 p-4 border-2 border-green-500 font-retro-mono text-retro-sm text-green-600 dark:text-green-400">
        Settings saved successfully!
      </div>

      <form @submit.prevent="saveSettings" class="space-y-8">
        <!-- Basic Info -->
        <section>
          <h3 class="font-retro-mono text-retro-sm text-retro-gray-darker dark:text-retro-cream uppercase tracking-wider mb-4">Basic Information</h3>
          <div class="space-y-4">
            <div>
              <label class="block font-retro-mono text-retro-xs text-retro-gray-medium uppercase tracking-wider mb-2">Blog Name</label>
              <input
                v-model="form.name"
                type="text"
                class="w-full px-3 py-2 border-2 border-retro-gray-light dark:border-retro-gray-darker bg-white dark:bg-black font-retro-sans text-retro-base text-retro-gray-darker dark:text-retro-cream focus:outline-none focus:border-retro-orange"
              />
            </div>
            <div>
              <label class="block font-retro-mono text-retro-xs text-retro-gray-medium uppercase tracking-wider mb-2">Blog URL</label>
              <input
                v-model="form.url"
                type="url"
                class="w-full px-3 py-2 border-2 border-retro-gray-light dark:border-retro-gray-darker bg-white dark:bg-black font-retro-mono text-retro-sm text-retro-gray-darker dark:text-retro-cream focus:outline-none focus:border-retro-orange"
                placeholder="https://myblog.com"
              />
            </div>
            <div>
              <label class="block font-retro-mono text-retro-xs text-retro-gray-medium uppercase tracking-wider mb-2">Tagline</label>
              <input
                v-model="form.tagline"
                type="text"
                class="w-full px-3 py-2 border-2 border-retro-gray-light dark:border-retro-gray-darker bg-white dark:bg-black font-retro-sans text-retro-base text-retro-gray-darker dark:text-retro-cream focus:outline-none focus:border-retro-orange"
              />
            </div>
            <div>
              <label class="block font-retro-mono text-retro-xs text-retro-gray-medium uppercase tracking-wider mb-2">Timezone</label>
              <select
                v-model="form.timezone"
                class="w-full px-3 py-2 border-2 border-retro-gray-light dark:border-retro-gray-darker bg-white dark:bg-black font-retro-mono text-retro-sm text-retro-gray-darker dark:text-retro-cream focus:outline-none focus:border-retro-orange"
              >
                <option value="UTC">UTC</option>
                <optgroup label="Americas">
                  <option value="America/New_York">Eastern Time (US & Canada)</option>
                  <option value="America/Chicago">Central Time (US & Canada)</option>
                  <option value="America/Denver">Mountain Time (US & Canada)</option>
                  <option value="America/Los_Angeles">Pacific Time (US & Canada)</option>
                  <option value="America/Anchorage">Alaska</option>
                  <option value="Pacific/Honolulu">Hawaii</option>
                  <option value="America/Phoenix">Arizona</option>
                  <option value="America/Toronto">Toronto</option>
                  <option value="America/Vancouver">Vancouver</option>
                  <option value="America/Mexico_City">Mexico City</option>
                  <option value="America/Sao_Paulo">São Paulo</option>
                  <option value="America/Buenos_Aires">Buenos Aires</option>
                </optgroup>
                <optgroup label="Europe">
                  <option value="Europe/London">London</option>
                  <option value="Europe/Paris">Paris</option>
                  <option value="Europe/Berlin">Berlin</option>
                  <option value="Europe/Amsterdam">Amsterdam</option>
                  <option value="Europe/Madrid">Madrid</option>
                  <option value="Europe/Rome">Rome</option>
                  <option value="Europe/Stockholm">Stockholm</option>
                  <option value="Europe/Moscow">Moscow</option>
                </optgroup>
                <optgroup label="Asia">
                  <option value="Asia/Tokyo">Tokyo</option>
                  <option value="Asia/Shanghai">Shanghai</option>
                  <option value="Asia/Hong_Kong">Hong Kong</option>
                  <option value="Asia/Singapore">Singapore</option>
                  <option value="Asia/Seoul">Seoul</option>
                  <option value="Asia/Kolkata">Mumbai/Kolkata</option>
                  <option value="Asia/Dubai">Dubai</option>
                  <option value="Asia/Bangkok">Bangkok</option>
                </optgroup>
                <optgroup label="Pacific">
                  <option value="Australia/Sydney">Sydney</option>
                  <option value="Australia/Melbourne">Melbourne</option>
                  <option value="Australia/Perth">Perth</option>
                  <option value="Pacific/Auckland">Auckland</option>
                </optgroup>
                <optgroup label="Africa">
                  <option value="Africa/Johannesburg">Johannesburg</option>
                  <option value="Africa/Cairo">Cairo</option>
                  <option value="Africa/Lagos">Lagos</option>
                </optgroup>
              </select>
              <p class="mt-2 font-retro-mono text-retro-xs text-retro-gray-medium">Dates on your published blog will display in this timezone</p>
            </div>
          </div>
        </section>

        <!-- Author Info -->
        <section class="border-t border-retro-gray-light dark:border-retro-gray-darker pt-8">
          <h3 class="font-retro-mono text-retro-sm text-retro-gray-darker dark:text-retro-cream uppercase tracking-wider mb-4">Author Information</h3>
          <div class="space-y-4">
            <div>
              <label class="block font-retro-mono text-retro-xs text-retro-gray-medium uppercase tracking-wider mb-2">Author Name</label>
              <input
                v-model="form.authorName"
                type="text"
                class="w-full px-3 py-2 border-2 border-retro-gray-light dark:border-retro-gray-darker bg-white dark:bg-black font-retro-sans text-retro-base text-retro-gray-darker dark:text-retro-cream focus:outline-none focus:border-retro-orange"
              />
            </div>
            <div>
              <label class="block font-retro-mono text-retro-xs text-retro-gray-medium uppercase tracking-wider mb-2">Author URL</label>
              <input
                v-model="form.authorUrl"
                type="url"
                class="w-full px-3 py-2 border-2 border-retro-gray-light dark:border-retro-gray-darker bg-white dark:bg-black font-retro-mono text-retro-sm text-retro-gray-darker dark:text-retro-cream focus:outline-none focus:border-retro-orange"
              />
            </div>
            <div>
              <label class="block font-retro-mono text-retro-xs text-retro-gray-medium uppercase tracking-wider mb-2">Author Email</label>
              <input
                v-model="form.authorEmail"
                type="email"
                class="w-full px-3 py-2 border-2 border-retro-gray-light dark:border-retro-gray-darker bg-white dark:bg-black font-retro-mono text-retro-sm text-retro-gray-darker dark:text-retro-cream focus:outline-none focus:border-retro-orange"
              />
            </div>
          </div>
        </section>

        <!-- Simple Analytics -->
        <section class="border-t border-retro-gray-light dark:border-retro-gray-darker pt-8">
          <h3 class="font-retro-mono text-retro-sm text-retro-gray-darker dark:text-retro-cream uppercase tracking-wider mb-2">Simple Analytics</h3>
          <p class="font-retro-sans text-retro-sm text-retro-gray-dark dark:text-retro-gray-medium mb-4">
            Enable Simple Analytics to track pageviews and visitors on your published blog.
            <a href="https://simpleanalytics.com" target="_blank" class="text-retro-orange hover:text-retro-orange-dark">Learn more</a>
          </p>
          <div class="space-y-4">
            <label class="flex items-center gap-3">
              <input
                v-model="form.simpleAnalyticsEnabled"
                type="checkbox"
                class="border-2 border-retro-gray-light dark:border-retro-gray-darker"
              />
              <span class="font-retro-sans text-retro-sm text-retro-gray-darker dark:text-retro-cream">
                Enable Simple Analytics tracking
              </span>
            </label>
            <div v-if="form.simpleAnalyticsEnabled">
              <label class="block font-retro-mono text-retro-xs text-retro-gray-medium uppercase tracking-wider mb-2">
                Domain Override (optional)
              </label>
              <input
                v-model="form.simpleAnalyticsDomain"
                type="text"
                class="w-full px-3 py-2 border-2 border-retro-gray-light dark:border-retro-gray-darker bg-white dark:bg-black font-retro-mono text-retro-sm text-retro-gray-darker dark:text-retro-cream focus:outline-none focus:border-retro-orange"
                placeholder="example.com"
              />
              <p class="mt-2 font-retro-mono text-retro-xs text-retro-gray-medium">
                Leave empty to use the domain from your Blog URL. Use this if your site is registered under a different domain in Simple Analytics.
              </p>
            </div>
          </div>
        </section>

        <!-- Discourse Comments -->
        <section class="border-t border-retro-gray-light dark:border-retro-gray-darker pt-8">
          <h3 class="font-retro-mono text-retro-sm text-retro-gray-darker dark:text-retro-cream uppercase tracking-wider mb-2">Discourse Comments</h3>
          <p class="font-retro-sans text-retro-sm text-retro-gray-dark dark:text-retro-gray-medium mb-4">
            Enable Discourse comment embedding on individual post pages.
            <a href="https://meta.discourse.org/t/embedding-discourse-comments-via-javascript/31963" target="_blank" class="text-retro-orange hover:text-retro-orange-dark">Learn more</a>
          </p>
          <div class="space-y-4">
            <label class="flex items-center gap-3">
              <input
                v-model="form.discourseCommentsEnabled"
                type="checkbox"
                class="border-2 border-retro-gray-light dark:border-retro-gray-darker"
              />
              <span class="font-retro-sans text-retro-sm text-retro-gray-darker dark:text-retro-cream">
                Enable Discourse comment embedding
              </span>
            </label>
            <div v-if="form.discourseCommentsEnabled">
              <label class="block font-retro-mono text-retro-xs text-retro-gray-medium uppercase tracking-wider mb-2">
                Discourse Server URL
              </label>
              <input
                v-model="form.discourseUrl"
                type="url"
                class="w-full px-3 py-2 border-2 border-retro-gray-light dark:border-retro-gray-darker bg-white dark:bg-black font-retro-mono text-retro-sm text-retro-gray-darker dark:text-retro-cream focus:outline-none focus:border-retro-orange"
                placeholder="https://discourse.example.com/"
              />
              <p class="mt-2 font-retro-mono text-retro-xs text-retro-gray-medium">
                The URL of your Discourse server. Must include a trailing slash.
              </p>
            </div>
          </div>
        </section>

        <!-- Actions -->
        <section class="border-t border-retro-gray-light dark:border-retro-gray-darker pt-8">
          <div class="flex justify-between">
            <button
              type="button"
              @click="deleteBlog"
              class="font-retro-mono text-retro-sm text-red-500 hover:text-red-400 uppercase tracking-wider"
            >
              Delete Blog
            </button>
            <button
              type="submit"
              :disabled="saving"
              class="px-4 py-2 border-2 border-retro-orange bg-retro-orange font-retro-mono text-retro-sm text-white hover:bg-retro-orange-dark hover:border-retro-orange-dark uppercase tracking-wider disabled:opacity-50"
            >
              {{ saving ? 'Saving...' : 'Save Settings' }}
            </button>
          </div>
        </section>
      </form>

      <!-- Developer Tools -->
      <section class="border-t border-retro-gray-light dark:border-retro-gray-darker pt-8 mt-8">
        <h3 class="font-retro-mono text-retro-sm text-retro-gray-darker dark:text-retro-cream uppercase tracking-wider mb-2">Developer Tools</h3>
        <p class="font-retro-sans text-retro-sm text-retro-gray-dark dark:text-retro-gray-medium mb-4">
          Export a debug bundle containing the full generated site and sync data. Useful for comparing output between iOS and Self-Hosted apps.
        </p>
        <button
          type="button"
          @click="downloadDebugExport"
          :disabled="exporting"
          class="px-4 py-2 border-2 border-retro-gray-dark dark:border-retro-gray-medium font-retro-mono text-retro-sm text-retro-gray-darker dark:text-retro-cream hover:border-retro-orange hover:text-retro-orange uppercase tracking-wider disabled:opacity-50"
        >
          {{ exporting ? 'Exporting...' : 'Download Debug Export' }}
        </button>
      </section>
    </main>

    </div><!-- End max-width wrapper -->
  </div>
</template>
