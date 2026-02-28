<script setup>
import { ref, computed, watch } from 'vue';
import { useRoute } from 'vue-router';
import { useBlogStore } from '@/stores/blog';

const route = useRoute();
const blogStore = useBlogStore();

const blogId = computed(() => route.params.blogId);

const form = ref({});
const saving = ref(false);
const error = ref(null);
const success = ref(false);

watch(() => blogStore.currentBlog, (blog) => {
  if (blog) {
    form.value = { ...blog };
  }
}, { immediate: true });

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
