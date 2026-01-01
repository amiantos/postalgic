<script setup>
import { ref, computed, onMounted } from 'vue';
import { useRoute } from 'vue-router';
import { useBlogStore } from '@/stores/blog';
import PageToolbar from '@/components/PageToolbar.vue';
import SettingsTabs from '@/components/SettingsTabs.vue';

const route = useRoute();
const blogStore = useBlogStore();

const blogId = computed(() => route.params.blogId);
const fileInput = ref(null);
const faviconInput = ref(null);
const socialShareInput = ref(null);
const uploading = ref(false);
const error = ref(null);

onMounted(async () => {
  await blogStore.fetchStaticFiles(blogId.value);
});

const regularFiles = computed(() =>
  blogStore.staticFiles.filter(f => !f.isSpecialFile)
);

const favicon = computed(() =>
  blogStore.staticFiles.find(f => f.specialFileType === 'favicon')
);

const socialShareImage = computed(() =>
  blogStore.staticFiles.find(f => f.specialFileType === 'social-share')
);

function triggerFileUpload() {
  fileInput.value?.click();
}

function triggerFaviconUpload() {
  faviconInput.value?.click();
}

function triggerSocialShareUpload() {
  socialShareInput.value?.click();
}

async function handleFileUpload(event) {
  const files = event.target.files;
  if (!files.length) return;

  uploading.value = true;
  error.value = null;

  try {
    for (const file of files) {
      await blogStore.uploadStaticFile(blogId.value, file);
    }
  } catch (e) {
    error.value = e.message;
  } finally {
    uploading.value = false;
    event.target.value = '';
  }
}

async function handleFaviconUpload(event) {
  const file = event.target.files[0];
  if (!file) return;

  uploading.value = true;
  error.value = null;

  try {
    await blogStore.uploadStaticFile(blogId.value, file, {
      isSpecialFile: true,
      specialFileType: 'favicon'
    });
    await blogStore.fetchStaticFiles(blogId.value);
  } catch (e) {
    error.value = e.message;
  } finally {
    uploading.value = false;
    event.target.value = '';
  }
}

async function handleSocialShareUpload(event) {
  const file = event.target.files[0];
  if (!file) return;

  uploading.value = true;
  error.value = null;

  try {
    await blogStore.uploadStaticFile(blogId.value, file, {
      isSpecialFile: true,
      specialFileType: 'social-share'
    });
    await blogStore.fetchStaticFiles(blogId.value);
  } catch (e) {
    error.value = e.message;
  } finally {
    uploading.value = false;
    event.target.value = '';
  }
}

async function deleteFile(fileId) {
  if (confirm('Are you sure you want to delete this file?')) {
    await blogStore.deleteStaticFile(blogId.value, fileId);
  }
}

function formatFileSize(bytes) {
  if (bytes < 1024) return bytes + ' B';
  if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + ' KB';
  return (bytes / (1024 * 1024)).toFixed(1) + ' MB';
}
</script>

