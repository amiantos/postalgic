<script setup>
import { ref, computed, onMounted } from 'vue';
import { useRoute } from 'vue-router';
import { useBlogStore } from '@/stores/blog';
import { publishApi } from '@/api';

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

// Credentials (not stored, entered at publish time)
const awsSecretKey = ref('');
const sftpPassword = ref('');
const sftpPrivateKey = ref('');
const gitToken = ref('');

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

async function publishToAWS() {
  if (!awsSecretKey.value) {
    error.value = 'AWS Secret Access Key is required';
    return;
  }

  publishing.value = true;
  error.value = null;
  successMessage.value = null;

  try {
    const result = await publishApi.publishToAWS(blogId.value, awsSecretKey.value);
    successMessage.value = result.message;
    awsSecretKey.value = '';
    await loadStatus();
  } catch (e) {
    error.value = e.message;
  } finally {
    publishing.value = false;
  }
}

async function publishToSFTP() {
  if (!sftpPassword.value && !sftpPrivateKey.value) {
    error.value = 'Password or Private Key is required';
    return;
  }

  publishing.value = true;
  error.value = null;
  successMessage.value = null;

  try {
    const credentials = {};
    if (sftpPassword.value) credentials.password = sftpPassword.value;
    if (sftpPrivateKey.value) credentials.privateKey = sftpPrivateKey.value;

    const result = await publishApi.publishToSFTP(blogId.value, credentials);
    successMessage.value = result.message;
    sftpPassword.value = '';
    sftpPrivateKey.value = '';
    await loadStatus();
  } catch (e) {
    error.value = e.message;
  } finally {
    publishing.value = false;
  }
}

