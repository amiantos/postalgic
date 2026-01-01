<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useBlogStore } from '@/stores/blog';

const props = defineProps({
  title: { type: String, default: '' },
  subtitle: { type: String, default: '' },
  showNavButtons: { type: Boolean, default: true }
});

const route = useRoute();
const router = useRouter();
const blogStore = useBlogStore();

const customizeDropdownOpen = ref(false);
const blogId = computed(() => route.params.blogId);

const customizeItems = [
  { name: 'Categories', route: 'categories' },
  { name: 'Tags', route: 'tags' },
  { name: 'Sidebar', route: 'sidebar' },
  { name: 'Files', route: 'files' },
  { name: 'Themes', route: 'themes' }
];

function toggleCustomizeDropdown() {
  customizeDropdownOpen.value = !customizeDropdownOpen.value;
}

function handleClickOutside(event) {
  const dropdown = document.getElementById('customize-dropdown');
  if (dropdown && !dropdown.contains(event.target)) {
    customizeDropdownOpen.value = false;
  }
}

function navigateToCustomize(routeName) {
  customizeDropdownOpen.value = false;
  router.push({ name: routeName, params: { blogId: blogId.value } });
}

onMounted(() => {
  document.addEventListener('click', handleClickOutside);
});

onUnmounted(() => {
  document.removeEventListener('click', handleClickOutside);
});
</script>

<template>
  <header class="sticky top-0 z-40 bg-white/90 dark:bg-gray-900/90 backdrop-blur-lg border-b border-black/5 dark:border-white/10 mb-6">
    <div class="max-w-3xl mx-auto px-4 sm:px-6">
      <!-- Top row: Back link + Blog name centered -->
      <div class="flex items-center justify-between py-2">
        <router-link to="/" class="flex items-center gap-2 text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-300 text-sm">
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
          </svg>
          <span>All Blogs</span>
        </router-link>

        <router-link
          :to="{ name: 'blog-posts', params: { blogId } }"
          class="absolute left-1/2 -translate-x-1/2 text-sm font-medium text-gray-900 dark:text-gray-100 hover:text-primary-600 dark:hover:text-primary-400 transition-colors"
        >
          {{ blogStore.currentBlog?.name }}
        </router-link>

        <!-- Spacer to balance the layout -->
        <div class="w-20"></div>
      </div>

      <!-- Bottom row: Title + Actions -->
      <div class="flex items-center justify-between pb-3">
        <div>
          <h1 class="text-xl font-semibold text-gray-900 dark:text-gray-100">{{ title }}</h1>
          <p v-if="subtitle" class="text-gray-500 dark:text-gray-400 text-sm">{{ subtitle }}</p>
        </div>

        <!-- Action buttons -->
        <div class="flex items-center gap-2">
          <!-- Custom actions slot -->
          <slot name="actions"></slot>

          <!-- Nav buttons (Publish, Customize, Settings) -->
          <template v-if="showNavButtons">
            <!-- Publish (cloud icon) -->
            <router-link
              :to="{ name: 'publish', params: { blogId } }"
              class="glass p-2 text-gray-600 dark:text-gray-400 hover:text-gray-900 dark:hover:text-white"
              title="Publish"
            >
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12" />
              </svg>
            </router-link>

            <!-- Customize dropdown -->
            <div id="customize-dropdown" class="relative">
              <button
                @click.stop="toggleCustomizeDropdown"
                class="glass px-3 py-2 text-sm font-medium text-gray-700 dark:text-gray-300 flex items-center gap-1"
              >
                Customize
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
                </svg>
              </button>

              <!-- Dropdown menu -->
              <div
                v-if="customizeDropdownOpen"
                class="absolute right-0 mt-2 w-48 glass rounded-xl shadow-lg py-1 z-50"
              >
                <button
                  v-for="item in customizeItems"
                  :key="item.route"
                  @click="navigateToCustomize(item.route)"
                  class="block w-full text-left px-4 py-2 text-sm text-gray-700 dark:text-gray-300 hover:bg-black/5 dark:hover:bg-white/10"
                >
                  {{ item.name }}
                </button>
              </div>
            </div>

            <!-- Settings (cog icon) -->
            <router-link
              :to="{ name: 'blog-settings', params: { blogId } }"
              class="glass p-2 text-gray-600 dark:text-gray-400 hover:text-gray-900 dark:hover:text-white"
              title="Settings"
            >
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z" />
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
              </svg>
            </router-link>
          </template>
        </div>
      </div>

      <!-- Extra content slot (for search bars, filters, etc.) -->
      <slot name="controls"></slot>
    </div>
  </header>
</template>
