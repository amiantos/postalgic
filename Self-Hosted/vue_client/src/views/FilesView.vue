<script setup>
import { ref, computed, onMounted } from 'vue';
import { useRoute } from 'vue-router';
import { useBlogStore } from '@/stores/blog';

const route = useRoute();
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
      <button
        @click="triggerFileUpload"
        :disabled="uploading"
        class="px-3 py-1.5 border-2 border-retro-gray-light dark:border-retro-gray-darker bg-white dark:bg-black font-retro-mono text-retro-sm text-retro-gray-dark dark:text-retro-gray-medium hover:border-retro-orange hover:text-retro-orange uppercase tracking-wider disabled:opacity-50"
      >
        {{ uploading ? 'Uploading...' : '+ Upload Files' }}
      </button>
    </nav>
    <input
      ref="fileInput"
      type="file"
      multiple
      class="hidden"
      @change="handleFileUpload"
    />

    <!-- Hero section -->
    <header class="relative h-52 md:h-60">
      <!-- Divider that extends to the right -->
      <div class="absolute bottom-0 left-6 right-0 border-b border-retro-gray-light dark:border-retro-gray-darker lg:left-0 lg:-right-[100vw]"></div>
      <!-- Giant background text -->
      <span class="absolute inset-0 flex items-center justify-start font-retro-serif font-bold text-[10rem] md:text-[14rem] leading-none tracking-tighter text-retro-gray-lightest dark:text-[#1a1a1a] select-none pointer-events-none whitespace-nowrap uppercase" aria-hidden="true">
        FILES
      </span>
      <!-- Foreground content -->
      <div class="absolute bottom-4 left-6 lg:left-0">
        <h1 class="font-retro-serif font-bold text-6xl md:text-7xl leading-none tracking-tight text-retro-gray-darker dark:text-retro-cream lowercase whitespace-nowrap">
          files
        </h1>
        <!-- Stats line -->
        <div class="mt-2 font-retro-mono text-retro-sm text-retro-gray-medium">
          {{ blogStore.staticFiles.length }} files
        </div>
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
      <!-- Error -->
      <div v-if="error" class="mb-6 p-4 border-2 border-red-500 font-retro-mono text-retro-sm text-red-600 dark:text-red-400">
        {{ error }}
      </div>

      <!-- Favicon Section -->
      <section class="border-2 border-retro-gray-light dark:border-retro-gray-darker p-4 mb-6">
        <h3 class="font-retro-mono text-retro-sm text-retro-gray-darker dark:text-retro-cream uppercase tracking-wider mb-4">Favicon</h3>
        <div class="flex items-center gap-4">
          <div class="w-16 h-16 border-2 border-retro-gray-light dark:border-retro-gray-darker flex items-center justify-center overflow-hidden bg-retro-gray-lightest dark:bg-retro-gray-darker">
            <img
              v-if="favicon"
              :src="favicon.url"
              alt="Favicon"
              class="w-full h-full object-contain"
            />
            <span v-else class="font-retro-mono text-retro-xs text-retro-gray-medium">None</span>
          </div>
          <div>
            <p class="font-retro-sans text-retro-sm text-retro-gray-dark dark:text-retro-gray-medium mb-2">
              {{ favicon ? 'Current favicon' : 'No favicon set' }}
            </p>
            <button
              @click="triggerFaviconUpload"
              :disabled="uploading"
              class="font-retro-mono text-retro-sm text-retro-orange hover:text-retro-orange-dark"
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
      <section class="border-2 border-retro-gray-light dark:border-retro-gray-darker p-4 mb-6">
        <h3 class="font-retro-mono text-retro-sm text-retro-gray-darker dark:text-retro-cream uppercase tracking-wider mb-2">Social Share Image</h3>
        <p class="font-retro-sans text-retro-sm text-retro-gray-dark dark:text-retro-gray-medium mb-4">This image appears when your blog is shared on social media (Open Graph image).</p>
        <div class="flex items-start gap-4">
          <div class="w-32 h-20 border-2 border-retro-gray-light dark:border-retro-gray-darker flex items-center justify-center overflow-hidden flex-shrink-0 bg-retro-gray-lightest dark:bg-retro-gray-darker">
            <img
              v-if="socialShareImage"
              :src="socialShareImage.url"
              alt="Social Share Image"
              class="w-full h-full object-cover"
            />
            <span v-else class="font-retro-mono text-retro-xs text-retro-gray-medium">None</span>
          </div>
          <div>
            <p class="font-retro-sans text-retro-sm text-retro-gray-dark dark:text-retro-gray-medium mb-1">
              {{ socialShareImage ? 'Current social share image' : 'No social share image set' }}
            </p>
            <p class="font-retro-mono text-retro-xs text-retro-gray-medium mb-2">Recommended: 1200 x 630 pixels</p>
            <button
              @click="triggerSocialShareUpload"
              :disabled="uploading"
              class="font-retro-mono text-retro-sm text-retro-orange hover:text-retro-orange-dark"
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
      <section class="border-2 border-retro-gray-light dark:border-retro-gray-darker">
        <div v-if="regularFiles.length === 0" class="p-8 text-center">
          <p class="font-retro-serif text-2xl font-bold text-retro-gray-darker dark:text-retro-gray-light">
            No files yet.
          </p>
          <p class="font-retro-sans text-retro-sm text-retro-gray-dark dark:text-retro-gray-medium mt-2">
            Upload files to use in your blog.
          </p>
        </div>

        <div v-else>
          <div
            v-for="file in regularFiles"
            :key="file.id"
            class="p-4 flex items-center justify-between border-b border-retro-gray-light dark:border-retro-gray-darker last:border-b-0"
          >
            <div class="flex items-center gap-4">
              <div class="w-12 h-12 border-2 border-retro-gray-light dark:border-retro-gray-darker flex items-center justify-center overflow-hidden bg-retro-gray-lightest dark:bg-retro-gray-darker">
                <img
                  v-if="file.isImage"
                  :src="file.url"
                  :alt="file.filename"
                  class="w-full h-full object-cover"
                />
                <span v-else class="font-retro-mono text-retro-xs text-retro-gray-medium">FILE</span>
              </div>
              <div>
                <p class="font-retro-mono text-retro-sm text-retro-gray-darker dark:text-retro-cream">{{ file.filename }}</p>
                <p class="font-retro-mono text-retro-xs text-retro-gray-medium">{{ formatFileSize(file.size) }}</p>
              </div>
            </div>
            <div class="flex items-center gap-4">
              <a
                :href="file.url"
                target="_blank"
                class="font-retro-mono text-retro-xs text-retro-gray-dark dark:text-retro-gray-medium hover:text-retro-orange uppercase tracking-wider"
              >
                View
              </a>
              <button
                @click="deleteFile(file.id)"
                class="font-retro-mono text-retro-xs text-red-500 hover:text-red-400 uppercase tracking-wider"
              >
                Delete
              </button>
            </div>
          </div>
        </div>
      </section>
    </main>

    </div><!-- End max-width wrapper -->
  </div>
</template>
