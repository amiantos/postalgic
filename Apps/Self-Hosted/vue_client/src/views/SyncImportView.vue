<script setup>
import { ref } from 'vue';
import { useRouter } from 'vue-router';
import { syncApi } from '@/api';
import { useBlogStore } from '@/stores/blog';

const router = useRouter();
const blogStore = useBlogStore();

const url = ref('');
const password = ref('');
const manifest = ref(null);
const checking = ref(false);
const importing = ref(false);
const error = ref(null);
const needsPassword = ref(false);
const importProgress = ref('');

async function checkUrl() {
  if (!url.value.trim()) {
    error.value = 'Please enter a URL';
    return;
  }

  checking.value = true;
  error.value = null;
  manifest.value = null;
  needsPassword.value = false;

  try {
    const result = await syncApi.check(url.value);
    manifest.value = result.manifest;
    needsPassword.value = result.manifest.hasDrafts;
  } catch (e) {
    error.value = e.message;
  } finally {
    checking.value = false;
  }
}

function clearManifest() {
  manifest.value = null;
  url.value = '';
  password.value = '';
  needsPassword.value = false;
  error.value = null;
}

async function importBlog() {
  if (!manifest.value) return;
  if (needsPassword.value && !password.value) {
    error.value = 'Password is required for blogs with drafts';
    return;
  }

  importing.value = true;
  error.value = null;
  importProgress.value = 'Starting import...';

  try {
    const result = await syncApi.import(url.value, password.value || null);
    // Refresh blog list
    await blogStore.fetchBlogs();
    // Navigate to the imported blog
    router.push({ name: 'blog-posts', params: { blogId: result.blogId } });
  } catch (e) {
    error.value = e.message;
    importing.value = false;
  }
}

function formatDate(dateString) {
  if (!dateString) return 'Unknown';
  return new Date(dateString).toLocaleDateString(undefined, {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit'
  });
}
</script>

