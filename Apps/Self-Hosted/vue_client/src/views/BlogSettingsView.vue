<script setup>
import { ref, computed, watch, onMounted } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useBlogStore } from '@/stores/blog';
import { syncApi } from '@/api';
import PageToolbar from '@/components/PageToolbar.vue';
import SettingsTabs from '@/components/SettingsTabs.vue';

const route = useRoute();
const router = useRouter();
const blogStore = useBlogStore();

const blogId = computed(() => route.params.blogId);

const form = ref({});
const saving = ref(false);
const error = ref(null);
const success = ref(false);

// Sync settings state
const syncConfig = ref(null);
const syncLoading = ref(false);
const syncError = ref(null);
const syncPassword = ref('');
const syncConfirmPassword = ref('');
const showPassword = ref(false);
const showConfirmPassword = ref(false);
const changingPassword = ref(false);

// Sync Down state
const checkingChanges = ref(false);
const syncingDown = ref(false);
const syncCheckResult = ref(null);
const syncDownResult = ref(null);
const syncDownError = ref(null);
const syncDownProgress = ref(null);

watch(() => blogStore.currentBlog, (blog) => {
  if (blog) {
    form.value = { ...blog };
  }
}, { immediate: true });

onMounted(async () => {
  await fetchSyncConfig();
});

async function fetchSyncConfig() {
  syncLoading.value = true;
  syncError.value = null;
  try {
    syncConfig.value = await syncApi.getStatus(blogId.value);
  } catch (e) {
    // Config doesn't exist yet, that's fine
    syncConfig.value = { syncEnabled: false, hasPassword: false };
  } finally {
    syncLoading.value = false;
  }
}

const passwordsMatch = computed(() => {
  return syncPassword.value && syncPassword.value === syncConfirmPassword.value;
});

const canEnableSync = computed(() => {
  if (syncConfig.value?.hasPassword) {
    return true;
  }
  return passwordsMatch.value && syncPassword.value.length >= 8;
});

async function enableSync() {
  syncError.value = null;

  if (!syncConfig.value?.hasPassword) {
    if (!passwordsMatch.value) {
      syncError.value = 'Passwords do not match';
      return;
    }
    if (syncPassword.value.length < 8) {
      syncError.value = 'Password must be at least 8 characters';
      return;
    }
  }

  try {
    await syncApi.enable(blogId.value, syncPassword.value || undefined);
    syncPassword.value = '';
    syncConfirmPassword.value = '';
    await fetchSyncConfig();
  } catch (e) {
    syncError.value = e.message;
  }
}

async function disableSync() {
  syncError.value = null;
  try {
    await syncApi.disable(blogId.value);
    await fetchSyncConfig();
  } catch (e) {
    syncError.value = e.message;
  }
}

async function changePassword() {
  syncError.value = null;

  if (!passwordsMatch.value) {
    syncError.value = 'Passwords do not match';
    return;
  }
  if (syncPassword.value.length < 8) {
    syncError.value = 'Password must be at least 8 characters';
    return;
  }

  try {
    await syncApi.updatePassword(blogId.value, syncPassword.value);
    syncPassword.value = '';
    syncConfirmPassword.value = '';
    changingPassword.value = false;
    await fetchSyncConfig();
  } catch (e) {
    syncError.value = e.message;
  }
}

async function checkForChanges() {
  checkingChanges.value = true;
  syncDownError.value = null;
  syncCheckResult.value = null;
  syncDownResult.value = null;

  try {
    const result = await syncApi.checkChanges(blogId.value);
    syncCheckResult.value = result;
  } catch (e) {
    syncDownError.value = e.message;
  } finally {
    checkingChanges.value = false;
  }
}

async function pullChanges() {
  syncingDown.value = true;
  syncDownError.value = null;
  syncDownProgress.value = 'Starting sync...';

  try {
    const result = await syncApi.pull(blogId.value, syncPassword.value || undefined);
    syncDownResult.value = result;
    syncCheckResult.value = null;
    await fetchSyncConfig();

    // Refresh blog data to show pulled changes
    if (result.updated) {
      syncDownProgress.value = 'Refreshing data...';
      await Promise.all([
        blogStore.fetchBlog(blogId.value),
        blogStore.fetchPosts(blogId.value),
        blogStore.fetchCategories(blogId.value),
        blogStore.fetchTags(blogId.value),
        blogStore.fetchSidebarObjects(blogId.value),
      ]);
    }
  } catch (e) {
    syncDownError.value = e.message;
  } finally {
    syncingDown.value = false;
    syncDownProgress.value = null;
  }
}

// Helper to check if a category has any changes
function hasChangesInCategory(category) {
  if (!category) return false;
  return (category.new?.length > 0) || (category.modified?.length > 0) || (category.deleted?.length > 0);
}

// Helper to truncate long IDs for display
function truncateId(id) {
  if (!id) return 'unknown';
  if (id.length <= 20) return id;
  return id.substring(0, 8) + '...' + id.substring(id.length - 8);
}

