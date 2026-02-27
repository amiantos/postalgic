<script setup>
import { ref, computed, onMounted } from 'vue';
import { useRoute } from 'vue-router';
import { useBlogStore } from '@/stores/blog';

const route = useRoute();
const blogStore = useBlogStore();

const blogId = computed(() => route.params.blogId);

const fileInput = ref(null);
const faviconInput = ref(null);
const socialShareInput = ref(null);
const uploading = ref(false);
const error = ref(null);
const searchText = ref('');

onMounted(async () => {
  await blogStore.fetchStaticFiles(blogId.value);
});

const regularFiles = computed(() =>
  blogStore.staticFiles.filter(f => !f.isSpecialFile)
);

const filteredFiles = computed(() => {
  if (!searchText.value.trim()) return regularFiles.value;
  const query = searchText.value.toLowerCase();
  return regularFiles.value.filter(f => f.filename.toLowerCase().includes(query));
});

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
    <!-- Header with search and upload button -->
    <div class="flex items-center gap-3 mb-6">
      <input
        v-model="searchText"
        type="text"
        placeholder="Search files..."
        class="admin-input flex-1"
      />
      <button
        @click="triggerFileUpload"
        :disabled="uploading"
        class="h-10 px-3 font-mono text-sm uppercase tracking-wider bg-site-accent text-white hover:bg-[#e89200] transition-colors disabled:opacity-50"
      >
        {{ uploading ? 'Uploading...' : 'Upload Files' }}
      </button>
    </div>
    <input
      ref="fileInput"
      type="file"
      multiple
      class="hidden"
      @change="handleFileUpload"
    />

    <!-- Error -->
    <div v-if="error" class="mb-6 p-4 border border-red-500 text-sm text-red-600">
      {{ error }}
    </div>

    <!-- Favicon Section -->
    <section class="border border-site-light p-4 mb-6">
      <h3 class="text-sm font-semibold text-site-dark mb-4">Favicon</h3>
      <div class="flex items-center gap-4">
        <div class="w-16 h-16 border border-site-light flex items-center justify-center overflow-hidden bg-white">
          <img
            v-if="favicon"
            :src="favicon.url"
            alt="Favicon"
            class="w-full h-full object-contain"
          />
          <span v-else class="text-xs text-site-medium">None</span>
        </div>
        <div>
          <p class="text-sm text-site-dark mb-2">
            {{ favicon ? 'Current favicon' : 'No favicon set' }}
          </p>
          <button
            @click="triggerFaviconUpload"
            :disabled="uploading"
            class="text-sm text-site-accent hover:underline"
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
    </section>

    <!-- Social Share Image Section -->
    <section class="border border-site-light p-4 mb-6">
      <h3 class="text-sm font-semibold text-site-dark mb-2">Social Share Image</h3>
      <p class="text-sm text-site-dark mb-4">This image appears when your blog is shared on social media (Open Graph image).</p>
      <div class="flex items-start gap-4">
        <div class="w-32 h-20 border border-site-light flex items-center justify-center overflow-hidden flex-shrink-0 bg-white">
          <img
            v-if="socialShareImage"
            :src="socialShareImage.url"
            alt="Social Share Image"
            class="w-full h-full object-cover"
          />
          <span v-else class="text-xs text-site-medium">None</span>
        </div>
        <div>
          <p class="text-sm text-site-dark mb-1">
            {{ socialShareImage ? 'Current social share image' : 'No social share image set' }}
          </p>
          <p class="text-xs text-site-medium mb-2">Recommended: 1200 x 630 pixels</p>
          <button
            @click="triggerSocialShareUpload"
            :disabled="uploading"
            class="text-sm text-site-accent hover:underline"
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
    </section>

    <!-- Files List -->
    <section class="border border-site-light">
      <div v-if="filteredFiles.length === 0" class="p-8 text-center">
        <p class="text-xl font-bold text-site-dark">
          {{ searchText.trim() ? 'No matching files.' : 'No files yet.' }}
        </p>
        <p class="text-sm text-site-dark mt-2">
          {{ searchText.trim() ? 'Try a different search.' : 'Upload files to use in your blog.' }}
        </p>
      </div>

      <div v-else>
        <div
          v-for="file in filteredFiles"
          :key="file.id"
          class="p-4 flex items-center justify-between border-b border-site-light last:border-b-0"
        >
          <div class="flex items-center gap-4">
            <div class="w-12 h-12 border border-site-light flex items-center justify-center overflow-hidden bg-white">
              <img
                v-if="file.isImage"
                :src="file.url"
                :alt="file.filename"
                class="w-full h-full object-cover"
              />
              <span v-else class="text-xs text-site-medium">FILE</span>
            </div>
            <div>
              <p class="text-sm text-site-dark">{{ file.filename }}</p>
              <p class="text-xs text-site-medium">{{ formatFileSize(file.size) }}</p>
            </div>
          </div>
          <div class="flex items-center gap-4">
            <a
              :href="file.url"
              target="_blank"
              class="text-xs font-semibold text-site-dark hover:text-site-accent"
            >
              View
            </a>
            <button
              @click="deleteFile(file.id)"
              class="text-xs font-semibold text-red-500 hover:text-red-400"
            >
              Delete
            </button>
          </div>
        </div>
      </div>
    </section>
  </div>
</template>
