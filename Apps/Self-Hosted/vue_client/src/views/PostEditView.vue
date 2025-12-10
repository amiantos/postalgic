<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useBlogStore } from '@/stores/blog';

const route = useRoute();
const router = useRouter();
const blogStore = useBlogStore();

const blogId = computed(() => route.params.blogId);
const postId = computed(() => route.params.postId);
const isNew = computed(() => !postId.value);

const form = ref({
  title: '',
  content: '',
  isDraft: true,
  categoryId: null,
  tagIds: [],
  createdAt: new Date().toISOString().slice(0, 16)
});

const saving = ref(false);
const error = ref(null);
const newTag = ref('');

onMounted(async () => {
  if (!isNew.value) {
    const post = await blogStore.fetchPost(blogId.value, postId.value);
    form.value = {
      title: post.title || '',
      content: post.content || '',
      isDraft: post.isDraft,
      categoryId: post.categoryId || null,
      tagIds: post.tagIds || [],
      createdAt: new Date(post.createdAt).toISOString().slice(0, 16)
    };
  }
});

async function savePost() {
  if (!form.value.content.trim()) {
    error.value = 'Post content is required';
    return;
  }

  saving.value = true;
  error.value = null;

  try {
    const data = {
      ...form.value,
      createdAt: new Date(form.value.createdAt).toISOString()
    };

    if (isNew.value) {
      await blogStore.createPost(blogId.value, data);
    } else {
      await blogStore.updatePost(blogId.value, postId.value, data);
    }
    router.push({ name: 'blog-posts', params: { blogId: blogId.value } });
  } catch (e) {
    error.value = e.message;
  } finally {
    saving.value = false;
  }
}

async function publishPost() {
  form.value.isDraft = false;
  await savePost();
}

async function addTag() {
  if (!newTag.value.trim()) return;

  try {
    const tag = await blogStore.createTag(blogId.value, { name: newTag.value.trim() });
    form.value.tagIds.push(tag.id);
    newTag.value = '';
  } catch (e) {
    error.value = e.message;
  }
}

function toggleTag(tagId) {
  const index = form.value.tagIds.indexOf(tagId);
  if (index === -1) {
    form.value.tagIds.push(tagId);
  } else {
    form.value.tagIds.splice(index, 1);
  }
}
</script>

<template>
  <div class="p-6 max-w-4xl mx-auto">
    <!-- Header -->
    <div class="flex items-center justify-between mb-6">
      <div class="flex items-center gap-4">
        <router-link
          :to="{ name: 'blog-posts', params: { blogId } }"
          class="text-gray-500 hover:text-gray-700"
        >
          <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
          </svg>
        </router-link>
        <h2 class="text-xl font-bold text-gray-900">
          {{ isNew ? 'New Post' : 'Edit Post' }}
        </h2>
      </div>
      <div class="flex items-center gap-2">
        <button
          @click="savePost"
          :disabled="saving"
          class="px-4 py-2 bg-gray-100 text-gray-700 rounded-lg hover:bg-gray-200 transition-colors disabled:opacity-50"
        >
          {{ saving ? 'Saving...' : 'Save Draft' }}
        </button>
        <button
          @click="publishPost"
          :disabled="saving"
          class="px-4 py-2 bg-primary-600 text-white rounded-lg hover:bg-primary-700 transition-colors disabled:opacity-50"
        >
          Publish
        </button>
      </div>
    </div>

    <!-- Error -->
    <div v-if="error" class="mb-6 p-4 bg-red-50 border border-red-200 rounded-lg text-red-800">
      {{ error }}
    </div>

    <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
      <!-- Main Content -->
      <div class="lg:col-span-2 space-y-6">
        <!-- Title -->
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">Title</label>
          <input
            v-model="form.title"
            type="text"
            class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-primary-500"
            placeholder="Post title (optional)"
          />
        </div>

        <!-- Content -->
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">
            Content <span class="text-red-500">*</span>
          </label>
          <textarea
            v-model="form.content"
            rows="20"
            class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-primary-500 font-mono text-sm"
            placeholder="Write your post content in Markdown..."
          ></textarea>
          <p class="mt-1 text-sm text-gray-500">Supports Markdown formatting</p>
        </div>
      </div>

      <!-- Sidebar -->
      <div class="space-y-6">
        <!-- Status -->
        <div class="bg-white rounded-lg border border-gray-200 p-4">
          <h3 class="font-medium text-gray-900 mb-3">Status</h3>
          <label class="flex items-center gap-2">
            <input
              type="checkbox"
              v-model="form.isDraft"
              class="rounded border-gray-300 text-primary-600 focus:ring-primary-500"
            />
            <span class="text-sm text-gray-700">Save as draft</span>
          </label>
        </div>

        <!-- Date -->
        <div class="bg-white rounded-lg border border-gray-200 p-4">
          <h3 class="font-medium text-gray-900 mb-3">Publish Date</h3>
          <input
            v-model="form.createdAt"
            type="datetime-local"
            class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-primary-500 text-sm"
          />
        </div>

        <!-- Category -->
        <div class="bg-white rounded-lg border border-gray-200 p-4">
          <h3 class="font-medium text-gray-900 mb-3">Category</h3>
          <select
            v-model="form.categoryId"
            class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-primary-500 text-sm"
          >
            <option :value="null">No category</option>
            <option v-for="category in blogStore.categories" :key="category.id" :value="category.id">
              {{ category.name }}
            </option>
          </select>
        </div>

        <!-- Tags -->
        <div class="bg-white rounded-lg border border-gray-200 p-4">
          <h3 class="font-medium text-gray-900 mb-3">Tags</h3>

          <!-- Selected Tags -->
          <div v-if="form.tagIds.length > 0" class="flex flex-wrap gap-2 mb-3">
            <span
              v-for="tagId in form.tagIds"
              :key="tagId"
              class="px-2 py-1 bg-primary-100 text-primary-700 text-xs rounded-full flex items-center gap-1"
            >
              {{ blogStore.tags.find(t => t.id === tagId)?.name }}
              <button @click="toggleTag(tagId)" class="hover:text-primary-900">×</button>
            </span>
          </div>

          <!-- Available Tags -->
          <div v-if="blogStore.tags.length > 0" class="mb-3">
            <div class="flex flex-wrap gap-1">
              <button
                v-for="tag in blogStore.tags.filter(t => !form.tagIds.includes(t.id))"
                :key="tag.id"
                @click="toggleTag(tag.id)"
                class="px-2 py-1 bg-gray-100 text-gray-600 text-xs rounded-full hover:bg-gray-200"
              >
                + {{ tag.name }}
              </button>
            </div>
          </div>

          <!-- Add New Tag -->
          <div class="flex gap-2">
            <input
              v-model="newTag"
              type="text"
              placeholder="New tag"
              class="flex-1 px-3 py-1.5 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-primary-500 text-sm"
              @keyup.enter="addTag"
            />
            <button
              @click="addTag"
              class="px-3 py-1.5 bg-gray-100 text-gray-700 rounded-lg hover:bg-gray-200 text-sm"
            >
              Add
            </button>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
