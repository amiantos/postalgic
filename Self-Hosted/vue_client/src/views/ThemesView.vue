<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useRoute } from 'vue-router';
import { useBlogStore } from '@/stores/blog';
import { themeApi } from '@/api';

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
        @click="duplicateTheme('default')"
        :disabled="duplicating"
        class="font-retro-mono text-retro-sm text-retro-gray-dark dark:text-retro-gray-medium hover:text-retro-orange uppercase tracking-wider disabled:opacity-50"
      >
        {{ duplicating ? 'Creating...' : '+ New Theme' }}
      </button>
    </nav>

    <!-- Hero section -->
    <header class="relative h-52 md:h-60">
      <!-- Divider that extends to the right -->
      <div class="absolute bottom-0 left-6 right-0 border-b border-retro-gray-light dark:border-retro-gray-darker lg:left-0 lg:-right-[100vw]"></div>
      <!-- Giant background text -->
      <span class="absolute inset-0 flex items-center justify-start font-retro-serif font-bold text-[10rem] md:text-[14rem] leading-none tracking-tighter text-retro-gray-lightest dark:text-[#1a1a1a] select-none pointer-events-none whitespace-nowrap uppercase" aria-hidden="true">
        THEMES
      </span>
      <!-- Foreground content -->
      <div class="absolute bottom-4 left-6 lg:left-0">
        <h1 class="font-retro-serif font-bold text-6xl md:text-7xl leading-none tracking-tight text-retro-gray-darker dark:text-retro-cream lowercase whitespace-nowrap">
          themes
        </h1>
        <!-- Spacer -->
        <div class="mt-2 font-retro-mono text-retro-sm text-retro-gray-medium">&nbsp;</div>
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
      <!-- Error -->
      <div v-if="error" class="mb-6 p-4 border-2 border-red-500 font-retro-mono text-retro-sm text-red-600 dark:text-red-400">
        {{ error }}
      </div>

      <!-- Loading -->
      <div v-if="loading" class="py-12">
        <p class="font-retro-mono text-retro-sm text-retro-gray-medium uppercase tracking-widest">Loading themes...</p>
      </div>

      <!-- Theme List -->
      <div v-else class="space-y-3">
        <div
          v-for="theme in themes"
          :key="theme.id"
          :class="[
            'border-2 p-4',
            selectedThemeId === theme.id
              ? 'border-retro-orange'
              : 'border-retro-gray-light dark:border-retro-gray-darker'
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
                    'w-4 h-4 border-2 flex items-center justify-center',
                    selectedThemeId === theme.id ? 'border-retro-orange' : 'border-retro-gray-medium'
                  ]"
                >
                  <div
                    v-if="selectedThemeId === theme.id"
                    class="w-2 h-2 bg-retro-orange"
                  ></div>
                </div>
                <div>
                  <p class="font-retro-sans text-retro-base text-retro-gray-darker dark:text-retro-cream">{{ theme.name }}</p>
                  <p class="font-retro-mono text-retro-xs text-retro-gray-medium">
                    {{ theme.isDefault ? 'Built-in' : 'Custom' }}
                  </p>
                </div>
              </button>
            </div>

            <div class="flex items-center gap-4">
              <!-- Edit Button (custom themes only) -->
              <button
                v-if="!theme.isDefault"
                @click="openThemeEditor(theme.id)"
                class="font-retro-mono text-retro-xs text-retro-gray-dark dark:text-retro-gray-medium hover:text-retro-orange uppercase tracking-wider"
              >
                Edit
              </button>

              <!-- Duplicate Button -->
              <button
                @click="duplicateTheme(theme.id)"
                :disabled="duplicating"
                class="font-retro-mono text-retro-xs text-retro-gray-dark dark:text-retro-gray-medium hover:text-retro-orange uppercase tracking-wider"
              >
                Duplicate
              </button>

              <!-- Delete Button (custom themes only) -->
              <button
                v-if="!theme.isDefault"
                @click="themeToDelete = theme"
                class="font-retro-mono text-retro-xs text-red-500 hover:text-red-400 uppercase tracking-wider"
              >
                Delete
              </button>
            </div>
          </div>
        </div>
      </div>

      <p class="mt-4 font-retro-sans text-retro-sm text-retro-gray-dark dark:text-retro-gray-medium">
        Custom themes can be used across all your blogs.
      </p>

      <!-- Theme Colors -->
      <section class="border-t border-retro-gray-light dark:border-retro-gray-darker pt-8 mt-8">
        <h3 class="font-retro-mono text-retro-sm text-retro-gray-darker dark:text-retro-cream uppercase tracking-wider mb-4">Theme Colors</h3>

        <div v-if="colorSuccess" class="mb-4 p-4 border-2 border-green-500 font-retro-mono text-retro-sm text-green-600 dark:text-green-400">
          Colors saved successfully!
        </div>

        <div class="grid grid-cols-2 sm:grid-cols-3 gap-4">
          <div>
            <label class="block font-retro-mono text-retro-xs text-retro-gray-medium uppercase tracking-wider mb-2">Accent Color</label>
            <div class="flex items-center gap-2">
              <input
                v-model="colorForm.accentColor"
                type="color"
                class="w-10 h-10 shrink-0 border-2 border-retro-gray-light dark:border-retro-gray-darker"
              />
              <input
                v-model="colorForm.accentColor"
                type="text"
                class="min-w-0 flex-1 px-2 py-1 border-2 border-retro-gray-light dark:border-retro-gray-darker bg-white dark:bg-black font-retro-mono text-retro-xs text-retro-gray-darker dark:text-retro-cream focus:outline-none focus:border-retro-orange"
              />
            </div>
          </div>
          <div>
            <label class="block font-retro-mono text-retro-xs text-retro-gray-medium uppercase tracking-wider mb-2">Background</label>
            <div class="flex items-center gap-2">
              <input
                v-model="colorForm.backgroundColor"
                type="color"
                class="w-10 h-10 shrink-0 border-2 border-retro-gray-light dark:border-retro-gray-darker"
              />
              <input
                v-model="colorForm.backgroundColor"
                type="text"
                class="min-w-0 flex-1 px-2 py-1 border-2 border-retro-gray-light dark:border-retro-gray-darker bg-white dark:bg-black font-retro-mono text-retro-xs text-retro-gray-darker dark:text-retro-cream focus:outline-none focus:border-retro-orange"
              />
            </div>
          </div>
          <div>
            <label class="block font-retro-mono text-retro-xs text-retro-gray-medium uppercase tracking-wider mb-2">Text Color</label>
            <div class="flex items-center gap-2">
              <input
                v-model="colorForm.textColor"
                type="color"
                class="w-10 h-10 shrink-0 border-2 border-retro-gray-light dark:border-retro-gray-darker"
              />
              <input
                v-model="colorForm.textColor"
                type="text"
                class="min-w-0 flex-1 px-2 py-1 border-2 border-retro-gray-light dark:border-retro-gray-darker bg-white dark:bg-black font-retro-mono text-retro-xs text-retro-gray-darker dark:text-retro-cream focus:outline-none focus:border-retro-orange"
              />
            </div>
          </div>
          <div>
            <label class="block font-retro-mono text-retro-xs text-retro-gray-medium uppercase tracking-wider mb-2">Light Shade</label>
            <div class="flex items-center gap-2">
              <input
                v-model="colorForm.lightShade"
                type="color"
                class="w-10 h-10 shrink-0 border-2 border-retro-gray-light dark:border-retro-gray-darker"
              />
              <input
                v-model="colorForm.lightShade"
                type="text"
                class="min-w-0 flex-1 px-2 py-1 border-2 border-retro-gray-light dark:border-retro-gray-darker bg-white dark:bg-black font-retro-mono text-retro-xs text-retro-gray-darker dark:text-retro-cream focus:outline-none focus:border-retro-orange"
              />
            </div>
          </div>
          <div>
            <label class="block font-retro-mono text-retro-xs text-retro-gray-medium uppercase tracking-wider mb-2">Medium Shade</label>
            <div class="flex items-center gap-2">
              <input
                v-model="colorForm.mediumShade"
                type="color"
                class="w-10 h-10 shrink-0 border-2 border-retro-gray-light dark:border-retro-gray-darker"
              />
              <input
                v-model="colorForm.mediumShade"
                type="text"
                class="min-w-0 flex-1 px-2 py-1 border-2 border-retro-gray-light dark:border-retro-gray-darker bg-white dark:bg-black font-retro-mono text-retro-xs text-retro-gray-darker dark:text-retro-cream focus:outline-none focus:border-retro-orange"
              />
            </div>
          </div>
          <div>
            <label class="block font-retro-mono text-retro-xs text-retro-gray-medium uppercase tracking-wider mb-2">Dark Shade</label>
            <div class="flex items-center gap-2">
              <input
                v-model="colorForm.darkShade"
                type="color"
                class="w-10 h-10 shrink-0 border-2 border-retro-gray-light dark:border-retro-gray-darker"
              />
              <input
                v-model="colorForm.darkShade"
                type="text"
                class="min-w-0 flex-1 px-2 py-1 border-2 border-retro-gray-light dark:border-retro-gray-darker bg-white dark:bg-black font-retro-mono text-retro-xs text-retro-gray-darker dark:text-retro-cream focus:outline-none focus:border-retro-orange"
              />
            </div>
          </div>
        </div>

        <!-- Color Preview -->
        <div class="mt-6">
          <label class="block font-retro-mono text-retro-xs text-retro-gray-medium uppercase tracking-wider mb-2">Preview</label>
          <div class="border-2 border-retro-gray-light dark:border-retro-gray-darker overflow-hidden">
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
            class="px-4 py-2 border-2 border-retro-orange bg-retro-orange font-retro-mono text-retro-sm text-white hover:bg-retro-orange-dark hover:border-retro-orange-dark uppercase tracking-wider disabled:opacity-50"
          >
            {{ savingColors ? 'Saving...' : 'Save Colors' }}
          </button>
        </div>
      </section>
    </main>

    </div><!-- End max-width wrapper -->

    <!-- Delete Confirmation Modal -->
    <div
      v-if="themeToDelete"
      class="fixed inset-0 bg-black/90 flex items-center justify-center z-50 p-6"
      @click.self="themeToDelete = null"
    >
      <div class="max-w-md w-full bg-white dark:bg-black border-2 border-retro-gray-light dark:border-retro-gray-darker p-6">
        <h3 class="font-retro-serif text-2xl font-bold text-retro-gray-darker dark:text-retro-cream mb-4">Delete Theme</h3>
        <p class="font-retro-sans text-retro-base text-retro-gray-dark dark:text-retro-gray-medium mb-6">
          Are you sure you want to delete "{{ themeToDelete.name }}"? This action cannot be undone.
        </p>
        <div class="flex justify-end gap-6">
          <button
            @click="themeToDelete = null"
            class="font-retro-mono text-retro-sm text-retro-gray-dark dark:text-retro-gray-medium hover:text-retro-orange uppercase tracking-wider"
          >
            Cancel
          </button>
          <button
            @click="confirmDeleteTheme"
            class="font-retro-mono text-retro-sm text-red-500 hover:text-red-400 uppercase tracking-wider"
          >
            Delete
          </button>
        </div>
      </div>
    </div>

    <!-- Theme Editor Modal -->
    <div
      v-if="editingTheme"
      class="fixed inset-0 bg-black/90 flex items-center justify-center z-50"
    >
      <div class="bg-white dark:bg-black border-2 border-retro-gray-light dark:border-retro-gray-darker max-w-6xl w-full mx-4 h-[90vh] flex flex-col">
        <!-- Header -->
        <div class="flex items-center justify-between p-4 border-b border-retro-gray-light dark:border-retro-gray-darker">
          <h3 class="font-retro-serif text-xl font-bold text-retro-gray-darker dark:text-retro-cream">
            Edit Theme: {{ editingTheme.name }}
          </h3>
          <button
            @click="closeEditor"
            class="font-retro-mono text-retro-sm text-retro-gray-dark dark:text-retro-gray-medium hover:text-retro-orange uppercase"
          >
            Close
          </button>
        </div>

        <!-- Content -->
        <div class="flex-1 flex overflow-hidden">
          <!-- Template List -->
          <div class="w-64 border-r border-retro-gray-light dark:border-retro-gray-darker overflow-y-auto">
            <div class="p-4">
              <h4 class="font-retro-mono text-retro-xs text-retro-gray-medium uppercase tracking-wider mb-3">Templates</h4>
              <div class="space-y-1">
                <button
                  v-for="name in templateNames"
                  :key="name"
                  @click="selectTemplate(name)"
                  :class="[
                    'w-full text-left px-3 py-2 font-retro-mono text-retro-sm',
                    editingTemplateName === name
                      ? 'bg-retro-orange text-white'
                      : 'text-retro-gray-darker dark:text-retro-gray-medium hover:text-retro-orange'
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
              <div class="p-4 border-b border-retro-gray-light dark:border-retro-gray-darker flex items-center justify-between">
                <h4 class="font-retro-mono text-retro-sm text-retro-gray-darker dark:text-retro-cream uppercase">{{ editingTemplateName }}</h4>
                <button
                  @click="saveTemplate"
                  :disabled="savingTemplate"
                  class="px-4 py-2 border-2 border-retro-orange bg-retro-orange font-retro-mono text-retro-sm text-white hover:bg-retro-orange-dark hover:border-retro-orange-dark uppercase tracking-wider disabled:opacity-50"
                >
                  {{ savingTemplate ? 'Saving...' : 'Save Template' }}
                </button>
              </div>
              <div class="flex-1 p-4">
                <textarea
                  v-model="editingTemplateContent"
                  class="w-full h-full font-retro-mono text-retro-sm border-2 border-retro-gray-light dark:border-retro-gray-darker p-3 resize-none bg-white dark:bg-black text-retro-gray-darker dark:text-retro-cream focus:outline-none focus:border-retro-orange"
                  spellcheck="false"
                ></textarea>
              </div>
            </div>
            <div v-else class="flex-1 flex items-center justify-center">
              <p class="font-retro-mono text-retro-sm text-retro-gray-medium">Select a template to edit</p>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
