<script setup>
import { ref, computed, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useBlogStore } from '@/stores/blog';
import { blogApi } from '@/api';

const route = useRoute();
const router = useRouter();
const blogStore = useBlogStore();

const blogId = computed(() => route.params.blogId);

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
  <div>
    <!-- Messages -->
    <div v-if="error" class="mb-6 p-4 border border-red-500 font-mono text-sm text-red-600">
      {{ error }}
    </div>
    <div v-if="success" class="mb-6 p-4 border border-green-500 font-mono text-sm text-green-600">
      Settings saved successfully!
    </div>

    <form @submit.prevent="saveSettings" class="space-y-8">
      <!-- Basic Info -->
      <section>
        <h3 class="font-mono text-sm text-site-dark uppercase tracking-wider mb-4">Basic Information</h3>
        <div class="space-y-4">
          <div>
            <label class="block font-mono text-xs text-site-medium uppercase tracking-wider mb-2">Blog Name</label>
            <input
              v-model="form.name"
              type="text"
              class="w-full px-3 py-2 border border-site-light focus:outline-none focus:border-site-accent"
            />
          </div>
          <div>
            <label class="block font-mono text-xs text-site-medium uppercase tracking-wider mb-2">Blog URL</label>
            <input
              v-model="form.url"
              type="url"
              class="w-full px-3 py-2 border border-site-light font-mono text-sm focus:outline-none focus:border-site-accent"
              placeholder="https://myblog.com"
            />
          </div>
          <div>
            <label class="block font-mono text-xs text-site-medium uppercase tracking-wider mb-2">Tagline</label>
            <input
              v-model="form.tagline"
              type="text"
              class="w-full px-3 py-2 border border-site-light focus:outline-none focus:border-site-accent"
            />
          </div>
          <div>
            <label class="block font-mono text-xs text-site-medium uppercase tracking-wider mb-2">Timezone</label>
            <select
              v-model="form.timezone"
              class="w-full px-3 py-2 border border-site-light font-mono text-sm focus:outline-none focus:border-site-accent"
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
            <p class="mt-2 font-mono text-xs text-site-medium">Dates on your published blog will display in this timezone</p>
          </div>
        </div>
      </section>

      <!-- Author Info -->
      <section class="border-t border-site-light pt-8">
        <h3 class="font-mono text-sm text-site-dark uppercase tracking-wider mb-4">Author Information</h3>
        <div class="space-y-4">
          <div>
            <label class="block font-mono text-xs text-site-medium uppercase tracking-wider mb-2">Author Name</label>
            <input
              v-model="form.authorName"
              type="text"
              class="w-full px-3 py-2 border border-site-light focus:outline-none focus:border-site-accent"
            />
          </div>
          <div>
            <label class="block font-mono text-xs text-site-medium uppercase tracking-wider mb-2">Author URL</label>
            <input
              v-model="form.authorUrl"
              type="url"
              class="w-full px-3 py-2 border border-site-light font-mono text-sm focus:outline-none focus:border-site-accent"
            />
          </div>
          <div>
            <label class="block font-mono text-xs text-site-medium uppercase tracking-wider mb-2">Author Email</label>
            <input
              v-model="form.authorEmail"
              type="email"
              class="w-full px-3 py-2 border border-site-light font-mono text-sm focus:outline-none focus:border-site-accent"
            />
          </div>
        </div>
      </section>

      <!-- Simple Analytics -->
      <section class="border-t border-site-light pt-8">
        <h3 class="font-mono text-sm text-site-dark uppercase tracking-wider mb-2">Simple Analytics</h3>
        <p class="text-sm text-site-dark mb-4">
          Enable Simple Analytics to track pageviews and visitors on your published blog.
          <a href="https://simpleanalytics.com" target="_blank" class="text-site-accent hover:text-site-accent">Learn more</a>
        </p>
        <div class="space-y-4">
          <label class="flex items-center gap-3">
            <input
              v-model="form.simpleAnalyticsEnabled"
              type="checkbox"
              class="border border-site-light"
            />
            <span class="text-sm text-site-dark">
              Enable Simple Analytics tracking
            </span>
          </label>
          <div v-if="form.simpleAnalyticsEnabled">
            <label class="block font-mono text-xs text-site-medium uppercase tracking-wider mb-2">
              Domain Override (optional)
            </label>
            <input
              v-model="form.simpleAnalyticsDomain"
              type="text"
              class="w-full px-3 py-2 border border-site-light font-mono text-sm focus:outline-none focus:border-site-accent"
              placeholder="example.com"
            />
            <p class="mt-2 font-mono text-xs text-site-medium">
              Leave empty to use the domain from your Blog URL. Use this if your site is registered under a different domain in Simple Analytics.
            </p>
          </div>
        </div>
      </section>

      <!-- Actions -->
      <section class="border-t border-site-light pt-8">
        <div class="flex justify-between">
          <button
            type="button"
            @click="deleteBlog"
            class="font-mono text-sm text-red-500 hover:text-red-400 uppercase tracking-wider"
          >
            Delete Blog
          </button>
          <button
            type="submit"
            :disabled="saving"
            class="px-4 py-2 border border-site-accent bg-site-accent font-mono text-sm text-white hover:bg-[#e89200] hover:border-[#e89200] uppercase tracking-wider disabled:opacity-50"
          >
            {{ saving ? 'Saving...' : 'Save Settings' }}
          </button>
        </div>
      </section>
    </form>

    <!-- Developer Tools -->
    <section class="border-t border-site-light pt-8 mt-8">
      <h3 class="font-mono text-sm text-site-dark uppercase tracking-wider mb-2">Developer Tools</h3>
      <p class="text-sm text-site-dark mb-4">
        Export a debug bundle containing the full generated site and sync data. Useful for comparing output between iOS and Self-Hosted apps.
      </p>
      <button
        type="button"
        @click="downloadDebugExport"
        :disabled="exporting"
        class="px-4 py-2 border border-site-dark font-mono text-sm text-site-dark hover:border-site-accent hover:text-site-accent uppercase tracking-wider disabled:opacity-50"
      >
        {{ exporting ? 'Exporting...' : 'Download Debug Export' }}
      </button>
    </section>
  </div>
</template>
