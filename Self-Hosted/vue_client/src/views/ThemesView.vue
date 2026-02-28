<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useRoute } from 'vue-router';
import { useBlogStore } from '@/stores/blog';
import { themeApi } from '@/api';

const route = useRoute();
const blogStore = useBlogStore();

const blogId = computed(() => route.params.blogId);

const themes = ref([]);
const loading = ref(false);
const error = ref(null);
const duplicating = ref(false);
const themeToDelete = ref(null);
const selectedThemeId = ref(null);
const searchText = ref('');

// Editing state
const editingTheme = ref(null);
const editingTemplateName = ref(null);
const editingTemplateContent = ref('');
const savingTemplate = ref(false);

// Color settings
const colorForm = ref({});
const savingColors = ref(false);
const colorSuccess = ref(false);

watch(() => blogStore.currentBlog, (blog) => {
  if (blog) {
    colorForm.value = {
      accentColor: blog.accentColor,
      backgroundColor: blog.backgroundColor,
      textColor: blog.textColor,
      lightShade: blog.lightShade,
      mediumShade: blog.mediumShade,
      darkShade: blog.darkShade
    };
  }
}, { immediate: true });

onMounted(async () => {
  await loadThemes();
  // Get current theme from blog
  selectedThemeId.value = blogStore.currentBlog?.themeIdentifier || 'default';
});

const filteredThemes = computed(() => {
  if (!searchText.value.trim()) return themes.value;
  const query = searchText.value.toLowerCase();
  return themes.value.filter(t => t.name.toLowerCase().includes(query));
});

const colorPreviewHtml = computed(() => {
  const accentColor = colorForm.value.accentColor || '#FFA100';
  const backgroundColor = colorForm.value.backgroundColor || '#efefef';
  const textColor = colorForm.value.textColor || '#2d3748';
  const lightShade = colorForm.value.lightShade || '#dedede';
  const mediumShade = colorForm.value.mediumShade || '#a0aec0';
  const darkShade = colorForm.value.darkShade || '#4a5568';

  return `<!DOCTYPE html>
<html>
<head>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        :root {
            --accent-color: ${accentColor};
            --background-color: ${backgroundColor};
            --text-color: ${textColor};
            --light-shade: ${lightShade};
            --medium-shade: ${mediumShade};
            --dark-shade: ${darkShade};
        }

        body {
            font-family: -apple-system, BlinkMacSystemFont, sans-serif;
            background-color: var(--background-color);
            color: var(--text-color);
            padding: 12px;
            line-height: 1.6;
            margin: 0;
        }

        a {
            color: var(--accent-color);
            text-decoration: none;
        }

        .header-separator {
            height: 28px;
            width: 100%;
            background-color: var(--accent-color);
            --mask:
              radial-gradient(10.96px at 50% calc(100% + 5.6px),#0000 calc(99% - 4px),#000 calc(101% - 4px) 99%,#0000 101%) calc(50% - 14px) calc(50% - 5.5px + .5px)/28px 11px repeat-x,
              radial-gradient(10.96px at 50% -5.6px,#0000 calc(99% - 4px),#000 calc(101% - 4px) 99%,#0000 101%) 50% calc(50% + 5.5px)/28px 11px repeat-x;
            -webkit-mask: var(--mask);
            mask: var(--mask);
            margin: 15px 0;
        }

        .category, .tag {
            display: inline-block;
            margin-right: 5px;
        }

        .category a {
            display: inline-block;
            color: white;
            background-color: var(--accent-color);
            border: 1px solid var(--accent-color);
            padding: 3px 8px;
            border-radius: 1em;
            font-size: 0.8em;
        }

        .tag a {
            display: inline-block;
            color: var(--accent-color);
            background-color: var(--background-color);
            border: 1px solid var(--accent-color);
            padding: 3px 8px;
            border-radius: 1em;
            font-size: 0.8em;
        }

        .section {
            margin-bottom: 20px;
        }

        h3 {
            margin-bottom: 8px;
            color: var(--dark-shade);
        }

        h2 {
            color: var(--text-color);
            font-size: 1.5em;
            font-weight: bold;
            margin-bottom: 0px;
            margin-top: 10px;
        }

        .post-date {
            color: var(--medium-shade);
            font-size: 0.9em;
            display: inline-block;
            margin-top: 0px;
        }

        .menu-button {
            display: block;
            padding: 8px 0;
            font-weight: 600;
            font-size: 1.1rem;
            color: var(--dark-shade);
            text-decoration: none;
        }

        .menu-sample {
            margin-bottom: 25px;
            border-bottom: 1px solid var(--light-shade);
        }
    </style>
</head>
<body>
    <div class="section">
        <h2>Example Post Title</h2>
        <div class="post-date">May 24, 2025 at 1:50 AM</div>

        <p>This is regular text on your blog, and <a href="#">this is a link</a> to demonstrate how the accent color looks.</p>
        <div class="category"><a href="#">Category Name</a></div>
        <div class="tag"><a href="#">#tag name</a></div>
        <div class="header-separator"></div>
        <div class="menu-sample">
            <a class="menu-button">Menu Nav Item</a>
        </div>
    </div>
</body>
</html>`;
});

