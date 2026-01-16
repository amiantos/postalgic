<script setup>
import { ref, computed, onMounted, onBeforeUnmount, watch } from 'vue';
import { useRoute, useRouter, onBeforeRouteLeave } from 'vue-router';
import { useBlogStore } from '@/stores/blog';
import EmbedEditor from '@/components/EmbedEditor.vue';
import PublishModal from '@/components/PublishModal.vue';

const route = useRoute();
const router = useRouter();
const blogStore = useBlogStore();

const blogId = computed(() => route.params.blogId);
const postId = computed(() => route.params.postId);
const isNew = computed(() => !postId.value);

// Mobile sidebar state (desktop sidebar is always visible)
const mobileSidebarOpen = ref(false);

// Auto-resize textarea
const contentTextarea = ref(null);
function autoResize() {
  const textarea = contentTextarea.value;
  if (textarea) {
    textarea.style.height = 'auto';
    textarea.style.height = Math.max(400, textarea.scrollHeight) + 'px';
  }
}

// Convert a Date to local datetime-local format (YYYY-MM-DDTHH:MM)
function toLocalDateTimeString(date) {
  const d = new Date(date);
  const year = d.getFullYear();
  const month = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  const hours = String(d.getHours()).padStart(2, '0');
  const minutes = String(d.getMinutes()).padStart(2, '0');
  return `${year}-${month}-${day}T${hours}:${minutes}`;
}

const form = ref({
  title: '',
  content: '',
  isDraft: true,
  categoryId: null,
  tagIds: [],
  embed: null,
  createdAt: toLocalDateTimeString(new Date())
});

const saving = ref(false);
const error = ref(null);
const tagSearchQuery = ref('');

// Track initial form state for dirty checking
const initialFormState = ref(null);
const hasSaved = ref(false);

// Check if form has unsaved changes
const isDirty = computed(() => {
  if (!initialFormState.value) return false;
  if (hasSaved.value) return false;

  const current = form.value;
  const initial = initialFormState.value;

  return (
    current.title !== initial.title ||
    current.content !== initial.content ||
    current.isDraft !== initial.isDraft ||
    current.categoryId !== initial.categoryId ||
    current.createdAt !== initial.createdAt ||
    JSON.stringify(current.tagIds) !== JSON.stringify(initial.tagIds) ||
    JSON.stringify(current.embed) !== JSON.stringify(initial.embed)
  );
});

function captureInitialState() {
  initialFormState.value = {
    title: form.value.title,
    content: form.value.content,
    isDraft: form.value.isDraft,
    categoryId: form.value.categoryId,
    tagIds: [...form.value.tagIds],
    embed: form.value.embed ? JSON.parse(JSON.stringify(form.value.embed)) : null,
    createdAt: form.value.createdAt
  };
}
const showTagDropdown = ref(false);
const showEmbedEditor = ref(false);
const showPublishModal = ref(false);
const showDeleteModal = ref(false);
const wasPublished = ref(false); // Track if post was originally published

// Tags matching search query (case-insensitive)
const filteredTags = computed(() => {
  if (!tagSearchQuery.value.trim()) return [];
  const query = tagSearchQuery.value.toLowerCase();
  return blogStore.tags.filter(t =>
    !form.value.tagIds.includes(t.id) &&
    t.name.toLowerCase().includes(query)
  );
});

// Check if exact match exists (to decide whether to show "Create" option)
const exactTagMatch = computed(() => {
  const query = tagSearchQuery.value.trim().toLowerCase();
  if (!query) return true; // Don't show create option when empty
  return blogStore.tags.some(t => t.name.toLowerCase() === query);
});

// Tags suggested based on post content (partial/prefix matching)
const suggestedTags = computed(() => {
  const text = `${form.value.title} ${form.value.content}`.toLowerCase();
  if (!text.trim()) return [];
  return blogStore.tags.filter(tag => {
    if (form.value.tagIds.includes(tag.id)) return false;
    const tagName = tag.name.toLowerCase();
    return text.includes(tagName);
  });
});

onMounted(async () => {
  if (!isNew.value) {
    const post = await blogStore.fetchPost(blogId.value, postId.value);
    form.value = {
      title: post.title || '',
      content: post.content || '',
      isDraft: post.isDraft,
      categoryId: post.categoryId || null,
      tagIds: post.tagIds || [],
      embed: post.embed || null,
      createdAt: toLocalDateTimeString(new Date(post.createdAt))
    };
    wasPublished.value = !post.isDraft; // Track if post was originally published
    // Auto-resize after content is loaded
    setTimeout(autoResize, 0);
  }
  // Capture initial state for dirty checking
  captureInitialState();

  // Add beforeunload handler for browser refresh/close
  window.addEventListener('beforeunload', handleBeforeUnload);
});

