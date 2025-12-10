<script setup>
import { ref, computed, onMounted } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useBlogStore } from '@/stores/blog';

const route = useRoute();
const router = useRouter();
const blogStore = useBlogStore();

const showDeleteModal = ref(false);
const postToDelete = ref(null);
const filter = ref('all'); // 'all', 'published', 'draft'

const blogId = computed(() => route.params.blogId);

const filteredPosts = computed(() => {
  if (filter.value === 'published') {
    return blogStore.publishedPosts;
  } else if (filter.value === 'draft') {
    return blogStore.draftPosts;
  }
  return blogStore.posts;
});

function navigateToPost(postId) {
  router.push({ name: 'post-edit', params: { blogId: blogId.value, postId } });
}

function createNewPost() {
  router.push({ name: 'post-create', params: { blogId: blogId.value } });
}

function confirmDelete(post) {
  postToDelete.value = post;
  showDeleteModal.value = true;
}

async function deletePost() {
  if (postToDelete.value) {
    await blogStore.deletePost(blogId.value, postToDelete.value.id);
    showDeleteModal.value = false;
    postToDelete.value = null;
  }
}
</script>

<template>
  <div class="p-6">
    <!-- Header -->
    <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 mb-6">
      <div>
        <h2 class="text-xl font-bold text-gray-900">Posts</h2>
        <p class="text-gray-500 text-sm">
          {{ blogStore.posts.length }} total
          ({{ blogStore.publishedPosts.length }} published, {{ blogStore.draftPosts.length }} drafts)
        </p>
      </div>
      <button
        @click="createNewPost"
        class="px-4 py-2 bg-primary-600 text-white rounded-lg hover:bg-primary-700 transition-colors"
      >
        New Post
      </button>
    </div>

    <!-- Filters -->
    <div class="flex gap-2 mb-6">
      <button
        v-for="f in ['all', 'published', 'draft']"
        :key="f"
        @click="filter = f"
        :class="[
          'px-3 py-1 rounded-full text-sm transition-colors',
          filter === f
            ? 'bg-primary-100 text-primary-700'
            : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
        ]"
      >
        {{ f.charAt(0).toUpperCase() + f.slice(1) }}
      </button>
    </div>

    <!-- Empty State -->
    <div v-if="filteredPosts.length === 0" class="text-center py-12 bg-white rounded-lg border border-gray-200">
      <div class="w-16 h-16 bg-gray-100 rounded-full flex items-center justify-center mx-auto mb-4">
        <svg class="w-8 h-8 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
        </svg>
      </div>
      <h3 class="text-lg font-medium text-gray-900 mb-2">No posts yet</h3>
      <p class="text-gray-500 mb-6">Create your first post to get started.</p>
      <button
        @click="createNewPost"
        class="inline-flex items-center px-4 py-2 bg-primary-600 text-white rounded-lg hover:bg-primary-700"
      >
        Create Post
      </button>
    </div>

    <!-- Posts List -->
    <div v-else class="space-y-3">
      <div
        v-for="post in filteredPosts"
        :key="post.id"
        class="bg-white rounded-lg border border-gray-200 p-4 hover:shadow-md transition-shadow cursor-pointer"
        @click="navigateToPost(post.id)"
      >
        <div class="flex items-start justify-between">
          <div class="flex-1 min-w-0">
            <div class="flex items-center gap-2 mb-1">
              <h3 class="font-medium text-gray-900 truncate">{{ post.displayTitle }}</h3>
              <span
                v-if="post.isDraft"
                class="px-2 py-0.5 text-xs bg-yellow-100 text-yellow-800 rounded-full"
              >
                Draft
              </span>
            </div>
            <p class="text-sm text-gray-500">{{ post.shortFormattedDate }}</p>
            <div class="flex items-center gap-2 mt-2">
              <span
                v-if="post.category"
                class="px-2 py-0.5 text-xs bg-primary-100 text-primary-700 rounded-full"
              >
                {{ post.category.name }}
              </span>
              <span
                v-for="tag in post.tags?.slice(0, 3)"
                :key="tag.id"
                class="px-2 py-0.5 text-xs bg-gray-100 text-gray-600 rounded-full"
              >
                #{{ tag.name }}
              </span>
              <span v-if="post.tags?.length > 3" class="text-xs text-gray-400">
                +{{ post.tags.length - 3 }} more
              </span>
            </div>
          </div>
          <button
            @click.stop="confirmDelete(post)"
            class="p-2 text-gray-400 hover:text-red-600 transition-colors"
          >
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
            </svg>
          </button>
        </div>
      </div>
    </div>

    <!-- Delete Modal -->
    <div v-if="showDeleteModal" class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div class="bg-white rounded-lg p-6 max-w-md w-full mx-4">
        <h3 class="text-lg font-semibold text-gray-900 mb-2">Delete Post</h3>
        <p class="text-gray-600 mb-6">
          Are you sure you want to delete "{{ postToDelete?.displayTitle }}"? This action cannot be undone.
        </p>
        <div class="flex justify-end gap-3">
          <button
            @click="showDeleteModal = false"
            class="px-4 py-2 text-gray-700 hover:bg-gray-100 rounded-lg transition-colors"
          >
            Cancel
          </button>
          <button
            @click="deletePost"
            class="px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 transition-colors"
          >
            Delete
          </button>
        </div>
      </div>
    </div>
  </div>
</template>
