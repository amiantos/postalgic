<script setup>
import { ref, computed, watch, onMounted } from 'vue';
import { metadataApi } from '@/api';
import EmbedPreview from '@/components/EmbedPreview.vue';

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
const isLoading = ref(false);
const error = ref(null);

// Metadata state
const metadata = ref({
  title: null,
  description: null,
  imageUrl: null,
  imageData: null,
  imageFilename: null,
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

    if (props.embed.type === 'youtube') {
      metadata.value = {
        title: props.embed.title || null,
        videoId: props.embed.videoId || null,
        imageData: props.embed.imageData || null,
        imageFilename: props.embed.imageFilename || null
      };
    } else if (props.embed.type === 'link') {
      metadata.value = {
        title: props.embed.title || null,
        description: props.embed.description || null,
        imageUrl: props.embed.imageUrl || null,
        imageData: props.embed.imageData || null,
        imageFilename: props.embed.imageFilename || null
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
    return metadata.value.title || metadata.value.description || metadata.value.imageUrl || metadata.value.imageFilename;
  }
  return false;
});

// Build a preview embed object for EmbedPreview
const previewEmbed = computed(() => {
  if (embedType.value === 'image' && images.value.length > 0) {
    return { type: 'image', images: images.value };
  }
  if (!hasMetadata.value) return null;
  if (embedType.value === 'youtube') {
    return {
      type: 'youtube',
      url: url.value,
      title: metadata.value.title,
      videoId: metadata.value.videoId,
      imageData: metadata.value.imageData,
      imageFilename: metadata.value.imageFilename
    };
  }
  if (embedType.value === 'link') {
    return {
      type: 'link',
      url: url.value,
      title: metadata.value.title,
      description: metadata.value.description,
      imageUrl: metadata.value.imageUrl,
      imageData: metadata.value.imageData,
      imageFilename: metadata.value.imageFilename
    };
  }
  return null;
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
        videoId: result.videoId,
        imageData: result.imageData,
        imageFilename: null
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
    position: props.embed?.position || 'below'
  };

  if (embedType.value === 'youtube') {
    embedData.url = url.value;
    embedData.title = metadata.value.title;
    embedData.videoId = metadata.value.videoId;
    embedData.imageData = metadata.value.imageData;
    embedData.imageFilename = metadata.value.imageFilename;
  } else if (embedType.value === 'link') {
    embedData.url = url.value;
    embedData.title = metadata.value.title;
    embedData.description = metadata.value.description;
    embedData.imageUrl = metadata.value.imageUrl;
    embedData.imageData = metadata.value.imageData;
    embedData.imageFilename = metadata.value.imageFilename;
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
  <div class="rounded-lg bg-site-bg/50 p-4 space-y-4">
    <h3 class="font-medium text-site-dark">
      {{ embed ? 'Edit Embed' : 'Add Embed' }}
    </h3>

    <!-- Embed Type Selector -->
    <div>
      <label class="block text-sm font-medium text-site-dark mb-2">Type</label>
      <div class="flex gap-2">
        <button
          @click="embedType = 'youtube'"
          :class="[
            'px-4 py-1.5 text-sm rounded-full transition-colors',
            embedType === 'youtube'
              ? 'bg-site-accent text-white'
              : 'bg-white border border-site-light text-site-dark hover:border-site-accent hover:text-site-accent'
          ]"
        >
          YouTube
        </button>
        <button
          @click="embedType = 'link'"
          :class="[
            'px-4 py-1.5 text-sm rounded-full transition-colors',
            embedType === 'link'
              ? 'bg-site-accent text-white'
              : 'bg-white border border-site-light text-site-dark hover:border-site-accent hover:text-site-accent'
          ]"
        >
          Link
        </button>
        <button
          @click="embedType = 'image'"
          :class="[
            'px-4 py-1.5 text-sm rounded-full transition-colors',
            embedType === 'image'
              ? 'bg-site-accent text-white'
              : 'bg-white border border-site-light text-site-dark hover:border-site-accent hover:text-site-accent'
          ]"
        >
          Images
        </button>
      </div>
    </div>

    <!-- URL Input (for YouTube and Link) -->
    <div v-if="embedType !== 'image'">
      <label class="block text-sm font-medium text-site-dark mb-2">URL</label>
      <div class="flex gap-2">
        <input
          v-model="url"
          type="url"
          class="flex-1 px-3 py-2 border border-site-light rounded-lg bg-white text-site-dark focus:outline-none focus:border-site-accent text-sm"
          :placeholder="embedType === 'youtube' ? 'https://youtube.com/watch?v=...' : 'https://example.com/article'"
        />
        <button
          @click="fetchMetadata"
          :disabled="isLoading || !url.trim()"
          class="px-4 py-2 bg-site-accent text-white rounded-full hover:bg-[#e89200] transition-colors disabled:opacity-50 text-sm"
        >
          {{ isLoading ? 'Loading...' : 'Fetch' }}
        </button>
      </div>
    </div>

    <!-- Error Message -->
    <div v-if="error" class="p-3 bg-red-50 border border-red-200 rounded-lg text-red-800 text-sm">
      {{ error }}
    </div>

    <!-- Use as title button (YouTube/Link with metadata) -->
    <div v-if="(embedType === 'youtube' || embedType === 'link') && hasMetadata && metadata.title">
      <button
        @click="useAsPostTitle"
        class="text-xs text-site-accent hover:text-[#e89200] transition-colors"
      >
        Use "{{ metadata.title }}" as post title
      </button>
    </div>

    <!-- Image Upload -->
    <div v-if="embedType === 'image'">
      <label class="block text-sm font-medium text-site-dark mb-2">Images</label>

      <!-- Image Grid -->
      <div v-if="images.length > 0" class="grid grid-cols-4 gap-2 mb-3">
        <div
          v-for="(image, index) in images"
          :key="image.id"
          class="relative group"
        >
          <img
            :src="image.data || `/uploads/${props.blogId}/${image.filename}`"
            class="w-full h-20 object-cover rounded-lg"
            alt=""
          />
          <div class="absolute inset-0 bg-black bg-opacity-0 group-hover:bg-opacity-40 transition-all rounded-lg flex items-center justify-center gap-1 opacity-0 group-hover:opacity-100">
            <button
              v-if="index > 0"
              @click="moveImage(index, -1)"
              class="p-1 bg-white rounded-full text-site-dark hover:bg-site-light"
              title="Move left"
            >
              <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
              </svg>
            </button>
            <button
              v-if="index < images.length - 1"
              @click="moveImage(index, 1)"
              class="p-1 bg-white rounded-full text-site-dark hover:bg-site-light"
              title="Move right"
            >
              <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
              </svg>
            </button>
            <button
              @click="removeImage(index)"
              class="p-1 bg-red-500 rounded-full text-white hover:bg-red-600"
              title="Remove"
            >
              <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
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
        class="w-full px-4 py-3 border-2 border-dashed border-site-light rounded-lg text-site-medium hover:border-site-accent hover:text-site-accent transition-colors text-sm"
      >
        Click to add images
      </button>
    </div>

    <!-- Live Preview -->
    <div v-if="previewEmbed" class="border-t border-site-light pt-4">
      <p class="text-xs font-semibold text-site-medium uppercase tracking-wide mb-2">Preview</p>
      <EmbedPreview :embed="previewEmbed" :blog-id="blogId" />
    </div>

    <!-- Actions -->
    <div class="flex justify-end gap-2 pt-2">
      <button
        @click="cancel"
        class="px-4 py-2 border border-site-light text-site-dark rounded-full hover:border-site-accent hover:text-site-accent transition-colors text-sm"
      >
        Cancel
      </button>
      <button
        @click="save"
        :disabled="!canSave"
        class="px-4 py-2 bg-site-accent text-white rounded-full hover:bg-[#e89200] transition-colors disabled:opacity-50 text-sm"
      >
        {{ embed ? 'Update' : 'Add' }} Embed
      </button>
    </div>
  </div>
</template>
