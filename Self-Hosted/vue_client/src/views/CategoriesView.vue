<script setup>
import { ref, computed } from 'vue';
import { useRoute } from 'vue-router';
import { useBlogStore } from '@/stores/blog';

const route = useRoute();
const blogStore = useBlogStore();

const blogId = computed(() => route.params.blogId);

const showModal = ref(false);
const editingCategory = ref(null);
const form = ref({ name: '', description: '' });
const saving = ref(false);
const error = ref(null);

function openCreateModal() {
  editingCategory.value = null;
  form.value = { name: '', description: '' };
  error.value = null;
  showModal.value = true;
}

function openEditModal(category) {
  editingCategory.value = category;
  form.value = { name: category.name, description: category.description || '' };
  error.value = null;
  showModal.value = true;
}

async function saveCategory() {
  if (!form.value.name.trim()) {
    error.value = 'Category name is required';
    return;
  }

  saving.value = true;
  error.value = null;

  try {
    if (editingCategory.value) {
      await blogStore.updateCategory(blogId.value, editingCategory.value.id, form.value);
    } else {
      await blogStore.createCategory(blogId.value, form.value);
    }
    showModal.value = false;
  } catch (e) {
    error.value = e.message;
  } finally {
    saving.value = false;
  }
}

async function deleteCategory(category) {
  if (confirm(`Are you sure you want to delete "${category.name}"?`)) {
    await blogStore.deleteCategory(blogId.value, category.id);
  }
}
</script>

<template>
  <div>
    <!-- Header with create button -->
    <div class="flex items-center justify-between mb-6">
      <h2 class="font-mono text-sm text-site-dark uppercase tracking-wider">
        {{ blogStore.categories.length }} categories
      </h2>
      <button
        @click="openCreateModal"
        class="px-4 py-2 bg-site-accent text-white font-semibold rounded-full hover:bg-[#e89200] transition-colors"
      >
        + New Category
      </button>
    </div>

    <!-- Empty State -->
    <div v-if="blogStore.categories.length === 0" class="py-12">
      <p class="text-xl font-bold text-site-dark leading-tight">
        No categories yet.
      </p>
      <button
        @click="openCreateModal"
        class="inline-block mt-6 text-site-accent hover:underline"
      >
        Create your first category &rarr;
      </button>
    </div>

    <!-- Categories List -->
    <div v-else class="space-y-4">
      <div
        v-for="category in blogStore.categories"
        :key="category.id"
        class="border border-site-light p-4"
      >
        <div class="flex items-start justify-between">
          <div class="flex-1">
            <h3 class="font-medium text-site-dark">{{ category.name }}</h3>
            <p v-if="category.description" class="text-sm text-site-dark mt-1">{{ category.description }}</p>
            <p class="font-mono text-xs text-site-medium mt-2">{{ category.postCount || 0 }} posts</p>
          </div>
          <div class="flex items-center gap-4">
            <button
              @click="openEditModal(category)"
              class="font-mono text-xs text-site-dark hover:text-site-accent uppercase tracking-wider"
            >
              Edit
            </button>
            <button
              @click="deleteCategory(category)"
              class="font-mono text-xs text-red-500 hover:text-red-400 uppercase tracking-wider"
            >
              Delete
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- Modal -->
    <div v-if="showModal" class="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-6">
      <div class="max-w-md w-full bg-white border border-site-light p-6 rounded-lg shadow-xl">
        <h3 class="text-xl font-bold text-site-dark mb-6">
          {{ editingCategory ? 'Edit Category' : 'New Category' }}
        </h3>

        <div v-if="error" class="mb-4 p-3 border border-red-500 font-mono text-sm text-red-600">
          {{ error }}
        </div>

        <div class="space-y-4">
          <div>
            <label class="block font-mono text-xs text-site-medium uppercase tracking-wider mb-2">Name</label>
            <input
              v-model="form.name"
              type="text"
              class="w-full px-3 py-2 border border-site-light focus:outline-none focus:border-site-accent"
              placeholder="Category name"
            />
          </div>

          <div>
            <label class="block font-mono text-xs text-site-medium uppercase tracking-wider mb-2">Description</label>
            <textarea
              v-model="form.description"
              rows="3"
              class="w-full px-3 py-2 border border-site-light focus:outline-none focus:border-site-accent"
              placeholder="Optional description"
            ></textarea>
          </div>
        </div>

        <div class="flex justify-end gap-6 mt-6">
          <button
            @click="showModal = false"
            class="text-site-dark hover:text-site-accent"
          >
            Cancel
          </button>
          <button
            @click="saveCategory"
            :disabled="saving"
            class="px-4 py-2 bg-site-accent text-white font-semibold rounded-full hover:bg-[#e89200] transition-colors disabled:opacity-50"
          >
            {{ saving ? 'Saving...' : 'Save' }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>
