<script setup>
import { ref, computed, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useBlogStore } from '@/stores/blog';

const route = useRoute();
const router = useRouter();
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
  <div class="p-6 max-w-2xl">
    <h2 class="text-xl font-bold text-gray-900 dark:text-gray-100 mb-6">Blog Settings</h2>

    <!-- Messages -->
    <div v-if="error" class="mb-6 p-4 bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded-lg text-red-800 dark:text-red-400">
      {{ error }}
    </div>
    <div v-if="success" class="mb-6 p-4 bg-green-50 dark:bg-green-900/20 border border-green-200 dark:border-green-800 rounded-lg text-green-800 dark:text-green-400">
      Settings saved successfully!
    </div>

    <form @submit.prevent="saveSettings" class="space-y-8">
      <!-- Basic Info -->
      <section class="bg-white dark:bg-gray-800 rounded-lg border border-gray-200 dark:border-gray-700 p-6">
        <h3 class="text-lg font-medium text-gray-900 dark:text-gray-100 mb-4">Basic Information</h3>
        <div class="space-y-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Blog Name</label>
            <input
              v-model="form.name"
              type="text"
              class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100 focus:ring-2 focus:ring-primary-500 focus:border-primary-500"
            />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Blog URL</label>
            <input
              v-model="form.url"
              type="url"
              class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100 focus:ring-2 focus:ring-primary-500 focus:border-primary-500"
              placeholder="https://myblog.com"
            />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Tagline</label>
            <input
              v-model="form.tagline"
              type="text"
              class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100 focus:ring-2 focus:ring-primary-500 focus:border-primary-500"
            />
          </div>
        </div>
      </section>

      <!-- Author Info -->
      <section class="bg-white dark:bg-gray-800 rounded-lg border border-gray-200 dark:border-gray-700 p-6">
        <h3 class="text-lg font-medium text-gray-900 dark:text-gray-100 mb-4">Author Information</h3>
        <div class="space-y-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Author Name</label>
            <input
              v-model="form.authorName"
              type="text"
              class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100 focus:ring-2 focus:ring-primary-500 focus:border-primary-500"
            />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Author URL</label>
            <input
              v-model="form.authorUrl"
              type="url"
              class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100 focus:ring-2 focus:ring-primary-500 focus:border-primary-500"
            />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Author Email</label>
            <input
              v-model="form.authorEmail"
              type="email"
              class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100 focus:ring-2 focus:ring-primary-500 focus:border-primary-500"
            />
          </div>
        </div>
      </section>

      <!-- Theme Colors -->
      <section class="bg-white dark:bg-gray-800 rounded-lg border border-gray-200 dark:border-gray-700 p-6">
        <h3 class="text-lg font-medium text-gray-900 dark:text-gray-100 mb-4">Theme Colors</h3>
        <div class="grid grid-cols-2 md:grid-cols-3 gap-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Accent Color</label>
            <div class="flex items-center gap-2">
              <input
                v-model="form.accentColor"
                type="color"
                class="w-10 h-10"
              />
              <input
                v-model="form.accentColor"
                type="text"
                class="flex-1 px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100 text-sm"
              />
            </div>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Background</label>
            <div class="flex items-center gap-2">
              <input
                v-model="form.backgroundColor"
                type="color"
                class="w-10 h-10"
              />
              <input
                v-model="form.backgroundColor"
                type="text"
                class="flex-1 px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100 text-sm"
              />
            </div>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Text Color</label>
            <div class="flex items-center gap-2">
              <input
                v-model="form.textColor"
                type="color"
                class="w-10 h-10"
              />
              <input
                v-model="form.textColor"
                type="text"
                class="flex-1 px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100 text-sm"
              />
            </div>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Light Shade</label>
            <div class="flex items-center gap-2">
              <input
                v-model="form.lightShade"
                type="color"
                class="w-10 h-10"
              />
              <input
                v-model="form.lightShade"
                type="text"
                class="flex-1 px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100 text-sm"
              />
            </div>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Medium Shade</label>
            <div class="flex items-center gap-2">
              <input
                v-model="form.mediumShade"
                type="color"
                class="w-10 h-10"
              />
              <input
                v-model="form.mediumShade"
                type="text"
                class="flex-1 px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100 text-sm"
              />
            </div>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Dark Shade</label>
            <div class="flex items-center gap-2">
              <input
                v-model="form.darkShade"
                type="color"
                class="w-10 h-10"
              />
              <input
                v-model="form.darkShade"
                type="text"
                class="flex-1 px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100 text-sm"
              />
            </div>
          </div>
        </div>

        <!-- Color Preview -->
        <div class="mt-6">
          <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">Preview</label>
          <div class="rounded-lg overflow-hidden border border-gray-200 dark:border-gray-700">
            <iframe
              :srcdoc="colorPreviewHtml"
              class="w-full border-0"
              style="height: 340px;"
            ></iframe>
          </div>
        </div>
      </section>

      <!-- Publishing Settings -->
      <section class="bg-white dark:bg-gray-800 rounded-lg border border-gray-200 dark:border-gray-700 p-6">
        <h3 class="text-lg font-medium text-gray-900 dark:text-gray-100 mb-4">Publishing</h3>
        <div class="space-y-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Publisher Type</label>
            <select
              v-model="form.publisherType"
              class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100 focus:ring-2 focus:ring-primary-500 focus:border-primary-500"
            >
              <option value="manual">Manual (Download ZIP)</option>
              <option value="aws">AWS S3</option>
              <option value="sftp">SFTP</option>
              <option value="git">Git (GitHub Pages, etc.)</option>
            </select>
          </div>

          <!-- AWS Settings -->
          <div v-if="form.publisherType === 'aws'" class="space-y-4 p-4 bg-gray-50 dark:bg-gray-700 rounded-lg">
            <h4 class="font-medium text-gray-900 dark:text-gray-100">AWS S3 Configuration</h4>
            <div class="grid grid-cols-2 gap-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Region</label>
                <input
                  v-model="form.awsRegion"
                  type="text"
                  class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-600 text-gray-900 dark:text-gray-100 focus:ring-2 focus:ring-primary-500 focus:border-primary-500"
                  placeholder="us-east-1"
                />
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">S3 Bucket</label>
                <input
                  v-model="form.awsS3Bucket"
                  type="text"
                  class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-600 text-gray-900 dark:text-gray-100 focus:ring-2 focus:ring-primary-500 focus:border-primary-500"
                  placeholder="my-blog-bucket"
                />
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Access Key ID</label>
                <input
                  v-model="form.awsAccessKeyId"
                  type="text"
                  class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-600 text-gray-900 dark:text-gray-100 focus:ring-2 focus:ring-primary-500 focus:border-primary-500"
                />
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Secret Access Key</label>
                <input
                  v-model="form.awsSecretAccessKey"
                  type="password"
                  class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-600 text-gray-900 dark:text-gray-100 focus:ring-2 focus:ring-primary-500 focus:border-primary-500"
                />
              </div>
              <div class="col-span-2">
                <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">CloudFront Distribution ID</label>
                <input
                  v-model="form.awsCloudFrontDistId"
                  type="text"
                  class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-600 text-gray-900 dark:text-gray-100 focus:ring-2 focus:ring-primary-500 focus:border-primary-500"
                  placeholder="Optional - for cache invalidation"
                />
              </div>
            </div>
          </div>

          <!-- SFTP Settings -->
          <div v-if="form.publisherType === 'sftp'" class="space-y-4 p-4 bg-gray-50 dark:bg-gray-700 rounded-lg">
            <h4 class="font-medium text-gray-900 dark:text-gray-100">SFTP Configuration</h4>
            <div class="grid grid-cols-2 gap-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Host</label>
                <input
                  v-model="form.ftpHost"
                  type="text"
                  class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-600 text-gray-900 dark:text-gray-100 focus:ring-2 focus:ring-primary-500 focus:border-primary-500"
                  placeholder="sftp.example.com"
                />
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Port</label>
                <input
                  v-model.number="form.ftpPort"
                  type="number"
                  class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-600 text-gray-900 dark:text-gray-100 focus:ring-2 focus:ring-primary-500 focus:border-primary-500"
                  placeholder="22"
                />
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Username</label>
                <input
                  v-model="form.ftpUsername"
                  type="text"
                  class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-600 text-gray-900 dark:text-gray-100 focus:ring-2 focus:ring-primary-500 focus:border-primary-500"
                />
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Password</label>
                <input
                  v-model="form.ftpPassword"
                  type="password"
                  class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-600 text-gray-900 dark:text-gray-100 focus:ring-2 focus:ring-primary-500 focus:border-primary-500"
                />
              </div>
              <div class="col-span-2">
                <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Remote Path</label>
                <input
                  v-model="form.ftpPath"
                  type="text"
                  class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-600 text-gray-900 dark:text-gray-100 focus:ring-2 focus:ring-primary-500 focus:border-primary-500"
                  placeholder="/var/www/html"
                />
              </div>
              <div class="col-span-2">
                <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Private Key (optional, alternative to password)</label>
                <textarea
                  v-model="form.ftpPrivateKey"
                  rows="3"
                  class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-600 text-gray-900 dark:text-gray-100 focus:ring-2 focus:ring-primary-500 focus:border-primary-500 font-mono text-xs"
                  placeholder="-----BEGIN OPENSSH PRIVATE KEY-----..."
                ></textarea>
              </div>
            </div>
          </div>

          <!-- Git Settings -->
          <div v-if="form.publisherType === 'git'" class="space-y-4 p-4 bg-gray-50 dark:bg-gray-700 rounded-lg">
            <h4 class="font-medium text-gray-900 dark:text-gray-100">Git Configuration</h4>
            <div class="space-y-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Repository URL</label>
                <input
                  v-model="form.gitRepositoryUrl"
                  type="text"
                  class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-600 text-gray-900 dark:text-gray-100 focus:ring-2 focus:ring-primary-500 focus:border-primary-500"
                  placeholder="https://github.com/username/repo.git"
                />
              </div>
              <div class="grid grid-cols-2 gap-4">
                <div>
                  <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Username</label>
                  <input
                    v-model="form.gitUsername"
                    type="text"
                    class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-600 text-gray-900 dark:text-gray-100 focus:ring-2 focus:ring-primary-500 focus:border-primary-500"
                  />
                </div>
                <div>
                  <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Personal Access Token</label>
                  <input
                    v-model="form.gitToken"
                    type="password"
                    class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-600 text-gray-900 dark:text-gray-100 focus:ring-2 focus:ring-primary-500 focus:border-primary-500"
                  />
                </div>
              </div>
              <div class="grid grid-cols-2 gap-4">
                <div>
                  <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Branch</label>
                  <input
                    v-model="form.gitBranch"
                    type="text"
                    class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-600 text-gray-900 dark:text-gray-100 focus:ring-2 focus:ring-primary-500 focus:border-primary-500"
                    placeholder="main"
                  />
                </div>
                <div>
                  <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Commit Message</label>
                  <input
                    v-model="form.gitCommitMessage"
                    type="text"
                    class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-600 text-gray-900 dark:text-gray-100 focus:ring-2 focus:ring-primary-500 focus:border-primary-500"
                    placeholder="Update blog"
                  />
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      <!-- Save Button -->
      <div class="flex justify-between">
        <button
          type="button"
          @click="deleteBlog"
          class="px-4 py-2 text-red-600 dark:text-red-400 hover:bg-red-50 dark:hover:bg-red-900/20 rounded-lg transition-colors"
        >
          Delete Blog
        </button>
        <button
          type="submit"
          :disabled="saving"
          class="px-6 py-2 bg-primary-600 text-white rounded-lg hover:bg-primary-700 transition-colors disabled:opacity-50"
        >
          {{ saving ? 'Saving...' : 'Save Settings' }}
        </button>
      </div>
    </form>
  </div>
</template>
