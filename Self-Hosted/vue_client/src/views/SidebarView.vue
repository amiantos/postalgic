<script setup>
import { ref, computed, onMounted } from 'vue';
import { useRoute } from 'vue-router';
import { useBlogStore } from '@/stores/blog';

const route = useRoute();
const blogStore = useBlogStore();

const blogId = computed(() => route.params.blogId);
const currentRouteName = computed(() => route.name);

const settingsTabs = [
  { name: 'Basic', route: 'blog-settings' },
  { name: 'Categories', route: 'categories' },
  { name: 'Tags', route: 'tags' },
  { name: 'Sidebar', route: 'sidebar' },
  { name: 'Files', route: 'files' },
  { name: 'Themes', route: 'themes' },
  { name: 'Publish', route: 'publish-settings' }
];

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
  <div class="min-h-screen bg-white dark:bg-black overflow-x-hidden">
    <!-- Max-width content wrapper for desktop -->
    <div class="lg:max-w-[700px] lg:mx-auto">

    <!-- Navigation bar -->
    <nav class="flex items-center justify-between px-6 py-4 lg:px-0">
      <router-link
        :to="{ name: 'blog-posts', params: { blogId } }"
        class="font-retro-mono text-retro-sm text-retro-gray-dark dark:text-retro-gray-medium hover:text-retro-orange uppercase tracking-wider"
      >
        <span class="relative -top-px">&lt;</span> {{ blogStore.currentBlog?.name || 'Posts' }}
      </router-link>
      <div class="flex items-center gap-4">
        <button
          @click="openCreateModal('text')"
          class="font-retro-mono text-retro-sm text-retro-gray-dark dark:text-retro-gray-medium hover:text-retro-orange uppercase tracking-wider"
        >
          <span class="relative -top-px">+</span> Text Block
        </button>
        <button
          @click="openCreateModal('linkList')"
          class="font-retro-mono text-retro-sm text-retro-gray-dark dark:text-retro-gray-medium hover:text-retro-orange uppercase tracking-wider"
        >
          <span class="relative -top-px">+</span> Link List
        </button>
      </div>
    </nav>

    <!-- Hero section -->
    <header class="relative h-52 md:h-60">
      <!-- Divider that extends to the right -->
      <div class="absolute bottom-0 left-6 right-0 border-b border-retro-gray-light dark:border-retro-gray-darker lg:left-0 lg:-right-[100vw]"></div>
      <!-- Giant background text -->
      <span class="absolute inset-0 flex items-center justify-start font-retro-serif font-bold text-[10rem] md:text-[14rem] leading-none tracking-tighter text-retro-gray-lightest dark:text-[#1a1a1a] select-none pointer-events-none whitespace-nowrap uppercase" aria-hidden="true">
        SETTINGS
      </span>
      <!-- Foreground content -->
      <div class="absolute bottom-4 left-6 lg:left-0">
        <h1 class="font-retro-serif font-bold text-6xl md:text-7xl leading-none tracking-tight text-retro-gray-darker dark:text-retro-cream lowercase whitespace-nowrap">
          sidebar
        </h1>
        <!-- Stats line -->
        <div class="mt-2 font-retro-mono text-retro-sm text-retro-gray-medium">
          {{ blogStore.sidebarObjects.length }} items
        </div>
      </div>
    </header>

    <!-- Settings tabs -->
    <nav class="flex flex-wrap gap-x-4 gap-y-2 px-6 lg:px-0 py-4 border-b border-retro-gray-light dark:border-retro-gray-darker">
      <router-link
        v-for="tab in settingsTabs"
        :key="tab.route"
        :to="{ name: tab.route, params: { blogId } }"
        :class="[
          'font-retro-mono text-retro-sm uppercase tracking-wider',
          currentRouteName === tab.route
            ? 'text-retro-orange'
            : 'text-retro-gray-dark dark:text-retro-gray-medium hover:text-retro-orange'
        ]"
      >
        {{ tab.name }}
      </router-link>
    </nav>

    <!-- Content -->
    <main class="px-6 lg:px-0 py-6">
      <!-- Empty State -->
      <div v-if="blogStore.sidebarObjects.length === 0" class="py-12">
        <p class="font-retro-serif text-4xl md:text-5xl font-bold text-retro-gray-darker dark:text-retro-gray-light leading-tight">
          No sidebar content yet.
        </p>
        <p class="font-retro-sans text-retro-base text-retro-gray-dark dark:text-retro-gray-medium mt-4">
          Add text blocks or link lists to your blog's sidebar.
        </p>
      </div>

      <!-- Sidebar Objects List -->
      <div v-else class="space-y-4">
        <div
          v-for="obj in blogStore.sidebarObjects"
          :key="obj.id"
          class="border-2 border-retro-gray-light dark:border-retro-gray-darker p-4"
        >
          <div class="flex items-start justify-between">
            <div class="flex-1">
              <div class="flex items-center gap-2 mb-2">
                <h3 class="font-retro-sans text-retro-lg font-medium text-retro-gray-darker dark:text-retro-cream">{{ obj.title }}</h3>
                <span class="font-retro-mono text-retro-xs text-retro-gray-medium uppercase">
                  {{ obj.type === 'text' ? 'Text' : 'Links' }}
                </span>
              </div>
              <div v-if="obj.type === 'text'" class="font-retro-sans text-retro-sm text-retro-gray-dark dark:text-retro-gray-medium line-clamp-2">
                {{ obj.content }}
              </div>
              <div v-else class="font-retro-mono text-retro-xs text-retro-gray-medium">
                {{ obj.links?.length || 0 }} links
              </div>
            </div>
            <div class="flex items-center gap-4">
              <button
                @click="openEditModal(obj)"
                class="font-retro-mono text-retro-xs text-retro-gray-dark dark:text-retro-gray-medium hover:text-retro-orange uppercase tracking-wider"
              >
                Edit
              </button>
              <button
                @click="deleteSidebarObject(obj)"
                class="font-retro-mono text-retro-xs text-red-500 hover:text-red-400 uppercase tracking-wider"
              >
                Delete
              </button>
            </div>
          </div>
        </div>
      </div>
    </main>

    </div><!-- End max-width wrapper -->

    <!-- Modal -->
    <div v-if="showModal" class="fixed inset-0 bg-black/90 flex items-center justify-center z-50 p-6">
      <div class="max-w-lg w-full max-h-[90vh] overflow-y-auto bg-white dark:bg-black border-2 border-retro-gray-light dark:border-retro-gray-darker p-6">
        <h3 class="font-retro-serif text-2xl font-bold text-retro-gray-darker dark:text-retro-cream mb-6">
          {{ editingObject ? 'Edit Sidebar Item' : 'New Sidebar Item' }}
        </h3>

        <div v-if="error" class="mb-4 p-3 border-2 border-red-500 font-retro-mono text-retro-sm text-red-600 dark:text-red-400">
          {{ error }}
        </div>

        <div class="space-y-4">
          <div>
            <label class="block font-retro-mono text-retro-xs text-retro-gray-medium uppercase tracking-wider mb-2">Title</label>
            <input
              v-model="form.title"
              type="text"
              class="w-full px-3 py-2 border-2 border-retro-gray-light dark:border-retro-gray-darker bg-white dark:bg-black font-retro-sans text-retro-base text-retro-gray-darker dark:text-retro-cream focus:outline-none focus:border-retro-orange"
              placeholder="Section title"
            />
          </div>

          <div v-if="!editingObject">
            <label class="block font-retro-mono text-retro-xs text-retro-gray-medium uppercase tracking-wider mb-2">Type</label>
            <select
              v-model="form.type"
              class="w-full px-3 py-2 border-2 border-retro-gray-light dark:border-retro-gray-darker bg-white dark:bg-black font-retro-mono text-retro-sm text-retro-gray-darker dark:text-retro-cream focus:outline-none focus:border-retro-orange"
            >
              <option value="text">Text Block</option>
              <option value="linkList">Link List</option>
            </select>
          </div>

          <!-- Text Content -->
          <div v-if="form.type === 'text'">
            <label class="block font-retro-mono text-retro-xs text-retro-gray-medium uppercase tracking-wider mb-2">Content</label>
            <textarea
              v-model="form.content"
              rows="5"
              class="w-full px-3 py-2 border-2 border-retro-gray-light dark:border-retro-gray-darker bg-white dark:bg-black font-retro-sans text-retro-base text-retro-gray-darker dark:text-retro-cream focus:outline-none focus:border-retro-orange"
              placeholder="Write your content (Markdown supported)"
            ></textarea>
          </div>

          <!-- Link List -->
          <div v-else>
            <label class="block font-retro-mono text-retro-xs text-retro-gray-medium uppercase tracking-wider mb-2">Links</label>
            <div class="space-y-3">
              <div v-for="(link, index) in form.links" :key="index" class="flex gap-2">
                <input
                  v-model="link.title"
                  type="text"
                  class="flex-1 px-3 py-2 border-2 border-retro-gray-light dark:border-retro-gray-darker bg-white dark:bg-black font-retro-sans text-retro-sm text-retro-gray-darker dark:text-retro-cream focus:outline-none focus:border-retro-orange"
                  placeholder="Link title"
                />
                <input
                  v-model="link.url"
                  type="url"
                  class="flex-1 px-3 py-2 border-2 border-retro-gray-light dark:border-retro-gray-darker bg-white dark:bg-black font-retro-mono text-retro-xs text-retro-gray-darker dark:text-retro-cream focus:outline-none focus:border-retro-orange"
                  placeholder="URL"
                />
                <button
                  @click="removeLink(index)"
                  :disabled="form.links.length === 1"
                  class="px-2 font-retro-mono text-retro-sm text-red-500 hover:text-red-400 disabled:opacity-30"
                >
                  ×
                </button>
              </div>
            </div>
            <button
              @click="addLink"
              class="mt-3 font-retro-mono text-retro-sm text-retro-orange hover:text-retro-orange-dark"
            >
              + Add another link
            </button>
          </div>
        </div>

        <div class="flex justify-end gap-6 mt-6">
          <button
            @click="showModal = false"
            class="font-retro-mono text-retro-sm text-retro-gray-dark dark:text-retro-gray-medium hover:text-retro-orange uppercase tracking-wider"
          >
            Cancel
          </button>
          <button
            @click="saveSidebarObject"
            :disabled="saving"
            class="px-4 py-2 border-2 border-retro-orange bg-retro-orange font-retro-mono text-retro-sm text-white hover:bg-retro-orange-dark hover:border-retro-orange-dark uppercase tracking-wider disabled:opacity-50"
          >
            {{ saving ? 'Saving...' : 'Save' }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>
