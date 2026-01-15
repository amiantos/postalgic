<script setup>
import { ref } from 'vue';
import { useRouter } from 'vue-router';
import { importApi } from '@/api';
import { useBlogStore } from '@/stores/blog';

const router = useRouter();
const blogStore = useBlogStore();

const selectedFile = ref(null);
const validation = ref(null);
const importing = ref(false);
const validating = ref(false);
const error = ref(null);
const dragOver = ref(false);

function handleFileSelect(event) {
  const file = event.target.files?.[0];
  if (file) {
    selectFile(file);
  }
}

function handleDrop(event) {
  event.preventDefault();
  dragOver.value = false;
  const file = event.dataTransfer.files?.[0];
  if (file) {
    selectFile(file);
  }
}

function handleDragOver(event) {
  event.preventDefault();
  dragOver.value = true;
}

function handleDragLeave() {
  dragOver.value = false;
}

async function selectFile(file) {
  if (!file.name.toLowerCase().endsWith('.zip')) {
    error.value = 'Please select a ZIP file';
    return;
  }

  selectedFile.value = file;
  validation.value = null;
  error.value = null;
  validating.value = true;

  try {
    const result = await importApi.validate(file);
    validation.value = result;
    if (!result.valid) {
      error.value = result.error;
    }
  } catch (e) {
    error.value = e.message;
  } finally {
    validating.value = false;
  }
}

function clearSelection() {
  selectedFile.value = null;
  validation.value = null;
  error.value = null;
}

async function importBlog() {
  if (!selectedFile.value || !validation.value?.valid) return;

  importing.value = true;
  error.value = null;

  try {
    const result = await importApi.import(selectedFile.value);
    // Refresh blog list
    await blogStore.fetchBlogs();
    // Navigate to the imported blog
    router.push({ name: 'blog-posts', params: { blogId: result.blog.id } });
  } catch (e) {
    error.value = e.message;
    importing.value = false;
  }
}

function formatNumber(num) {
  return num.toLocaleString();
}
</script>

