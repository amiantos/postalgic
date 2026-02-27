<script setup>
import { ref, computed, watch, onMounted } from 'vue';
import { useRoute } from 'vue-router';
import { useBlogStore } from '@/stores/blog';
import { useSyncStore } from '@/stores/sync';
import { syncApi } from '@/api';

const route = useRoute();
const blogStore = useBlogStore();
const syncStore = useSyncStore();

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

    // Clear the sync badge since we've synced
    syncStore.clearChanges();

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
    <!-- Messages -->
    <div v-if="error" class="mb-6 p-4 border border-red-500 text-sm text-red-600">
      {{ error }}
    </div>
    <div v-if="success" class="mb-6 p-4 border border-green-500 text-sm text-green-600">
      Settings saved successfully!
    </div>

    <form @submit.prevent="saveSettings" class="space-y-8">
      <!-- Publishing Settings -->
      <section>
        <h3 class="text-sm font-semibold text-site-dark mb-4">Publishing</h3>
        <div class="space-y-4">
          <div>
            <label class="block text-xs font-semibold text-site-medium mb-2">Publisher Type</label>
            <select
              v-model="form.publisherType"
              class="admin-input"
            >
              <option value="manual">Manual (Download ZIP)</option>
              <option value="aws">AWS S3</option>
              <option value="sftp">SFTP</option>
              <option value="git">Git (GitHub Pages, etc.)</option>
              <option value="cloudflare">Cloudflare Pages</option>
            </select>
          </div>

          <!-- AWS Settings -->
          <div v-if="form.publisherType === 'aws'" class="space-y-4 p-4 border border-site-light">
            <h4 class="text-sm font-semibold text-site-dark">AWS S3 Configuration</h4>
            <div class="grid grid-cols-2 gap-4">
              <div>
                <label class="block text-xs font-semibold text-site-medium mb-2">Region</label>
                <input
                  v-model="form.awsRegion"
                  type="text"
                  class="admin-input"
                  placeholder="us-east-1"
                />
              </div>
              <div>
                <label class="block text-xs font-semibold text-site-medium mb-2">S3 Bucket</label>
                <input
                  v-model="form.awsS3Bucket"
                  type="text"
                  class="admin-input"
                  placeholder="my-blog-bucket"
                />
              </div>
              <div>
                <label class="block text-xs font-semibold text-site-medium mb-2">Access Key ID</label>
                <input
                  v-model="form.awsAccessKeyId"
                  type="text"
                  class="admin-input"
                />
              </div>
              <div>
                <label class="block text-xs font-semibold text-site-medium mb-2">Secret Access Key</label>
                <input
                  v-model="form.awsSecretAccessKey"
                  type="password"
                  class="admin-input"
                />
              </div>
              <div class="col-span-2">
                <label class="block text-xs font-semibold text-site-medium mb-2">CloudFront Distribution ID</label>
                <input
                  v-model="form.awsCloudFrontDistId"
                  type="text"
                  class="admin-input"
                  placeholder="Optional - for cache invalidation"
                />
              </div>
            </div>
          </div>

          <!-- SFTP Settings -->
          <div v-if="form.publisherType === 'sftp'" class="space-y-4 p-4 border border-site-light">
            <h4 class="text-sm font-semibold text-site-dark">SFTP Configuration</h4>
            <div class="grid grid-cols-2 gap-4">
              <div>
                <label class="block text-xs font-semibold text-site-medium mb-2">Host</label>
                <input
                  v-model="form.ftpHost"
                  type="text"
                  class="admin-input"
                  placeholder="sftp.example.com"
                />
              </div>
              <div>
                <label class="block text-xs font-semibold text-site-medium mb-2">Port</label>
                <input
                  v-model.number="form.ftpPort"
                  type="number"
                  class="admin-input"
                  placeholder="22"
                />
              </div>
              <div>
                <label class="block text-xs font-semibold text-site-medium mb-2">Username</label>
                <input
                  v-model="form.ftpUsername"
                  type="text"
                  class="admin-input"
                />
              </div>
              <div>
                <label class="block text-xs font-semibold text-site-medium mb-2">Password</label>
                <input
                  v-model="form.ftpPassword"
                  type="password"
                  class="admin-input"
                />
              </div>
              <div class="col-span-2">
                <label class="block text-xs font-semibold text-site-medium mb-2">Remote Path</label>
                <input
                  v-model="form.ftpPath"
                  type="text"
                  class="admin-input"
                  placeholder="/var/www/html"
                />
              </div>
              <div class="col-span-2">
                <label class="block text-xs font-semibold text-site-medium mb-2">Private Key (optional)</label>
                <textarea
                  v-model="form.ftpPrivateKey"
                  rows="3"
                  class="admin-input"
                  placeholder="-----BEGIN OPENSSH PRIVATE KEY-----..."
                ></textarea>
              </div>
            </div>
          </div>

          <!-- Git Settings -->
          <div v-if="form.publisherType === 'git'" class="space-y-4 p-4 border border-site-light">
            <h4 class="text-sm font-semibold text-site-dark">Git Configuration</h4>
            <div class="space-y-4">
              <div>
                <label class="block text-xs font-semibold text-site-medium mb-2">Repository URL</label>
                <input
                  v-model="form.gitRepositoryUrl"
                  type="text"
                  class="admin-input"
                  placeholder="https://github.com/user/repo.git"
                />
                <p class="mt-2 text-xs text-site-medium">
                  Use HTTPS URL with username/token, or SSH URL with private key
                </p>
              </div>
              <div class="grid grid-cols-2 gap-4">
                <div>
                  <label class="block text-xs font-semibold text-site-medium mb-2">Username</label>
                  <input
                    v-model="form.gitUsername"
                    type="text"
                    class="admin-input"
                    placeholder="For HTTPS URLs"
                  />
                </div>
                <div>
                  <label class="block text-xs font-semibold text-site-medium mb-2">Personal Access Token</label>
                  <input
                    v-model="form.gitToken"
                    type="password"
                    class="admin-input"
                    placeholder="For HTTPS URLs"
                  />
                </div>
              </div>
              <div>
                <label class="block text-xs font-semibold text-site-medium mb-2">Private Key (for SSH URLs)</label>
                <textarea
                  v-model="form.gitPrivateKey"
                  rows="3"
                  class="admin-input"
                  placeholder="-----BEGIN OPENSSH PRIVATE KEY-----..."
                ></textarea>
                <p class="mt-2 text-xs text-site-medium">
                  Required for SSH URLs. Leave blank for HTTPS URLs.
                </p>
              </div>
              <div class="grid grid-cols-2 gap-4">
                <div>
                  <label class="block text-xs font-semibold text-site-medium mb-2">Branch</label>
                  <input
                    v-model="form.gitBranch"
                    type="text"
                    class="admin-input"
                    placeholder="main"
                  />
                </div>
                <div>
                  <label class="block text-xs font-semibold text-site-medium mb-2">Commit Message</label>
                  <input
                    v-model="form.gitCommitMessage"
                    type="text"
                    class="admin-input"
                    placeholder="Update blog"
                  />
                </div>
              </div>
            </div>
          </div>

          <!-- Cloudflare Pages Settings -->
          <div v-if="form.publisherType === 'cloudflare'" class="space-y-4 p-4 border border-site-light">
            <h4 class="text-sm font-semibold text-site-dark">Cloudflare Pages Configuration</h4>
            <p class="text-sm text-site-dark">
              Requires the <code class="font-mono">wrangler</code> CLI to be installed. The project will be auto-created if it doesn't exist.
            </p>
            <div class="space-y-4">
              <div>
                <label class="block text-xs font-semibold text-site-medium mb-2">Account ID</label>
                <input
                  v-model="form.cfAccountId"
                  type="text"
                  class="admin-input"
                  placeholder="Your Cloudflare Account ID"
                />
                <p class="mt-1 text-xs text-site-medium">
                  Found in your Cloudflare dashboard under Account ID
                </p>
              </div>
              <div>
                <label class="block text-xs font-semibold text-site-medium mb-2">API Token</label>
                <input
                  v-model="form.cfApiToken"
                  type="password"
                  class="admin-input"
                  placeholder="Cloudflare API Token"
                />
                <p class="mt-1 text-xs text-site-medium">
                  Create a token with "Cloudflare Pages: Edit" permission
                </p>
              </div>
              <div>
                <label class="block text-xs font-semibold text-site-medium mb-2">Project Name</label>
                <input
                  v-model="form.cfProjectName"
                  type="text"
                  class="admin-input"
                  placeholder="my-blog"
                />
                <p class="mt-1 text-xs text-site-medium">
                  Your site will be available at &lt;project-name&gt;.pages.dev
                </p>
              </div>
            </div>
          </div>
        </div>
      </section>

      <!-- Sync Settings -->
      <section class="border-t border-site-light pt-8">
        <h3 class="text-sm font-semibold text-site-dark mb-2">Sync</h3>
        <p class="text-sm text-site-dark mb-4">
          Sync data is automatically generated alongside your published site, allowing you to import your blog on other devices or the iOS app.
          Drafts are not synced - they remain local to each device.
        </p>

        <!-- Loading -->
        <div v-if="syncLoading" class="py-4">
          <p class="text-sm text-site-medium">Loading...</p>
        </div>

        <!-- Sync Status -->
        <div v-else class="space-y-4">
          <div class="p-4 border border-site-light">
            <div v-if="syncConfig?.lastSyncedAt" class="text-sm text-site-dark">
              Last published: {{ new Date(syncConfig.lastSyncedAt).toLocaleString() }}
            </div>
            <div v-else class="text-sm text-site-dark">
              Sync data will be generated when you publish your blog.
            </div>
          </div>

          <!-- Sync Down Section -->
          <div v-if="form.url" class="mt-4 pt-4 border-t border-site-light">
            <h4 class="text-sm font-semibold text-site-dark mb-3">Sync Down</h4>
            <p class="text-sm text-site-dark mb-3">
              Pull changes from your published site to update this instance.
            </p>

            <!-- Sync Down Error -->
            <div v-if="syncDownError" class="mb-4 p-3 border border-red-500 text-sm text-red-600">
              {{ syncDownError }}
            </div>

            <!-- Sync Down Result -->
            <div v-if="syncDownResult" class="mb-4 p-3 border" :class="syncDownResult.success ? 'border-green-500' : 'border-red-500'">
              <span :class="syncDownResult.success ? 'text-green-600' : 'text-red-600'" class="text-sm">
                {{ syncDownResult.message }}
              </span>
            </div>

            <!-- Checking Changes -->
            <div v-if="checkingChanges" class="p-3 border border-site-light">
              <span class="text-sm text-site-dark">Checking for changes...</span>
            </div>

            <!-- Syncing -->
            <div v-else-if="syncingDown" class="p-3 border border-site-light">
              <span class="text-sm text-site-dark">{{ syncDownProgress || 'Syncing...' }}</span>
            </div>

            <!-- Check Result -->
            <div v-else-if="syncCheckResult" class="p-3 border border-site-light">
              <div v-if="syncCheckResult.hasChanges" class="space-y-3">
                <div class="text-sm text-site-dark">
                  Changes available
                </div>

                <!-- Version info -->
                <div class="text-xs text-site-medium">
                  Local v{{ syncCheckResult.localVersion }} → Remote v{{ syncCheckResult.remoteVersion }}
                </div>

                <!-- Summary -->
                <p class="text-sm text-site-dark">
                  {{ syncCheckResult.summary.new }} new, {{ syncCheckResult.summary.modified }} modified, {{ syncCheckResult.summary.deleted }} deleted
                </p>

                <!-- Detailed breakdown -->
                <div v-if="syncCheckResult.details" class="mt-3 space-y-2 text-xs border-t border-site-light pt-3">
                  <div class="text-xs font-semibold text-site-medium mb-2">Detailed Changes:</div>

                  <!-- Blog settings -->
                  <div v-if="hasChangesInCategory(syncCheckResult.details.blog)" class="pl-2 border-l border-blue-400">
                    <div class="text-site-dark">Blog Settings</div>
                    <div v-for="item in syncCheckResult.details.blog.modified" :key="item.path" class="text-yellow-600">
                      ⟳ Modified
                    </div>
                  </div>

                  <!-- Categories -->
                  <div v-if="hasChangesInCategory(syncCheckResult.details.categories)" class="pl-2 border-l border-purple-400">
                    <div class="text-site-dark">Categories</div>
                    <div v-for="item in syncCheckResult.details.categories.new" :key="item.path" class="text-green-600">
                      + New: {{ item.id }}
                    </div>
                    <div v-for="item in syncCheckResult.details.categories.modified" :key="item.path" class="text-yellow-600">
                      ⟳ Modified: {{ item.id }}
                    </div>
                    <div v-for="item in syncCheckResult.details.categories.deleted" :key="item.path" class="text-red-600">
                      − Deleted: {{ item.id }}
                    </div>
                  </div>

                  <!-- Tags -->
                  <div v-if="hasChangesInCategory(syncCheckResult.details.tags)" class="pl-2 border-l border-pink-400">
                    <div class="text-site-dark">Tags</div>
                    <div v-for="item in syncCheckResult.details.tags.new" :key="item.path" class="text-green-600">
                      + New: {{ item.id }}
                    </div>
                    <div v-for="item in syncCheckResult.details.tags.modified" :key="item.path" class="text-yellow-600">
                      ⟳ Modified: {{ item.id }}
                    </div>
                    <div v-for="item in syncCheckResult.details.tags.deleted" :key="item.path" class="text-red-600">
                      − Deleted: {{ item.id }}
                    </div>
                  </div>

                  <!-- Posts -->
                  <div v-if="hasChangesInCategory(syncCheckResult.details.posts)" class="pl-2 border-l border-green-400">
                    <div class="text-site-dark">Posts</div>
                    <div v-for="item in syncCheckResult.details.posts.new" :key="item.path" class="text-green-600 truncate" :title="item.id">
                      + New: {{ truncateId(item.id) }}
                    </div>
                    <div v-for="item in syncCheckResult.details.posts.modified" :key="item.path" class="text-yellow-600 truncate" :title="item.id">
                      ⟳ Modified: {{ truncateId(item.id) }}
                    </div>
                    <div v-for="item in syncCheckResult.details.posts.deleted" :key="item.path" class="text-red-600 truncate" :title="item.id">
                      − Deleted: {{ truncateId(item.id) }}
                    </div>
                  </div>

                  <!-- Sidebar -->
                  <div v-if="hasChangesInCategory(syncCheckResult.details.sidebar)" class="pl-2 border-l border-indigo-400">
                    <div class="text-site-dark">Sidebar Objects</div>
                    <div v-for="item in syncCheckResult.details.sidebar.new" :key="item.path" class="text-green-600 truncate" :title="item.id">
                      + New: {{ truncateId(item.id) }}
                    </div>
                    <div v-for="item in syncCheckResult.details.sidebar.modified" :key="item.path" class="text-yellow-600 truncate" :title="item.id">
                      ⟳ Modified: {{ truncateId(item.id) }}
                    </div>
                    <div v-for="item in syncCheckResult.details.sidebar.deleted" :key="item.path" class="text-red-600 truncate" :title="item.id">
                      − Deleted: {{ truncateId(item.id) }}
                    </div>
                  </div>

                  <!-- Static Files -->
                  <div v-if="hasChangesInCategory(syncCheckResult.details.staticFiles)" class="pl-2 border-l border-cyan-400">
                    <div class="text-site-dark">Static Files</div>
                    <div v-for="item in syncCheckResult.details.staticFiles.new" :key="item.path" class="text-green-600 truncate" :title="item.path">
                      + New: {{ item.path.split('/').pop() }}
                    </div>
                    <div v-for="item in syncCheckResult.details.staticFiles.modified" :key="item.path" class="text-yellow-600 truncate" :title="item.path">
                      ⟳ Modified: {{ item.path.split('/').pop() }}
                    </div>
                    <div v-for="item in syncCheckResult.details.staticFiles.deleted" :key="item.path" class="text-red-600 truncate" :title="item.path">
                      − Deleted: {{ item.path.split('/').pop() }}
                    </div>
                  </div>
                </div>

                <button
                  type="button"
                  @click="pullChanges"
                  class="h-10 px-3 font-mono text-sm uppercase tracking-wider bg-site-accent text-white hover:bg-[#e89200] transition-colors"
                >
                  Pull Changes
                </button>
              </div>
              <div v-else class="text-sm text-green-600">
                Up to date (v{{ syncCheckResult.localVersion }})
              </div>
            </div>

            <!-- Default: Check for Changes button -->
            <div v-else>
              <button
                type="button"
                @click="checkForChanges"
                class="h-10 px-3 font-mono text-sm uppercase tracking-wider border border-site-dark text-site-dark hover:border-site-accent hover:text-site-accent transition-colors"
              >
                Check for Changes
              </button>
            </div>
          </div>
          <div v-else class="mt-4 pt-4 border-t border-site-light">
            <p class="text-sm text-site-dark">
              Set a Blog URL in Basic settings to enable sync down functionality.
            </p>
          </div>
        </div>
      </section>

      <!-- Save Button -->
      <section class="border-t border-site-light pt-8">
        <div class="flex justify-end">
          <button
            type="submit"
            :disabled="saving"
            class="h-10 px-3 font-mono text-sm uppercase tracking-wider bg-site-accent text-white hover:bg-[#e89200] transition-colors disabled:opacity-50"
          >
            {{ saving ? 'Saving...' : 'Save Settings' }}
          </button>
        </div>
      </section>
    </form>
  </div>
</template>