const colorPreviewHtml = computed(() => {
  const accentColor = form.value.accentColor || '#FFA100';
  const backgroundColor = form.value.backgroundColor || '#efefef';
  const textColor = form.value.textColor || '#2d3748';
  const lightShade = form.value.lightShade || '#dedede';
  const mediumShade = form.value.mediumShade || '#a0aec0';
  const darkShade = form.value.darkShade || '#4a5568';

  return `<!DOCTYPE html>
<html>
<head>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        :root {
            --accent-color: ${accentColor};
            --background-color: ${backgroundColor};
            --text-color: ${textColor};
            --light-shade: ${lightShade};
            --medium-shade: ${mediumShade};
            --dark-shade: ${darkShade};
        }

        body {
            font-family: -apple-system, BlinkMacSystemFont, sans-serif;
            background-color: var(--background-color);
            color: var(--text-color);
            padding: 12px;
            line-height: 1.6;
            margin: 0;
        }

        a {
            color: var(--accent-color);
            text-decoration: none;
        }

        .header-separator {
            height: 28px;
            width: 100%;
            background-color: var(--accent-color);
            --mask:
              radial-gradient(10.96px at 50% calc(100% + 5.6px),#0000 calc(99% - 4px),#000 calc(101% - 4px) 99%,#0000 101%) calc(50% - 14px) calc(50% - 5.5px + .5px)/28px 11px repeat-x,
              radial-gradient(10.96px at 50% -5.6px,#0000 calc(99% - 4px),#000 calc(101% - 4px) 99%,#0000 101%) 50% calc(50% + 5.5px)/28px 11px repeat-x;
            -webkit-mask: var(--mask);
            mask: var(--mask);
            margin: 15px 0;
        }

        .category, .tag {
            display: inline-block;
            margin-right: 5px;
        }

        .category a {
            display: inline-block;
            color: white;
            background-color: var(--accent-color);
            border: 1px solid var(--accent-color);
            padding: 3px 8px;
            border-radius: 1em;
            font-size: 0.8em;
        }

        .tag a {
            display: inline-block;
            color: var(--accent-color);
            background-color: var(--background-color);
            border: 1px solid var(--accent-color);
            padding: 3px 8px;
            border-radius: 1em;
            font-size: 0.8em;
        }

        .section {
            margin-bottom: 20px;
        }

        h3 {
            margin-bottom: 8px;
            color: var(--dark-shade);
        }

        h2 {
            color: var(--text-color);
            font-size: 1.5em;
            font-weight: bold;
            margin-bottom: 0px;
            margin-top: 10px;
        }

        .post-date {
            color: var(--medium-shade);
            font-size: 0.9em;
            display: inline-block;
            margin-top: 0px;
        }

        .menu-button {
            display: block;
            padding: 8px 0;
            font-weight: 600;
            font-size: 1.1rem;
            color: var(--dark-shade);
            text-decoration: none;
        }

        .menu-sample {
            margin-bottom: 25px;
            border-bottom: 1px solid var(--light-shade);
        }
    </style>
</head>
<body>
    <div class="section">
        <h2>Example Post Title</h2>
        <div class="post-date">May 24, 2025 at 1:50 AM</div>

        <p>This is regular text on your blog, and <a href="#">this is a link</a> to demonstrate how the accent color looks.</p>
        <div class="category"><a href="#">Category Name</a></div>
        <div class="tag"><a href="#">#tag name</a></div>
        <div class="header-separator"></div>
        <div class="menu-sample">
            <a class="menu-button">Menu Nav Item</a>
        </div>
    </div>
</body>
</html>`;
});

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
</script>

