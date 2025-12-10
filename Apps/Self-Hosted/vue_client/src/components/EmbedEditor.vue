<script setup>
import { ref, computed, watch, onMounted } from 'vue';
import { metadataApi } from '@/api';

const props = defineProps({
  embed: {
    type: Object,
    default: null
  },
  blogId: {
    type: String,
    required: true
  }
});

const emit = defineEmits(['save', 'cancel', 'use-title']);

// Form state
const embedType = ref('youtube');
const url = ref('');
const position = ref('below');
const isLoading = ref(false);
const error = ref(null);

// Metadata state
const metadata = ref({
  title: null,
  description: null,
  imageUrl: null,
  imageData: null,
  videoId: null
});

// Image embed state
const images = ref([]);
const imageInput = ref(null);

// Initialize from existing embed
onMounted(() => {
  if (props.embed) {
    embedType.value = props.embed.type || 'youtube';
    url.value = props.embed.url || '';
    position.value = props.embed.position || 'below';

    if (props.embed.type === 'youtube') {
      metadata.value = {
        title: props.embed.title || null,
        videoId: props.embed.videoId || null
      };
    } else if (props.embed.type === 'link') {
      metadata.value = {
        title: props.embed.title || null,
        description: props.embed.description || null,
        imageUrl: props.embed.imageUrl || null,
        imageData: props.embed.imageData || null
      };
    } else if (props.embed.type === 'image') {
      images.value = props.embed.images || [];
    }
  }
});

// Computed
const canSave = computed(() => {
  if (embedType.value === 'image') {
    return images.value.length > 0;
  }
  return url.value.trim().length > 0;
});

const hasMetadata = computed(() => {
  if (embedType.value === 'youtube') {
    return metadata.value.title || metadata.value.videoId;
  }
  if (embedType.value === 'link') {
    return metadata.value.title || metadata.value.description || metadata.value.imageUrl;
  }
  return false;
});

// Watch for type changes to reset state
watch(embedType, () => {
  error.value = null;
  if (embedType.value !== 'image') {
    images.value = [];
  }
});

// Methods
async function fetchMetadata() {
  if (!url.value.trim()) {
    error.value = 'Please enter a URL';
    return;
  }

  isLoading.value = true;
  error.value = null;

  try {
    const result = await metadataApi.fetch(url.value);

    if (result.type === 'youtube') {
      embedType.value = 'youtube';
      metadata.value = {
        title: result.title,
        videoId: result.videoId
      };
    } else {
      metadata.value = {
        title: result.title,
        description: result.description,
        imageUrl: result.imageUrl,
        imageData: result.imageData
      };
    }

    if (!result.title && !result.description && !result.imageUrl && !result.videoId) {
      error.value = 'Could not fetch metadata for this URL';
    }
  } catch (e) {
    error.value = e.message || 'Failed to fetch metadata';
  } finally {
    isLoading.value = false;
  }
}

function handleImageSelect(event) {
  const files = event.target.files;
  if (!files) return;

  for (const file of files) {
    if (!file.type.startsWith('image/')) continue;

    const reader = new FileReader();
    reader.onload = (e) => {
      images.value.push({
        id: Date.now() + Math.random().toString(36).substring(2),
        filename: file.name,
        data: e.target.result,
        order: images.value.length
      });
    };
    reader.readAsDataURL(file);
  }

  // Reset input
  if (imageInput.value) {
    imageInput.value.value = '';
  }
}

function removeImage(index) {
  images.value.splice(index, 1);
  // Update order
  images.value.forEach((img, i) => {
    img.order = i;
  });
}

function moveImage(index, direction) {
  const newIndex = index + direction;
  if (newIndex < 0 || newIndex >= images.value.length) return;

  const temp = images.value[index];
  images.value[index] = images.value[newIndex];
  images.value[newIndex] = temp;

  // Update order
  images.value.forEach((img, i) => {
    img.order = i;
  });
}

function useAsPostTitle() {
  if (metadata.value.title) {
    emit('use-title', metadata.value.title);
  }
}

function save() {
  const embedData = {
    type: embedType.value,
    position: position.value
  };

  if (embedType.value === 'youtube') {
    embedData.url = url.value;
    embedData.title = metadata.value.title;
    embedData.videoId = metadata.value.videoId;
  } else if (embedType.value === 'link') {
    embedData.url = url.value;
    embedData.title = metadata.value.title;
    embedData.description = metadata.value.description;
    embedData.imageUrl = metadata.value.imageUrl;
    embedData.imageData = metadata.value.imageData;
  } else if (embedType.value === 'image') {
    embedData.images = images.value;
  }

  emit('save', embedData);
}

function cancel() {
  emit('cancel');
}
</script>

