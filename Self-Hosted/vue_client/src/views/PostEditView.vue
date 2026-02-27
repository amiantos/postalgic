<script setup>
import { ref, computed, onMounted, onBeforeUnmount, watch } from 'vue';
import { useRoute, useRouter, onBeforeRouteLeave } from 'vue-router';
import { useBlogStore } from '@/stores/blog';
import EmbedEditor from '@/components/EmbedEditor.vue';
import EmbedPreview from '@/components/EmbedPreview.vue';
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
    const hasEmbedBelow = embedPosition.value === 'below' && (showEmbedEditor.value || form.value.embed);
    const minH = hasEmbedBelow ? 100 : 400;
    textarea.style.height = 'auto';
    textarea.style.height = Math.max(minH, textarea.scrollHeight) + 'px';
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
const embedPosition = computed(() => form.value.embed?.position ?? 'below');

function addEmbedAt(position) {
  if (form.value.embed) {
    form.value.embed.position = position;
  }
  editingEmbedPosition.value = position;
  showEmbedEditor.value = true;
}

const editingEmbedPosition = ref('below');

function handleEmbedSave(embedData) {
  embedData.position = editingEmbedPosition.value;
  form.value.embed = embedData;
  showEmbedEditor.value = false;
}

function moveEmbed() {
  if (form.value.embed) {
    form.value.embed.position = form.value.embed.position === 'above' ? 'below' : 'above';
  }
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
  <div class="min-h-screen bg-site-bg overflow-x-hidden lg:pr-[calc(16rem+28px)]">
    <!-- Max-width content wrapper for desktop -->
    <div class="lg:max-w-[600px] lg:mx-auto">

    <!-- Navigation bar -->
    <nav class="flex items-center justify-between px-6 py-4 lg:px-0">
      <router-link
        :to="{ name: 'blog-posts', params: { blogId } }"
        class="px-4 py-2 border border-site-light text-site-dark font-semibold rounded-full hover:border-site-accent hover:text-site-accent transition-colors text-sm"
      >
        &lt; {{ blogStore.currentBlog?.name || 'Posts' }}
      </router-link>

      <div class="flex items-center gap-4">
        <!-- Action buttons (mobile only) -->
        <button
          @click="saveDraft"
          :disabled="saving"
          class="lg:hidden text-sm text-site-dark font-semibold hover:text-site-accent transition-colors disabled:opacity-50"
        >
          {{ saving ? 'Saving...' : 'Save Draft' }}
        </button>
        <button
          @click="publishPost"
          :disabled="saving"
          class="lg:hidden text-sm text-site-accent font-semibold hover:text-[#e89200] transition-colors disabled:opacity-50"
        >
          Publish
        </button>
        <!-- Settings toggle (mobile only) -->
        <button
          @click="mobileSidebarOpen = true"
          class="lg:hidden text-sm text-site-dark font-semibold hover:text-site-accent transition-colors"
        >
          Settings
        </button>
      </div>
    </nav>

    <!-- Error -->
    <div v-if="error" class="mx-6 lg:mx-0 mt-6 p-4 border border-red-300 rounded-lg bg-red-50 text-sm text-red-600">
      {{ error }}
    </div>

    <!-- Editor Area -->
    <main class="px-6 lg:px-0 py-6">
      <!-- Title -->
      <div class="pb-4">
        <input
          v-model="form.title"
          type="text"
          class="w-full text-3xl md:text-4xl font-bold bg-transparent border-none outline-none text-site-text placeholder:text-site-medium"
          style="font-family: system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;"
          placeholder="Post title..."
        />
      </div>

      <!-- Embed Above Slot -->
      <div v-if="showEmbedEditor && editingEmbedPosition === 'above'" class="mb-6 border-2 border-dashed border-site-light rounded-xl p-4">
        <EmbedEditor
          :embed="form.embed"
          :blog-id="blogId"
          @save="handleEmbedSave"
          @cancel="handleEmbedCancel"
          @use-title="handleUseTitle"
        />
      </div>
      <div v-else-if="form.embed && embedPosition === 'above'" class="mb-6 group relative">
        <EmbedPreview :embed="form.embed" :blog-id="blogId" />
        <div class="absolute top-2 right-2 flex gap-2 opacity-0 group-hover:opacity-100 transition-opacity">
          <button
            @click="addEmbedAt('above')"
            class="px-3 py-1 bg-white/90 border border-site-light text-xs text-site-dark rounded-full hover:border-site-accent hover:text-site-accent transition-colors shadow-sm"
          >
            Edit
          </button>
          <button
            @click="moveEmbed"
            class="px-3 py-1 bg-white/90 border border-site-light text-xs text-site-dark rounded-full hover:border-site-accent hover:text-site-accent transition-colors shadow-sm"
          >
            Move Below
          </button>
          <button
            @click="removeEmbed"
            class="px-3 py-1 bg-red-500/90 text-xs text-white rounded-full hover:bg-red-600 transition-colors shadow-sm"
          >
            Remove
          </button>
        </div>
      </div>
      <div v-else-if="!form.embed && !showEmbedEditor" class="mb-6">
        <button
          @click="addEmbedAt('above')"
          class="w-full py-3 border-2 border-dashed border-site-light text-sm text-site-medium rounded-xl hover:border-site-accent hover:text-site-accent transition-colors flex items-center justify-center gap-1"
        >
          + Add Embed Above
        </button>
      </div>

      <!-- Content -->
      <div>
        <textarea
          ref="contentTextarea"
          v-model="form.content"
          @input="autoResize"
          :class="[
            'w-full bg-transparent border-none outline-none resize-none text-site-text placeholder:text-site-medium',
            (embedPosition === 'below' && (showEmbedEditor || form.embed)) ? 'min-h-[100px]' : 'min-h-[400px]'
          ]"
          style="font-family: system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif; font-size: 1.15rem; line-height: 1.8;"
          placeholder="Write your post content in Markdown..."
        ></textarea>
      </div>

      <!-- Embed Below Slot -->
      <div v-if="showEmbedEditor && editingEmbedPosition === 'below'" class="mt-2 border-2 border-dashed border-site-light rounded-xl p-4">
        <EmbedEditor
          :embed="form.embed"
          :blog-id="blogId"
          @save="handleEmbedSave"
          @cancel="handleEmbedCancel"
          @use-title="handleUseTitle"
        />
      </div>
      <div v-else-if="form.embed && embedPosition === 'below'" class="mt-2 group relative">
        <EmbedPreview :embed="form.embed" :blog-id="blogId" />
        <div class="absolute top-2 right-2 flex gap-2 opacity-0 group-hover:opacity-100 transition-opacity">
          <button
            @click="addEmbedAt('below')"
            class="px-3 py-1 bg-white/90 border border-site-light text-xs text-site-dark rounded-full hover:border-site-accent hover:text-site-accent transition-colors shadow-sm"
          >
            Edit
          </button>
          <button
            @click="moveEmbed"
            class="px-3 py-1 bg-white/90 border border-site-light text-xs text-site-dark rounded-full hover:border-site-accent hover:text-site-accent transition-colors shadow-sm"
          >
            Move Above
          </button>
          <button
            @click="removeEmbed"
            class="px-3 py-1 bg-red-500/90 text-xs text-white rounded-full hover:bg-red-600 transition-colors shadow-sm"
          >
            Remove
          </button>
        </div>
      </div>
      <div v-else-if="!form.embed && !showEmbedEditor" class="mt-2">
        <button
          @click="addEmbedAt('below')"
          class="w-full py-3 border-2 border-dashed border-site-light text-sm text-site-medium rounded-xl hover:border-site-accent hover:text-site-accent transition-colors flex items-center justify-center gap-1"
        >
          + Add Embed Below
        </button>
      </div>
    </main>

    </div><!-- End max-width wrapper -->

    <!-- Desktop Sidebar (always visible on lg+) -->
    <aside class="hidden lg:flex lg:flex-row w-[calc(16rem+28px)] bg-site-bg fixed top-0 right-0 h-screen z-30">
      <div class="wavy-separator-vertical flex-shrink-0"></div>
      <div class="flex-1 overflow-y-auto overflow-x-hidden p-4">
        <!-- Header -->
        <h3 class="text-sm text-site-dark font-semibold uppercase tracking-wide mb-4">Settings</h3>

        <!-- Action Buttons -->
        <div class="flex flex-col gap-2 mb-4">
          <button
            @click="saveDraft"
            :disabled="saving"
            class="w-full px-4 py-2 border border-site-light text-site-dark font-semibold rounded-full hover:border-site-accent hover:text-site-accent transition-colors text-sm disabled:opacity-50"
          >
            {{ saving ? 'Saving...' : 'Save Draft' }}
          </button>
          <button
            @click="publishPost"
            :disabled="saving"
            class="w-full px-4 py-2 bg-site-accent text-white font-semibold rounded-full hover:bg-[#e89200] transition-colors text-sm disabled:opacity-50"
          >
            Publish
          </button>
        </div>

        <div class="border-t border-site-light mb-4"></div>

        <!-- Settings Content -->
        <div class="space-y-4">
          <!-- Status -->
          <div>
            <h3 class="text-xs font-semibold text-site-medium uppercase tracking-wide mb-2">Status</h3>
            <label class="flex items-center gap-2">
              <input
                type="checkbox"
                v-model="form.isDraft"
                class="border-site-light"
              />
              <span class="text-sm text-site-dark">Save as draft</span>
            </label>
          </div>

          <div class="border-t border-site-light"></div>

          <!-- Date -->
          <div>
            <h3 class="text-xs font-semibold text-site-medium uppercase tracking-wide mb-2">Publish Date</h3>
            <input
              v-model="form.createdAt"
              type="datetime-local"
              class="w-full px-2 py-1 border border-site-light rounded-lg bg-white text-sm text-site-dark focus:outline-none focus:border-site-accent transition-colors"
            />
          </div>

          <!-- Category -->
          <template v-if="blogStore.categories.length > 0">
            <div class="border-t border-site-light"></div>

            <div>
              <h3 class="text-xs font-semibold text-site-medium uppercase tracking-wide mb-2">Category</h3>
              <select
                v-model="form.categoryId"
                class="w-full px-2 py-1 border border-site-light rounded-lg bg-white text-sm text-site-dark focus:outline-none focus:border-site-accent transition-colors"
              >
                <option :value="null">No category</option>
                <option v-for="category in blogStore.categories" :key="category.id" :value="category.id">
                  {{ category.name }}
                </option>
              </select>
            </div>
          </template>

          <div class="border-t border-site-light"></div>

          <!-- Tags -->
          <div>
            <h3 class="text-xs font-semibold text-site-medium uppercase tracking-wide mb-2">Tags</h3>

            <div v-if="form.tagIds.length > 0" class="flex flex-wrap gap-1.5 mb-3">
              <span
                v-for="tagId in form.tagIds"
                :key="tagId"
                class="px-2 py-0.5 bg-site-accent text-white text-xs rounded-full flex items-center gap-1"
              >
                {{ blogStore.tags.find(t => t.id === tagId)?.name }}
                <button @click="toggleTag(tagId)" class="hover:text-[#e89200]">×</button>
              </span>
            </div>

            <div v-if="suggestedTags.length > 0" class="mb-3">
              <p class="text-xs font-semibold text-site-medium mb-1">Suggested</p>
              <div class="flex flex-wrap gap-1">
                <button
                  v-for="tag in suggestedTags"
                  :key="tag.id"
                  @click="toggleTag(tag.id)"
                  class="px-2 py-0.5 border border-site-light text-xs text-site-dark rounded-full hover:border-site-accent hover:text-site-accent transition-colors"
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
                class="w-full px-2 py-1 border border-site-light rounded-lg bg-white text-sm text-site-dark placeholder:text-site-medium focus:outline-none focus:border-site-accent transition-colors"
                @focus="showTagDropdown = true"
                @blur="hideTagDropdown"
                @keyup.enter="exactTagMatch ? null : createTag()"
              />
              <div
                v-if="showTagDropdown && (filteredTags.length > 0 || (!exactTagMatch && tagSearchQuery.trim()))"
                class="absolute z-50 w-full mt-1 bg-white border border-site-light rounded-lg max-h-48 overflow-y-auto"
              >
                <button
                  v-for="tag in filteredTags"
                  :key="tag.id"
                  @mousedown.prevent="selectTag(tag.id)"
                  class="w-full px-2 py-1 text-left text-sm text-site-dark hover:bg-site-accent hover:text-white"
                >
                  {{ tag.name }}
                </button>
                <button
                  v-if="!exactTagMatch && tagSearchQuery.trim()"
                  @mousedown.prevent="createTag"
                  class="w-full px-2 py-1 text-left text-sm text-site-accent hover:bg-site-accent hover:text-white border-t border-site-light"
                >
                  Create "{{ tagSearchQuery.trim() }}"
                </button>
              </div>
            </div>
          </div>

          <!-- Delete Post (only for existing posts) -->
          <template v-if="!isNew">
            <div class="border-t border-site-light"></div>
            <div>
              <button
                @click="showDeleteModal = true"
                class="w-full px-4 py-2 bg-red-500 text-white font-semibold rounded-full hover:bg-red-600 transition-colors text-sm"
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
        class="absolute right-0 top-0 bottom-0 w-80 bg-site-bg border-l border-site-light overflow-y-auto"
        @click.stop
      >
        <div class="p-4">
          <!-- Header -->
          <div class="flex items-center justify-between mb-4">
            <h3 class="text-sm text-site-dark font-semibold uppercase tracking-wide">Settings</h3>
            <button
              @click="mobileSidebarOpen = false"
              class="text-sm text-site-dark hover:text-site-accent transition-colors"
            >
              <span class="relative -top-px">×</span>
            </button>
          </div>

          <!-- Settings Content (same as desktop) -->
          <div class="space-y-4">
            <!-- Status -->
            <div>
              <h3 class="text-xs font-semibold text-site-medium uppercase tracking-wide mb-2">Status</h3>
              <label class="flex items-center gap-2">
                <input
                  type="checkbox"
                  v-model="form.isDraft"
                  class="border-site-light"
                />
                <span class="text-sm text-site-dark">Save as draft</span>
              </label>
            </div>

            <div class="border-t border-site-light"></div>

            <!-- Date -->
            <div>
              <h3 class="text-xs font-semibold text-site-medium uppercase tracking-wide mb-2">Publish Date</h3>
              <input
                v-model="form.createdAt"
                type="datetime-local"
                class="w-full px-2 py-1 border border-site-light rounded-lg bg-white text-sm text-site-dark focus:outline-none focus:border-site-accent transition-colors"
              />
            </div>

            <!-- Category -->
            <template v-if="blogStore.categories.length > 0">
              <div class="border-t border-site-light"></div>

              <div>
                <h3 class="text-xs font-semibold text-site-medium uppercase tracking-wide mb-2">Category</h3>
                <select
                  v-model="form.categoryId"
                  class="w-full px-2 py-1 border border-site-light rounded-lg bg-white text-sm text-site-dark focus:outline-none focus:border-site-accent transition-colors"
                >
                  <option :value="null">No category</option>
                  <option v-for="category in blogStore.categories" :key="category.id" :value="category.id">
                    {{ category.name }}
                  </option>
                </select>
              </div>
            </template>

            <div class="border-t border-site-light"></div>

            <!-- Tags -->
            <div>
              <h3 class="text-xs font-semibold text-site-medium uppercase tracking-wide mb-2">Tags</h3>

              <div v-if="form.tagIds.length > 0" class="flex flex-wrap gap-1.5 mb-3">
                <span
                  v-for="tagId in form.tagIds"
                  :key="tagId"
                  class="px-2 py-0.5 bg-site-accent text-white text-xs rounded-full flex items-center gap-1"
                >
                  {{ blogStore.tags.find(t => t.id === tagId)?.name }}
                  <button @click="toggleTag(tagId)" class="hover:text-[#e89200]">×</button>
                </span>
              </div>

              <div v-if="suggestedTags.length > 0" class="mb-3">
                <p class="text-xs font-semibold text-site-medium mb-1">Suggested</p>
                <div class="flex flex-wrap gap-1">
                  <button
                    v-for="tag in suggestedTags"
                    :key="tag.id"
                    @click="toggleTag(tag.id)"
                    class="px-2 py-0.5 border border-site-light text-xs text-site-dark rounded-full hover:border-site-accent hover:text-site-accent transition-colors"
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
                  class="w-full px-2 py-1 border border-site-light rounded-lg bg-white text-sm text-site-dark placeholder:text-site-medium focus:outline-none focus:border-site-accent transition-colors"
                  @focus="showTagDropdown = true"
                  @blur="hideTagDropdown"
                  @keyup.enter="exactTagMatch ? null : createTag()"
                />
                <div
                  v-if="showTagDropdown && (filteredTags.length > 0 || (!exactTagMatch && tagSearchQuery.trim()))"
                  class="absolute z-50 w-full mt-1 bg-white border border-site-light rounded-lg max-h-48 overflow-y-auto"
                >
                  <button
                    v-for="tag in filteredTags"
                    :key="tag.id"
                    @mousedown.prevent="selectTag(tag.id)"
                    class="w-full px-2 py-1 text-left text-sm text-site-dark hover:bg-site-accent hover:text-white"
                  >
                    {{ tag.name }}
                  </button>
                  <button
                    v-if="!exactTagMatch && tagSearchQuery.trim()"
                    @mousedown.prevent="createTag"
                    class="w-full px-2 py-1 text-left text-sm text-site-accent hover:bg-site-accent hover:text-white border-t border-site-light"
                  >
                    Create "{{ tagSearchQuery.trim() }}"
                  </button>
                </div>
              </div>
            </div>

          </div>

          <!-- Delete Post (only for existing posts) -->
          <template v-if="!isNew">
            <div class="border-t border-site-light mt-4"></div>
            <div class="mt-4">
              <button
                @click="showDeleteModal = true"
                class="w-full px-4 py-2 bg-red-500 text-white font-semibold rounded-full hover:bg-red-600 transition-colors text-sm"
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
        <p class="text-3xl md:text-4xl font-bold text-white mb-6">
          Delete "{{ form.title || 'Untitled post' }}"?
        </p>
        <p class="text-base text-site-medium mb-8">
          This cannot be undone.
        </p>
        <div class="flex gap-4">
          <button
            @click="showDeleteModal = false"
            class="px-4 py-2 border border-white/30 text-white font-semibold rounded-full hover:border-white hover:text-white transition-colors text-sm"
          >
            Cancel
          </button>
          <button
            @click="deletePost"
            class="px-4 py-2 bg-red-500 text-white font-semibold rounded-full hover:bg-red-600 transition-colors text-sm"
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
