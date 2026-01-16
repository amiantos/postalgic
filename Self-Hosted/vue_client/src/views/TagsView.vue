<script setup>
import { ref, computed } from 'vue';
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
  { name: 'Publishing', route: 'publish-settings' }
];

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
      <button
        @click="openCreateModal"
        class="font-retro-mono text-retro-sm text-retro-gray-dark dark:text-retro-gray-medium hover:text-retro-orange uppercase tracking-wider"
      >
        <span class="relative -top-px">+</span> New Tag
      </button>
    </nav>

    <!-- Hero section -->
    <header class="relative h-52 md:h-60">
      <!-- Divider that extends to the right -->
      <div class="absolute bottom-0 left-6 right-0 border-b border-retro-gray-light dark:border-retro-gray-darker lg:left-0 lg:-right-[100vw]"></div>
      <!-- Giant background text -->
      <span class="absolute inset-0 flex items-center justify-start font-retro-serif font-bold text-[10rem] md:text-[14rem] leading-none tracking-tighter text-retro-gray-lightest dark:text-[#1a1a1a] select-none pointer-events-none whitespace-nowrap uppercase" aria-hidden="true">
        TAGS
      </span>
      <!-- Foreground content -->
      <div class="absolute bottom-4 left-6 lg:left-0">
        <h1 class="font-retro-serif font-bold text-6xl md:text-7xl leading-none tracking-tight text-retro-gray-darker dark:text-retro-cream lowercase whitespace-nowrap">
          tags
        </h1>
        <!-- Stats line -->
        <div class="mt-2 font-retro-mono text-retro-sm text-retro-gray-medium">
          {{ blogStore.tags.length }} tags
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
      <div v-if="blogStore.tags.length === 0" class="py-12">
        <p class="font-retro-serif text-4xl md:text-5xl font-bold text-retro-gray-darker dark:text-retro-gray-light leading-tight">
          No tags yet.
        </p>
        <button
          @click="openCreateModal"
          class="inline-block mt-6 font-retro-mono text-retro-sm text-retro-orange hover:text-retro-orange-dark uppercase tracking-wider"
        >
          Create your first tag &rarr;
        </button>
      </div>

      <!-- Tags List -->
      <div v-else class="flex flex-wrap gap-3">
        <div
          v-for="tag in blogStore.tags"
          :key="tag.id"
          class="border-2 border-retro-gray-light dark:border-retro-gray-darker px-4 py-2 flex items-center gap-3"
        >
          <span class="font-retro-mono text-retro-sm text-retro-gray-darker dark:text-retro-cream">#{{ tag.name }}</span>
          <span class="font-retro-mono text-retro-xs text-retro-gray-medium">({{ tag.postCount || 0 }})</span>
          <div class="flex items-center gap-2 ml-2">
            <button
              @click="openEditModal(tag)"
              class="font-retro-mono text-retro-xs text-retro-gray-dark dark:text-retro-gray-medium hover:text-retro-orange uppercase"
            >
              Edit
            </button>
            <button
              @click="deleteTag(tag)"
              class="font-retro-mono text-retro-xs text-red-500 hover:text-red-400 uppercase"
            >
              ×
            </button>
          </div>
        </div>
      </div>
    </main>

    </div><!-- End max-width wrapper -->

    <!-- Modal -->
    <div v-if="showModal" class="fixed inset-0 bg-black/90 flex items-center justify-center z-50 p-6">
      <div class="max-w-md w-full bg-white dark:bg-black border-2 border-retro-gray-light dark:border-retro-gray-darker p-6">
        <h3 class="font-retro-serif text-2xl font-bold text-retro-gray-darker dark:text-retro-cream mb-6">
          {{ editingTag ? 'Edit Tag' : 'New Tag' }}
        </h3>

        <div v-if="error" class="mb-4 p-3 border-2 border-red-500 font-retro-mono text-retro-sm text-red-600 dark:text-red-400">
          {{ error }}
        </div>

        <div>
          <label class="block font-retro-mono text-retro-xs text-retro-gray-medium uppercase tracking-wider mb-2">Name</label>
          <input
            v-model="form.name"
            type="text"
            class="w-full px-3 py-2 border-2 border-retro-gray-light dark:border-retro-gray-darker bg-white dark:bg-black font-retro-sans text-retro-base text-retro-gray-darker dark:text-retro-cream focus:outline-none focus:border-retro-orange"
            placeholder="Tag name"
            @keyup.enter="saveTag"
          />
          <p class="mt-2 font-retro-mono text-retro-xs text-retro-gray-medium">Tags are automatically lowercased</p>
        </div>

        <div class="flex justify-end gap-6 mt-6">
          <button
            @click="showModal = false"
            class="font-retro-mono text-retro-sm text-retro-gray-dark dark:text-retro-gray-medium hover:text-retro-orange uppercase tracking-wider"
          >
            Cancel
          </button>
          <button
            @click="saveTag"
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