<template>
  <div class="bg-white rounded-lg border border-gray-200 p-4">
    <h3 class="font-medium text-gray-900 mb-4">
      {{ embed ? 'Edit Embed' : 'Add Embed' }}
    </h3>

    <!-- Embed Type Selector -->
    <div class="mb-4">
      <label class="block text-sm font-medium text-gray-700 mb-2">Type</label>
      <div class="flex gap-2">
        <button
          @click="embedType = 'youtube'"
          :class="[
            'px-3 py-1.5 text-sm rounded-lg transition-colors',
            embedType === 'youtube'
              ? 'bg-primary-600 text-white'
              : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
          ]"
        >
          YouTube
        </button>
        <button
          @click="embedType = 'link'"
          :class="[
            'px-3 py-1.5 text-sm rounded-lg transition-colors',
            embedType === 'link'
              ? 'bg-primary-600 text-white'
              : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
          ]"
        >
          Link
        </button>
        <button
          @click="embedType = 'image'"
          :class="[
            'px-3 py-1.5 text-sm rounded-lg transition-colors',
            embedType === 'image'
              ? 'bg-primary-600 text-white'
              : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
          ]"
        >
          Images
        </button>
      </div>
    </div>

    <!-- URL Input (for YouTube and Link) -->
    <div v-if="embedType !== 'image'" class="mb-4">
      <label class="block text-sm font-medium text-gray-700 mb-2">URL</label>
      <div class="flex gap-2">
        <input
          v-model="url"
          type="url"
          class="flex-1 px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-primary-500 text-sm"
          :placeholder="embedType === 'youtube' ? 'https://youtube.com/watch?v=...' : 'https://example.com/article'"
        />
        <button
          @click="fetchMetadata"
          :disabled="isLoading || !url.trim()"
          class="px-4 py-2 bg-gray-100 text-gray-700 rounded-lg hover:bg-gray-200 transition-colors disabled:opacity-50 text-sm"
        >
          {{ isLoading ? 'Loading...' : 'Fetch' }}
        </button>
      </div>
    </div>

    <!-- Error Message -->
    <div v-if="error" class="mb-4 p-3 bg-red-50 border border-red-200 rounded-lg text-red-800 text-sm">
      {{ error }}
    </div>

    <!-- YouTube Preview -->
    <div v-if="embedType === 'youtube' && hasMetadata" class="mb-4 p-3 bg-gray-50 rounded-lg">
      <p class="text-sm font-medium text-gray-900">{{ metadata.title || 'YouTube Video' }}</p>
      <p v-if="metadata.videoId" class="text-xs text-gray-500 mt-1">Video ID: {{ metadata.videoId }}</p>
      <button
        v-if="metadata.title"
        @click="useAsPostTitle"
        class="mt-2 text-xs text-primary-600 hover:text-primary-700"
      >
        Use as post title
      </button>
    </div>

    <!-- Link Preview -->
    <div v-if="embedType === 'link' && hasMetadata" class="mb-4 p-3 bg-gray-50 rounded-lg">
      <div class="flex gap-3">
        <img
          v-if="metadata.imageData || metadata.imageUrl"
          :src="metadata.imageData || metadata.imageUrl"
          class="w-20 h-20 object-cover rounded"
          alt=""
        />
        <div class="flex-1 min-w-0">
          <p class="text-sm font-medium text-gray-900 truncate">{{ metadata.title || 'No title' }}</p>
          <p v-if="metadata.description" class="text-xs text-gray-500 mt-1 line-clamp-2">
            {{ metadata.description }}
          </p>
          <button
            v-if="metadata.title"
            @click="useAsPostTitle"
            class="mt-2 text-xs text-primary-600 hover:text-primary-700"
          >
            Use as post title
          </button>
        </div>
      </div>
    </div>

    <!-- Image Upload -->
    <div v-if="embedType === 'image'" class="mb-4">
      <label class="block text-sm font-medium text-gray-700 mb-2">Images</label>

      <!-- Image Grid -->
      <div v-if="images.length > 0" class="grid grid-cols-3 gap-2 mb-3">
        <div
          v-for="(image, index) in images"
          :key="image.id"
          class="relative group"
        >
          <img
            :src="image.data"
            class="w-full h-24 object-cover rounded"
            alt=""
          />
          <div class="absolute inset-0 bg-black bg-opacity-0 group-hover:bg-opacity-40 transition-all rounded flex items-center justify-center gap-1 opacity-0 group-hover:opacity-100">
            <button
              v-if="index > 0"
              @click="moveImage(index, -1)"
              class="p-1 bg-white rounded text-gray-700 hover:bg-gray-100"
              title="Move left"
            >
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
              </svg>
            </button>
            <button
              v-if="index < images.length - 1"
              @click="moveImage(index, 1)"
              class="p-1 bg-white rounded text-gray-700 hover:bg-gray-100"
              title="Move right"
            >
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
              </svg>
            </button>
            <button
              @click="removeImage(index)"
              class="p-1 bg-red-500 rounded text-white hover:bg-red-600"
              title="Remove"
            >
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
          </div>
        </div>
      </div>

      <!-- Upload Button -->
      <input
        ref="imageInput"
        type="file"
        accept="image/*"
        multiple
        class="hidden"
        @change="handleImageSelect"
      />
      <button
        @click="imageInput?.click()"
        class="w-full px-4 py-3 border-2 border-dashed border-gray-300 rounded-lg text-gray-500 hover:border-primary-500 hover:text-primary-600 transition-colors text-sm"
      >
        Click to add images
      </button>
    </div>

    <!-- Position Selector -->
    <div class="mb-4">
      <label class="block text-sm font-medium text-gray-700 mb-2">Position</label>
      <select
        v-model="position"
        class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-primary-500 text-sm"
      >
        <option value="above">Above content</option>
        <option value="below">Below content</option>
      </select>
    </div>

    <!-- Actions -->
    <div class="flex justify-end gap-2">
      <button
        @click="cancel"
        class="px-4 py-2 text-gray-700 hover:bg-gray-100 rounded-lg transition-colors text-sm"
      >
        Cancel
      </button>
      <button
        @click="save"
        :disabled="!canSave"
        class="px-4 py-2 bg-primary-600 text-white rounded-lg hover:bg-primary-700 transition-colors disabled:opacity-50 text-sm"
      >
        {{ embed ? 'Update' : 'Add' }} Embed
      </button>
    </div>
  </div>
</template>
