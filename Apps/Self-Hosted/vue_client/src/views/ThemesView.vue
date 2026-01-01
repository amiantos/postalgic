<script setup>
import { ref, computed, onMounted } from 'vue';
import { useRoute } from 'vue-router';
import { useBlogStore } from '@/stores/blog';
import { themeApi } from '@/api';
import PageToolbar from '@/components/PageToolbar.vue';
import SettingsTabs from '@/components/SettingsTabs.vue';

const route = useRoute();
const blogStore = useBlogStore();

const blogId = computed(() => route.params.blogId);

const themes = ref([]);
const loading = ref(false);
const error = ref(null);
const duplicating = ref(false);
const themeToDelete = ref(null);
const selectedThemeId = ref(null);

// Editing state
const editingTheme = ref(null);
const editingTemplateName = ref(null);
const editingTemplateContent = ref('');
const savingTemplate = ref(false);

onMounted(async () => {
  await loadThemes();
  // Get current theme from blog
  selectedThemeId.value = blogStore.currentBlog?.themeIdentifier || 'default';
});

async function loadThemes() {
  loading.value = true;
  error.value = null;
  try {
    themes.value = await themeApi.list();
  } catch (e) {
    error.value = e.message;
  } finally {
    loading.value = false;
  }
}

async function selectTheme(themeId) {
  try {
    await blogStore.updateBlog(blogId.value, { themeIdentifier: themeId });
    selectedThemeId.value = themeId;
  } catch (e) {
    error.value = e.message;
  }
}

async function duplicateTheme(sourceId) {
  duplicating.value = true;
  error.value = null;
  try {
    const blogName = blogStore.currentBlog?.name || 'Blog';
    const newTheme = await themeApi.duplicate(sourceId, `Default (${blogName})`);
    themes.value.push(newTheme);
    // Select the new theme
    await selectTheme(newTheme.id);
    // Open editor
    await openThemeEditor(newTheme.id);
  } catch (e) {
    error.value = e.message;
  } finally {
    duplicating.value = false;
  }
}

async function openThemeEditor(themeId) {
  try {
    const theme = await themeApi.get(themeId);
    editingTheme.value = theme;
    editingTemplateName.value = null;
    editingTemplateContent.value = '';
  } catch (e) {
    error.value = e.message;
  }
}

function selectTemplate(name) {
  editingTemplateName.value = name;
  editingTemplateContent.value = editingTheme.value.templates[name] || '';
}

async function saveTemplate() {
  if (!editingTheme.value || !editingTemplateName.value) return;

  savingTemplate.value = true;
  error.value = null;
  try {
    const updatedTheme = await themeApi.update(editingTheme.value.id, {
      templates: {
        [editingTemplateName.value]: editingTemplateContent.value
      }
    });
    // Update local state
    editingTheme.value.templates = updatedTheme.templates;
    // Update themes list
    const index = themes.value.findIndex(t => t.id === editingTheme.value.id);
    if (index !== -1) {
      themes.value[index] = { ...themes.value[index], ...updatedTheme };
    }
  } catch (e) {
    error.value = e.message;
  } finally {
    savingTemplate.value = false;
  }
}

function closeEditor() {
  editingTheme.value = null;
  editingTemplateName.value = null;
  editingTemplateContent.value = '';
}

async function confirmDeleteTheme() {
  if (!themeToDelete.value) return;

  try {
    await themeApi.delete(themeToDelete.value.id);
    themes.value = themes.value.filter(t => t.id !== themeToDelete.value.id);
    // If deleting the currently selected theme, switch to default
    if (selectedThemeId.value === themeToDelete.value.id) {
      await selectTheme('default');
    }
    themeToDelete.value = null;
  } catch (e) {
    error.value = e.message;
  }
}

const templateNames = computed(() => {
  if (!editingTheme.value?.templates) return [];
  return Object.keys(editingTheme.value.templates).sort();
});
</script>