<template>
  <div class="min-h-screen bg-gray-50 dark:bg-gray-900">
    <!-- Header -->
    <header class="bg-white dark:bg-gray-800 shadow-sm">
      <div class="max-w-2xl mx-auto px-4 py-6">
        <div class="flex items-center gap-4">
          <router-link to="/" class="text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-200">
            <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
            </svg>
          </router-link>
          <h1 class="text-xl font-bold text-gray-900 dark:text-gray-100">Import from URL</h1>
        </div>
      </div>
    </header>

    <!-- Content -->
    <main class="max-w-2xl mx-auto px-4 py-8">
      <div class="bg-white dark:bg-gray-800 rounded-lg shadow-sm border border-gray-200 dark:border-gray-700 p-6">
        <!-- Description -->
        <p class="text-gray-600 dark:text-gray-400 mb-6">
          Import a blog from a published Postalgic site that has sync enabled. Enter the URL of the published site to fetch its content.
        </p>

        <!-- Error -->
        <div v-if="error" class="mb-6 p-4 bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded-lg text-red-800 dark:text-red-400">
          {{ error }}
        </div>

        <!-- URL Input -->
        <div v-if="!manifest" class="mb-6">
          <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
            Published Site URL
          </label>
          <div class="flex gap-2">
            <input
              v-model="url"
              type="url"
              placeholder="https://example.com"
              class="flex-1 px-4 py-2 border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-primary-500"
              @keyup.enter="checkUrl"
              :disabled="checking"
            />
            <button
              @click="checkUrl"
              :disabled="checking || !url.trim()"
              class="px-4 py-2 bg-primary-600 text-white rounded-lg hover:bg-primary-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {{ checking ? 'Checking...' : 'Check' }}
            </button>
          </div>
          <p class="mt-2 text-sm text-gray-500 dark:text-gray-400">
            Enter the URL of a Postalgic site that has sync enabled (e.g., https://myblog.com)
          </p>
        </div>

        <!-- Checking -->
        <div v-if="checking" class="mb-6">
          <div class="border border-gray-200 dark:border-gray-700 rounded-lg p-6 text-center">
            <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-primary-600 mx-auto mb-4"></div>
            <p class="text-gray-600 dark:text-gray-400">Checking sync availability...</p>
          </div>
        </div>

        <!-- Manifest Results -->
        <div v-if="manifest && !checking" class="mb-6">
          <div class="border border-gray-200 dark:border-gray-700 rounded-lg p-6">
            <!-- Site Info -->
            <div class="flex items-start justify-between mb-4">
              <div class="flex items-center gap-3">
                <svg class="w-10 h-10 text-primary-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 12a9 9 0 01-9 9m9-9a9 9 0 00-9-9m9 9H3m9 9a9 9 0 01-9-9m9 9c1.657 0 3-4.03 3-9s-1.343-9-3-9m0 18c-1.657 0-3-4.03-3-9s1.343-9 3-9m-9 9a9 9 0 019-9" />
                </svg>
                <div>
                  <p class="font-medium text-gray-900 dark:text-gray-100">{{ manifest.blogName }}</p>
                  <p class="text-sm text-gray-500 dark:text-gray-400">{{ url }}</p>
                </div>
              </div>
              <button
                @click="clearManifest"
                class="text-gray-400 hover:text-gray-600 dark:hover:text-gray-300"
              >
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>
            </div>

            <!-- Sync Info -->
            <div class="bg-gray-50 dark:bg-gray-700/50 rounded-lg p-4 mb-4">
              <div class="grid grid-cols-2 gap-4 text-sm">
                <div>
                  <p class="text-gray-500 dark:text-gray-400">Last Modified</p>
                  <p class="font-medium text-gray-900 dark:text-gray-100">{{ formatDate(manifest.lastModified) }}</p>
                </div>
                <div>
                  <p class="text-gray-500 dark:text-gray-400">Source</p>
                  <p class="font-medium text-gray-900 dark:text-gray-100">{{ manifest.appSource || 'Postalgic' }}</p>
                </div>
                <div>
                  <p class="text-gray-500 dark:text-gray-400">Files</p>
                  <p class="font-medium text-gray-900 dark:text-gray-100">{{ manifest.fileCount }} files</p>
                </div>
                <div>
                  <p class="text-gray-500 dark:text-gray-400">Has Drafts</p>
                  <p class="font-medium text-gray-900 dark:text-gray-100">{{ manifest.hasDrafts ? 'Yes (encrypted)' : 'No' }}</p>
                </div>
              </div>
            </div>

            <!-- Password Input (if needed) -->
            <div v-if="needsPassword" class="mb-4">
              <div class="bg-yellow-50 dark:bg-yellow-900/20 border border-yellow-200 dark:border-yellow-800 rounded-lg p-4 mb-4">
                <div class="flex items-start gap-3">
                  <svg class="w-5 h-5 text-yellow-600 dark:text-yellow-500 mt-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
                  </svg>
                  <div>
                    <p class="font-medium text-yellow-800 dark:text-yellow-400">Password Required</p>
                    <p class="text-sm text-yellow-700 dark:text-yellow-500 mt-1">This blog has encrypted drafts. Enter the sync password to import them.</p>
                  </div>
                </div>
              </div>
              <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                Sync Password
              </label>
              <input
                v-model="password"
                type="password"
                placeholder="Enter sync password"
                class="w-full px-4 py-2 border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-primary-500"
                :disabled="importing"
              />
            </div>

            <!-- Import Progress -->
            <div v-if="importing" class="mb-4">
              <div class="bg-primary-50 dark:bg-primary-900/20 border border-primary-200 dark:border-primary-800 rounded-lg p-4">
                <div class="flex items-center gap-3">
                  <div class="animate-spin rounded-full h-5 w-5 border-b-2 border-primary-600"></div>
                  <p class="text-primary-800 dark:text-primary-400">{{ importProgress || 'Importing blog...' }}</p>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Actions -->
        <div class="flex justify-end gap-3 pt-4">
          <router-link
            to="/"
            class="px-4 py-2 text-gray-700 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-700 rounded-lg transition-colors"
          >
            Cancel
          </router-link>
          <button
            v-if="manifest"
            @click="importBlog"
            :disabled="importing || (needsPassword && !password)"
            class="px-4 py-2 bg-primary-600 text-white rounded-lg hover:bg-primary-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {{ importing ? 'Importing...' : 'Import Blog' }}
          </button>
        </div>
      </div>
    </main>
  </div>
</template>
