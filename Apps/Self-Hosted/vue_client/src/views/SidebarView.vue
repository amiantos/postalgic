<script setup>
import { ref, computed, onMounted } from 'vue';
import { useRoute } from 'vue-router';
import { useBlogStore } from '@/stores/blog';
import PageToolbar from '@/components/PageToolbar.vue';
import SettingsTabs from '@/components/SettingsTabs.vue';
import PublishModal from '@/components/PublishModal.vue';

const route = useRoute();
const blogStore = useBlogStore();

const blogId = computed(() => route.params.blogId);

const showModal = ref(false);
const showPublishModal = ref(false);
const editingObject = ref(null);
const form = ref({
  title: '',
  type: 'text',
  content: '',
  links: []
});
const saving = ref(false);
const error = ref(null);

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
    <PageToolbar
      title="Sidebar"
      :subtitle="`${blogStore.sidebarObjects.length} items`"
      @deploy="showPublishModal = true"
    >
      <template #actions>
        <button
          @click="openCreateModal('text')"
          class="glass px-3 py-2 text-sm font-medium text-gray-700 dark:text-gray-300 flex items-center gap-1"
        >
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
          </svg>
          Text Block
        </button>
        <button
          @click="openCreateModal('linkList')"
          class="glass px-3 py-2 text-sm font-medium text-gray-700 dark:text-gray-300 flex items-center gap-1"
        >
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
          </svg>
          Link List
        </button>
      </template>
      <template #tabs>
        <SettingsTabs />
      </template>
    </PageToolbar>

    <div class="px-6 pb-6">
    <!-- Empty State -->
    <div v-if="blogStore.sidebarObjects.length === 0" class="text-center py-12 bg-white dark:bg-gray-800 rounded-lg border border-gray-200 dark:border-gray-700">
      <div class="w-16 h-16 bg-gray-100 dark:bg-gray-700 rounded-full flex items-center justify-center mx-auto mb-4">
        <svg class="w-8 h-8 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 5a1 1 0 011-1h14a1 1 0 011 1v2a1 1 0 01-1 1H5a1 1 0 01-1-1V5zM4 13a1 1 0 011-1h6a1 1 0 011 1v6a1 1 0 01-1 1H5a1 1 0 01-1-1v-6zM16 13a1 1 0 011-1h2a1 1 0 011 1v6a1 1 0 01-1 1h-2a1 1 0 01-1-1v-6z" />
        </svg>
      </div>
      <h3 class="text-lg font-medium text-gray-900 dark:text-gray-100 mb-2">No sidebar content yet</h3>
      <p class="text-gray-500 dark:text-gray-400 mb-6">Add text blocks or link lists to your blog's sidebar.</p>
    </div>

    <!-- Sidebar Objects List -->
    <div v-else class="space-y-4">
      <div
        v-for="obj in blogStore.sidebarObjects"
        :key="obj.id"
        class="bg-white dark:bg-gray-800 rounded-lg border border-gray-200 dark:border-gray-700 p-4"
      >
        <div class="flex items-start justify-between">
          <div class="flex-1">
            <div class="flex items-center gap-2 mb-2">
              <h3 class="font-medium text-gray-900 dark:text-gray-100">{{ obj.title }}</h3>
              <span class="px-2 py-0.5 text-xs bg-gray-100 dark:bg-gray-700 text-gray-600 dark:text-gray-400 rounded-full">
                {{ obj.type === 'text' ? 'Text' : 'Links' }}
              </span>
            </div>
            <div v-if="obj.type === 'text'" class="text-sm text-gray-500 dark:text-gray-400 line-clamp-2">
              {{ obj.content }}
            </div>
            <div v-else class="text-sm text-gray-500 dark:text-gray-400">
              {{ obj.links?.length || 0 }} links
            </div>
          </div>
          <div class="flex items-center gap-2">
            <button
              @click="openEditModal(obj)"
              class="p-1.5 text-gray-400 hover:text-gray-600 dark:hover:text-gray-300"
            >
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.232 5.232l3.536 3.536m-2.036-5.036a2.5 2.5 0 113.536 3.536L6.5 21.036H3v-3.572L16.732 3.732z" />
              </svg>
            </button>
            <button
              @click="deleteSidebarObject(obj)"
              class="p-1.5 text-gray-400 hover:text-red-600 dark:hover:text-red-400"
            >
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
              </svg>
            </button>
          </div>
        </div>
      </div>
    </div>
    </div>

    <!-- Modal -->
    <div v-if="showModal" class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div class="bg-white dark:bg-gray-800 rounded-lg p-6 max-w-lg w-full mx-4 max-h-[90vh] overflow-y-auto">
        <h3 class="text-lg font-semibold text-gray-900 dark:text-gray-100 mb-4">
          {{ editingObject ? 'Edit Sidebar Item' : 'New Sidebar Item' }}
        </h3>

        <div v-if="error" class="mb-4 p-3 bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded-lg text-red-800 dark:text-red-400 text-sm">
          {{ error }}
        </div>

        <div class="space-y-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Title</label>
            <input
              v-model="form.title"
              type="text"
              class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100 focus:ring-2 focus:ring-primary-500 focus:border-primary-500"
              placeholder="Section title"
            />
          </div>

          <div v-if="!editingObject">
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Type</label>
            <select
              v-model="form.type"
              class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100 focus:ring-2 focus:ring-primary-500 focus:border-primary-500"
            >
              <option value="text">Text Block</option>
              <option value="linkList">Link List</option>
            </select>
          </div>

          <!-- Text Content -->
          <div v-if="form.type === 'text'">
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Content</label>
            <textarea
              v-model="form.content"
              rows="5"
              class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100 focus:ring-2 focus:ring-primary-500 focus:border-primary-500"
              placeholder="Write your content (Markdown supported)"
            ></textarea>
          </div>

          <!-- Link List -->
          <div v-else>
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">Links</label>
            <div class="space-y-3">
              <div v-for="(link, index) in form.links" :key="index" class="flex gap-2">
                <input
                  v-model="link.title"
                  type="text"
                  class="flex-1 px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100 focus:ring-2 focus:ring-primary-500 focus:border-primary-500 text-sm"
                  placeholder="Link title"
                />
                <input
                  v-model="link.url"
                  type="url"
                  class="flex-1 px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100 focus:ring-2 focus:ring-primary-500 focus:border-primary-500 text-sm"
                  placeholder="URL"
                />
                <button
                  @click="removeLink(index)"
                  class="p-2 text-gray-400 hover:text-red-600 dark:hover:text-red-400"
                  :disabled="form.links.length === 1"
                >
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                  </svg>
                </button>
              </div>
            </div>
            <button
              @click="addLink"
              class="mt-2 text-sm text-primary-600 dark:text-primary-400 hover:text-primary-700 dark:hover:text-primary-300"
            >
              + Add another link
            </button>
          </div>
        </div>

        <div class="flex justify-end gap-3 mt-6">
          <button
            @click="showModal = false"
            class="px-4 py-2 text-gray-700 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-700 rounded-lg transition-colors"
          >
            Cancel
          </button>
          <button
            @click="saveSidebarObject"
            :disabled="saving"
            class="px-4 py-2 bg-primary-600 text-white rounded-lg hover:bg-primary-700 transition-colors disabled:opacity-50"
          >
            {{ saving ? 'Saving...' : 'Save' }}
          </button>
        </div>
      </div>
    </div>

    <!-- Publish Modal -->
    <PublishModal
      v-if="showPublishModal"
      :blog-id="blogId"
      :show="showPublishModal"
      @close="showPublishModal = false"
    />
  </div>
</template>