<template>
  <div>
    <PageToolbar title="Themes">
      <template #actions>
        <button
          @click="duplicateTheme('default')"
          :disabled="duplicating"
          class="glass px-3 py-2 text-sm font-medium text-gray-700 dark:text-gray-300 flex items-center gap-1 disabled:opacity-50"
        >
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
          </svg>
          {{ duplicating ? 'Creating...' : 'New Theme' }}
        </button>
      </template>
      <template #tabs>
        <SettingsTabs />
      </template>
    </PageToolbar>

    <div class="px-6 pb-6">
    <!-- Error -->
    <div v-if="error" class="mb-6 p-4 bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded-lg text-red-800 dark:text-red-400">
      {{ error }}
    </div>

    <!-- Loading -->
    <div v-if="loading" class="text-center py-12 text-gray-500 dark:text-gray-400">
      Loading themes...
    </div>

    <!-- Theme List -->
    <div v-else class="space-y-3">
      <div
        v-for="theme in themes"
        :key="theme.id"
        :class="[
          'bg-white dark:bg-gray-800 rounded-lg border p-4 transition-colors',
          selectedThemeId === theme.id ? 'border-primary-500 ring-1 ring-primary-500' : 'border-gray-200 dark:border-gray-700'
        ]"
      >
        <div class="flex items-center justify-between">
          <div class="flex items-center gap-3">
            <button
              @click="selectTheme(theme.id)"
              class="flex items-center gap-3"
            >
              <div
                :class="[
                  'w-5 h-5 rounded-full border-2 flex items-center justify-center',
                  selectedThemeId === theme.id ? 'border-primary-600' : 'border-gray-300 dark:border-gray-600'
                ]"
              >
                <div
                  v-if="selectedThemeId === theme.id"
                  class="w-3 h-3 rounded-full bg-primary-600"
                ></div>
              </div>
              <div>
                <p class="font-medium text-gray-900 dark:text-gray-100">{{ theme.name }}</p>
                <p class="text-sm text-gray-500 dark:text-gray-400">
                  {{ theme.isDefault ? 'Built-in' : 'Custom' }}
                </p>
              </div>
            </button>
          </div>

          <div class="flex items-center gap-2">
            <!-- Edit Button (custom themes only) -->
            <button
              v-if="!theme.isDefault"
              @click="openThemeEditor(theme.id)"
              class="px-3 py-1.5 text-gray-700 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-700 rounded-lg text-sm flex items-center gap-1"
            >
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
              </svg>
              Edit
            </button>

            <!-- Duplicate Button -->
            <button
              @click="duplicateTheme(theme.id)"
              :disabled="duplicating"
              class="px-3 py-1.5 text-gray-700 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-700 rounded-lg text-sm flex items-center gap-1"
            >
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z" />
              </svg>
              Duplicate
            </button>

            <!-- Delete Button (custom themes only) -->
            <button
              v-if="!theme.isDefault"
              @click="themeToDelete = theme"
              class="px-3 py-1.5 text-red-600 dark:text-red-400 hover:bg-red-50 dark:hover:bg-red-900/20 rounded-lg text-sm"
            >
              Delete
            </button>
          </div>
        </div>
      </div>
    </div>

    <p class="mt-4 text-sm text-gray-500 dark:text-gray-400">
      Custom themes can be used across all your blogs.
    </p>
    </div>

    <!-- Delete Confirmation Modal -->
    <div
      v-if="themeToDelete"
      class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50"
      @click.self="themeToDelete = null"
    >
      <div class="bg-white dark:bg-gray-800 rounded-lg p-6 max-w-md w-full mx-4">
        <h3 class="text-lg font-medium text-gray-900 dark:text-gray-100 mb-2">Delete Theme</h3>
        <p class="text-gray-600 dark:text-gray-400 mb-4">
          Are you sure you want to delete "{{ themeToDelete.name }}"? This action cannot be undone.
        </p>
        <div class="flex justify-end gap-2">
          <button
            @click="themeToDelete = null"
            class="px-4 py-2 text-gray-700 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-700 rounded-lg"
          >
            Cancel
          </button>
          <button
            @click="confirmDeleteTheme"
            class="px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700"
          >
            Delete
          </button>
        </div>
      </div>
    </div>

    <!-- Theme Editor Modal -->
    <div
      v-if="editingTheme"
      class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50"
    >
      <div class="bg-white dark:bg-gray-800 rounded-lg max-w-6xl w-full mx-4 h-[90vh] flex flex-col">
        <!-- Header -->
        <div class="flex items-center justify-between p-4 border-b border-gray-200 dark:border-gray-700">
          <h3 class="text-lg font-medium text-gray-900 dark:text-gray-100">
            Edit Theme: {{ editingTheme.name }}
          </h3>
          <button
            @click="closeEditor"
            class="p-2 text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-300"
          >
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>

        <!-- Content -->
        <div class="flex-1 flex overflow-hidden">
          <!-- Template List -->
          <div class="w-64 border-r border-gray-200 dark:border-gray-700 overflow-y-auto">
            <div class="p-4">
              <h4 class="text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">Templates</h4>
              <div class="space-y-1">
                <button
                  v-for="name in templateNames"
                  :key="name"
                  @click="selectTemplate(name)"
                  :class="[
                    'w-full text-left px-3 py-2 text-sm rounded-lg transition-colors',
                    editingTemplateName === name
                      ? 'bg-primary-50 dark:bg-primary-900/30 text-primary-700 dark:text-primary-300'
                      : 'text-gray-600 dark:text-gray-400 hover:bg-gray-100 dark:hover:bg-gray-700'
                  ]"
                >
                  {{ name }}
                </button>
              </div>
            </div>
          </div>

          <!-- Editor -->
          <div class="flex-1 flex flex-col">
            <div v-if="editingTemplateName" class="flex-1 flex flex-col">
              <div class="p-4 border-b border-gray-200 dark:border-gray-700 flex items-center justify-between">
                <h4 class="font-medium text-gray-900 dark:text-gray-100">{{ editingTemplateName }}</h4>
                <button
                  @click="saveTemplate"
                  :disabled="savingTemplate"
                  class="px-4 py-2 bg-primary-600 text-white rounded-lg hover:bg-primary-700 transition-colors disabled:opacity-50"
                >
                  {{ savingTemplate ? 'Saving...' : 'Save Template' }}
                </button>
              </div>
              <div class="flex-1 p-4">
                <textarea
                  v-model="editingTemplateContent"
                  class="w-full h-full font-mono text-sm border border-gray-300 dark:border-gray-600 rounded-lg p-3 resize-none bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100 focus:ring-2 focus:ring-primary-500 focus:border-primary-500"
                  spellcheck="false"
                ></textarea>
              </div>
            </div>
            <div v-else class="flex-1 flex items-center justify-center text-gray-500 dark:text-gray-400">
              Select a template to edit
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
