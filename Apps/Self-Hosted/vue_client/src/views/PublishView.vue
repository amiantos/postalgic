<script setup>
import { ref, computed, onMounted } from 'vue';
import { useRoute } from 'vue-router';
import { useBlogStore } from '@/stores/blog';
import { publishApi } from '@/api';
import PageToolbar from '@/components/PageToolbar.vue';

const route = useRoute();
const blogStore = useBlogStore();

const blogId = computed(() => route.params.blogId);
const publisherType = computed(() => blogStore.currentBlog?.publisherType || 'manual');

const generating = ref(false);
const downloading = ref(false);
const publishing = ref(false);
const error = ref(null);
const successMessage = ref(null);
const previewUrl = ref(null);
const publishStatus = ref(null);
const changes = ref(null);
const showNewFiles = ref(false);
const showModifiedFiles = ref(false);
const showDeletedFiles = ref(false);

onMounted(async () => {
  await loadStatus();
});

async function loadStatus() {
  try {
    publishStatus.value = await publishApi.status(blogId.value);
  } catch (e) {
    console.error('Failed to load publish status:', e);
  }
}

async function generateSite() {
  generating.value = true;
  error.value = null;

  try {
    const result = await blogStore.generateSite(blogId.value);
    previewUrl.value = result.previewUrl;

    // Check for changes
    changes.value = await publishApi.changes(blogId.value);
  } catch (e) {
    error.value = e.message;
  } finally {
    generating.value = false;
  }
}

async function downloadSite() {
  downloading.value = true;
  error.value = null;

  try {
    const { blob, filename } = await blogStore.downloadSite(blogId.value);

    // Create download link
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);

    // Mark as published
    await publishApi.markPublished(blogId.value);
    await loadStatus();
  } catch (e) {
    error.value = e.message;
  } finally {
    downloading.value = false;
  }
}

async function publishToAWS(forceUploadAll = false) {
  publishing.value = true;
  error.value = null;
  successMessage.value = null;

  try {
    const result = await publishApi.publishToAWS(blogId.value, { forceUploadAll });
    successMessage.value = result.message;
    await loadStatus();
  } catch (e) {
    error.value = e.message;
  } finally {
    publishing.value = false;
  }
}

async function publishToSFTP(forceUploadAll = false) {
  publishing.value = true;
  error.value = null;
  successMessage.value = null;

  try {
    const result = await publishApi.publishToSFTP(blogId.value, { forceUploadAll });
    successMessage.value = result.message;
    await loadStatus();
  } catch (e) {
    error.value = e.message;
  } finally {
    publishing.value = false;
  }
}

async function publishToGit() {
  publishing.value = true;
  error.value = null;
  successMessage.value = null;

  try {
    const result = await publishApi.publishToGit(blogId.value);
    successMessage.value = result.message;
    await loadStatus();
  } catch (e) {
    error.value = e.message;
  } finally {
    publishing.value = false;
  }
}

function openPreview() {
  if (previewUrl.value) {
    window.open(previewUrl.value, '_blank');
  }
}

function getPublisherLabel(type) {
  const labels = {
    manual: 'Manual (ZIP)',
    aws: 'AWS S3',
    sftp: 'SFTP',
    git: 'Git'
  };
  return labels[type] || type;
}
</script>