<template>
  <div>
    <PageToolbar title="Basic Settings">
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

      <!-- Theme Colors -->
      <section class="surface p-6">
        <h3 class="text-lg font-medium text-gray-900 dark:text-gray-100 mb-4">Theme Colors</h3>
        <div class="grid grid-cols-2 sm:grid-cols-3 gap-4 max-w-lg">
          <div>
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Accent Color</label>
            <div class="flex items-center gap-2">
              <input
                v-model="form.accentColor"
                type="color"
                class="w-10 h-10 shrink-0"
              />
              <input
                v-model="form.accentColor"
                type="text"
                class="min-w-0 flex-1 px-3 py-2 rounded-lg bg-black/5 dark:bg-white/5 text-gray-900 dark:text-gray-100 text-sm border-0 focus:ring-2 focus:ring-primary-500/50 transition-colors"
              />
            </div>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Background</label>
            <div class="flex items-center gap-2">
              <input
                v-model="form.backgroundColor"
                type="color"
                class="w-10 h-10 shrink-0"
              />
              <input
                v-model="form.backgroundColor"
                type="text"
                class="min-w-0 flex-1 px-3 py-2 rounded-lg bg-black/5 dark:bg-white/5 text-gray-900 dark:text-gray-100 text-sm border-0 focus:ring-2 focus:ring-primary-500/50 transition-colors"
              />
            </div>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Text Color</label>
            <div class="flex items-center gap-2">
              <input
                v-model="form.textColor"
                type="color"
                class="w-10 h-10 shrink-0"
              />
              <input
                v-model="form.textColor"
                type="text"
                class="min-w-0 flex-1 px-3 py-2 rounded-lg bg-black/5 dark:bg-white/5 text-gray-900 dark:text-gray-100 text-sm border-0 focus:ring-2 focus:ring-primary-500/50 transition-colors"
              />
            </div>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Light Shade</label>
            <div class="flex items-center gap-2">
              <input
                v-model="form.lightShade"
                type="color"
                class="w-10 h-10 shrink-0"
              />
              <input
                v-model="form.lightShade"
                type="text"
                class="min-w-0 flex-1 px-3 py-2 rounded-lg bg-black/5 dark:bg-white/5 text-gray-900 dark:text-gray-100 text-sm border-0 focus:ring-2 focus:ring-primary-500/50 transition-colors"
              />
            </div>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Medium Shade</label>
            <div class="flex items-center gap-2">
              <input
                v-model="form.mediumShade"
                type="color"
                class="w-10 h-10 shrink-0"
              />
              <input
                v-model="form.mediumShade"
                type="text"
                class="min-w-0 flex-1 px-3 py-2 rounded-lg bg-black/5 dark:bg-white/5 text-gray-900 dark:text-gray-100 text-sm border-0 focus:ring-2 focus:ring-primary-500/50 transition-colors"
              />
            </div>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Dark Shade</label>
            <div class="flex items-center gap-2">
              <input
                v-model="form.darkShade"
                type="color"
                class="w-10 h-10 shrink-0"
              />
              <input
                v-model="form.darkShade"
                type="text"
                class="min-w-0 flex-1 px-3 py-2 rounded-lg bg-black/5 dark:bg-white/5 text-gray-900 dark:text-gray-100 text-sm border-0 focus:ring-2 focus:ring-primary-500/50 transition-colors"
              />
            </div>
          </div>
        </div>

        <!-- Color Preview -->
        <div class="mt-6">
          <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">Preview</label>
          <div class="rounded-xl overflow-hidden bg-black/5 dark:bg-white/5">
            <iframe
              :srcdoc="colorPreviewHtml"
              class="w-full border-0"
              style="height: 340px;"
            ></iframe>
          </div>
        </div>
      </section>

      <!-- Publishing Settings -->
      <section class="surface p-6">
        <h3 class="text-lg font-medium text-gray-900 dark:text-gray-100 mb-4">Publishing</h3>
        <div class="space-y-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Publisher Type</label>
            <select
              v-model="form.publisherType"
              class="w-full px-3.5 py-2.5 rounded-xl bg-black/5 dark:bg-white/5 text-gray-900 dark:text-gray-100 border-0 focus:ring-2 focus:ring-primary-500/50 focus:bg-white dark:focus:bg-white/10 transition-colors"
            >
              <option value="manual">Manual (Download ZIP)</option>
              <option value="aws">AWS S3</option>
              <option value="sftp">SFTP</option>
              <option value="git">Git (GitHub Pages, etc.)</option>
            </select>
          </div>

          <!-- AWS Settings -->
          <div v-if="form.publisherType === 'aws'" class="space-y-4 p-4 bg-black/5 dark:bg-white/5 rounded-xl">
            <h4 class="font-medium text-gray-900 dark:text-gray-100">AWS S3 Configuration</h4>
            <div class="grid grid-cols-2 gap-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Region</label>
                <input
                  v-model="form.awsRegion"
                  type="text"
                  class="w-full px-3.5 py-2.5 rounded-xl bg-white/80 dark:bg-white/10 text-gray-900 dark:text-gray-100 border-0 focus:ring-2 focus:ring-primary-500/50 transition-colors"
                  placeholder="us-east-1"
                />
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">S3 Bucket</label>
                <input
                  v-model="form.awsS3Bucket"
                  type="text"
                  class="w-full px-3.5 py-2.5 rounded-xl bg-white/80 dark:bg-white/10 text-gray-900 dark:text-gray-100 border-0 focus:ring-2 focus:ring-primary-500/50 transition-colors"
                  placeholder="my-blog-bucket"
                />
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Access Key ID</label>
                <input
                  v-model="form.awsAccessKeyId"
                  type="text"
                  class="w-full px-3.5 py-2.5 rounded-xl bg-white/80 dark:bg-white/10 text-gray-900 dark:text-gray-100 border-0 focus:ring-2 focus:ring-primary-500/50 transition-colors"
                />
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Secret Access Key</label>
                <input
                  v-model="form.awsSecretAccessKey"
                  type="password"
                  class="w-full px-3.5 py-2.5 rounded-xl bg-white/80 dark:bg-white/10 text-gray-900 dark:text-gray-100 border-0 focus:ring-2 focus:ring-primary-500/50 transition-colors"
                />
              </div>
              <div class="col-span-2">
                <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">CloudFront Distribution ID</label>
                <input
                  v-model="form.awsCloudFrontDistId"
                  type="text"
                  class="w-full px-3.5 py-2.5 rounded-xl bg-white/80 dark:bg-white/10 text-gray-900 dark:text-gray-100 border-0 focus:ring-2 focus:ring-primary-500/50 transition-colors"
                  placeholder="Optional - for cache invalidation"
                />
              </div>
            </div>
          </div>

          <!-- SFTP Settings -->
          <div v-if="form.publisherType === 'sftp'" class="space-y-4 p-4 bg-black/5 dark:bg-white/5 rounded-xl">
            <h4 class="font-medium text-gray-900 dark:text-gray-100">SFTP Configuration</h4>
            <div class="grid grid-cols-2 gap-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Host</label>
                <input
                  v-model="form.ftpHost"
                  type="text"
                  class="w-full px-3.5 py-2.5 rounded-xl bg-white/80 dark:bg-white/10 text-gray-900 dark:text-gray-100 border-0 focus:ring-2 focus:ring-primary-500/50 transition-colors"
                  placeholder="sftp.example.com"
                />
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Port</label>
                <input
                  v-model.number="form.ftpPort"
                  type="number"
                  class="w-full px-3.5 py-2.5 rounded-xl bg-white/80 dark:bg-white/10 text-gray-900 dark:text-gray-100 border-0 focus:ring-2 focus:ring-primary-500/50 transition-colors"
                  placeholder="22"
                />
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Username</label>
                <input
                  v-model="form.ftpUsername"
                  type="text"
                  class="w-full px-3.5 py-2.5 rounded-xl bg-white/80 dark:bg-white/10 text-gray-900 dark:text-gray-100 border-0 focus:ring-2 focus:ring-primary-500/50 transition-colors"
                />
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Password</label>
                <input
                  v-model="form.ftpPassword"
                  type="password"
                  class="w-full px-3.5 py-2.5 rounded-xl bg-white/80 dark:bg-white/10 text-gray-900 dark:text-gray-100 border-0 focus:ring-2 focus:ring-primary-500/50 transition-colors"
                />
              </div>
              <div class="col-span-2">
                <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Remote Path</label>
                <input
                  v-model="form.ftpPath"
                  type="text"
                  class="w-full px-3.5 py-2.5 rounded-xl bg-white/80 dark:bg-white/10 text-gray-900 dark:text-gray-100 border-0 focus:ring-2 focus:ring-primary-500/50 transition-colors"
                  placeholder="/var/www/html"
                />
              </div>
              <div class="col-span-2">
                <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Private Key (optional, alternative to password)</label>
                <textarea
                  v-model="form.ftpPrivateKey"
                  rows="3"
                  class="w-full px-3.5 py-2.5 rounded-xl bg-white/80 dark:bg-white/10 text-gray-900 dark:text-gray-100 border-0 focus:ring-2 focus:ring-primary-500/50 font-mono text-xs transition-colors"
                  placeholder="-----BEGIN OPENSSH PRIVATE KEY-----..."
                ></textarea>
              </div>
            </div>
          </div>

          <!-- Git Settings -->
          <div v-if="form.publisherType === 'git'" class="space-y-4 p-4 bg-black/5 dark:bg-white/5 rounded-xl">
            <h4 class="font-medium text-gray-900 dark:text-gray-100">Git Configuration</h4>
            <div class="space-y-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Repository URL</label>
                <input
                  v-model="form.gitRepositoryUrl"
                  type="text"
                  class="w-full px-3.5 py-2.5 rounded-xl bg-white/80 dark:bg-white/10 text-gray-900 dark:text-gray-100 border-0 focus:ring-2 focus:ring-primary-500/50 transition-colors"
                  placeholder="https://github.com/username/repo.git"
                />
              </div>
              <div class="grid grid-cols-2 gap-4">
                <div>
                  <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Username</label>
                  <input
                    v-model="form.gitUsername"
                    type="text"
                    class="w-full px-3.5 py-2.5 rounded-xl bg-white/80 dark:bg-white/10 text-gray-900 dark:text-gray-100 border-0 focus:ring-2 focus:ring-primary-500/50 transition-colors"
                  />
                </div>
                <div>
                  <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Personal Access Token</label>
                  <input
                    v-model="form.gitToken"
                    type="password"
                    class="w-full px-3.5 py-2.5 rounded-xl bg-white/80 dark:bg-white/10 text-gray-900 dark:text-gray-100 border-0 focus:ring-2 focus:ring-primary-500/50 transition-colors"
                  />
                </div>
              </div>
              <div class="grid grid-cols-2 gap-4">
                <div>
                  <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Branch</label>
                  <input
                    v-model="form.gitBranch"
                    type="text"
                    class="w-full px-3.5 py-2.5 rounded-xl bg-white/80 dark:bg-white/10 text-gray-900 dark:text-gray-100 border-0 focus:ring-2 focus:ring-primary-500/50 transition-colors"
                    placeholder="main"
                  />
                </div>
                <div>
                  <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Commit Message</label>
                  <input
                    v-model="form.gitCommitMessage"
                    type="text"
                    class="w-full px-3.5 py-2.5 rounded-xl bg-white/80 dark:bg-white/10 text-gray-900 dark:text-gray-100 border-0 focus:ring-2 focus:ring-primary-500/50 transition-colors"
                    placeholder="Update blog"
                  />
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      <!-- Sync Settings -->
      <section class="surface p-6">
        <h3 class="text-lg font-medium text-gray-900 dark:text-gray-100 mb-4">Sync Settings</h3>
        <p class="text-sm text-gray-600 dark:text-gray-400 mb-4">
          When enabled, sync data will be generated alongside your published site, allowing you to import your blog on other devices or the iOS app.
        </p>

        <!-- Sync Error -->
        <div v-if="syncError" class="mb-4 p-4 bg-red-500/10 rounded-xl text-red-600 dark:text-red-400">
          {{ syncError }}
        </div>

        <!-- Loading -->
        <div v-if="syncLoading" class="text-center py-4">
          <div class="animate-spin rounded-full h-6 w-6 border-b-2 border-primary-600 mx-auto"></div>
        </div>

        <!-- Sync Enabled -->
        <div v-else-if="syncConfig?.syncEnabled" class="space-y-4">
          <div class="flex items-center justify-between p-4 bg-green-500/10 rounded-xl">
            <div class="flex items-center gap-3">
              <svg class="w-5 h-5 text-green-600 dark:text-green-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
              </svg>
              <div>
                <p class="font-medium text-green-800 dark:text-green-400">Sync Enabled</p>
                <p v-if="syncConfig.lastSyncedAt" class="text-sm text-green-700 dark:text-green-500">
                  Last synced: {{ new Date(syncConfig.lastSyncedAt).toLocaleString() }}
                </p>
                <p v-else class="text-sm text-green-700 dark:text-green-500">
                  Sync data will be generated when you publish your blog.
                </p>
              </div>
            </div>
            <button
              type="button"
              @click="disableSync"
              class="px-4 py-2 text-sm text-red-500 dark:text-red-400 hover:bg-red-500/10 rounded-xl transition-colors"
            >
              Disable
            </button>
          </div>

          <!-- Change Password -->
          <div v-if="!changingPassword">
            <button
              type="button"
              @click="changingPassword = true"
              class="text-sm text-primary-600 dark:text-primary-400 hover:underline"
            >
              Change sync password
            </button>
          </div>
          <div v-else class="space-y-3 p-4 bg-black/5 dark:bg-white/5 rounded-xl">
            <h4 class="font-medium text-gray-900 dark:text-gray-100">Change Password</h4>
            <div class="relative">
              <input
                v-model="syncPassword"
                :type="showPassword ? 'text' : 'password'"
                placeholder="New password (min 8 characters)"
                class="w-full px-3.5 py-2.5 pr-10 rounded-xl bg-white/80 dark:bg-white/10 text-gray-900 dark:text-gray-100 border-0 focus:ring-2 focus:ring-primary-500/50 transition-colors"
              />
              <button
                type="button"
                @click="showPassword = !showPassword"
                class="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600"
              >
                <svg v-if="showPassword" class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.88 9.88l-3.29-3.29m7.532 7.532l3.29 3.29M3 3l3.59 3.59m0 0A9.953 9.953 0 0112 5c4.478 0 8.268 2.943 9.543 7a10.025 10.025 0 01-4.132 5.411m0 0L21 21" />
                </svg>
                <svg v-else class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
                </svg>
              </button>
            </div>
            <div class="relative">
              <input
                v-model="syncConfirmPassword"
                :type="showConfirmPassword ? 'text' : 'password'"
                placeholder="Confirm new password"
                class="w-full px-3.5 py-2.5 pr-10 rounded-xl bg-white/80 dark:bg-white/10 text-gray-900 dark:text-gray-100 border-0 focus:ring-2 focus:ring-primary-500/50 transition-colors"
              />
              <button
                type="button"
                @click="showConfirmPassword = !showConfirmPassword"
                class="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600"
              >
                <svg v-if="showConfirmPassword" class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.88 9.88l-3.29-3.29m7.532 7.532l3.29 3.29M3 3l3.59 3.59m0 0A9.953 9.953 0 0112 5c4.478 0 8.268 2.943 9.543 7a10.025 10.025 0 01-4.132 5.411m0 0L21 21" />
                </svg>
                <svg v-else class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
                </svg>
              </button>
            </div>
            <p v-if="syncPassword && syncConfirmPassword && !passwordsMatch" class="text-sm text-red-600 dark:text-red-400">
              Passwords do not match
            </p>
            <div class="flex gap-2">
              <button
                type="button"
                @click="changingPassword = false; syncPassword = ''; syncConfirmPassword = '';"
                class="px-4 py-2 text-sm text-gray-600 dark:text-gray-400 hover:bg-black/5 dark:hover:bg-white/10 rounded-xl transition-colors"
              >
                Cancel
              </button>
              <button
                type="button"
                @click="changePassword"
                :disabled="!passwordsMatch || syncPassword.length < 8"
                class="px-4 py-2 text-sm bg-primary-500 text-white rounded-xl font-medium hover:bg-primary-600 transition-colors shadow-sm disabled:opacity-50 disabled:cursor-not-allowed"
              >
                Update Password
              </button>
            </div>
          </div>

          <!-- Sync Down Section -->
          <div v-if="form.url" class="mt-4 pt-4 border-t border-gray-200 dark:border-gray-600">
            <h4 class="font-medium text-gray-900 dark:text-gray-100 mb-3">Sync Down</h4>
            <p class="text-sm text-gray-600 dark:text-gray-400 mb-3">
              Pull changes from your published site to update this instance.
            </p>

            <!-- Sync Down Error -->
            <div v-if="syncDownError" class="mb-4 p-3 bg-red-500/10 rounded-xl text-sm text-red-600 dark:text-red-400">
              {{ syncDownError }}
            </div>

            <!-- Sync Down Result -->
            <div v-if="syncDownResult" class="mb-4 p-3 rounded-xl" :class="syncDownResult.success ? 'bg-green-500/10' : 'bg-red-500/10'">
              <div class="flex items-center gap-2">
                <svg v-if="syncDownResult.success" class="w-5 h-5 text-green-600 dark:text-green-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
                </svg>
                <svg v-else class="w-5 h-5 text-red-600 dark:text-red-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                </svg>
                <span :class="syncDownResult.success ? 'text-green-800 dark:text-green-400' : 'text-red-800 dark:text-red-400'">
                  {{ syncDownResult.message }}
                </span>
              </div>
            </div>

            <!-- Checking Changes -->
            <div v-if="checkingChanges" class="flex items-center gap-3 p-3 bg-black/5 dark:bg-white/5 rounded-xl">
              <div class="animate-spin rounded-full h-5 w-5 border-b-2 border-primary-600"></div>
              <span class="text-gray-700 dark:text-gray-300">Checking for changes...</span>
            </div>

            <!-- Syncing -->
            <div v-else-if="syncingDown" class="p-3 bg-black/5 dark:bg-white/5 rounded-xl">
              <div class="flex items-center gap-3">
                <div class="animate-spin rounded-full h-5 w-5 border-b-2 border-primary-600"></div>
                <span class="text-gray-700 dark:text-gray-300">{{ syncDownProgress || 'Syncing...' }}</span>
              </div>
            </div>

            <!-- Check Result -->
            <div v-else-if="syncCheckResult" class="p-3 bg-black/5 dark:bg-white/5 rounded-xl">
              <div v-if="syncCheckResult.hasChanges" class="space-y-3">
                <div class="flex items-center gap-2">
                  <svg class="w-5 h-5 text-blue-600 dark:text-blue-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 14l-7 7m0 0l-7-7m7 7V3" />
                  </svg>
                  <span class="font-medium text-gray-900 dark:text-gray-100">Changes available</span>
                </div>

                <!-- Version info -->
                <div class="text-xs text-gray-500 dark:text-gray-400 font-mono">
                  Local v{{ syncCheckResult.localVersion }} → Remote v{{ syncCheckResult.remoteVersion }}
                </div>

                <!-- Summary -->
                <p class="text-sm text-gray-600 dark:text-gray-400">
                  {{ syncCheckResult.summary.new }} new, {{ syncCheckResult.summary.modified }} modified, {{ syncCheckResult.summary.deleted }} deleted
                </p>

                <!-- Detailed breakdown -->
                <div v-if="syncCheckResult.details" class="mt-3 space-y-2 text-xs border-t border-gray-200 dark:border-gray-600 pt-3">
                  <div class="font-medium text-gray-700 dark:text-gray-300 mb-2">Detailed Changes:</div>

                  <!-- Blog settings -->
                  <div v-if="hasChangesInCategory(syncCheckResult.details.blog)" class="pl-2 border-l-2 border-blue-400">
                    <div class="font-medium text-gray-800 dark:text-gray-200">Blog Settings</div>
                    <div v-for="item in syncCheckResult.details.blog.modified" :key="item.path" class="text-yellow-600 dark:text-yellow-400">
                      ⟳ Modified
                    </div>
                  </div>

                  <!-- Categories -->
                  <div v-if="hasChangesInCategory(syncCheckResult.details.categories)" class="pl-2 border-l-2 border-purple-400">
                    <div class="font-medium text-gray-800 dark:text-gray-200">Categories</div>
                    <div v-for="item in syncCheckResult.details.categories.new" :key="item.path" class="text-green-600 dark:text-green-400">
                      + New: {{ item.id }}
                    </div>
                    <div v-for="item in syncCheckResult.details.categories.modified" :key="item.path" class="text-yellow-600 dark:text-yellow-400">
                      ⟳ Modified: {{ item.id }}
                    </div>
                    <div v-for="item in syncCheckResult.details.categories.deleted" :key="item.path" class="text-red-600 dark:text-red-400">
                      − Deleted: {{ item.id }}
                    </div>
                  </div>

                  <!-- Tags -->
                  <div v-if="hasChangesInCategory(syncCheckResult.details.tags)" class="pl-2 border-l-2 border-pink-400">
                    <div class="font-medium text-gray-800 dark:text-gray-200">Tags</div>
                    <div v-for="item in syncCheckResult.details.tags.new" :key="item.path" class="text-green-600 dark:text-green-400">
                      + New: {{ item.id }}
                    </div>
                    <div v-for="item in syncCheckResult.details.tags.modified" :key="item.path" class="text-yellow-600 dark:text-yellow-400">
                      ⟳ Modified: {{ item.id }}
                    </div>
                    <div v-for="item in syncCheckResult.details.tags.deleted" :key="item.path" class="text-red-600 dark:text-red-400">
                      − Deleted: {{ item.id }}
                    </div>
                  </div>

                  <!-- Posts -->
                  <div v-if="hasChangesInCategory(syncCheckResult.details.posts)" class="pl-2 border-l-2 border-green-400">
                    <div class="font-medium text-gray-800 dark:text-gray-200">Posts</div>
                    <div v-for="item in syncCheckResult.details.posts.new" :key="item.path" class="text-green-600 dark:text-green-400 truncate" :title="item.id">
                      + New: {{ truncateId(item.id) }}
                    </div>
                    <div v-for="item in syncCheckResult.details.posts.modified" :key="item.path" class="text-yellow-600 dark:text-yellow-400 truncate" :title="item.id">
                      ⟳ Modified: {{ truncateId(item.id) }}
                    </div>
                    <div v-for="item in syncCheckResult.details.posts.deleted" :key="item.path" class="text-red-600 dark:text-red-400 truncate" :title="item.id">
                      − Deleted: {{ truncateId(item.id) }}
                    </div>
                  </div>

                  <!-- Drafts -->
                  <div v-if="hasChangesInCategory(syncCheckResult.details.drafts)" class="pl-2 border-l-2 border-orange-400">
                    <div class="font-medium text-gray-800 dark:text-gray-200">Drafts (encrypted)</div>
                    <div v-for="item in syncCheckResult.details.drafts.new" :key="item.path" class="text-green-600 dark:text-green-400 truncate" :title="item.id">
                      + New: {{ truncateId(item.id) }}
                    </div>
                    <div v-for="item in syncCheckResult.details.drafts.modified" :key="item.path" class="text-yellow-600 dark:text-yellow-400 truncate" :title="item.id">
                      ⟳ Modified: {{ truncateId(item.id) }}
                    </div>
                    <div v-for="item in syncCheckResult.details.drafts.deleted" :key="item.path" class="text-red-600 dark:text-red-400 truncate" :title="item.id">
                      − Deleted: {{ truncateId(item.id) }}
                    </div>
                  </div>

                  <!-- Sidebar -->
                  <div v-if="hasChangesInCategory(syncCheckResult.details.sidebar)" class="pl-2 border-l-2 border-indigo-400">
                    <div class="font-medium text-gray-800 dark:text-gray-200">Sidebar Objects</div>
                    <div v-for="item in syncCheckResult.details.sidebar.new" :key="item.path" class="text-green-600 dark:text-green-400 truncate" :title="item.id">
                      + New: {{ truncateId(item.id) }}
                    </div>
                    <div v-for="item in syncCheckResult.details.sidebar.modified" :key="item.path" class="text-yellow-600 dark:text-yellow-400 truncate" :title="item.id">
                      ⟳ Modified: {{ truncateId(item.id) }}
                    </div>
                    <div v-for="item in syncCheckResult.details.sidebar.deleted" :key="item.path" class="text-red-600 dark:text-red-400 truncate" :title="item.id">
                      − Deleted: {{ truncateId(item.id) }}
                    </div>
                  </div>

                  <!-- Static Files -->
                  <div v-if="hasChangesInCategory(syncCheckResult.details.staticFiles)" class="pl-2 border-l-2 border-cyan-400">
                    <div class="font-medium text-gray-800 dark:text-gray-200">Static Files</div>
                    <div v-for="item in syncCheckResult.details.staticFiles.new" :key="item.path" class="text-green-600 dark:text-green-400 truncate" :title="item.path">
                      + New: {{ item.path.split('/').pop() }}
                    </div>
                    <div v-for="item in syncCheckResult.details.staticFiles.modified" :key="item.path" class="text-yellow-600 dark:text-yellow-400 truncate" :title="item.path">
                      ⟳ Modified: {{ item.path.split('/').pop() }}
                    </div>
                    <div v-for="item in syncCheckResult.details.staticFiles.deleted" :key="item.path" class="text-red-600 dark:text-red-400 truncate" :title="item.path">
                      − Deleted: {{ item.path.split('/').pop() }}
                    </div>
                  </div>

                  <!-- Embed Images -->
                  <div v-if="hasChangesInCategory(syncCheckResult.details.embedImages)" class="pl-2 border-l-2 border-teal-400">
                    <div class="font-medium text-gray-800 dark:text-gray-200">Embed Images</div>
                    <div class="text-gray-600 dark:text-gray-400">
                      {{ syncCheckResult.details.embedImages.new.length }} new,
                      {{ syncCheckResult.details.embedImages.modified.length }} modified,
                      {{ syncCheckResult.details.embedImages.deleted.length }} deleted
                    </div>
                  </div>

                  <!-- Themes -->
                  <div v-if="hasChangesInCategory(syncCheckResult.details.themes)" class="pl-2 border-l-2 border-amber-400">
                    <div class="font-medium text-gray-800 dark:text-gray-200">Themes</div>
                    <div v-for="item in syncCheckResult.details.themes.new" :key="item.path" class="text-green-600 dark:text-green-400">
                      + New: {{ item.id }}
                    </div>
                    <div v-for="item in syncCheckResult.details.themes.modified" :key="item.path" class="text-yellow-600 dark:text-yellow-400">
                      ⟳ Modified: {{ item.id }}
                    </div>
                    <div v-for="item in syncCheckResult.details.themes.deleted" :key="item.path" class="text-red-600 dark:text-red-400">
                      − Deleted: {{ item.id }}
                    </div>
                  </div>
                </div>

                <button
                  type="button"
                  @click="pullChanges"
                  class="px-5 py-2.5 bg-primary-500 text-white rounded-xl font-medium hover:bg-primary-600 transition-colors shadow-sm"
                >
                  Pull Changes
                </button>
              </div>
              <div v-else class="flex items-center gap-2">
                <svg class="w-5 h-5 text-green-600 dark:text-green-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
                </svg>
                <span class="text-gray-700 dark:text-gray-300">Up to date (v{{ syncCheckResult.localVersion }})</span>
              </div>
            </div>

            <!-- Default: Check for Changes button -->
            <div v-else>
              <button
                type="button"
                @click="checkForChanges"
                class="px-5 py-2.5 bg-black/5 dark:bg-white/10 text-gray-700 dark:text-gray-300 rounded-xl font-medium hover:bg-black/10 dark:hover:bg-white/15 transition-colors"
              >
                Check for Changes
              </button>
            </div>
          </div>
          <div v-else class="mt-4 pt-4 border-t border-gray-200 dark:border-gray-600">
            <p class="text-sm text-gray-500 dark:text-gray-400">
              Set a Blog URL to enable sync down functionality.
            </p>
          </div>
        </div>

        <!-- Sync Not Enabled -->
        <div v-else class="space-y-4">
          <!-- Password already set -->
          <div v-if="syncConfig?.hasPassword" class="space-y-3">
            <div class="flex items-center gap-2 text-sm text-gray-600 dark:text-gray-400">
              <svg class="w-4 h-4 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
              </svg>
              Password is set
            </div>
            <button
              type="button"
              @click="enableSync"
              class="px-5 py-2.5 bg-primary-500 text-white rounded-xl font-medium hover:bg-primary-600 transition-colors shadow-sm"
            >
              Enable Sync
            </button>
          </div>

          <!-- Need to set password -->
          <div v-else class="space-y-3">
            <p class="text-sm text-gray-600 dark:text-gray-400">
              Set a password to encrypt your draft posts. You'll need this password to import your blog on another device.
            </p>
            <div class="relative">
              <input
                v-model="syncPassword"
                :type="showPassword ? 'text' : 'password'"
                placeholder="Password (min 8 characters)"
                class="w-full px-3.5 py-2.5 pr-10 rounded-xl bg-black/5 dark:bg-white/5 text-gray-900 dark:text-gray-100 border-0 focus:ring-2 focus:ring-primary-500/50 focus:bg-white dark:focus:bg-white/10 transition-colors"
              />
              <button
                type="button"
                @click="showPassword = !showPassword"
                class="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600"
              >
                <svg v-if="showPassword" class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.88 9.88l-3.29-3.29m7.532 7.532l3.29 3.29M3 3l3.59 3.59m0 0A9.953 9.953 0 0112 5c4.478 0 8.268 2.943 9.543 7a10.025 10.025 0 01-4.132 5.411m0 0L21 21" />
                </svg>
                <svg v-else class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
                </svg>
              </button>
            </div>
            <div class="relative">
              <input
                v-model="syncConfirmPassword"
                :type="showConfirmPassword ? 'text' : 'password'"
                placeholder="Confirm password"
                class="w-full px-3.5 py-2.5 pr-10 rounded-xl bg-black/5 dark:bg-white/5 text-gray-900 dark:text-gray-100 border-0 focus:ring-2 focus:ring-primary-500/50 focus:bg-white dark:focus:bg-white/10 transition-colors"
              />
              <button
                type="button"
                @click="showConfirmPassword = !showConfirmPassword"
                class="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600"
              >
                <svg v-if="showConfirmPassword" class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.88 9.88l-3.29-3.29m7.532 7.532l3.29 3.29M3 3l3.59 3.59m0 0A9.953 9.953 0 0112 5c4.478 0 8.268 2.943 9.543 7a10.025 10.025 0 01-4.132 5.411m0 0L21 21" />
                </svg>
                <svg v-else class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
                </svg>
              </button>
            </div>
            <p v-if="syncPassword && syncConfirmPassword && !passwordsMatch" class="text-sm text-red-600 dark:text-red-400">
              Passwords do not match
            </p>
            <button
              type="button"
              @click="enableSync"
              :disabled="!canEnableSync"
              class="px-5 py-2.5 bg-primary-500 text-white rounded-xl font-medium hover:bg-primary-600 transition-colors shadow-sm disabled:opacity-50 disabled:cursor-not-allowed"
            >
              Enable Sync
            </button>
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
    </div>
  </div>
</template>