async function publishToGit() {
  if (!gitToken.value) {
    error.value = 'Git Personal Access Token is required';
    return;
  }

  publishing.value = true;
  error.value = null;
  successMessage.value = null;

  try {
    const result = await publishApi.publishToGit(blogId.value, gitToken.value);
    successMessage.value = result.message;
    gitToken.value = '';
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
  <div class="p-6 max-w-2xl">
    <h2 class="text-xl font-bold text-gray-900 mb-6">Publish</h2>

    <!-- Error -->
    <div v-if="error" class="mb-6 p-4 bg-red-50 border border-red-200 rounded-lg text-red-800">
      {{ error }}
    </div>

    <!-- Success -->
    <div v-if="successMessage" class="mb-6 p-4 bg-green-50 border border-green-200 rounded-lg text-green-800">
      {{ successMessage }}
    </div>

    <!-- Blog URL Warning -->
    <div v-if="!blogStore.currentBlog?.url" class="mb-6 p-4 bg-yellow-50 border border-yellow-200 rounded-lg">
      <div class="flex items-start gap-3">
        <svg class="w-5 h-5 text-yellow-600 mt-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
        </svg>
        <div>
          <p class="text-yellow-800 font-medium">Blog URL not set</p>
          <p class="text-yellow-700 text-sm mt-1">
            Set your blog URL in Settings for correct links in your generated site.
          </p>
        </div>
      </div>
    </div>

    <!-- Stats -->
    <div class="bg-white rounded-lg border border-gray-200 p-6 mb-6">
      <h3 class="font-medium text-gray-900 mb-4">Content Summary</h3>
      <div class="grid grid-cols-3 gap-4">
        <div class="text-center">
          <p class="text-2xl font-bold text-primary-600">{{ blogStore.publishedPosts.length }}</p>
          <p class="text-sm text-gray-500">Published Posts</p>
        </div>
        <div class="text-center">
          <p class="text-2xl font-bold text-gray-900">{{ blogStore.categories.length }}</p>
          <p class="text-sm text-gray-500">Categories</p>
        </div>
        <div class="text-center">
          <p class="text-2xl font-bold text-gray-900">{{ blogStore.tags.length }}</p>
          <p class="text-sm text-gray-500">Tags</p>
        </div>
      </div>
    </div>

    <!-- Last Published -->
    <div v-if="publishStatus?.lastPublishedDate" class="bg-white rounded-lg border border-gray-200 p-6 mb-6">
      <h3 class="font-medium text-gray-900 mb-2">Last Published</h3>
      <p class="text-gray-600">{{ new Date(publishStatus.lastPublishedDate).toLocaleString() }}</p>
      <p class="text-sm text-gray-500 mt-1">
        {{ publishStatus.fileCount }} files via {{ getPublisherLabel(publishStatus.publisherType) }}
      </p>
    </div>

    <!-- Publisher Type Info -->
    <div class="bg-white rounded-lg border border-gray-200 p-6 mb-6">
      <div class="flex items-center justify-between">
        <div>
          <h3 class="font-medium text-gray-900">Publishing Method</h3>
          <p class="text-sm text-gray-500">{{ getPublisherLabel(publisherType) }}</p>
        </div>
        <router-link
          :to="`/blogs/${blogId}/settings`"
          class="text-sm text-primary-600 hover:text-primary-700"
        >
          Change in Settings
        </router-link>
      </div>
    </div>

    <!-- Actions -->
    <div class="bg-white rounded-lg border border-gray-200 p-6 space-y-4">
      <h3 class="font-medium text-gray-900 mb-4">Generate & Publish</h3>

      <!-- Step 1: Generate -->
      <div class="flex items-center justify-between p-4 bg-gray-50 rounded-lg">
        <div>
          <p class="font-medium text-gray-900">1. Generate Site</p>
          <p class="text-sm text-gray-500">Build your static site for preview</p>
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
      <div v-if="previewUrl" class="flex items-center justify-between p-4 bg-green-50 rounded-lg">
        <div>
          <p class="font-medium text-green-900">Site Generated!</p>
          <p class="text-sm text-green-700">Preview your site before publishing</p>
        </div>
        <button
          @click="openPreview"
          class="px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition-colors"
        >
          Open Preview
        </button>
      </div>

      <!-- Manual Download -->
      <div v-if="publisherType === 'manual'" class="flex items-center justify-between p-4 bg-gray-50 rounded-lg">
        <div>
          <p class="font-medium text-gray-900">2. Download ZIP</p>
          <p class="text-sm text-gray-500">Download your site as a ZIP archive</p>
        </div>
        <button
          @click="downloadSite"
          :disabled="downloading || blogStore.publishedPosts.length === 0"
          class="px-4 py-2 bg-gray-800 text-white rounded-lg hover:bg-gray-900 transition-colors disabled:opacity-50"
        >
          {{ downloading ? 'Downloading...' : 'Download ZIP' }}
        </button>
      </div>

      <!-- AWS Publish -->
      <div v-if="publisherType === 'aws'" class="p-4 bg-gray-50 rounded-lg space-y-3">
        <div>
          <p class="font-medium text-gray-900">2. Publish to AWS S3</p>
          <p class="text-sm text-gray-500">Upload directly to your S3 bucket</p>
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Secret Access Key</label>
          <input
            v-model="awsSecretKey"
            type="password"
            class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-primary-500"
            placeholder="Enter your AWS secret access key"
          />
        </div>
        <button
          @click="publishToAWS"
          :disabled="publishing || blogStore.publishedPosts.length === 0"
          class="w-full px-4 py-2 bg-orange-600 text-white rounded-lg hover:bg-orange-700 transition-colors disabled:opacity-50"
        >
          {{ publishing ? 'Publishing...' : 'Publish to S3' }}
        </button>
      </div>

      <!-- SFTP Publish -->
      <div v-if="publisherType === 'sftp'" class="p-4 bg-gray-50 rounded-lg space-y-3">
        <div>
          <p class="font-medium text-gray-900">2. Publish via SFTP</p>
          <p class="text-sm text-gray-500">Upload directly to your server</p>
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Password</label>
          <input
            v-model="sftpPassword"
            type="password"
            class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-primary-500"
            placeholder="Enter your SFTP password"
          />
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Or Private Key</label>
          <textarea
            v-model="sftpPrivateKey"
            rows="3"
            class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-primary-500 font-mono text-xs"
            placeholder="Paste your private key here..."
          ></textarea>
        </div>
        <button
          @click="publishToSFTP"
          :disabled="publishing || blogStore.publishedPosts.length === 0"
          class="w-full px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors disabled:opacity-50"
        >
          {{ publishing ? 'Publishing...' : 'Publish via SFTP' }}
        </button>
      </div>

      <!-- Git Publish -->
      <div v-if="publisherType === 'git'" class="p-4 bg-gray-50 rounded-lg space-y-3">
        <div>
          <p class="font-medium text-gray-900">2. Publish to Git</p>
          <p class="text-sm text-gray-500">Push to your Git repository</p>
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Personal Access Token</label>
          <input
            v-model="gitToken"
            type="password"
            class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-primary-500"
            placeholder="Enter your Git personal access token"
          />
        </div>
        <button
          @click="publishToGit"
          :disabled="publishing || blogStore.publishedPosts.length === 0"
          class="w-full px-4 py-2 bg-gray-800 text-white rounded-lg hover:bg-gray-900 transition-colors disabled:opacity-50"
        >
          {{ publishing ? 'Publishing...' : 'Push to Git' }}
        </button>
      </div>

      <!-- Changes Summary -->
      <div v-if="changes" class="p-4 bg-gray-50 rounded-lg">
        <p class="font-medium text-gray-900 mb-2">Changes Since Last Publish</p>
        <div class="text-sm space-y-1">
          <p v-if="changes.newFiles.length > 0" class="text-green-600">
            + {{ changes.newFiles.length }} new files
          </p>
          <p v-if="changes.modifiedFiles.length > 0" class="text-yellow-600">
            ~ {{ changes.modifiedFiles.length }} modified files
          </p>
          <p v-if="changes.deletedFiles.length > 0" class="text-red-600">
            - {{ changes.deletedFiles.length }} deleted files
          </p>
          <p v-if="!changes.hasChanges" class="text-gray-500">
            No changes since last publish
          </p>
        </div>
      </div>
    </div>

    <!-- Help Text -->
    <div class="mt-6 p-4 bg-gray-50 rounded-lg">
      <h4 class="font-medium text-gray-900 mb-2">How to Deploy</h4>
      <div v-if="publisherType === 'manual'">
        <ol class="text-sm text-gray-600 space-y-2 list-decimal list-inside">
          <li>Generate and preview your site to make sure everything looks correct</li>
          <li>Download the ZIP file containing your complete static site</li>
          <li>Extract and upload the files to your web hosting provider</li>
          <li>Your blog is now live!</li>
        </ol>
      </div>
      <div v-else-if="publisherType === 'aws'">
        <ol class="text-sm text-gray-600 space-y-2 list-decimal list-inside">
          <li>Configure your AWS S3 bucket and credentials in Settings</li>
          <li>Generate and preview your site</li>
          <li>Enter your secret access key and click Publish</li>
          <li>Files are uploaded to S3 and CloudFront cache is invalidated (if configured)</li>
        </ol>
      </div>
      <div v-else-if="publisherType === 'sftp'">
        <ol class="text-sm text-gray-600 space-y-2 list-decimal list-inside">
          <li>Configure your SFTP connection details in Settings</li>
          <li>Generate and preview your site</li>
          <li>Enter your password or private key and click Publish</li>
          <li>Files are uploaded directly to your server</li>
        </ol>
      </div>
      <div v-else-if="publisherType === 'git'">
        <ol class="text-sm text-gray-600 space-y-2 list-decimal list-inside">
          <li>Configure your Git repository URL and credentials in Settings</li>
          <li>Generate and preview your site</li>
          <li>Enter your personal access token and click Publish</li>
          <li>Changes are committed and pushed to your repository</li>
        </ol>
      </div>
    </div>
  </div>
</template>