<template>
  <div>
    <PageToolbar title="Publish" />

    <div class="px-6 pb-6">
    <!-- Error -->
    <div v-if="error" class="mb-6 p-4 bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded-lg text-red-800 dark:text-red-400">
      {{ error }}
    </div>

    <!-- Success -->
    <div v-if="successMessage" class="mb-6 p-4 bg-green-50 dark:bg-green-900/20 border border-green-200 dark:border-green-800 rounded-lg text-green-800 dark:text-green-400">
      {{ successMessage }}
    </div>

    <!-- Blog URL Warning -->
    <div v-if="!blogStore.currentBlog?.url" class="mb-6 p-4 bg-yellow-50 dark:bg-yellow-900/30 border border-yellow-200 dark:border-yellow-700 rounded-lg">
      <div class="flex items-start gap-3">
        <svg class="w-5 h-5 text-yellow-600 dark:text-yellow-400 mt-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
        </svg>
        <div>
          <p class="text-yellow-800 dark:text-yellow-300 font-medium">Blog URL not set</p>
          <p class="text-yellow-700 dark:text-yellow-400 text-sm mt-1">
            Set your blog URL in Settings for correct links in your generated site.
          </p>
        </div>
      </div>
    </div>

    <!-- Stats -->
    <div class="bg-white dark:bg-gray-800 rounded-lg border border-gray-200 dark:border-gray-700 p-6 mb-6">
      <h3 class="font-medium text-gray-900 dark:text-gray-100 mb-4">Content Summary</h3>
      <div class="grid grid-cols-3 gap-4">
        <div class="text-center">
          <p class="text-2xl font-bold text-primary-600 dark:text-primary-400">{{ blogStore.publishedPosts.length }}</p>
          <p class="text-sm text-gray-500 dark:text-gray-400">Published Posts</p>
        </div>
        <div class="text-center">
          <p class="text-2xl font-bold text-gray-900 dark:text-gray-100">{{ blogStore.categories.length }}</p>
          <p class="text-sm text-gray-500 dark:text-gray-400">Categories</p>
        </div>
        <div class="text-center">
          <p class="text-2xl font-bold text-gray-900 dark:text-gray-100">{{ blogStore.tags.length }}</p>
          <p class="text-sm text-gray-500 dark:text-gray-400">Tags</p>
        </div>
      </div>
    </div>

    <!-- Last Published -->
    <div v-if="publishStatus?.lastPublishedDate" class="bg-white dark:bg-gray-800 rounded-lg border border-gray-200 dark:border-gray-700 p-6 mb-6">
      <h3 class="font-medium text-gray-900 dark:text-gray-100 mb-2">Last Published</h3>
      <p class="text-gray-600 dark:text-gray-400">{{ new Date(publishStatus.lastPublishedDate).toLocaleString() }}</p>
      <p class="text-sm text-gray-500 dark:text-gray-400 mt-1">
        {{ publishStatus.fileCount }} files via {{ getPublisherLabel(publishStatus.publisherType) }}
      </p>
    </div>

    <!-- Publisher Type Info -->
    <div class="bg-white dark:bg-gray-800 rounded-lg border border-gray-200 dark:border-gray-700 p-6 mb-6">
      <div class="flex items-center justify-between">
        <div>
          <h3 class="font-medium text-gray-900 dark:text-gray-100">Publishing Method</h3>
          <p class="text-sm text-gray-500 dark:text-gray-400">{{ getPublisherLabel(publisherType) }}</p>
        </div>
        <router-link
          :to="`/blogs/${blogId}/settings`"
          class="text-sm text-primary-600 dark:text-primary-400 hover:text-primary-700 dark:hover:text-primary-300"
        >
          Change in Settings
        </router-link>
      </div>
    </div>

    <!-- Actions -->
    <div class="bg-white dark:bg-gray-800 rounded-lg border border-gray-200 dark:border-gray-700 p-6 space-y-4">
      <h3 class="font-medium text-gray-900 dark:text-gray-100 mb-4">Generate & Publish</h3>

      <!-- Step 1: Generate -->
      <div class="flex items-center justify-between p-4 bg-gray-50 dark:bg-gray-700 rounded-lg">
        <div>
          <p class="font-medium text-gray-900 dark:text-gray-100">1. Generate Site</p>
          <p class="text-sm text-gray-500 dark:text-gray-400">Build your static site for preview</p>
        </div>
        <button
          @click="generateSite"
          :disabled="generating"
          class="px-4 py-2 bg-primary-600 text-white rounded-lg hover:bg-primary-700 transition-colors disabled:opacity-50"
        >
          {{ generating ? 'Generating...' : 'Generate' }}
        </button>
      </div>

      <!-- Preview Button -->
      <div v-if="previewUrl" class="flex items-center justify-between p-4 bg-green-50 dark:bg-green-900/30 rounded-lg">
        <div>
          <p class="font-medium text-green-900 dark:text-green-300">Site Generated!</p>
          <p class="text-sm text-green-700 dark:text-green-400">Preview your site before publishing</p>
        </div>
        <button
          @click="openPreview"
          class="px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition-colors"
        >
          Open Preview
        </button>
      </div>

      <!-- Manual Download -->
      <div v-if="publisherType === 'manual'" class="flex items-center justify-between p-4 bg-gray-50 dark:bg-gray-700 rounded-lg">
        <div>
          <p class="font-medium text-gray-900 dark:text-gray-100">2. Download ZIP</p>
          <p class="text-sm text-gray-500 dark:text-gray-400">Download your site as a ZIP archive</p>
        </div>
        <button
          @click="downloadSite"
          :disabled="downloading || blogStore.publishedPosts.length === 0"
          class="px-4 py-2 bg-gray-800 dark:bg-gray-600 text-white rounded-lg hover:bg-gray-900 dark:hover:bg-gray-500 transition-colors disabled:opacity-50"
        >
          {{ downloading ? 'Downloading...' : 'Download ZIP' }}
        </button>
      </div>

      <!-- AWS Publish -->
      <div v-if="publisherType === 'aws'" class="flex items-center justify-between p-4 bg-gray-50 dark:bg-gray-700 rounded-lg">
        <div>
          <p class="font-medium text-gray-900 dark:text-gray-100">2. Publish to AWS S3</p>
          <p class="text-sm text-gray-500 dark:text-gray-400">Upload directly to your S3 bucket</p>
        </div>
        <div class="flex gap-2">
          <button
            @click="publishToAWS(false)"
            :disabled="publishing || blogStore.publishedPosts.length === 0"
            class="px-4 py-2 bg-orange-600 text-white rounded-lg hover:bg-orange-700 transition-colors disabled:opacity-50"
          >
            {{ publishing ? 'Publishing...' : 'Publish' }}
          </button>
          <button
            @click="publishToAWS(true)"
            :disabled="publishing || blogStore.publishedPosts.length === 0"
            class="px-4 py-2 bg-orange-800 text-white rounded-lg hover:bg-orange-900 transition-colors disabled:opacity-50"
            title="Re-upload all files, even if they already exist in S3"
          >
            {{ publishing ? 'Publishing...' : 'Full Publish' }}
          </button>
        </div>
      </div>

      <!-- SFTP Publish -->
      <div v-if="publisherType === 'sftp'" class="flex items-center justify-between p-4 bg-gray-50 dark:bg-gray-700 rounded-lg">
        <div>
          <p class="font-medium text-gray-900 dark:text-gray-100">2. Publish via SFTP</p>
          <p class="text-sm text-gray-500 dark:text-gray-400">Upload directly to your server</p>
        </div>
        <div class="flex gap-2">
          <button
            @click="publishToSFTP(false)"
            :disabled="publishing || blogStore.publishedPosts.length === 0"
            class="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors disabled:opacity-50"
          >
            {{ publishing ? 'Publishing...' : 'Publish' }}
          </button>
          <button
            @click="publishToSFTP(true)"
            :disabled="publishing || blogStore.publishedPosts.length === 0"
            class="px-4 py-2 bg-blue-800 text-white rounded-lg hover:bg-blue-900 transition-colors disabled:opacity-50"
            title="Re-upload all files, even if they already exist on the server"
          >
            {{ publishing ? 'Publishing...' : 'Full Publish' }}
          </button>
        </div>
      </div>

      <!-- Git Publish -->
      <div v-if="publisherType === 'git'" class="flex items-center justify-between p-4 bg-gray-50 dark:bg-gray-700 rounded-lg">
        <div>
          <p class="font-medium text-gray-900 dark:text-gray-100">2. Publish to Git</p>
          <p class="text-sm text-gray-500 dark:text-gray-400">Push to your Git repository</p>
        </div>
        <button
          @click="publishToGit"
          :disabled="publishing || blogStore.publishedPosts.length === 0"
          class="px-4 py-2 bg-gray-800 dark:bg-gray-600 text-white rounded-lg hover:bg-gray-900 dark:hover:bg-gray-500 transition-colors disabled:opacity-50"
        >
          {{ publishing ? 'Publishing...' : 'Push to Git' }}
        </button>
      </div>

      <!-- Changes Summary -->
      <div v-if="changes" class="p-4 bg-gray-50 dark:bg-gray-700 rounded-lg">
        <p class="font-medium text-gray-900 dark:text-gray-100 mb-3">Changes Since Last Publish</p>

        <!-- Summary -->
        <div class="text-sm mb-3 p-3 bg-white dark:bg-gray-800 rounded-lg">
          <div class="flex flex-wrap gap-3 text-center">
            <div v-if="changes.newFiles.length > 0" class="flex items-center gap-1 text-green-600 dark:text-green-400">
              <span class="font-semibold">+{{ changes.newFiles.length }}</span> new
            </div>
            <div v-if="changes.modifiedFiles.length > 0" class="flex items-center gap-1 text-yellow-600 dark:text-yellow-400">
              <span class="font-semibold">~{{ changes.modifiedFiles.length }}</span> modified
            </div>
            <div v-if="changes.deletedFiles.length > 0" class="flex items-center gap-1 text-red-600 dark:text-red-400">
              <span class="font-semibold">-{{ changes.deletedFiles.length }}</span> deleted
            </div>
            <div v-if="changes.unchangedCount > 0" class="flex items-center gap-1 text-gray-500 dark:text-gray-400">
              <span class="font-semibold">{{ changes.unchangedCount }}</span> unchanged
            </div>
          </div>
          <p v-if="!changes.hasChanges" class="text-gray-500 dark:text-gray-400 mt-2">
            No changes since last publish
          </p>
        </div>

        <!-- Expandable File Lists -->
        <div class="space-y-2">
          <!-- New Files -->
          <div v-if="changes.newFiles.length > 0">
            <button
              @click="showNewFiles = !showNewFiles"
              class="flex items-center gap-2 text-sm font-medium text-green-600 dark:text-green-400 hover:text-green-700 dark:hover:text-green-300"
            >
              <svg :class="{ 'rotate-90': showNewFiles }" class="w-4 h-4 transition-transform" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
              </svg>
              New files ({{ changes.newFiles.length }})
            </button>
            <div v-if="showNewFiles" class="mt-2 ml-6 text-xs text-gray-600 dark:text-gray-400 max-h-40 overflow-y-auto bg-white dark:bg-gray-800 rounded p-2">
              <div v-for="file in changes.newFiles" :key="file" class="py-0.5 truncate">{{ file }}</div>
            </div>
          </div>

          <!-- Modified Files -->
          <div v-if="changes.modifiedFiles.length > 0">
            <button
              @click="showModifiedFiles = !showModifiedFiles"
              class="flex items-center gap-2 text-sm font-medium text-yellow-600 dark:text-yellow-400 hover:text-yellow-700 dark:hover:text-yellow-300"
            >
              <svg :class="{ 'rotate-90': showModifiedFiles }" class="w-4 h-4 transition-transform" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
              </svg>
              Modified files ({{ changes.modifiedFiles.length }})
            </button>
            <div v-if="showModifiedFiles" class="mt-2 ml-6 text-xs text-gray-600 dark:text-gray-400 max-h-40 overflow-y-auto bg-white dark:bg-gray-800 rounded p-2">
              <div v-for="file in changes.modifiedFiles" :key="file" class="py-0.5 truncate">{{ file }}</div>
            </div>
          </div>

          <!-- Deleted Files -->
          <div v-if="changes.deletedFiles.length > 0">
            <button
              @click="showDeletedFiles = !showDeletedFiles"
              class="flex items-center gap-2 text-sm font-medium text-red-600 dark:text-red-400 hover:text-red-700 dark:hover:text-red-300"
            >
              <svg :class="{ 'rotate-90': showDeletedFiles }" class="w-4 h-4 transition-transform" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
              </svg>
              Deleted files ({{ changes.deletedFiles.length }})
            </button>
            <div v-if="showDeletedFiles" class="mt-2 ml-6 text-xs text-gray-600 dark:text-gray-400 max-h-40 overflow-y-auto bg-white dark:bg-gray-800 rounded p-2">
              <div v-for="file in changes.deletedFiles" :key="file" class="py-0.5 truncate">{{ file }}</div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Help Text -->
    <div class="mt-6 p-4 bg-gray-50 dark:bg-gray-800 rounded-lg">
      <h4 class="font-medium text-gray-900 dark:text-gray-100 mb-2">How to Deploy</h4>
      <div v-if="publisherType === 'manual'">
        <ol class="text-sm text-gray-600 dark:text-gray-400 space-y-2 list-decimal list-inside">
          <li>Generate and preview your site to make sure everything looks correct</li>
          <li>Download the ZIP file containing your complete static site</li>
          <li>Extract and upload the files to your web hosting provider</li>
          <li>Your blog is now live!</li>
        </ol>
      </div>
      <div v-else-if="publisherType === 'aws'">
        <ol class="text-sm text-gray-600 dark:text-gray-400 space-y-2 list-decimal list-inside">
          <li>Configure your AWS S3 bucket and credentials in Settings</li>
          <li>Generate and preview your site</li>
          <li>Click Publish to upload to S3</li>
          <li>CloudFront cache is automatically invalidated (if configured)</li>
        </ol>
      </div>
      <div v-else-if="publisherType === 'sftp'">
        <ol class="text-sm text-gray-600 dark:text-gray-400 space-y-2 list-decimal list-inside">
          <li>Configure your SFTP connection details in Settings</li>
          <li>Generate and preview your site</li>
          <li>Click Publish to upload to your server</li>
          <li>Files are synced directly to your remote path</li>
        </ol>
      </div>
      <div v-else-if="publisherType === 'git'">
        <ol class="text-sm text-gray-600 dark:text-gray-400 space-y-2 list-decimal list-inside">
          <li>Configure your Git repository URL and credentials in Settings</li>
          <li>Generate and preview your site</li>
          <li>Click Publish to commit and push changes</li>
          <li>Your site is deployed via GitHub Pages or similar</li>
        </ol>
      </div>
    </div>
    </div>
  </div>
</template>
