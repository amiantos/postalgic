<script setup>
import { ref, computed, watch, nextTick } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useBlogStore } from '@/stores/blog';
import { blogApi, postApi } from '@/api';

const route = useRoute();
const router = useRouter();
const blogStore = useBlogStore();

const blogId = computed(() => route.params.blogId);

const form = ref({});
const saving = ref(false);
const error = ref(null);
const saveStatus = ref(''); // '', 'saving', 'saved'
const exporting = ref(false);
const backfilling = ref(false);
const backfillResult = ref(null);
const searchText = ref('');
const skipNextSave = ref(true);

const sections = [
  { id: 'basic', label: 'Basic Information', terms: 'blog name url tagline timezone' },
  { id: 'author', label: 'Author Information', terms: 'author name url email' },
  { id: 'analytics', label: 'Simple Analytics', terms: 'simple analytics tracking pageviews visitors domain' },
  { id: 'publishing', label: 'Publishing', terms: 'publishing publisher type aws s3 sftp ftp git github cloudflare pages deploy bucket region' },
  { id: 'maintenance', label: 'Maintenance', terms: 'maintenance youtube thumbnails backfill' },
  { id: 'developer', label: 'Developer Tools', terms: 'developer tools debug export' },
  { id: 'danger', label: 'Danger Zone', terms: 'danger delete blog' },
];

function isSectionVisible(sectionId) {
  if (!searchText.value.trim()) return true;
  const query = searchText.value.toLowerCase();
  const section = sections.find(s => s.id === sectionId);
  return section ? section.terms.includes(query) : true;
}

// Load blog data into form
watch(() => blogStore.currentBlog, (blog) => {
  if (blog) {
    skipNextSave.value = true;
    form.value = { ...blog };
  }
}, { immediate: true });

// Debounced auto-save
let saveTimeout = null;
let savedTimeout = null;

watch(form, () => {
  if (skipNextSave.value) {
    skipNextSave.value = false;
    return;
  }

  if (saveTimeout) clearTimeout(saveTimeout);
  saveTimeout = setTimeout(() => autoSave(), 1000);
}, { deep: true });

