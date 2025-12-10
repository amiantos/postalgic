<script setup>
import { ref, computed } from 'vue';
import { useRoute } from 'vue-router';
import { useBlogStore } from '@/stores/blog';

const route = useRoute();
const blogStore = useBlogStore();

const blogId = computed(() => route.params.blogId);

const showModal = ref(false);
const editingTag = ref(null);
const form = ref({ name: '' });
const saving = ref(false);
const error = ref(null);

function openCreateModal() {
  editingTag.value = null;
  form.value = { name: '' };
  error.value = null;
  showModal.value = true;
}

function openEditModal(tag) {
  editingTag.value = tag;
  form.value = { name: tag.name };
  error.value = null;
  showModal.value = true;
}

async function saveTag() {
  if (!form.value.name.trim()) {
    error.value = 'Tag name is required';
    return;
  }

  saving.value = true;
  error.value = null;

  try {
    if (editingTag.value) {
      await blogStore.updateTag(blogId.value, editingTag.value.id, form.value);
    } else {
      await blogStore.createTag(blogId.value, form.value);
    }
    showModal.value = false;
  } catch (e) {
    error.value = e.message;
  } finally {
    saving.value = false;
  }
}

async function deleteTag(tag) {
  if (confirm(`Are you sure you want to delete "${tag.name}"?`)) {
    await blogStore.deleteTag(blogId.value, tag.id);
  }
}
</script>

<template>
  <div class="p-6">
    <!-- Header -->
    <div class="flex items-center justify-between mb-6">
      <div>
        <h2 class="text-xl font-bold text-gray-900 dark:text-gray-100">Tags</h2>
        <p class="text-gray-500 dark:text-gray-400 text-sm">{{ blogStore.tags.length }} tags</p>
      </div>
      <button
        @click="openCreateModal"
        class="px-4 py-2 bg-primary-600 text-white rounded-lg hover:bg-primary-700 transition-colors"
      >
        New Tag
      </button>
    </div>

    <!-- Empty State -->
    <div v-if="blogStore.tags.length === 0" class="text-center py-12 bg-white dark:bg-gray-800 rounded-lg border border-gray-200 dark:border-gray-700">
      <div class="w-16 h-16 bg-gray-100 dark:bg-gray-700 rounded-full flex items-center justify-center mx-auto mb-4">
        <svg class="w-8 h-8 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 7h.01M7 3h5c.512 0 1.024.195 1.414.586l7 7a2 2 0 010 2.828l-7 7a2 2 0 01-2.828 0l-7-7A2 2 0 013 12V7a4 4 0 014-4z" />
        </svg>
      </div>
      <h3 class="text-lg font-medium text-gray-900 dark:text-gray-100 mb-2">No tags yet</h3>
      <p class="text-gray-500 dark:text-gray-400 mb-6">Create tags to organize your posts.</p>
      <button
        @click="openCreateModal"
        class="inline-flex items-center px-4 py-2 bg-primary-600 text-white rounded-lg hover:bg-primary-700"
      >
        Create Tag
      </button>
    </div>

    <!-- Tags List -->
    <div v-else class="flex flex-wrap gap-3">
      <div
        v-for="tag in blogStore.tags"
        :key="tag.id"
        class="bg-white dark:bg-gray-800 rounded-lg border border-gray-200 dark:border-gray-700 px-4 py-2 flex items-center gap-3"
      >
        <span class="font-medium text-gray-900 dark:text-gray-100">#{{ tag.name }}</span>
        <span class="text-sm text-gray-400">({{ tag.postCount || 0 }})</span>
        <div class="flex items-center gap-1 ml-2">
          <button
            @click="openEditModal(tag)"
            class="p-1 text-gray-400 hover:text-gray-600 dark:hover:text-gray-300"
          >
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.232 5.232l3.536 3.536m-2.036-5.036a2.5 2.5 0 113.536 3.536L6.5 21.036H3v-3.572L16.732 3.732z" />
            </svg>
          </button>
          <button
            @click="deleteTag(tag)"
            class="p-1 text-gray-400 hover:text-red-600 dark:hover:text-red-400"
          >
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>
      </div>
    </div>

    <!-- Modal -->
    <div v-if="showModal" class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div class="bg-white dark:bg-gray-800 rounded-lg p-6 max-w-md w-full mx-4">
        <h3 class="text-lg font-semibold text-gray-900 dark:text-gray-100 mb-4">
          {{ editingTag ? 'Edit Tag' : 'New Tag' }}
        </h3>

        <div v-if="error" class="mb-4 p-3 bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded-lg text-red-800 dark:text-red-400 text-sm">
          {{ error }}
        </div>

        <div>
          <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Name</label>
          <input
            v-model="form.name"
            type="text"
            class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100 focus:ring-2 focus:ring-primary-500 focus:border-primary-500"
            placeholder="Tag name"
            @keyup.enter="saveTag"
          />
          <p class="mt-1 text-sm text-gray-500 dark:text-gray-400">Tags are automatically lowercased</p>
        </div>

        <div class="flex justify-end gap-3 mt-6">
          <button
            @click="showModal = false"
            class="px-4 py-2 text-gray-700 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-700 rounded-lg transition-colors"
          >
            Cancel
          </button>
          <button
            @click="saveTag"
            :disabled="saving"
            class="px-4 py-2 bg-primary-600 text-white rounded-lg hover:bg-primary-700 transition-colors disabled:opacity-50"
          >
            {{ saving ? 'Saving...' : 'Save' }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>
