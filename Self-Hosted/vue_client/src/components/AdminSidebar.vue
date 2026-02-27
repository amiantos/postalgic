<script setup>
const props = defineProps({
  blogId: { type: String, required: true }
});

const emit = defineEmits(['close-mobile']);

const navLinks = [
  { name: 'Posts', route: 'blog-posts' },
  { name: 'Blog Settings', route: 'blog-settings' },
  { name: 'Categories', route: 'categories' },
  { name: 'Tags', route: 'tags' },
  { name: 'Sidebar', route: 'sidebar' },
  { name: 'Files', route: 'files' },
  { name: 'Themes', route: 'themes' },
  { name: 'Publishing', route: 'publish-settings' }
];

function handleNavClick() {
  emit('close-mobile');
}
</script>

<template>
  <aside class="sidebar">
    <!-- Navigation -->
    <div class="sidebar-section">
      <nav class="sidebar-nav">
        <ul>
          <li v-for="link in navLinks" :key="link.route">
            <router-link
              :to="{ name: link.route, params: { blogId } }"
              @click="handleNavClick"
            >
              {{ link.name }}
            </router-link>
          </li>
        </ul>
      </nav>
    </div>
  </aside>
</template>
