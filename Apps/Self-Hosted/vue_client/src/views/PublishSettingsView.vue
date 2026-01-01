<script setup>
import { ref, computed, watch, onMounted } from 'vue';
import { useRoute } from 'vue-router';
import { useBlogStore } from '@/stores/blog';
import { syncApi } from '@/api';
import PageToolbar from '@/components/PageToolbar.vue';
import SettingsTabs from '@/components/SettingsTabs.vue';

const route = useRoute();
const blogStore = useBlogStore();

const blogId = computed(() => route.params.blogId);

const form = ref({});
const saving = ref(false);
const error = ref(null);
const success = ref(false);

// Sync settings state
const syncConfig = ref(null);
const syncLoading = ref(false);

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
  try {
    syncConfig.value = await syncApi.getStatus(blogId.value);
  } catch (e) {
    // Config doesn't exist yet, that's fine
    syncConfig.value = { lastSyncedVersion: 0 };
  } finally {
    syncLoading.value = false;
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
    const result = await syncApi.pull(blogId.value);
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
</script>

<template>
  <div>
    <PageToolbar title="Publish Settings">
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
        <h3 class="text-lg font-medium text-gray-900 dark:text-gray-100 mb-4">Sync</h3>
        <p class="text-sm text-gray-600 dark:text-gray-400 mb-4">
          Sync data is automatically generated alongside your published site, allowing you to import your blog on other devices or the iOS app.
          Drafts are not synced - they remain local to each device.
        </p>

        <!-- Loading -->
        <div v-if="syncLoading" class="text-center py-4">
          <div class="animate-spin rounded-full h-6 w-6 border-b-2 border-primary-600 mx-auto"></div>
        </div>

        <!-- Sync Status -->
        <div v-else class="space-y-4">
          <div class="flex items-center gap-3 p-4 bg-black/5 dark:bg-white/5 rounded-xl">
            <svg class="w-5 h-5 text-primary-600 dark:text-primary-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
            </svg>
            <div>
              <p v-if="syncConfig?.lastSyncedAt" class="text-sm text-gray-700 dark:text-gray-300">
                Last published: {{ new Date(syncConfig.lastSyncedAt).toLocaleString() }}
              </p>
              <p v-else class="text-sm text-gray-700 dark:text-gray-300">
                Sync data will be generated when you publish your blog.
              </p>
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
      </section>

      <!-- Save Button -->
      <div class="flex justify-end">
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
