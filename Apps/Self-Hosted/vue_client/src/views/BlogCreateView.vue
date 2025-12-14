<script setup>
import { ref } from 'vue';
import { useRouter } from 'vue-router';
import { useBlogStore } from '@/stores/blog';

const router = useRouter();
const blogStore = useBlogStore();

const form = ref({
  name: '',
  url: '',
  tagline: '',
  authorName: '',
  authorUrl: '',
  authorEmail: ''
});

const saving = ref(false);
const error = ref(null);

async function createBlog() {
  if (!form.value.name.trim()) {
    error.value = 'Blog name is required';
    return;
  }

  saving.value = true;
  error.value = null;

  try {
    const blog = await blogStore.createBlog(form.value);
    router.push({ name: 'blog-posts', params: { blogId: blog.id } });
  } catch (e) {
    error.value = e.message;
  } finally {
    saving.value = false;
  }
}
</script>

<template>
  <div class="min-h-screen bg-gray-50">
    <!-- Header -->
    <header class="bg-white shadow-sm">
      <div class="max-w-2xl mx-auto px-4 py-6">
        <div class="flex items-center gap-4">
          <router-link to="/" class="text-gray-500 hover:text-gray-700">
            <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
            </svg>
          </router-link>
          <h1 class="text-xl font-bold text-gray-900">Create New Blog</h1>
        </div>
      </div>
    </header>

    <!-- Form -->
    <main class="max-w-2xl mx-auto px-4 py-8">
      <form @submit.prevent="createBlog" class="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
        <!-- Error -->
        <div v-if="error" class="mb-6 p-4 bg-red-50 border border-red-200 rounded-lg text-red-800">
          {{ error }}
        </div>

        <!-- Blog Name -->
        <div class="mb-6">
          <label class="block text-sm font-medium text-gray-700 mb-2">
            Blog Name <span class="text-red-500">*</span>
          </label>
          <input
            v-model="form.name"
            type="text"
            class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-primary-500"
            placeholder="My Awesome Blog"
          />
        </div>

        <!-- Blog URL -->
        <div class="mb-6">
          <label class="block text-sm font-medium text-gray-700 mb-2">Blog URL</label>
          <input
            v-model="form.url"
            type="url"
            class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-primary-500"
            placeholder="https://myblog.com"
          />
          <p class="mt-1 text-sm text-gray-500">The public URL where your blog will be hosted</p>
        </div>

        <!-- Tagline -->
        <div class="mb-6">
          <label class="block text-sm font-medium text-gray-700 mb-2">Tagline</label>
          <input
            v-model="form.tagline"
            type="text"
            class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-primary-500"
            placeholder="A blog about awesome things"
          />
        </div>

        <hr class="my-6" />

        <h3 class="text-lg font-medium text-gray-900 mb-4">Author Information</h3>

        <!-- Author Name -->
        <div class="mb-6">
          <label class="block text-sm font-medium text-gray-700 mb-2">Author Name</label>
          <input
            v-model="form.authorName"
            type="text"
            class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-primary-500"
            placeholder="John Doe"
          />
        </div>

        <!-- Author URL -->
        <div class="mb-6">
          <label class="block text-sm font-medium text-gray-700 mb-2">Author URL</label>
          <input
            v-model="form.authorUrl"
            type="url"
            class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-primary-500"
            placeholder="https://johndoe.com"
          />
        </div>

        <!-- Author Email -->
        <div class="mb-6">
          <label class="block text-sm font-medium text-gray-700 mb-2">Author Email</label>
          <input
            v-model="form.authorEmail"
            type="email"
            class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-primary-500"
            placeholder="john@example.com"
          />
        </div>

        <!-- Actions -->
        <div class="flex justify-end gap-3 pt-4">
          <router-link
            to="/"
            class="px-4 py-2 text-gray-700 hover:bg-gray-100 rounded-lg transition-colors"
          >
            Cancel
          </router-link>
          <button
            type="submit"
            :disabled="saving"
            class="px-4 py-2 bg-primary-600 text-white rounded-lg hover:bg-primary-700 transition-colors disabled:opacity-50"
          >
            {{ saving ? 'Creating...' : 'Create Blog' }}
          </button>
        </div>
      </form>
    </main>
  </div>
</template>