async function autoSave() {
  saving.value = true;
  saveStatus.value = 'saving';
  error.value = null;

  try {
    await blogStore.updateBlog(blogId.value, form.value);
    saveStatus.value = 'saved';
    if (savedTimeout) clearTimeout(savedTimeout);
    savedTimeout = setTimeout(() => {
      saveStatus.value = '';
    }, 2000);
  } catch (e) {
    error.value = e.message;
    saveStatus.value = '';
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

async function backfillYouTubeThumbnails() {
  backfilling.value = true;
  backfillResult.value = null;
  error.value = null;

  try {
    const result = await postApi.backfillYouTubeThumbnails(blogId.value);
    backfillResult.value = `Updated ${result.updated} of ${result.total} YouTube thumbnails`;
    setTimeout(() => backfillResult.value = null, 5000);
  } catch (e) {
    error.value = e.message;
  } finally {
    backfilling.value = false;
  }
}

async function downloadDebugExport() {
  exporting.value = true;
  error.value = null;

  try {
    const { blob, filename } = await blogApi.debugExport(blogId.value);

    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  } catch (e) {
    error.value = e.message;
  } finally {
    exporting.value = false;
  }
}
</script>

<template>
  <div>
    <!-- Search & Status Bar -->
    <div class="relative mb-6">
      <input
        v-model="searchText"
        type="text"
        placeholder="Search settings..."
        class="admin-input pl-8"
      />
      <svg class="absolute left-2.5 top-1/2 -translate-y-1/2 w-4 h-4 text-site-medium pointer-events-none" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
      </svg>
      <div class="absolute right-2.5 top-1/2 -translate-y-1/2 flex items-center gap-2">
        <span v-if="saveStatus === 'saving'" class="text-xs text-site-accent">Saving...</span>
        <span v-else-if="saveStatus === 'saved'" class="text-xs text-green-600">Saved</span>
        <button
          v-if="searchText"
          @click="searchText = ''"
          class="text-site-medium hover:text-site-dark"
        >
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
          </svg>
        </button>
      </div>
    </div>

    <!-- Error -->
    <div v-if="error" class="mb-6 p-4 border border-red-500 text-sm text-red-600">
      {{ error }}
    </div>

    <div class="space-y-8">
      <!-- Basic Info -->
      <section v-show="isSectionVisible('basic')">
        <h3 class="text-sm font-semibold text-site-dark mb-4 mt-2">Basic Information</h3>
        <div class="space-y-4">
          <div>
            <label class="block text-xs font-semibold text-site-medium mb-2">Blog Name</label>
            <input
              v-model="form.name"
              type="text"
              class="admin-input"
            />
          </div>
          <div>
            <label class="block text-xs font-semibold text-site-medium mb-2">Blog URL</label>
            <input
              v-model="form.url"
              type="url"
              class="admin-input"
              placeholder="https://myblog.com"
            />
          </div>
          <div>
            <label class="block text-xs font-semibold text-site-medium mb-2">Tagline</label>
            <input
              v-model="form.tagline"
              type="text"
              class="admin-input"
            />
          </div>
          <div>
            <label class="block text-xs font-semibold text-site-medium mb-2">Timezone</label>
            <select
              v-model="form.timezone"
              class="admin-input"
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
            <p class="mt-2 text-xs text-site-medium">Dates on your published blog will display in this timezone</p>
          </div>
        </div>
      </section>

      <!-- Author Info -->
      <section v-show="isSectionVisible('author')" class="border-t border-site-light pt-8">
        <h3 class="text-sm font-semibold text-site-dark mb-4">Author Information</h3>
        <div class="space-y-4">
          <div>
            <label class="block text-xs font-semibold text-site-medium mb-2">Author Name</label>
            <input
              v-model="form.authorName"
              type="text"
              class="admin-input"
            />
          </div>
          <div>
            <label class="block text-xs font-semibold text-site-medium mb-2">Author URL</label>
            <input
              v-model="form.authorUrl"
              type="url"
              class="admin-input"
            />
          </div>
          <div>
            <label class="block text-xs font-semibold text-site-medium mb-2">Author Email</label>
            <input
              v-model="form.authorEmail"
              type="email"
              class="admin-input"
            />
          </div>
        </div>
      </section>

      <!-- Simple Analytics -->
      <section v-show="isSectionVisible('analytics')" class="border-t border-site-light pt-8">
        <h3 class="text-sm font-semibold text-site-dark mb-2">Simple Analytics</h3>
        <p class="text-sm text-site-dark mb-4">
          Enable Simple Analytics to track pageviews and visitors on your published blog.
          <a href="https://simpleanalytics.com" target="_blank" class="text-site-accent hover:text-site-accent">Learn more</a>
        </p>
        <div class="space-y-4">
          <label class="flex items-center gap-3">
            <input
              v-model="form.simpleAnalyticsEnabled"
              type="checkbox"
              class="border border-site-light"
            />
            <span class="text-sm text-site-dark">
              Enable Simple Analytics tracking
            </span>
          </label>
          <div v-if="form.simpleAnalyticsEnabled">
            <label class="block text-xs font-semibold text-site-medium mb-2">
              Domain Override (optional)
            </label>
            <input
              v-model="form.simpleAnalyticsDomain"
              type="text"
              class="admin-input"
              placeholder="example.com"
            />
            <p class="mt-2 text-xs text-site-medium">
              Leave empty to use the domain from your Blog URL. Use this if your site is registered under a different domain in Simple Analytics.
            </p>
          </div>
        </div>
      </section>

      <!-- Publishing -->
      <section v-show="isSectionVisible('publishing')" class="border-t border-site-light pt-8">
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

      <!-- Maintenance -->
      <section v-show="isSectionVisible('maintenance')" class="border-t border-site-light pt-8">
        <h3 class="text-sm font-semibold text-site-dark mb-2">Maintenance</h3>
        <p class="text-sm text-site-dark mb-4">
          Download and save YouTube embed thumbnails locally for posts that are still using the YouTube CDN.
        </p>
        <div v-if="backfillResult" class="mb-4 p-4 border border-green-500 text-sm text-green-600">
          {{ backfillResult }}
        </div>
        <button
          type="button"
          @click="backfillYouTubeThumbnails"
          :disabled="backfilling"
          class="px-4 py-2 border border-site-dark text-sm font-semibold text-site-dark rounded-full hover:border-site-accent hover:text-site-accent disabled:opacity-50"
        >
          {{ backfilling ? 'Backfilling...' : 'Backfill YouTube Thumbnails' }}
        </button>
      </section>

      <!-- Developer Tools -->
      <section v-show="isSectionVisible('developer')" class="border-t border-site-light pt-8">
        <h3 class="text-sm font-semibold text-site-dark mb-2">Developer Tools</h3>
        <p class="text-sm text-site-dark mb-4">
          Export a debug bundle containing the full generated site.
        </p>
        <button
          type="button"
          @click="downloadDebugExport"
          :disabled="exporting"
          class="px-4 py-2 border border-site-dark text-sm font-semibold text-site-dark rounded-full hover:border-site-accent hover:text-site-accent disabled:opacity-50"
        >
          {{ exporting ? 'Exporting...' : 'Download Debug Export' }}
        </button>
      </section>

      <!-- Danger Zone -->
      <section v-show="isSectionVisible('danger')" class="border-t border-red-300 pt-8">
        <h3 class="text-sm font-semibold text-red-500 mb-4">Danger Zone</h3>
        <p class="text-sm text-site-dark mb-4">
          Permanently delete this blog and all of its posts, files, and settings. This action cannot be undone.
        </p>
        <button
          type="button"
          @click="deleteBlog"
          class="px-4 py-2 border border-red-500 text-sm font-semibold text-red-500 rounded-full hover:bg-red-500 hover:text-white"
        >
          Delete Blog
        </button>
      </section>
    </div>
  </div>
</template>
