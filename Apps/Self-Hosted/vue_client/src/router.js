import { createRouter, createWebHistory } from 'vue-router';

const routes = [
  {
    path: '/',
    name: 'home',
    component: () => import('./views/HomeView.vue')
  },
  {
    path: '/blogs/new',
    name: 'blog-create',
    component: () => import('./views/BlogCreateView.vue')
  },
  {
    path: '/blogs/import',
    name: 'blog-import',
    component: () => import('./views/BlogImportView.vue')
  },
  {
    path: '/blogs/:blogId',
    name: 'blog-detail',
    component: () => import('./views/BlogDetailView.vue'),
    children: [
      {
        path: '',
        name: 'blog-posts',
        component: () => import('./views/PostsListView.vue')
      },
      {
        path: 'posts/new',
        name: 'post-create',
        component: () => import('./views/PostEditView.vue')
      },
      {
        path: 'posts/:postId',
        name: 'post-edit',
        component: () => import('./views/PostEditView.vue')
      },
      {
        path: 'categories',
        name: 'categories',
        component: () => import('./views/CategoriesView.vue')
      },
      {
        path: 'tags',
        name: 'tags',
        component: () => import('./views/TagsView.vue')
      },
      {
        path: 'sidebar',
        name: 'sidebar',
        component: () => import('./views/SidebarView.vue')
      },
      {
        path: 'files',
        name: 'files',
        component: () => import('./views/FilesView.vue')
      },
      {
        path: 'settings',
        name: 'blog-settings',
        component: () => import('./views/BlogSettingsView.vue')
      },
      {
        path: 'themes',
        name: 'themes',
        component: () => import('./views/ThemesView.vue')
      },
      {
        path: 'publish',
        name: 'publish',
        component: () => import('./views/PublishView.vue')
      }
    ]
  }
];

const router = createRouter({
  history: createWebHistory(),
  routes
});

export default router;
