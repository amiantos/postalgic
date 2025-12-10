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
    <h2 class="text-xl font-bold text-gray-900 mb-6">Blog Settings</h2>

    <!-- Messages -->
    <div v-if="error" class="mb-6 p-4 bg-red-50 border border-red-200 rounded-lg text-red-800">
      {{ error }}
    </div>
    <div v-if="success" class="mb-6 p-4 bg-green-50 border border-green-200 rounded-lg text-green-800">
      Settings saved successfully!
    </div>

    <form @submit.prevent="saveSettings" class="space-y-8">
      <!-- Basic Info -->
      <section class="bg-white rounded-lg border border-gray-200 p-6">
        <h3 class="text-lg font-medium text-gray-900 mb-4">Basic Information</h3>
        <div class="space-y-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Blog Name</label>
            <input
              v-model="form.name"
              type="text"
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-primary-500"
            />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Blog URL</label>
            <input
              v-model="form.url"
              type="url"
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-primary-500"
              placeholder="https://myblog.com"
            />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Tagline</label>
            <input
              v-model="form.tagline"
              type="text"
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-primary-500"
            />
          </div>
        </div>
      </section>

      <!-- Author Info -->
      <section class="bg-white rounded-lg border border-gray-200 p-6">
        <h3 class="text-lg font-medium text-gray-900 mb-4">Author Information</h3>
        <div class="space-y-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Author Name</label>
            <input
              v-model="form.authorName"
              type="text"
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-primary-500"
            />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Author URL</label>
            <input
              v-model="form.authorUrl"
              type="url"
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-primary-500"
            />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Author Email</label>
            <input
              v-model="form.authorEmail"
              type="email"
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-primary-500"
            />
          </div>
        </div>
      </section>

      <!-- Theme Colors -->
      <section class="bg-white rounded-lg border border-gray-200 p-6">
        <h3 class="text-lg font-medium text-gray-900 mb-4">Theme Colors</h3>
        <div class="grid grid-cols-2 md:grid-cols-3 gap-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Accent Color</label>
            <div class="flex items-center gap-2">
              <input
                v-model="form.accentColor"
                type="color"
                class="w-10 h-10"
              />
              <input
                v-model="form.accentColor"
                type="text"
                class="flex-1 px-3 py-2 border border-gray-300 rounded-lg text-sm"
              />
            </div>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Background</label>
            <div class="flex items-center gap-2">
              <input
                v-model="form.backgroundColor"
                type="color"
                class="w-10 h-10"
              />
              <input
                v-model="form.backgroundColor"
                type="text"
                class="flex-1 px-3 py-2 border border-gray-300 rounded-lg text-sm"
              />
            </div>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Text Color</label>
            <div class="flex items-center gap-2">
              <input
                v-model="form.textColor"
                type="color"
                class="w-10 h-10"
              />
              <input
                v-model="form.textColor"
                type="text"
                class="flex-1 px-3 py-2 border border-gray-300 rounded-lg text-sm"
              />
            </div>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Light Shade</label>
            <div class="flex items-center gap-2">
              <input
                v-model="form.lightShade"
                type="color"
                class="w-10 h-10"
              />
              <input
                v-model="form.lightShade"
                type="text"
                class="flex-1 px-3 py-2 border border-gray-300 rounded-lg text-sm"
              />
            </div>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Medium Shade</label>
            <div class="flex items-center gap-2">
              <input
                v-model="form.mediumShade"
                type="color"
                class="w-10 h-10"
              />
              <input
                v-model="form.mediumShade"
                type="text"
                class="flex-1 px-3 py-2 border border-gray-300 rounded-lg text-sm"
              />
            </div>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Dark Shade</label>
            <div class="flex items-center gap-2">
              <input
                v-model="form.darkShade"
                type="color"
                class="w-10 h-10"
              />
              <input
                v-model="form.darkShade"
                type="text"
                class="flex-1 px-3 py-2 border border-gray-300 rounded-lg text-sm"
              />
            </div>
          </div>
        </div>
      </section>

      <!-- Save Button -->
      <div class="flex justify-between">
        <button
          type="button"
          @click="deleteBlog"
          class="px-4 py-2 text-red-600 hover:bg-red-50 rounded-lg transition-colors"
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
