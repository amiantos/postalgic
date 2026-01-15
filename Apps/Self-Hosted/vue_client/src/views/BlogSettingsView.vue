<script setup>
import { ref, computed, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useBlogStore } from '@/stores/blog';
import { blogApi } from '@/api';
import PageToolbar from '@/components/PageToolbar.vue';
import SettingsTabs from '@/components/SettingsTabs.vue';
import PublishModal from '@/components/PublishModal.vue';

const route = useRoute();
const router = useRouter();
const blogStore = useBlogStore();

const blogId = computed(() => route.params.blogId);

const form = ref({});
const saving = ref(false);
const error = ref(null);
const showPublishModal = ref(false);
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
  <div>
    <PageToolbar title="Basic Settings" @deploy="showPublishModal = true">
      <template #tabs>
        <SettingsTabs />
      </template>
    </PageToolbar>

    <div class="px-6 pb-6">
    <!-- Messages -->
    <div v-if="error" class="mb-6 p-4 bg-red-500/10 rounded-xl text-red-600 dark:text-red-400">
      {{ error }}
    </div>
    <div v-if="success" class="mb-6 p-4 bg-green-500/10 rounded-xl text-green-600 dark:text-green-400">
      Settings saved successfully!
    </div>

    <form @submit.prevent="saveSettings" class="space-y-8">
      <!-- Basic Info -->
      <section class="surface p-6">
        <h3 class="text-lg font-medium text-gray-900 dark:text-gray-100 mb-4">Basic Information</h3>
        <div class="space-y-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Blog Name</label>
            <input
              v-model="form.name"
              type="text"
              class="w-full px-3.5 py-2.5 rounded-xl bg-black/5 dark:bg-white/5 text-gray-900 dark:text-gray-100 border-0 focus:ring-2 focus:ring-primary-500/50 focus:bg-white dark:focus:bg-white/10 transition-colors"
            />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Blog URL</label>
            <input
              v-model="form.url"
              type="url"
              class="w-full px-3.5 py-2.5 rounded-xl bg-black/5 dark:bg-white/5 text-gray-900 dark:text-gray-100 border-0 focus:ring-2 focus:ring-primary-500/50 focus:bg-white dark:focus:bg-white/10 transition-colors"
              placeholder="https://myblog.com"
            />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Tagline</label>
            <input
              v-model="form.tagline"
              type="text"
              class="w-full px-3.5 py-2.5 rounded-xl bg-black/5 dark:bg-white/5 text-gray-900 dark:text-gray-100 border-0 focus:ring-2 focus:ring-primary-500/50 focus:bg-white dark:focus:bg-white/10 transition-colors"
            />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Timezone</label>
            <select
              v-model="form.timezone"
              class="w-full px-3.5 py-2.5 rounded-xl bg-black/5 dark:bg-white/5 text-gray-900 dark:text-gray-100 border-0 focus:ring-2 focus:ring-primary-500/50 focus:bg-white dark:focus:bg-white/10 transition-colors"
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
            <p class="mt-1 text-xs text-gray-500 dark:text-gray-400">Dates on your published blog will display in this timezone</p>
          </div>
        </div>
      </section>

      <!-- Author Info -->
      <section class="surface p-6">
        <h3 class="text-lg font-medium text-gray-900 dark:text-gray-100 mb-4">Author Information</h3>
        <div class="space-y-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Author Name</label>
            <input
              v-model="form.authorName"
              type="text"
              class="w-full px-3.5 py-2.5 rounded-xl bg-black/5 dark:bg-white/5 text-gray-900 dark:text-gray-100 border-0 focus:ring-2 focus:ring-primary-500/50 focus:bg-white dark:focus:bg-white/10 transition-colors"
            />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Author URL</label>
            <input
              v-model="form.authorUrl"
              type="url"
              class="w-full px-3.5 py-2.5 rounded-xl bg-black/5 dark:bg-white/5 text-gray-900 dark:text-gray-100 border-0 focus:ring-2 focus:ring-primary-500/50 focus:bg-white dark:focus:bg-white/10 transition-colors"
            />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Author Email</label>
            <input
              v-model="form.authorEmail"
              type="email"
              class="w-full px-3.5 py-2.5 rounded-xl bg-black/5 dark:bg-white/5 text-gray-900 dark:text-gray-100 border-0 focus:ring-2 focus:ring-primary-500/50 focus:bg-white dark:focus:bg-white/10 transition-colors"
            />
          </div>
        </div>
      </section>

      <!-- Simple Analytics -->
      <section class="surface p-6">
        <h3 class="text-lg font-medium text-gray-900 dark:text-gray-100 mb-4">Simple Analytics</h3>
        <p class="text-sm text-gray-500 dark:text-gray-400 mb-4">
          Enable Simple Analytics to track pageviews and visitors on your published blog.
          <a href="https://simpleanalytics.com" target="_blank" class="text-primary-600 dark:text-primary-400 hover:underline">Learn more</a>
        </p>
        <div class="space-y-4">
          <div class="flex items-center gap-3">
            <input
              id="simpleAnalyticsEnabled"
              v-model="form.simpleAnalyticsEnabled"
              type="checkbox"
              class="w-5 h-5 rounded border-gray-300 text-primary-600 focus:ring-primary-500"
            />
            <label for="simpleAnalyticsEnabled" class="text-gray-700 dark:text-gray-300">
              Enable Simple Analytics tracking
            </label>
          </div>
          <div v-if="form.simpleAnalyticsEnabled">
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
              Domain Override (optional)
            </label>
            <input
              v-model="form.simpleAnalyticsDomain"
              type="text"
              class="w-full px-3.5 py-2.5 rounded-xl bg-black/5 dark:bg-white/5 text-gray-900 dark:text-gray-100 border-0 focus:ring-2 focus:ring-primary-500/50 focus:bg-white dark:focus:bg-white/10 transition-colors"
              placeholder="example.com"
            />
            <p class="mt-1 text-xs text-gray-500 dark:text-gray-400">
              Leave empty to use the domain from your Blog URL. Use this if your site is registered under a different domain in Simple Analytics.
            </p>
          </div>
        </div>
      </section>

      <!-- Save Button -->
      <div class="flex justify-between">
        <button
          type="button"
          @click="deleteBlog"
          class="px-5 py-2.5 text-red-500 dark:text-red-400 hover:bg-red-500/10 rounded-xl font-medium transition-colors"
        >
          Delete Blog
        </button>
        <button
          type="submit"
          :disabled="saving"
          class="px-6 py-2.5 bg-primary-500 text-white rounded-xl font-medium hover:bg-primary-600 transition-colors shadow-sm disabled:opacity-50"
        >
          {{ saving ? 'Saving...' : 'Save Settings' }}
        </button>
      </div>
    </form>

    <!-- Developer Tools -->
    <section class="surface p-6 mt-8">
      <h3 class="text-lg font-medium text-gray-900 dark:text-gray-100 mb-2">Developer Tools</h3>
      <p class="text-sm text-gray-500 dark:text-gray-400 mb-4">
        Export a debug bundle containing the full generated site and sync data. Useful for comparing output between iOS and Self-Hosted apps.
      </p>
      <button
        type="button"
        @click="downloadDebugExport"
        :disabled="exporting"
        class="px-5 py-2.5 bg-gray-600 text-white rounded-xl font-medium hover:bg-gray-700 transition-colors shadow-sm disabled:opacity-50"
      >
        {{ exporting ? 'Exporting...' : 'Download Debug Export' }}
      </button>
    </section>

    <!-- Publish Modal -->
    <PublishModal
      v-if="showPublishModal"
      :blog-id="blogId"
      :show="showPublishModal"
      @close="showPublishModal = false"
    />
    </div>
  </div>
</template>