onBeforeUnmount(() => {
  window.removeEventListener('beforeunload', handleBeforeUnload);
});

// Handle browser refresh/close
function handleBeforeUnload(e) {
  if (isDirty.value) {
    e.preventDefault();
    e.returnValue = '';
    return '';
  }
}

// Navigation guard for route changes
onBeforeRouteLeave((to, from) => {
  if (isDirty.value) {
    const answer = window.confirm('You have unsaved changes. Are you sure you want to leave?');
    if (!answer) return false;
  }
});

async function saveDraft() {
  form.value.isDraft = true;
  await savePost();
}

async function savePost() {
  if (!form.value.content.trim()) {
    error.value = 'Post content is required';
    return;
  }

  saving.value = true;
  error.value = null;

  // Check if we're unpublishing (changing from published to draft)
  const isUnpublishing = wasPublished.value && form.value.isDraft;

  try {
    const data = {
      ...form.value,
      createdAt: new Date(form.value.createdAt).toISOString()
    };

    if (isNew.value) {
      await blogStore.createPost(blogId.value, data);
    } else {
      await blogStore.updatePost(blogId.value, postId.value, data);
    }
    // Mark as saved so navigation guard doesn't trigger
    hasSaved.value = true;

    // If unpublishing, show the publish modal to update the site
    if (isUnpublishing) {
      showPublishModal.value = true;
    } else {
      router.push({ name: 'blog-posts', params: { blogId: blogId.value } });
    }
  } catch (e) {
    error.value = e.message;
  } finally {
    saving.value = false;
  }
}

async function publishPost() {
  if (!form.value.content.trim()) {
    error.value = 'Post content is required';
    return;
  }

  // Check if we actually need to save (post is new, is a draft, or has changes)
  const needsSave = isNew.value || form.value.isDraft || isDirty.value;

  if (needsSave) {
    form.value.isDraft = false;
    saving.value = true;
    error.value = null;

    try {
      const data = {
        ...form.value,
        createdAt: new Date(form.value.createdAt).toISOString()
      };

      if (isNew.value) {
        await blogStore.createPost(blogId.value, data);
      } else {
        await blogStore.updatePost(blogId.value, postId.value, data);
      }
      hasSaved.value = true;
    } catch (e) {
      error.value = e.message;
      saving.value = false;
      return;
    } finally {
      saving.value = false;
    }
  }

  showPublishModal.value = true;
}

function handlePublishModalClose() {
  showPublishModal.value = false;
  router.push({ name: 'blog-posts', params: { blogId: blogId.value } });
}

async function createTag() {
  if (!tagSearchQuery.value.trim()) return;

  try {
    const tag = await blogStore.createTag(blogId.value, { name: tagSearchQuery.value.trim() });
    form.value.tagIds.push(tag.id);
    tagSearchQuery.value = '';
    showTagDropdown.value = false;
  } catch (e) {
    error.value = e.message;
  }
}

function selectTag(tagId) {
  form.value.tagIds.push(tagId);
  tagSearchQuery.value = '';
  showTagDropdown.value = false;
}

function hideTagDropdown() {
  setTimeout(() => {
    showTagDropdown.value = false;
  }, 150);
}

function toggleTag(tagId) {
  const index = form.value.tagIds.indexOf(tagId);
  if (index === -1) {
    form.value.tagIds.push(tagId);
  } else {
    form.value.tagIds.splice(index, 1);
  }
}

// Embed functions
const embedLabel = computed(() => {
  if (!form.value.embed) return 'Add Embed';
  switch (form.value.embed.type) {
    case 'youtube':
      return 'YouTube Video';
    case 'link':
      return 'Link Embedded';
    case 'image':
      const count = form.value.embed.images?.length || 0;
      return count === 1 ? '1 Image' : `${count} Images`;
    default:
      return 'Embed';
  }
});

function handleEmbedSave(embedData) {
  form.value.embed = embedData;
  showEmbedEditor.value = false;
}

function handleEmbedCancel() {
  showEmbedEditor.value = false;
}

function handleUseTitle(title) {
  form.value.title = title;
}

function removeEmbed() {
  form.value.embed = null;
}