<template>
  <div class="min-h-screen bg-gray-50">
    <!-- Header -->
    <header class="bg-white shadow-sm">
      <div class="max-w-2xl mx-auto px-4 py-6">
        <div class="flex items-center gap-4">
          <router-link to="/" class="text-gray-500 hover:text-gray-700">
            <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
            </svg>
          </router-link>
          <h1 class="text-xl font-bold text-gray-900">Import Blog</h1>
        </div>
      </div>
    </header>

    <!-- Content -->
    <main class="max-w-2xl mx-auto px-4 py-8">
      <div class="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
        <!-- Description -->
        <p class="text-gray-600 mb-6">
          Import a blog from a Postalgic iOS export. Select a ZIP file exported from the iOS app to import all posts, categories, tags, files, and settings.
        </p>

        <!-- Error -->
        <div v-if="error" class="mb-6 p-4 bg-red-50 border border-red-200 rounded-lg text-red-800">
          {{ error }}
        </div>

        <!-- File Drop Zone -->
        <div v-if="!selectedFile" class="mb-6">
          <div
            @drop="handleDrop"
            @dragover="handleDragOver"
            @dragleave="handleDragLeave"
            :class="[
              'border-2 border-dashed rounded-lg p-8 text-center transition-colors',
              dragOver ? 'border-primary-500 bg-primary-50' : 'border-gray-300 hover:border-gray-400'
            ]"
          >
            <svg class="w-12 h-12 mx-auto text-gray-400 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12" />
            </svg>
            <p class="text-gray-600 mb-2">Drag and drop your export ZIP file here</p>
            <p class="text-gray-500 text-sm mb-4">or</p>
            <label class="inline-block px-4 py-2 bg-primary-600 text-white rounded-lg hover:bg-primary-700 transition-colors cursor-pointer">
              Choose File
              <input
                type="file"
                accept=".zip"
                class="hidden"
                @change="handleFileSelect"
              />
            </label>
          </div>
        </div>

        <!-- Selected File / Validating -->
        <div v-else-if="validating" class="mb-6">
          <div class="border border-gray-200 rounded-lg p-6 text-center">
            <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-primary-600 mx-auto mb-4"></div>
            <p class="text-gray-600">Validating export file...</p>
          </div>
        </div>

        <!-- Validation Results -->
        <div v-else-if="validation" class="mb-6">
          <div class="border border-gray-200 rounded-lg p-6">
            <!-- File Info -->
            <div class="flex items-start justify-between mb-4">
              <div class="flex items-center gap-3">
                <svg class="w-10 h-10 text-primary-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 8h14M5 8a2 2 0 110-4h14a2 2 0 110 4M5 8v10a2 2 0 002 2h10a2 2 0 002-2V8m-9 4h4" />
                </svg>
                <div>
                  <p class="font-medium text-gray-900">{{ selectedFile.name }}</p>
                  <p class="text-sm text-gray-500">{{ (selectedFile.size / 1024 / 1024).toFixed(2) }} MB</p>
                </div>
              </div>
              <button
                @click="clearSelection"
                class="text-gray-400 hover:text-gray-600"
              >
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>
            </div>

            <div v-if="validation.valid">
              <!-- Blog Info -->
              <div class="bg-gray-50 rounded-lg p-4 mb-4">
                <h3 class="font-medium text-gray-900 mb-2">{{ validation.blogName }}</h3>
                <p v-if="validation.blogUrl" class="text-sm text-primary-600">{{ validation.blogUrl }}</p>
                <p class="text-sm text-gray-500 mt-1">
                  Exported {{ new Date(validation.manifest.exportDate).toLocaleDateString() }}
                  from Postalgic v{{ validation.manifest.appVersion }}
                </p>
              </div>

              <!-- Credentials Warning -->
              <div v-if="validation.includesCredentials" class="bg-yellow-50 border border-yellow-200 rounded-lg p-4 mb-4">
                <div class="flex items-start gap-3">
                  <svg class="w-5 h-5 text-yellow-600 mt-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
                  </svg>
                  <div>
                    <p class="font-medium text-yellow-800">Publishing credentials included</p>
                    <p class="text-sm text-yellow-700 mt-1">This export contains publishing credentials (AWS, SFTP, or Git). They will be imported with your blog.</p>
                  </div>
                </div>
              </div>

              <!-- Content Counts -->
              <div class="grid grid-cols-2 gap-3">
                <div class="bg-gray-50 rounded-lg p-3">
                  <p class="text-2xl font-bold text-gray-900">{{ formatNumber(validation.counts.posts) }}</p>
                  <p class="text-sm text-gray-500">Posts</p>
                </div>
                <div class="bg-gray-50 rounded-lg p-3">
                  <p class="text-2xl font-bold text-gray-900">{{ formatNumber(validation.counts.categories) }}</p>
                  <p class="text-sm text-gray-500">Categories</p>
                </div>
                <div class="bg-gray-50 rounded-lg p-3">
                  <p class="text-2xl font-bold text-gray-900">{{ formatNumber(validation.counts.tags) }}</p>
                  <p class="text-sm text-gray-500">Tags</p>
                </div>
                <div class="bg-gray-50 rounded-lg p-3">
                  <p class="text-2xl font-bold text-gray-900">{{ formatNumber(validation.counts.staticFiles) }}</p>
                  <p class="text-sm text-gray-500">Files</p>
                </div>
              </div>
            </div>

            <div v-else class="bg-red-50 rounded-lg p-4">
              <p class="text-red-800">Invalid export file: {{ validation.error }}</p>
            </div>
          </div>
        </div>

        <!-- Actions -->
        <div class="flex justify-end gap-3 pt-4">
          <router-link
            to="/"
            class="px-4 py-2 text-gray-700 hover:bg-gray-100 rounded-lg transition-colors"
          >
            Cancel
          </router-link>
          <button
            @click="importBlog"
            :disabled="!validation?.valid || importing"
            class="px-4 py-2 bg-primary-600 text-white rounded-lg hover:bg-primary-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {{ importing ? 'Importing...' : 'Import Blog' }}
          </button>
        </div>
      </div>
    </main>
  </div>
</template>
