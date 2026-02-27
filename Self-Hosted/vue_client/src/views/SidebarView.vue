<script setup>
import { ref, computed, onMounted } from 'vue';
import { useRoute } from 'vue-router';
import { useBlogStore } from '@/stores/blog';

const route = useRoute();
const blogStore = useBlogStore();

const blogId = computed(() => route.params.blogId);

const showModal = ref(false);
const editingObject = ref(null);
const form = ref({
  title: '',
  type: 'text',
  content: '',
  links: []
});
const saving = ref(false);
const error = ref(null);
const searchText = ref('');

const filteredSidebarObjects = computed(() => {
  if (!searchText.value.trim()) return blogStore.sidebarObjects;
  const query = searchText.value.toLowerCase();
  return blogStore.sidebarObjects.filter(obj => obj.title.toLowerCase().includes(query));
});

onMounted(async () => {
  await blogStore.fetchSidebarObjects(blogId.value);
});

function openCreateModal(type = 'text') {
  editingObject.value = null;
  form.value = {
    title: '',
    type,
    content: '',
    links: [{ title: '', url: '', order: 0 }]
  };
  error.value = null;
  showModal.value = true;
}

function openEditModal(obj) {
  editingObject.value = obj;
  form.value = {
    title: obj.title,
    type: obj.type,
    content: obj.content || '',
    links: obj.links?.length > 0 ? [...obj.links] : [{ title: '', url: '', order: 0 }]
  };
  error.value = null;
  showModal.value = true;
}

function addLink() {
  form.value.links.push({ title: '', url: '', order: form.value.links.length });
}

function removeLink(index) {
  form.value.links.splice(index, 1);
  form.value.links.forEach((link, i) => link.order = i);
}

async function saveSidebarObject() {
  if (!form.value.title.trim()) {
    error.value = 'Title is required';
    return;
  }

  saving.value = true;
  error.value = null;

  try {
    const data = {
      title: form.value.title,
      type: form.value.type,
      content: form.value.type === 'text' ? form.value.content : '',
      links: form.value.type === 'linkList' ? form.value.links.filter(l => l.title || l.url) : []
    };

    if (editingObject.value) {
      await blogStore.updateSidebarObject(blogId.value, editingObject.value.id, data);
    } else {
      await blogStore.createSidebarObject(blogId.value, data);
    }
    showModal.value = false;
  } catch (e) {
    error.value = e.message;
  } finally {
    saving.value = false;
  }
}

async function deleteSidebarObject(obj) {
  if (confirm(`Are you sure you want to delete "${obj.title}"?`)) {
    await blogStore.deleteSidebarObject(blogId.value, obj.id);
  }
}
</script>

<template>
  <div>
    <!-- Header with search and create buttons -->
    <div class="flex items-center gap-2 mb-6">
      <input
        v-model="searchText"
        type="text"
        class="admin-input flex-1"
        placeholder="Search sidebar items..."
      />
      <button
        @click="openCreateModal('text')"
        class="h-10 px-3 font-mono text-sm uppercase tracking-wider bg-site-accent text-white hover:bg-[#e89200] transition-colors"
      >
        New Text Block
      </button>
      <button
        @click="openCreateModal('linkList')"
        class="h-10 px-3 font-mono text-sm uppercase tracking-wider border border-site-accent text-site-accent hover:bg-site-accent hover:text-white transition-colors"
      >
        New Link List
      </button>
    </div>

    <!-- Empty State -->
    <div v-if="blogStore.sidebarObjects.length === 0" class="py-12">
      <p class="text-xl font-bold text-site-dark leading-tight">
        No sidebar content yet.
      </p>
      <p class="text-sm text-site-dark mt-4">
        Add text blocks or link lists to your blog's sidebar.
      </p>
    </div>

    <!-- Sidebar Objects List -->
    <div v-else class="space-y-4">
      <div
        v-for="obj in filteredSidebarObjects"
        :key="obj.id"
        class="border border-site-light p-4"
      >
        <div class="flex items-start justify-between">
          <div class="flex-1">
            <div class="flex items-center gap-2 mb-2">
              <h3 class="font-medium text-site-dark">{{ obj.title }}</h3>
              <span class="text-xs text-site-medium">
                {{ obj.type === 'text' ? 'Text' : 'Links' }}
              </span>
            </div>
            <div v-if="obj.type === 'text'" class="text-sm text-site-dark line-clamp-2">
              {{ obj.content }}
            </div>
            <div v-else class="text-xs text-site-medium">
              {{ obj.links?.length || 0 }} links
            </div>
          </div>
          <div class="flex items-center gap-4">
            <button
              @click="openEditModal(obj)"
              class="text-xs font-semibold text-site-dark hover:text-site-accent"
            >
              Edit
            </button>
            <button
              @click="deleteSidebarObject(obj)"
              class="text-xs font-semibold text-red-500 hover:text-red-400"
            >
              Delete
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- Modal -->
    <div v-if="showModal" class="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-6">
      <div class="max-w-lg w-full max-h-[90vh] overflow-y-auto bg-white border border-site-light p-6 rounded-lg shadow-xl">
        <h3 class="text-xl font-bold text-site-dark mb-6">
          {{ editingObject ? 'Edit Sidebar Item' : 'New Sidebar Item' }}
        </h3>

        <div v-if="error" class="mb-4 p-3 border border-red-500 text-sm text-red-600">
          {{ error }}
        </div>

        <div class="space-y-4">
          <div>
            <label class="block text-xs font-semibold text-site-medium mb-2">Title</label>
            <input
              v-model="form.title"
              type="text"
              class="admin-input"
              placeholder="Section title"
            />
          </div>

          <div v-if="!editingObject">
            <label class="block text-xs font-semibold text-site-medium mb-2">Type</label>
            <select
              v-model="form.type"
              class="admin-input"
            >
              <option value="text">Text Block</option>
              <option value="linkList">Link List</option>
            </select>
          </div>

          <!-- Text Content -->
          <div v-if="form.type === 'text'">
            <label class="block text-xs font-semibold text-site-medium mb-2">Content</label>
            <textarea
              v-model="form.content"
              rows="5"
              class="admin-input"
              placeholder="Write your content (Markdown supported)"
            ></textarea>
          </div>

          <!-- Link List -->
          <div v-else>
            <label class="block text-xs font-semibold text-site-medium mb-2">Links</label>
            <div class="space-y-3">
              <div v-for="(link, index) in form.links" :key="index" class="flex gap-2">
                <input
                  v-model="link.title"
                  type="text"
                  class="admin-input flex-1"
                  placeholder="Link title"
                />
                <input
                  v-model="link.url"
                  type="url"
                  class="admin-input flex-1"
                  placeholder="URL"
                />
                <button
                  @click="removeLink(index)"
                  :disabled="form.links.length === 1"
                  class="px-2 text-red-500 hover:text-red-400 disabled:opacity-30"
                >
                  &times;
                </button>
              </div>
            </div>
            <button
              @click="addLink"
              class="mt-3 text-sm text-site-accent hover:underline"
            >
              + Add another link
            </button>
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
            @click="saveSidebarObject"
            :disabled="saving"
            class="h-10 px-3 font-mono text-sm uppercase tracking-wider bg-site-accent text-white hover:bg-[#e89200] transition-colors disabled:opacity-50"
          >
            {{ saving ? 'Saving...' : 'Save' }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>