async function saveColors() {
  savingColors.value = true;
  error.value = null;
  colorSuccess.value = false;

  try {
    await blogStore.updateBlog(blogId.value, colorForm.value);
    colorSuccess.value = true;
    setTimeout(() => colorSuccess.value = false, 3000);
  } catch (e) {
    error.value = e.message;
  } finally {
    savingColors.value = false;
  }
}

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
    <!-- Header row with search and New Theme button -->
    <div class="flex items-center gap-3 mb-6">
      <div class="relative flex-1">
        <input
          v-model="searchText"
          type="text"
          placeholder="Search themes..."
          class="admin-input pl-8"
        />
        <svg class="absolute left-2.5 top-1/2 -translate-y-1/2 w-4 h-4 text-site-medium pointer-events-none" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
        </svg>
      </div>
      <button
        @click="duplicateTheme('default')"
        :disabled="duplicating"
        class="h-10 px-3 font-mono text-sm uppercase tracking-wider bg-site-accent text-white hover:bg-[#e89200] transition-colors disabled:opacity-50"
      >
        {{ duplicating ? 'Creating...' : 'New Theme' }}
      </button>
    </div>

    <!-- Error -->
    <div v-if="error" class="mb-6 p-4 border border-red-500 text-sm text-red-600">
      {{ error }}
    </div>

    <!-- Loading -->
    <div v-if="loading" class="py-12">
      <p class="text-sm text-site-medium">Loading themes...</p>
    </div>

    <!-- Theme List -->
    <div v-else class="space-y-3">
      <div
        v-for="theme in filteredThemes"
        :key="theme.id"
        :class="[
          'border p-4',
          selectedThemeId === theme.id
            ? 'border-site-accent'
            : 'border-site-light'
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
                  'w-4 h-4 border flex items-center justify-center',
                  selectedThemeId === theme.id ? 'border-site-accent' : 'border-site-medium'
                ]"
              >
                <div
                  v-if="selectedThemeId === theme.id"
                  class="w-2 h-2 bg-site-accent"
                ></div>
              </div>
              <div class="text-left">
                <p class="m-0 text-site-dark">{{ theme.name }}</p>
                <p v-if="theme.isDefault" class="m-0 text-xs text-site-medium">Built-in</p>
                <p v-else class="m-0 text-xs text-site-medium">Custom</p>
              </div>
            </button>
          </div>

          <div class="flex items-center gap-4">
            <!-- Edit Button (custom themes only) -->
            <button
              v-if="!theme.isDefault"
              @click="openThemeEditor(theme.id)"
              class="text-xs font-semibold text-site-dark hover:text-site-accent"
            >
              Edit
            </button>

            <!-- Duplicate Button -->
            <button
              @click="duplicateTheme(theme.id)"
              :disabled="duplicating"
              class="text-xs font-semibold text-site-dark hover:text-site-accent"
            >
              Duplicate
            </button>

            <!-- Delete Button (custom themes only) -->
            <button
              v-if="!theme.isDefault"
              @click="themeToDelete = theme"
              class="text-xs font-semibold text-red-500 hover:text-red-400"
            >
              Delete
            </button>
          </div>
        </div>
      </div>
    </div>

    <p class="mt-4 text-sm text-site-dark">
      Custom themes can be used across all your blogs.
    </p>

    <!-- Theme Colors -->
    <section class="border-t border-site-light pt-8 mt-8">
      <h3 class="text-sm font-semibold text-site-dark mb-4">Theme Colors</h3>

      <div v-if="colorSuccess" class="mb-4 p-4 border border-green-500 text-sm text-green-600">
        Colors saved successfully!
      </div>

      <div class="grid grid-cols-2 sm:grid-cols-3 gap-4">
        <div>
          <label class="block text-xs font-semibold text-site-medium mb-2">Accent Color</label>
          <div class="flex items-center gap-2">
            <input
              v-model="colorForm.accentColor"
              type="color"
              class="w-10 h-10 shrink-0 border border-site-light"
            />
            <input
              v-model="colorForm.accentColor"
              type="text"
              class="admin-input min-w-0 flex-1"
            />
          </div>
        </div>
        <div>
          <label class="block text-xs font-semibold text-site-medium mb-2">Background</label>
          <div class="flex items-center gap-2">
            <input
              v-model="colorForm.backgroundColor"
              type="color"
              class="w-10 h-10 shrink-0 border border-site-light"
            />
            <input
              v-model="colorForm.backgroundColor"
              type="text"
              class="admin-input min-w-0 flex-1"
            />
          </div>
        </div>
        <div>
          <label class="block text-xs font-semibold text-site-medium mb-2">Text Color</label>
          <div class="flex items-center gap-2">
            <input
              v-model="colorForm.textColor"
              type="color"
              class="w-10 h-10 shrink-0 border border-site-light"
            />
            <input
              v-model="colorForm.textColor"
              type="text"
              class="admin-input min-w-0 flex-1"
            />
          </div>
        </div>
        <div>
          <label class="block text-xs font-semibold text-site-medium mb-2">Light Shade</label>
          <div class="flex items-center gap-2">
            <input
              v-model="colorForm.lightShade"
              type="color"
              class="w-10 h-10 shrink-0 border border-site-light"
            />
            <input
              v-model="colorForm.lightShade"
              type="text"
              class="admin-input min-w-0 flex-1"
            />
          </div>
        </div>
        <div>
          <label class="block text-xs font-semibold text-site-medium mb-2">Medium Shade</label>
          <div class="flex items-center gap-2">
            <input
              v-model="colorForm.mediumShade"
              type="color"
              class="w-10 h-10 shrink-0 border border-site-light"
            />
            <input
              v-model="colorForm.mediumShade"
              type="text"
              class="admin-input min-w-0 flex-1"
            />
          </div>
        </div>
        <div>
          <label class="block text-xs font-semibold text-site-medium mb-2">Dark Shade</label>
          <div class="flex items-center gap-2">
            <input
              v-model="colorForm.darkShade"
              type="color"
              class="w-10 h-10 shrink-0 border border-site-light"
            />
            <input
              v-model="colorForm.darkShade"
              type="text"
              class="admin-input min-w-0 flex-1"
            />
          </div>
        </div>
      </div>

      <!-- Color Preview -->
      <div class="mt-6">
        <label class="block text-xs font-semibold text-site-medium mb-2">Preview</label>
        <div class="border border-site-light overflow-hidden">
          <iframe
            :srcdoc="colorPreviewHtml"
            class="w-full border-0"
            style="height: 340px;"
          ></iframe>
        </div>
      </div>

      <!-- Save Button -->
      <div class="mt-6 flex justify-end">
        <button
          @click="saveColors"
          :disabled="savingColors"
          class="h-10 px-3 font-mono text-sm uppercase tracking-wider bg-site-accent text-white hover:bg-[#e89200] transition-colors disabled:opacity-50"
        >
          {{ savingColors ? 'Saving...' : 'Save Colors' }}
        </button>
      </div>
    </section>

    <!-- Delete Confirmation Modal -->
    <div
      v-if="themeToDelete"
      class="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-6"
      @click.self="themeToDelete = null"
    >
      <div class="max-w-md w-full bg-white border border-site-light p-6">
        <h3 class="text-xl font-bold text-site-dark mb-4">Delete Theme</h3>
        <p class="text-site-dark mb-6">
          Are you sure you want to delete "{{ themeToDelete.name }}"? This action cannot be undone.
        </p>
        <div class="flex justify-end gap-6">
          <button
            @click="themeToDelete = null"
            class="text-xs font-semibold text-site-dark hover:text-site-accent"
          >
            Cancel
          </button>
          <button
            @click="confirmDeleteTheme"
            class="text-xs font-semibold text-red-500 hover:text-red-400"
          >
            Delete
          </button>
        </div>
      </div>
    </div>

    <!-- Theme Editor Modal -->
    <div
      v-if="editingTheme"
      class="fixed inset-0 bg-black/50 flex items-center justify-center z-50"
    >
      <div class="bg-white border border-site-light max-w-6xl w-full mx-4 h-[90vh] flex flex-col">
        <!-- Header -->
        <div class="flex items-center justify-between p-4 border-b border-site-light">
          <h3 class="text-lg font-bold text-site-dark">
            Edit Theme: {{ editingTheme.name }}
          </h3>
          <button
            @click="closeEditor"
            class="text-xs font-semibold text-site-dark hover:text-site-accent"
          >
            Close
          </button>
        </div>

        <!-- Content -->
        <div class="flex-1 flex overflow-hidden">
          <!-- Template List -->
          <div class="w-64 border-r border-site-light overflow-y-auto">
            <div class="p-4">
              <h4 class="text-xs font-semibold text-site-medium mb-3">Templates</h4>
              <div class="space-y-1">
                <button
                  v-for="name in templateNames"
                  :key="name"
                  @click="selectTemplate(name)"
                  :class="[
                    'w-full text-left px-3 py-2 font-mono text-sm',
                    editingTemplateName === name
                      ? 'bg-site-accent text-white'
                      : 'text-site-dark hover:text-site-accent'
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
              <div class="p-4 border-b border-site-light flex items-center justify-between">
                <h4 class="text-sm font-semibold text-site-dark">{{ editingTemplateName }}</h4>
                <button
                  @click="saveTemplate"
                  :disabled="savingTemplate"
                  class="h-10 px-3 font-mono text-sm uppercase tracking-wider bg-site-accent text-white hover:bg-[#e89200] transition-colors disabled:opacity-50"
                >
                  {{ savingTemplate ? 'Saving...' : 'Save Template' }}
                </button>
              </div>
              <div class="flex-1 p-4">
                <textarea
                  v-model="editingTemplateContent"
                  class="w-full h-full font-mono text-sm border border-site-light p-3 resize-none bg-white text-site-dark focus:outline-none focus:border-site-accent"
                  spellcheck="false"
                ></textarea>
              </div>
            </div>
            <div v-else class="flex-1 flex items-center justify-center">
              <p class="text-sm text-site-medium">Select a template to edit</p>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
