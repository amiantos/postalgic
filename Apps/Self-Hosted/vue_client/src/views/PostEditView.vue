<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useBlogStore } from '@/stores/blog';
import EmbedEditor from '@/components/EmbedEditor.vue';

const route = useRoute();
const router = useRouter();
const blogStore = useBlogStore();

const blogId = computed(() => route.params.blogId);
const postId = computed(() => route.params.postId);
const isNew = computed(() => !postId.value);

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
const showTagDropdown = ref(false);
const showEmbedEditor = ref(false);

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
  }
});

async function savePost() {
  if (!form.value.content.trim()) {
    error.value = 'Post content is required';
    return;
  }

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
    router.push({ name: 'blog-posts', params: { blogId: blogId.value } });
  } catch (e) {
    error.value = e.message;
  } finally {
    saving.value = false;
  }
}

async function publishPost() {
  form.value.isDraft = false;
  await savePost();
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
</script>

<template>
  <div class="p-6 max-w-4xl mx-auto">
    <!-- Header -->
    <div class="flex items-center justify-between mb-6">
      <div class="flex items-center gap-4">
        <router-link
          :to="{ name: 'blog-posts', params: { blogId } }"
          class="text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-300"
        >
          <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
          </svg>
        </router-link>
        <h2 class="text-xl font-bold text-gray-900 dark:text-gray-100">
          {{ isNew ? 'New Post' : 'Edit Post' }}
        </h2>
      </div>
      <div class="flex items-center gap-2">
        <button
          @click="savePost"
          :disabled="saving"
          class="px-4 py-2 bg-gray-100 dark:bg-gray-700 text-gray-700 dark:text-gray-300 rounded-lg hover:bg-gray-200 dark:hover:bg-gray-600 transition-colors disabled:opacity-50"
        >
          {{ saving ? 'Saving...' : 'Save Draft' }}
        </button>
        <button
          @click="publishPost"
          :disabled="saving"
          class="px-4 py-2 bg-primary-600 text-white rounded-lg hover:bg-primary-700 transition-colors disabled:opacity-50"
        >
          Publish
        </button>
      </div>
    </div>

    <!-- Error -->
    <div v-if="error" class="mb-6 p-4 bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded-lg text-red-800 dark:text-red-400">
      {{ error }}
    </div>

    <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
      <!-- Main Content -->
      <div class="lg:col-span-2 space-y-6">
        <!-- Title -->
        <div>
          <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">Title</label>
          <input
            v-model="form.title"
            type="text"
            class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100 focus:ring-2 focus:ring-primary-500 focus:border-primary-500"
            placeholder="Post title (optional)"
          />
        </div>

        <!-- Content -->
        <div>
          <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
            Content <span class="text-red-500">*</span>
          </label>
          <textarea
            v-model="form.content"
            rows="20"
            class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100 focus:ring-2 focus:ring-primary-500 focus:border-primary-500 font-mono text-sm"
            placeholder="Write your post content in Markdown..."
          ></textarea>
          <p class="mt-1 text-sm text-gray-500 dark:text-gray-400">Supports Markdown formatting</p>
        </div>
      </div>

      <!-- Sidebar -->
      <div class="space-y-6">
        <!-- Status -->
        <div class="bg-white dark:bg-gray-800 rounded-lg border border-gray-200 dark:border-gray-700 p-4">
          <h3 class="font-medium text-gray-900 dark:text-gray-100 mb-3">Status</h3>
          <label class="flex items-center gap-2">
            <input
              type="checkbox"
              v-model="form.isDraft"
              class="rounded border-gray-300 dark:border-gray-600 text-primary-600 focus:ring-primary-500"
            />
            <span class="text-sm text-gray-700 dark:text-gray-300">Save as draft</span>
          </label>
        </div>

        <!-- Date -->
        <div class="bg-white dark:bg-gray-800 rounded-lg border border-gray-200 dark:border-gray-700 p-4">
          <h3 class="font-medium text-gray-900 dark:text-gray-100 mb-3">Publish Date</h3>
          <input
            v-model="form.createdAt"
            type="datetime-local"
            class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100 focus:ring-2 focus:ring-primary-500 focus:border-primary-500 text-sm"
          />
        </div>

        <!-- Category -->
        <div class="bg-white dark:bg-gray-800 rounded-lg border border-gray-200 dark:border-gray-700 p-4">
          <h3 class="font-medium text-gray-900 dark:text-gray-100 mb-3">Category</h3>
          <select
            v-model="form.categoryId"
            class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100 focus:ring-2 focus:ring-primary-500 focus:border-primary-500 text-sm"
          >
            <option :value="null">No category</option>
            <option v-for="category in blogStore.categories" :key="category.id" :value="category.id">
              {{ category.name }}
            </option>
          </select>
        </div>

        <!-- Tags -->
        <div class="bg-white dark:bg-gray-800 rounded-lg border border-gray-200 dark:border-gray-700 p-4">
          <h3 class="font-medium text-gray-900 dark:text-gray-100 mb-3">Tags</h3>

          <!-- Selected Tags -->
          <div v-if="form.tagIds.length > 0" class="flex flex-wrap gap-2 mb-3">
            <span
              v-for="tagId in form.tagIds"
              :key="tagId"
              class="px-2 py-1 bg-primary-100 dark:bg-primary-900/30 text-primary-700 dark:text-primary-300 text-xs rounded-full flex items-center gap-1"
            >
              {{ blogStore.tags.find(t => t.id === tagId)?.name }}
              <button @click="toggleTag(tagId)" class="hover:text-primary-900 dark:hover:text-primary-100">×</button>
            </span>
          </div>

          <!-- Suggested Tags (based on content) -->
          <div v-if="suggestedTags.length > 0" class="mb-3">
            <p class="text-xs text-gray-500 dark:text-gray-400 mb-1">Suggested</p>
            <div class="flex flex-wrap gap-1">
              <button
                v-for="tag in suggestedTags"
                :key="tag.id"
                @click="toggleTag(tag.id)"
                class="px-2 py-1 bg-gray-100 dark:bg-gray-700 text-gray-600 dark:text-gray-400 text-xs rounded-full hover:bg-gray-200 dark:hover:bg-gray-600"
              >
                + {{ tag.name }}
              </button>
            </div>
          </div>

          <!-- Search/Add Tags -->
          <div class="relative">
            <input
              v-model="tagSearchQuery"
              type="text"
              placeholder="Search or add tags..."
              class="w-full px-3 py-1.5 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100 focus:ring-2 focus:ring-primary-500 focus:border-primary-500 text-sm"
              @focus="showTagDropdown = true"
              @blur="hideTagDropdown"
              @keyup.enter="exactTagMatch ? null : createTag()"
            />
            <!-- Dropdown -->
            <div
              v-if="showTagDropdown && (filteredTags.length > 0 || (!exactTagMatch && tagSearchQuery.trim()))"
              class="absolute z-10 w-full mt-1 bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-lg shadow-lg max-h-48 overflow-y-auto"
            >
              <!-- Matching tags -->
              <button
                v-for="tag in filteredTags"
                :key="tag.id"
                @mousedown.prevent="selectTag(tag.id)"
                class="w-full px-3 py-2 text-left text-sm text-gray-700 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-700"
              >
                {{ tag.name }}
              </button>
              <!-- Create new tag option -->
              <button
                v-if="!exactTagMatch && tagSearchQuery.trim()"
                @mousedown.prevent="createTag"
                class="w-full px-3 py-2 text-left text-sm text-primary-600 dark:text-primary-400 hover:bg-gray-100 dark:hover:bg-gray-700 border-t border-gray-200 dark:border-gray-700"
              >
                Create "{{ tagSearchQuery.trim() }}"
              </button>
            </div>
          </div>
        </div>

        <!-- Embed -->
        <div class="bg-white dark:bg-gray-800 rounded-lg border border-gray-200 dark:border-gray-700 p-4">
          <h3 class="font-medium text-gray-900 dark:text-gray-100 mb-3">Embed</h3>

          <!-- Embed Editor -->
          <EmbedEditor
            v-if="showEmbedEditor"
            :embed="form.embed"
            :blog-id="blogId"
            @save="handleEmbedSave"
            @cancel="handleEmbedCancel"
            @use-title="handleUseTitle"
          />

          <!-- Embed Preview / Add Button -->
          <div v-else>
            <!-- No Embed -->
            <button
              v-if="!form.embed"
              @click="showEmbedEditor = true"
              class="w-full px-4 py-3 border-2 border-dashed border-gray-300 dark:border-gray-600 rounded-lg text-gray-500 dark:text-gray-400 hover:border-primary-500 hover:text-primary-600 dark:hover:text-primary-400 transition-colors text-sm flex items-center justify-center gap-2"
            >
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.172 7l-6.586 6.586a2 2 0 102.828 2.828l6.414-6.586a4 4 0 00-5.656-5.656l-6.415 6.585a6 6 0 108.486 8.486L20.5 13" />
              </svg>
              Add Embed
            </button>

            <!-- Has Embed - Show Preview -->
            <div v-else>
              <!-- YouTube Preview -->
              <div v-if="form.embed.type === 'youtube'" class="p-3 bg-gray-50 dark:bg-gray-700 rounded-lg">
                <div class="flex items-center gap-2 text-sm">
                  <svg class="w-5 h-5 text-red-500" fill="currentColor" viewBox="0 0 24 24">
                    <path d="M23.498 6.186a3.016 3.016 0 0 0-2.122-2.136C19.505 3.545 12 3.545 12 3.545s-7.505 0-9.377.505A3.017 3.017 0 0 0 .502 6.186C0 8.07 0 12 0 12s0 3.93.502 5.814a3.016 3.016 0 0 0 2.122 2.136c1.871.505 9.376.505 9.376.505s7.505 0 9.377-.505a3.015 3.015 0 0 0 2.122-2.136C24 15.93 24 12 24 12s0-3.93-.502-5.814zM9.545 15.568V8.432L15.818 12l-6.273 3.568z"/>
                  </svg>
                  <span class="font-medium truncate text-gray-900 dark:text-gray-100">{{ form.embed.title || 'YouTube Video' }}</span>
                </div>
                <p class="text-xs text-gray-500 dark:text-gray-400 mt-1">Position: {{ form.embed.position === 'above' ? 'Above' : 'Below' }} content</p>
              </div>

              <!-- Link Preview -->
              <div v-else-if="form.embed.type === 'link'" class="p-3 bg-gray-50 dark:bg-gray-700 rounded-lg">
                <div class="flex gap-2">
                  <img
                    v-if="form.embed.imageData || form.embed.imageFilename || (form.embed.imageUrl && !form.embed.imageUrl.startsWith('file://'))"
                    :src="form.embed.imageData || (form.embed.imageFilename ? `/uploads/${blogId}/${form.embed.imageFilename}` : form.embed.imageUrl)"
                    class="w-12 h-12 object-cover rounded"
                    alt=""
                  />
                  <div class="flex-1 min-w-0">
                    <p class="text-sm font-medium truncate text-gray-900 dark:text-gray-100">{{ form.embed.title || 'Link' }}</p>
                    <p v-if="form.embed.description" class="text-xs text-gray-500 dark:text-gray-400 truncate">{{ form.embed.description }}</p>
                  </div>
                </div>
                <p class="text-xs text-gray-500 dark:text-gray-400 mt-2">Position: {{ form.embed.position === 'above' ? 'Above' : 'Below' }} content</p>
              </div>

              <!-- Image Preview -->
              <div v-else-if="form.embed.type === 'image'" class="p-3 bg-gray-50 dark:bg-gray-700 rounded-lg">
                <div class="flex gap-1 mb-2">
                  <img
                    v-for="(img, index) in form.embed.images?.slice(0, 4)"
                    :key="index"
                    :src="img.data"
                    class="w-12 h-12 object-cover rounded"
                    alt=""
                  />
                  <div
                    v-if="form.embed.images?.length > 4"
                    class="w-12 h-12 bg-gray-200 dark:bg-gray-600 rounded flex items-center justify-center text-xs text-gray-600 dark:text-gray-400"
                  >
                    +{{ form.embed.images.length - 4 }}
                  </div>
                </div>
                <p class="text-xs text-gray-500 dark:text-gray-400">{{ form.embed.images?.length || 0 }} image(s) - Position: {{ form.embed.position === 'above' ? 'Above' : 'Below' }} content</p>
              </div>

              <!-- Edit / Remove Buttons -->
              <div class="flex gap-2 mt-3">
                <button
                  @click="showEmbedEditor = true"
                  class="flex-1 px-3 py-1.5 bg-gray-100 dark:bg-gray-700 text-gray-700 dark:text-gray-300 rounded-lg hover:bg-gray-200 dark:hover:bg-gray-600 text-sm"
                >
                  Edit
                </button>
                <button
                  @click="removeEmbed"
                  class="px-3 py-1.5 text-red-600 dark:text-red-400 hover:bg-red-50 dark:hover:bg-red-900/20 rounded-lg text-sm"
                >
                  Remove
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
