<script setup>
import { ref, computed } from 'vue';

const props = defineProps({
  embed: {
    type: Object,
    required: true
  },
  blogId: {
    type: String,
    required: true
  }
});

// Gallery state
const currentIndex = ref(0);

const youtubeThumb = computed(() => {
  if (props.embed.type !== 'youtube' || !props.embed.videoId) return null;
  return `https://img.youtube.com/vi/${props.embed.videoId}/hqdefault.jpg`;
});

const linkImageSrc = computed(() => {
  if (props.embed.type !== 'link') return null;
  if (props.embed.imageData) return props.embed.imageData;
  if (props.embed.imageFilename) return `/uploads/${props.blogId}/${props.embed.imageFilename}`;
  if (props.embed.imageUrl && !props.embed.imageUrl.startsWith('file://')) return props.embed.imageUrl;
  return null;
});

const images = computed(() => props.embed.images || []);
const totalImages = computed(() => images.value.length);

function imageSrc(img) {
  return img.data || `/uploads/${props.blogId}/${img.filename}`;
}

function prevImage() {
  if (currentIndex.value > 0) currentIndex.value--;
}

function nextImage() {
  if (currentIndex.value < totalImages.value - 1) currentIndex.value++;
}

function goToImage(index) {
  currentIndex.value = index;
}

function urlDomain(url) {
  try {
    return new URL(url).hostname;
  } catch {
    return url;
  }
}
</script>

<template>
  <!-- YouTube Preview -->
  <div v-if="embed.type === 'youtube'" class="rounded-lg overflow-hidden">
    <div class="relative w-full" style="padding-bottom: 56.25%">
      <img
        v-if="youtubeThumb"
        :src="youtubeThumb"
        class="absolute inset-0 w-full h-full object-cover"
        alt=""
      />
      <div class="absolute inset-0 bg-black/20 flex items-center justify-center">
        <div class="w-16 h-16 bg-red-600 rounded-xl flex items-center justify-center shadow-lg">
          <svg class="w-8 h-8 text-white ml-1" fill="currentColor" viewBox="0 0 24 24">
            <path d="M8 5v14l11-7z" />
          </svg>
        </div>
      </div>
    </div>
    <p v-if="embed.title" class="text-sm font-medium text-site-dark mt-2">{{ embed.title }}</p>
  </div>

  <!-- Link Preview -->
  <div v-else-if="embed.type === 'link'" class="border border-site-light rounded-lg overflow-hidden hover:border-site-accent transition-colors">
    <div class="grid" :style="linkImageSrc ? 'grid-template-columns: 150px 1fr' : ''">
      <img
        v-if="linkImageSrc"
        :src="linkImageSrc"
        class="w-full h-full object-cover"
        style="min-height: 100px; max-height: 150px"
        alt=""
      />
      <div class="p-3 flex flex-col justify-center min-w-0">
        <p class="text-sm font-semibold text-site-dark truncate">{{ embed.title || 'Link' }}</p>
        <p v-if="embed.description" class="text-xs text-site-medium mt-1 line-clamp-2">{{ embed.description }}</p>
        <p v-if="embed.url" class="text-xs text-site-medium mt-1 truncate">{{ urlDomain(embed.url) }}</p>
      </div>
    </div>
  </div>

  <!-- Single Image -->
  <div v-else-if="embed.type === 'image' && totalImages === 1" class="rounded-lg overflow-hidden">
    <img
      :src="imageSrc(images[0])"
      class="w-full rounded-lg"
      alt=""
    />
  </div>

  <!-- Image Gallery -->
  <div v-else-if="embed.type === 'image' && totalImages > 1" class="relative rounded-lg overflow-hidden">
    <img
      :src="imageSrc(images[currentIndex])"
      class="w-full rounded-lg"
      alt=""
    />

    <!-- Prev/Next buttons -->
    <button
      v-if="currentIndex > 0"
      @click="prevImage"
      class="absolute left-2 top-1/2 -translate-y-1/2 w-8 h-8 bg-black/40 hover:bg-black/60 text-white rounded-full flex items-center justify-center transition-colors"
    >
      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
      </svg>
    </button>
    <button
      v-if="currentIndex < totalImages - 1"
      @click="nextImage"
      class="absolute right-2 top-1/2 -translate-y-1/2 w-8 h-8 bg-black/40 hover:bg-black/60 text-white rounded-full flex items-center justify-center transition-colors"
    >
      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
      </svg>
    </button>

    <!-- Dot indicators -->
    <div class="absolute bottom-3 left-1/2 -translate-x-1/2 flex gap-1.5">
      <button
        v-for="(_, index) in images"
        :key="index"
        @click="goToImage(index)"
        :class="[
          'w-2 h-2 rounded-full transition-colors',
          index === currentIndex ? 'bg-site-accent' : 'bg-white/60 hover:bg-white/80'
        ]"
      />
    </div>
  </div>
</template>
