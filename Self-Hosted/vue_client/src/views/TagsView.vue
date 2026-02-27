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
  <div>
    <!-- Header with create button -->
    <div class="flex items-center justify-between mb-6">
      <h2 class="font-mono text-sm text-site-dark uppercase tracking-wider">
        {{ blogStore.tags.length }} tags
      </h2>
      <button
        @click="openCreateModal"
        class="px-4 py-2 bg-site-accent text-white font-semibold rounded-full hover:bg-[#e89200] transition-colors"
      >
        + New Tag
      </button>
    </div>

    <!-- Empty State -->
    <div v-if="blogStore.tags.length === 0" class="py-12">
      <p class="text-xl font-bold text-site-dark leading-tight">
        No tags yet.
      </p>
      <button
        @click="openCreateModal"
        class="inline-block mt-6 text-site-accent hover:underline"
      >
        Create your first tag &rarr;
      </button>
    </div>

    <!-- Tags List -->
    <div v-else class="flex flex-wrap gap-3">
      <div
        v-for="tag in blogStore.tags"
        :key="tag.id"
        class="border border-site-light px-4 py-2 flex items-center gap-3"
      >
        <span class="font-mono text-sm text-site-dark">#{{ tag.name }}</span>
        <span class="font-mono text-xs text-site-medium">({{ tag.postCount || 0 }})</span>
        <div class="flex items-center gap-2 ml-2">
          <button
            @click="openEditModal(tag)"
            class="font-mono text-xs text-site-dark hover:text-site-accent uppercase"
          >
            Edit
          </button>
          <button
            @click="deleteTag(tag)"
            class="font-mono text-xs text-red-500 hover:text-red-400 uppercase"
          >
            &times;
          </button>
        </div>
      </div>
    </div>

    <!-- Modal -->
    <div v-if="showModal" class="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-6">
      <div class="max-w-md w-full bg-white border border-site-light p-6 rounded-lg shadow-xl">
        <h3 class="text-xl font-bold text-site-dark mb-6">
          {{ editingTag ? 'Edit Tag' : 'New Tag' }}
        </h3>

        <div v-if="error" class="mb-4 p-3 border border-red-500 font-mono text-sm text-red-600">
          {{ error }}
        </div>

        <div>
          <label class="block font-mono text-xs text-site-medium uppercase tracking-wider mb-2">Name</label>
          <input
            v-model="form.name"
            type="text"
            class="w-full px-3 py-2 border border-site-light focus:outline-none focus:border-site-accent"
            placeholder="Tag name"
            @keyup.enter="saveTag"
          />
          <p class="mt-2 font-mono text-xs text-site-medium">Tags are automatically lowercased</p>
        </div>

        <div class="flex justify-end gap-6 mt-6">
          <button
            @click="showModal = false"
            class="text-site-dark hover:text-site-accent"
          >
            Cancel
          </button>
          <button
            @click="saveTag"
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