<template>
  <div>
    <PageToolbar
      title="Files"
      :subtitle="`${blogStore.staticFiles.length} files`"
    >
      <template #actions>
        <button
          @click="triggerFileUpload"
          :disabled="uploading"
          class="glass px-3 py-2 text-sm font-medium text-gray-700 dark:text-gray-300 flex items-center gap-1 disabled:opacity-50"
        >
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-8l-4-4m0 0L8 8m4-4v12" />
          </svg>
          {{ uploading ? 'Uploading...' : 'Upload Files' }}
        </button>
      </template>
      <template #controls>
        <SettingsTabs />
      </template>
    </PageToolbar>
    <input
      ref="fileInput"
      type="file"
      multiple
      class="hidden"
      @change="handleFileUpload"
    />

    <div class="px-6 pb-6">
    <!-- Error -->
    <div v-if="error" class="mb-6 p-4 bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded-lg text-red-800 dark:text-red-400">
      {{ error }}
    </div>

    <!-- Favicon Section -->
    <div class="bg-white dark:bg-gray-800 rounded-lg border border-gray-200 dark:border-gray-700 p-6 mb-6">
      <h3 class="font-medium text-gray-900 dark:text-gray-100 mb-4">Favicon</h3>
      <div class="flex items-center gap-4">
        <div class="w-16 h-16 bg-gray-100 dark:bg-gray-700 rounded-lg flex items-center justify-center overflow-hidden">
          <img
            v-if="favicon"
            :src="favicon.url"
            alt="Favicon"
            class="w-full h-full object-contain"
          />
          <svg v-else class="w-8 h-8 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
          </svg>
        </div>
        <div>
          <p class="text-sm text-gray-600 dark:text-gray-400 mb-2">
            {{ favicon ? 'Current favicon' : 'No favicon set' }}
          </p>
          <button
            @click="triggerFaviconUpload"
            :disabled="uploading"
            class="text-sm text-primary-600 dark:text-primary-400 hover:text-primary-700 dark:hover:text-primary-300"
          >
            {{ favicon ? 'Change favicon' : 'Upload favicon' }}
          </button>
          <input
            ref="faviconInput"
            type="file"
            accept="image/*"
            class="hidden"
            @change="handleFaviconUpload"
          />
        </div>
      </div>
    </div>

    <!-- Social Share Image Section -->
    <div class="bg-white dark:bg-gray-800 rounded-lg border border-gray-200 dark:border-gray-700 p-6 mb-6">
      <h3 class="font-medium text-gray-900 dark:text-gray-100 mb-2">Social Share Image</h3>
      <p class="text-sm text-gray-500 dark:text-gray-400 mb-4">This image appears when your blog is shared on social media (Open Graph image).</p>
      <div class="flex items-start gap-4">
        <div class="w-32 h-20 bg-gray-100 dark:bg-gray-700 rounded-lg flex items-center justify-center overflow-hidden flex-shrink-0">
          <img
            v-if="socialShareImage"
            :src="socialShareImage.url"
            alt="Social Share Image"
            class="w-full h-full object-cover"
          />
          <svg v-else class="w-8 h-8 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
          </svg>
        </div>
        <div>
          <p class="text-sm text-gray-600 dark:text-gray-400 mb-2">
            {{ socialShareImage ? 'Current social share image' : 'No social share image set' }}
          </p>
          <p class="text-xs text-gray-400 mb-2">Recommended size: 1200 x 630 pixels</p>
          <button
            @click="triggerSocialShareUpload"
            :disabled="uploading"
            class="text-sm text-primary-600 dark:text-primary-400 hover:text-primary-700 dark:hover:text-primary-300"
          >
            {{ socialShareImage ? 'Change image' : 'Upload image' }}
          </button>
          <input
            ref="socialShareInput"
            type="file"
            accept="image/*"
            class="hidden"
            @change="handleSocialShareUpload"
          />
        </div>
      </div>
    </div>

    <!-- Files List -->
    <div class="bg-white dark:bg-gray-800 rounded-lg border border-gray-200 dark:border-gray-700">
      <div v-if="regularFiles.length === 0" class="p-8 text-center">
        <div class="w-16 h-16 bg-gray-100 dark:bg-gray-700 rounded-full flex items-center justify-center mx-auto mb-4">
          <svg class="w-8 h-8 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
          </svg>
        </div>
        <h3 class="text-lg font-medium text-gray-900 dark:text-gray-100 mb-2">No files yet</h3>
        <p class="text-gray-500 dark:text-gray-400">Upload files to use in your blog.</p>
      </div>

      <div v-else class="divide-y divide-gray-200 dark:divide-gray-700">
        <div
          v-for="file in regularFiles"
          :key="file.id"
          class="p-4 flex items-center justify-between"
        >
          <div class="flex items-center gap-4">
            <div class="w-12 h-12 bg-gray-100 dark:bg-gray-700 rounded-lg flex items-center justify-center overflow-hidden">
              <img
                v-if="file.isImage"
                :src="file.url"
                :alt="file.filename"
                class="w-full h-full object-cover"
              />
              <svg v-else class="w-6 h-6 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
              </svg>
            </div>
            <div>
              <p class="font-medium text-gray-900 dark:text-gray-100">{{ file.filename }}</p>
              <p class="text-sm text-gray-500 dark:text-gray-400">{{ formatFileSize(file.size) }}</p>
            </div>
          </div>
          <div class="flex items-center gap-2">
            <a
              :href="file.url"
              target="_blank"
              class="p-2 text-gray-400 hover:text-gray-600 dark:hover:text-gray-300"
            >
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
              </svg>
            </a>
            <button
              @click="deleteFile(file.id)"
              class="p-2 text-gray-400 hover:text-red-600 dark:hover:text-red-400"
            >
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
              </svg>
            </button>
          </div>
        </div>
      </div>
    </div>
    </div>
  </div>
</template>