async function deletePost() {
  try {
    await blogStore.deletePost(blogId.value, postId.value);
    hasSaved.value = true; // Prevent unsaved changes warning
    router.push({ name: 'blog-posts', params: { blogId: blogId.value } });
  } catch (e) {
    error.value = e.message;
    showDeleteModal.value = false;
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
        <span class="relative -top-px">&lt;</span> All Posts
      </router-link>

      <div class="flex items-center gap-4">
        <!-- Action buttons (mobile only) -->
        <button
          @click="saveDraft"
          :disabled="saving"
          class="lg:hidden font-retro-mono text-retro-sm text-retro-gray-dark dark:text-retro-gray-medium hover:text-retro-orange uppercase tracking-wider disabled:opacity-50"
        >
          {{ saving ? 'Saving...' : 'Save Draft' }}
        </button>
        <button
          @click="publishPost"
          :disabled="saving"
          class="lg:hidden font-retro-mono text-retro-sm text-retro-orange hover:text-retro-orange-dark uppercase tracking-wider disabled:opacity-50"
        >
          Publish
        </button>
        <!-- Settings toggle (mobile only) -->
        <button
          @click="mobileSidebarOpen = true"
          class="lg:hidden font-retro-mono text-retro-sm text-retro-gray-dark dark:text-retro-gray-medium hover:text-retro-orange uppercase tracking-wider"
        >
          Settings
        </button>
      </div>
    </nav>

    <!-- Hero section with giant title -->
    <header class="relative h-40 md:h-48">
      <!-- Divider that extends to the right -->
      <div class="absolute bottom-0 left-6 right-0 border-b border-retro-gray-light dark:border-retro-gray-darker lg:left-0 lg:-right-[100vw]"></div>
      <!-- Giant background text -->
      <span class="absolute inset-0 flex items-center justify-start font-retro-serif font-bold text-[6rem] md:text-[8rem] leading-none tracking-tighter text-retro-gray-lightest dark:text-[#1a1a1a] select-none pointer-events-none whitespace-nowrap uppercase" aria-hidden="true">
        {{ isNew ? 'NEW POST' : 'EDIT POST' }}
      </span>
      <!-- Foreground content -->
      <div class="absolute bottom-8 left-6 lg:left-0">
        <h1 class="font-retro-serif font-bold text-4xl md:text-5xl leading-none tracking-tight text-retro-gray-darker dark:text-retro-cream lowercase whitespace-nowrap">
          {{ isNew ? 'new post' : 'edit post' }}
        </h1>
      </div>
    </header>

    <!-- Error -->
    <div v-if="error" class="mx-6 lg:mx-0 mt-6 p-4 border-2 border-red-500 bg-red-50 dark:bg-red-900/20 font-retro-mono text-retro-sm text-red-600 dark:text-red-400">
      {{ error }}
    </div>

    <!-- Editor Area -->
    <main class="px-6 lg:px-0 py-6">
      <!-- Title -->
      <div class="pb-4">
        <input
          v-model="form.title"
          type="text"
          class="w-full font-retro-serif text-3xl md:text-4xl font-bold bg-transparent border-none outline-none text-retro-gray-darker dark:text-retro-cream placeholder:text-retro-gray-medium"
          placeholder="Post title..."
        />
      </div>

      <!-- Content -->
      <div>
        <textarea
          ref="contentTextarea"
          v-model="form.content"
          @input="autoResize"
          class="w-full min-h-[400px] font-retro-sans text-retro-base leading-relaxed bg-transparent border-none outline-none resize-none text-retro-gray-darker dark:text-retro-cream placeholder:text-retro-gray-medium"
          placeholder="Write your post content in Markdown..."
        ></textarea>
      </div>
    </main>

    </div><!-- End max-width wrapper -->

    <!-- Desktop Sidebar (always visible on lg+) -->
    <aside class="hidden lg:flex lg:flex-col w-64 bg-white dark:bg-black border-l-2 border-retro-gray-light dark:border-retro-gray-darker fixed top-0 right-0 h-screen overflow-y-auto overflow-x-hidden z-30">
      <div class="p-4">
        <!-- Header -->
        <h3 class="font-retro-mono text-retro-sm text-retro-gray-darker dark:text-retro-cream uppercase tracking-wider mb-4">Settings</h3>

        <!-- Action Buttons -->
        <div class="flex flex-col gap-2 mb-4">
          <button
            @click="saveDraft"
            :disabled="saving"
            class="w-full px-3 py-2 border-2 border-retro-gray-light dark:border-retro-gray-darker font-retro-mono text-retro-sm text-retro-gray-darker dark:text-retro-cream hover:border-retro-orange hover:text-retro-orange uppercase tracking-wider disabled:opacity-50"
          >
            {{ saving ? 'Saving...' : 'Save Draft' }}
          </button>
          <button
            @click="publishPost"
            :disabled="saving"
            class="w-full px-3 py-2 border-2 border-retro-orange bg-retro-orange font-retro-mono text-retro-sm text-white hover:bg-retro-orange-dark hover:border-retro-orange-dark uppercase tracking-wider disabled:opacity-50"
          >
            Publish
          </button>
        </div>

        <div class="border-t border-retro-gray-light dark:border-retro-gray-darker mb-4"></div>

        <!-- Settings Content -->
        <div class="space-y-4">
          <!-- Status -->
          <div>
            <h3 class="font-retro-mono text-retro-xs text-retro-gray-medium uppercase tracking-wider mb-2">Status</h3>
            <label class="flex items-center gap-2">
              <input
                type="checkbox"
                v-model="form.isDraft"
                class="border-retro-gray-light dark:border-retro-gray-darker"
              />
              <span class="font-retro-sans text-retro-sm text-retro-gray-darker dark:text-retro-cream">Save as draft</span>
            </label>
          </div>

          <div class="border-t border-retro-gray-light dark:border-retro-gray-darker"></div>

          <!-- Date -->
          <div>
            <h3 class="font-retro-mono text-retro-xs text-retro-gray-medium uppercase tracking-wider mb-2">Publish Date</h3>
            <input
              v-model="form.createdAt"
              type="datetime-local"
              class="w-full px-2 py-1 border-2 border-retro-gray-light dark:border-retro-gray-darker bg-white dark:bg-black font-retro-mono text-retro-sm text-retro-gray-darker dark:text-retro-cream focus:outline-none focus:border-retro-orange"
            />
          </div>

          <!-- Category -->
          <template v-if="blogStore.categories.length > 0">
            <div class="border-t border-retro-gray-light dark:border-retro-gray-darker"></div>

            <div>
              <h3 class="font-retro-mono text-retro-xs text-retro-gray-medium uppercase tracking-wider mb-2">Category</h3>
              <select
                v-model="form.categoryId"
                class="w-full px-2 py-1 border-2 border-retro-gray-light dark:border-retro-gray-darker bg-white dark:bg-black font-retro-mono text-retro-sm text-retro-gray-darker dark:text-retro-cream focus:outline-none focus:border-retro-orange"
              >
                <option :value="null">No category</option>
                <option v-for="category in blogStore.categories" :key="category.id" :value="category.id">
                  {{ category.name }}
                </option>
              </select>
            </div>
          </template>

          <div class="border-t border-retro-gray-light dark:border-retro-gray-darker"></div>

          <!-- Tags -->
          <div>
            <h3 class="font-retro-mono text-retro-xs text-retro-gray-medium uppercase tracking-wider mb-2">Tags</h3>

            <div v-if="form.tagIds.length > 0" class="flex flex-wrap gap-1.5 mb-3">
              <span
                v-for="tagId in form.tagIds"
                :key="tagId"
                class="px-2 py-0.5 border border-retro-orange text-retro-orange font-retro-mono text-retro-xs flex items-center gap-1"
              >
                {{ blogStore.tags.find(t => t.id === tagId)?.name }}
                <button @click="toggleTag(tagId)" class="hover:text-retro-orange-dark">×</button>
              </span>
            </div>

            <div v-if="suggestedTags.length > 0" class="mb-3">
              <p class="font-retro-mono text-retro-xs text-retro-gray-medium mb-1">Suggested</p>
              <div class="flex flex-wrap gap-1">
                <button
                  v-for="tag in suggestedTags"
                  :key="tag.id"
                  @click="toggleTag(tag.id)"
                  class="px-2 py-0.5 border border-retro-gray-light dark:border-retro-gray-darker font-retro-mono text-retro-xs text-retro-gray-dark dark:text-retro-gray-medium hover:border-retro-orange hover:text-retro-orange"
                >
                  + {{ tag.name }}
                </button>
              </div>
            </div>

            <div class="relative">
              <input
                v-model="tagSearchQuery"
                type="text"
                placeholder="Search or add tags..."
                class="w-full px-2 py-1 border-2 border-retro-gray-light dark:border-retro-gray-darker bg-white dark:bg-black font-retro-mono text-retro-sm text-retro-gray-darker dark:text-retro-cream placeholder:text-retro-gray-medium focus:outline-none focus:border-retro-orange"
                @focus="showTagDropdown = true"
                @blur="hideTagDropdown"
                @keyup.enter="exactTagMatch ? null : createTag()"
              />
              <div
                v-if="showTagDropdown && (filteredTags.length > 0 || (!exactTagMatch && tagSearchQuery.trim()))"
                class="absolute z-50 w-full mt-1 bg-white dark:bg-black border-2 border-retro-gray-light dark:border-retro-gray-darker max-h-48 overflow-y-auto"
              >
                <button
                  v-for="tag in filteredTags"
                  :key="tag.id"
                  @mousedown.prevent="selectTag(tag.id)"
                  class="w-full px-2 py-1 text-left font-retro-mono text-retro-sm text-retro-gray-darker dark:text-retro-cream hover:bg-retro-orange hover:text-white"
                >
                  {{ tag.name }}
                </button>
                <button
                  v-if="!exactTagMatch && tagSearchQuery.trim()"
                  @mousedown.prevent="createTag"
                  class="w-full px-2 py-1 text-left font-retro-mono text-retro-sm text-retro-orange hover:bg-retro-orange hover:text-white border-t border-retro-gray-light dark:border-retro-gray-darker"
                >
                  Create "{{ tagSearchQuery.trim() }}"
                </button>
              </div>
            </div>
          </div>

          <div class="border-t border-retro-gray-light dark:border-retro-gray-darker"></div>

          <!-- Embed -->
          <div>
            <h3 class="font-retro-mono text-retro-xs text-retro-gray-medium uppercase tracking-wider mb-2">Embed</h3>

            <EmbedEditor
              v-if="showEmbedEditor"
              :embed="form.embed"
              :blog-id="blogId"
              @save="handleEmbedSave"
              @cancel="handleEmbedCancel"
              @use-title="handleUseTitle"
            />

            <div v-else>
              <button
                v-if="!form.embed"
                @click="showEmbedEditor = true"
                class="w-full px-3 py-2 border-2 border-dashed border-retro-gray-light dark:border-retro-gray-darker font-retro-mono text-retro-sm text-retro-gray-medium hover:border-retro-orange hover:text-retro-orange flex items-center justify-center gap-2"
              >
                <span class="relative -top-px">+</span> Add Embed
              </button>

              <div v-else>
                <div v-if="form.embed.type === 'youtube'" class="p-2 border-2 border-retro-gray-light dark:border-retro-gray-darker">
                  <div class="flex items-center gap-2">
                    <span class="font-retro-mono text-retro-xs text-red-500">YT</span>
                    <span class="font-retro-sans text-retro-sm truncate text-retro-gray-darker dark:text-retro-cream">{{ form.embed.title || 'YouTube Video' }}</span>
                  </div>
                  <p class="font-retro-mono text-retro-xs text-retro-gray-medium mt-1">{{ form.embed.position === 'above' ? 'Above' : 'Below' }} content</p>
                </div>

                <div v-else-if="form.embed.type === 'link'" class="p-2 border-2 border-retro-gray-light dark:border-retro-gray-darker">
                  <div class="flex gap-2">
                    <img
                      v-if="form.embed.imageData || form.embed.imageFilename || (form.embed.imageUrl && !form.embed.imageUrl.startsWith('file://'))"
                      :src="form.embed.imageData || (form.embed.imageFilename ? `/uploads/${blogId}/${form.embed.imageFilename}` : form.embed.imageUrl)"
                      class="w-10 h-10 object-cover flex-shrink-0"
                      alt=""
                    />
                    <div class="flex-1 min-w-0">
                      <p class="font-retro-sans text-retro-sm truncate text-retro-gray-darker dark:text-retro-cream">{{ form.embed.title || 'Link' }}</p>
                      <p v-if="form.embed.description" class="font-retro-mono text-retro-xs text-retro-gray-medium truncate">{{ form.embed.description }}</p>
                    </div>
                  </div>
                  <p class="font-retro-mono text-retro-xs text-retro-gray-medium mt-2">{{ form.embed.position === 'above' ? 'Above' : 'Below' }} content</p>
                </div>

                <div v-else-if="form.embed.type === 'image'" class="p-2 border-2 border-retro-gray-light dark:border-retro-gray-darker">
                  <div class="flex gap-1 mb-2">
                    <img
                      v-for="(img, index) in form.embed.images?.slice(0, 4)"
                      :key="index"
                      :src="img.data || `/uploads/${blogId}/${img.filename}`"
                      class="w-10 h-10 object-cover"
                      alt=""
                    />
                    <div
                      v-if="form.embed.images?.length > 4"
                      class="w-10 h-10 border border-retro-gray-light dark:border-retro-gray-darker flex items-center justify-center font-retro-mono text-retro-xs text-retro-gray-medium"
                    >
                      +{{ form.embed.images.length - 4 }}
                    </div>
                  </div>
                  <p class="font-retro-mono text-retro-xs text-retro-gray-medium">{{ form.embed.images?.length || 0 }} image(s) - {{ form.embed.position === 'above' ? 'Above' : 'Below' }} content</p>
                </div>

                <div class="flex gap-2 mt-2">
                  <button
                    @click="showEmbedEditor = true"
                    class="flex-1 px-2 py-1 border-2 border-retro-gray-light dark:border-retro-gray-darker font-retro-mono text-retro-xs text-retro-gray-darker dark:text-retro-cream hover:border-retro-orange hover:text-retro-orange uppercase"
                  >
                    Edit
                  </button>
                  <button
                    @click="removeEmbed"
                    class="px-2 py-1 border-2 border-red-500 font-retro-mono text-retro-xs text-red-500 hover:bg-red-500 hover:text-white uppercase"
                  >
                    Remove
                  </button>
                </div>
              </div>
            </div>
          </div>

          <!-- Delete Post (only for existing posts) -->
          <template v-if="!isNew">
            <div class="border-t border-retro-gray-light dark:border-retro-gray-darker"></div>
            <div>
              <button
                @click="showDeleteModal = true"
                class="w-full px-3 py-2 border-2 border-red-500 font-retro-mono text-retro-sm text-red-500 hover:bg-red-500 hover:text-white uppercase tracking-wider"
              >
                Delete Post
              </button>
            </div>
          </template>
        </div>
      </div>
    </aside>

    <!-- Mobile Sidebar Panel (slide-in overlay) -->
    <div
      v-if="mobileSidebarOpen"
      class="lg:hidden fixed inset-0 z-40"
      @click="mobileSidebarOpen = false"
    >
      <!-- Backdrop -->
      <div class="absolute inset-0 bg-black/80"></div>

      <!-- Panel -->
      <div
        class="absolute right-0 top-0 bottom-0 w-80 bg-white dark:bg-black border-l-2 border-retro-gray-light dark:border-retro-gray-darker overflow-y-auto"
        @click.stop
      >
        <div class="p-4">
          <!-- Header -->
          <div class="flex items-center justify-between mb-4">
            <h3 class="font-retro-mono text-retro-sm text-retro-gray-darker dark:text-retro-cream uppercase tracking-wider">Settings</h3>
            <button
              @click="mobileSidebarOpen = false"
              class="font-retro-mono text-retro-sm text-retro-gray-dark dark:text-retro-gray-medium hover:text-retro-orange"
            >
              <span class="relative -top-px">×</span>
            </button>
          </div>

          <!-- Settings Content (same as desktop) -->
          <div class="space-y-4">
            <!-- Status -->
            <div>
              <h3 class="font-retro-mono text-retro-xs text-retro-gray-medium uppercase tracking-wider mb-2">Status</h3>
              <label class="flex items-center gap-2">
                <input
                  type="checkbox"
                  v-model="form.isDraft"
                  class="border-retro-gray-light dark:border-retro-gray-darker"
                />
                <span class="font-retro-sans text-retro-sm text-retro-gray-darker dark:text-retro-cream">Save as draft</span>
              </label>
            </div>

            <div class="border-t border-retro-gray-light dark:border-retro-gray-darker"></div>

            <!-- Date -->
            <div>
              <h3 class="font-retro-mono text-retro-xs text-retro-gray-medium uppercase tracking-wider mb-2">Publish Date</h3>
              <input
                v-model="form.createdAt"
                type="datetime-local"
                class="w-full px-2 py-1 border-2 border-retro-gray-light dark:border-retro-gray-darker bg-white dark:bg-black font-retro-mono text-retro-sm text-retro-gray-darker dark:text-retro-cream focus:outline-none focus:border-retro-orange"
              />
            </div>

            <!-- Category -->
            <template v-if="blogStore.categories.length > 0">
              <div class="border-t border-retro-gray-light dark:border-retro-gray-darker"></div>

              <div>
                <h3 class="font-retro-mono text-retro-xs text-retro-gray-medium uppercase tracking-wider mb-2">Category</h3>
                <select
                  v-model="form.categoryId"
                  class="w-full px-2 py-1 border-2 border-retro-gray-light dark:border-retro-gray-darker bg-white dark:bg-black font-retro-mono text-retro-sm text-retro-gray-darker dark:text-retro-cream focus:outline-none focus:border-retro-orange"
                >
                  <option :value="null">No category</option>
                  <option v-for="category in blogStore.categories" :key="category.id" :value="category.id">
                    {{ category.name }}
                  </option>
                </select>
              </div>
            </template>

            <div class="border-t border-retro-gray-light dark:border-retro-gray-darker"></div>

            <!-- Tags -->
            <div>
              <h3 class="font-retro-mono text-retro-xs text-retro-gray-medium uppercase tracking-wider mb-2">Tags</h3>

              <div v-if="form.tagIds.length > 0" class="flex flex-wrap gap-1.5 mb-3">
                <span
                  v-for="tagId in form.tagIds"
                  :key="tagId"
                  class="px-2 py-0.5 border border-retro-orange text-retro-orange font-retro-mono text-retro-xs flex items-center gap-1"
                >
                  {{ blogStore.tags.find(t => t.id === tagId)?.name }}
                  <button @click="toggleTag(tagId)" class="hover:text-retro-orange-dark">×</button>
                </span>
              </div>

              <div v-if="suggestedTags.length > 0" class="mb-3">
                <p class="font-retro-mono text-retro-xs text-retro-gray-medium mb-1">Suggested</p>
                <div class="flex flex-wrap gap-1">
                  <button
                    v-for="tag in suggestedTags"
                    :key="tag.id"
                    @click="toggleTag(tag.id)"
                    class="px-2 py-0.5 border border-retro-gray-light dark:border-retro-gray-darker font-retro-mono text-retro-xs text-retro-gray-dark dark:text-retro-gray-medium hover:border-retro-orange hover:text-retro-orange"
                  >
                    + {{ tag.name }}
                  </button>
                </div>
              </div>

              <div class="relative">
                <input
                  v-model="tagSearchQuery"
                  type="text"
                  placeholder="Search or add tags..."
                  class="w-full px-2 py-1 border-2 border-retro-gray-light dark:border-retro-gray-darker bg-white dark:bg-black font-retro-mono text-retro-sm text-retro-gray-darker dark:text-retro-cream placeholder:text-retro-gray-medium focus:outline-none focus:border-retro-orange"
                  @focus="showTagDropdown = true"
                  @blur="hideTagDropdown"
                  @keyup.enter="exactTagMatch ? null : createTag()"
                />
                <div
                  v-if="showTagDropdown && (filteredTags.length > 0 || (!exactTagMatch && tagSearchQuery.trim()))"
                  class="absolute z-50 w-full mt-1 bg-white dark:bg-black border-2 border-retro-gray-light dark:border-retro-gray-darker max-h-48 overflow-y-auto"
                >
                  <button
                    v-for="tag in filteredTags"
                    :key="tag.id"
                    @mousedown.prevent="selectTag(tag.id)"
                    class="w-full px-2 py-1 text-left font-retro-mono text-retro-sm text-retro-gray-darker dark:text-retro-cream hover:bg-retro-orange hover:text-white"
                  >
                    {{ tag.name }}
                  </button>
                  <button
                    v-if="!exactTagMatch && tagSearchQuery.trim()"
                    @mousedown.prevent="createTag"
                    class="w-full px-2 py-1 text-left font-retro-mono text-retro-sm text-retro-orange hover:bg-retro-orange hover:text-white border-t border-retro-gray-light dark:border-retro-gray-darker"
                  >
                    Create "{{ tagSearchQuery.trim() }}"
                  </button>
                </div>
              </div>
            </div>

            <div class="border-t border-retro-gray-light dark:border-retro-gray-darker"></div>

            <!-- Embed -->
            <div>
              <h3 class="font-retro-mono text-retro-xs text-retro-gray-medium uppercase tracking-wider mb-2">Embed</h3>

              <EmbedEditor
                v-if="showEmbedEditor"
                :embed="form.embed"
                :blog-id="blogId"
                @save="handleEmbedSave"
                @cancel="handleEmbedCancel"
                @use-title="handleUseTitle"
              />

              <div v-else>
                <button
                  v-if="!form.embed"
                  @click="showEmbedEditor = true"
                  class="w-full px-3 py-2 border-2 border-dashed border-retro-gray-light dark:border-retro-gray-darker font-retro-mono text-retro-sm text-retro-gray-medium hover:border-retro-orange hover:text-retro-orange flex items-center justify-center gap-2"
                >
                  <span class="relative -top-px">+</span> Add Embed
                </button>

                <div v-else>
                  <div v-if="form.embed.type === 'youtube'" class="p-2 border-2 border-retro-gray-light dark:border-retro-gray-darker">
                    <div class="flex items-center gap-2">
                      <span class="font-retro-mono text-retro-xs text-red-500">YT</span>
                      <span class="font-retro-sans text-retro-sm truncate text-retro-gray-darker dark:text-retro-cream">{{ form.embed.title || 'YouTube Video' }}</span>
                    </div>
                    <p class="font-retro-mono text-retro-xs text-retro-gray-medium mt-1">{{ form.embed.position === 'above' ? 'Above' : 'Below' }} content</p>
                  </div>

                  <div v-else-if="form.embed.type === 'link'" class="p-2 border-2 border-retro-gray-light dark:border-retro-gray-darker">
                    <div class="flex gap-2">
                      <img
                        v-if="form.embed.imageData || form.embed.imageFilename || (form.embed.imageUrl && !form.embed.imageUrl.startsWith('file://'))"
                        :src="form.embed.imageData || (form.embed.imageFilename ? `/uploads/${blogId}/${form.embed.imageFilename}` : form.embed.imageUrl)"
                        class="w-10 h-10 object-cover flex-shrink-0"
                        alt=""
                      />
                      <div class="flex-1 min-w-0">
                        <p class="font-retro-sans text-retro-sm truncate text-retro-gray-darker dark:text-retro-cream">{{ form.embed.title || 'Link' }}</p>
                        <p v-if="form.embed.description" class="font-retro-mono text-retro-xs text-retro-gray-medium truncate">{{ form.embed.description }}</p>
                      </div>
                    </div>
                    <p class="font-retro-mono text-retro-xs text-retro-gray-medium mt-2">{{ form.embed.position === 'above' ? 'Above' : 'Below' }} content</p>
                  </div>

                  <div v-else-if="form.embed.type === 'image'" class="p-2 border-2 border-retro-gray-light dark:border-retro-gray-darker">
                    <div class="flex gap-1 mb-2">
                      <img
                        v-for="(img, index) in form.embed.images?.slice(0, 4)"
                        :key="index"
                        :src="img.data || `/uploads/${blogId}/${img.filename}`"
                        class="w-10 h-10 object-cover"
                        alt=""
                      />
                      <div
                        v-if="form.embed.images?.length > 4"
                        class="w-10 h-10 border border-retro-gray-light dark:border-retro-gray-darker flex items-center justify-center font-retro-mono text-retro-xs text-retro-gray-medium"
                      >
                        +{{ form.embed.images.length - 4 }}
                      </div>
                    </div>
                    <p class="font-retro-mono text-retro-xs text-retro-gray-medium">{{ form.embed.images?.length || 0 }} image(s) - {{ form.embed.position === 'above' ? 'Above' : 'Below' }} content</p>
                  </div>

                  <div class="flex gap-2 mt-2">
                    <button
                      @click="showEmbedEditor = true"
                      class="flex-1 px-2 py-1 border-2 border-retro-gray-light dark:border-retro-gray-darker font-retro-mono text-retro-xs text-retro-gray-darker dark:text-retro-cream hover:border-retro-orange hover:text-retro-orange uppercase"
                    >
                      Edit
                    </button>
                    <button
                      @click="removeEmbed"
                      class="px-2 py-1 border-2 border-red-500 font-retro-mono text-retro-xs text-red-500 hover:bg-red-500 hover:text-white uppercase"
                    >
                      Remove
                    </button>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <!-- Delete Post (only for existing posts) -->
          <template v-if="!isNew">
            <div class="border-t border-retro-gray-light dark:border-retro-gray-darker mt-4"></div>
            <div class="mt-4">
              <button
                @click="showDeleteModal = true"
                class="w-full px-3 py-2 border-2 border-red-500 font-retro-mono text-retro-sm text-red-500 hover:bg-red-500 hover:text-white uppercase tracking-wider"
              >
                Delete Post
              </button>
            </div>
          </template>
        </div>
      </div>
    </div>

    <!-- Delete Confirmation Modal -->
    <div v-if="showDeleteModal" class="fixed inset-0 bg-black/90 flex items-center justify-center z-50 p-6">
      <div class="max-w-lg w-full">
        <p class="font-retro-serif text-3xl md:text-4xl font-bold text-white mb-6">
          Delete "{{ form.title || 'Untitled post' }}"?
        </p>
        <p class="font-retro-sans text-retro-base text-retro-gray-medium mb-8">
          This cannot be undone.
        </p>
        <div class="flex gap-6">
          <button
            @click="showDeleteModal = false"
            class="font-retro-mono text-retro-sm text-retro-gray-light hover:text-white uppercase tracking-wider"
          >
            Cancel
          </button>
          <button
            @click="deletePost"
            class="font-retro-mono text-retro-sm text-red-500 hover:text-red-400 uppercase tracking-wider"
          >
            Delete
          </button>
        </div>
      </div>
    </div>

    <!-- Publish Modal -->
    <PublishModal
      v-if="showPublishModal"
      :blog-id="blogId"
      :show="showPublishModal"
      :auto-publish="true"
      @close="handlePublishModalClose"
    />
  </div>
</template>
