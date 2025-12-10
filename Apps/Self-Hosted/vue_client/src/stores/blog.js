import { defineStore } from 'pinia';
import { ref, computed } from 'vue';
import { blogApi, postApi, categoryApi, tagApi, sidebarApi, staticFileApi, publishApi } from '@/api';

export const useBlogStore = defineStore('blog', () => {
  // State
  const blogs = ref([]);
  const currentBlog = ref(null);
  const posts = ref([]);
  const categories = ref([]);
  const tags = ref([]);
  const sidebarObjects = ref([]);
  const staticFiles = ref([]);
  const loading = ref(false);
  const error = ref(null);

  // Getters
  const publishedPosts = computed(() => posts.value.filter(p => !p.isDraft));
  const draftPosts = computed(() => posts.value.filter(p => p.isDraft));

  // Actions
  async function fetchBlogs() {
    loading.value = true;
    error.value = null;
    try {
      blogs.value = await blogApi.list();
    } catch (e) {
      error.value = e.message;
    } finally {
      loading.value = false;
    }
  }

  async function fetchBlog(blogId) {
    loading.value = true;
    error.value = null;
    try {
      currentBlog.value = await blogApi.get(blogId);
    } catch (e) {
      error.value = e.message;
    } finally {
      loading.value = false;
    }
  }

  async function createBlog(data) {
    const blog = await blogApi.create(data);
    blogs.value.unshift(blog);
    return blog;
  }

  async function updateBlog(blogId, data) {
    const blog = await blogApi.update(blogId, data);
    currentBlog.value = blog;
    const index = blogs.value.findIndex(b => b.id === blogId);
    if (index !== -1) {
      blogs.value[index] = blog;
    }
    return blog;
  }

  async function deleteBlog(blogId) {
    await blogApi.delete(blogId);
    blogs.value = blogs.value.filter(b => b.id !== blogId);
    if (currentBlog.value?.id === blogId) {
      currentBlog.value = null;
    }
  }

  // Posts
  async function fetchPosts(blogId, options = {}) {
    loading.value = true;
    try {
      const { includeDrafts = true, search = '', sort = 'date_desc' } = options;
      posts.value = await postApi.list(blogId, includeDrafts, search, sort);
    } catch (e) {
      error.value = e.message;
    } finally {
      loading.value = false;
    }
  }

  async function fetchPost(blogId, postId) {
    return await postApi.get(blogId, postId);
  }

  async function createPost(blogId, data) {
    const post = await postApi.create(blogId, data);
    posts.value.unshift(post);
    return post;
  }

  async function updatePost(blogId, postId, data) {
    const post = await postApi.update(blogId, postId, data);
    const index = posts.value.findIndex(p => p.id === postId);
    if (index !== -1) {
      posts.value[index] = post;
    }
    return post;
  }

  async function deletePost(blogId, postId) {
    await postApi.delete(blogId, postId);
    posts.value = posts.value.filter(p => p.id !== postId);
  }

  // Categories
  async function fetchCategories(blogId) {
    categories.value = await categoryApi.list(blogId);
  }

  async function createCategory(blogId, data) {
    const category = await categoryApi.create(blogId, data);
    categories.value.push(category);
    return category;
  }

  async function updateCategory(blogId, categoryId, data) {
    const category = await categoryApi.update(blogId, categoryId, data);
    const index = categories.value.findIndex(c => c.id === categoryId);
    if (index !== -1) {
      categories.value[index] = category;
    }
    return category;
  }

  async function deleteCategory(blogId, categoryId) {
    await categoryApi.delete(blogId, categoryId);
    categories.value = categories.value.filter(c => c.id !== categoryId);
  }

  // Tags
  async function fetchTags(blogId) {
    tags.value = await tagApi.list(blogId);
  }

  async function createTag(blogId, data) {
    const tag = await tagApi.create(blogId, data);
    tags.value.push(tag);
    return tag;
  }

  async function updateTag(blogId, tagId, data) {
    const tag = await tagApi.update(blogId, tagId, data);
    const index = tags.value.findIndex(t => t.id === tagId);
    if (index !== -1) {
      tags.value[index] = tag;
    }
    return tag;
  }

  async function deleteTag(blogId, tagId) {
    await tagApi.delete(blogId, tagId);
    tags.value = tags.value.filter(t => t.id !== tagId);
  }

  // Sidebar
  async function fetchSidebarObjects(blogId) {
    sidebarObjects.value = await sidebarApi.list(blogId);
  }

  async function createSidebarObject(blogId, data) {
    const obj = await sidebarApi.create(blogId, data);
    sidebarObjects.value.push(obj);
    return obj;
  }

  async function updateSidebarObject(blogId, objectId, data) {
    const obj = await sidebarApi.update(blogId, objectId, data);
    const index = sidebarObjects.value.findIndex(o => o.id === objectId);
    if (index !== -1) {
      sidebarObjects.value[index] = obj;
    }
    return obj;
  }

  async function deleteSidebarObject(blogId, objectId) {
    await sidebarApi.delete(blogId, objectId);
    sidebarObjects.value = sidebarObjects.value.filter(o => o.id !== objectId);
  }

  // Static Files
  async function fetchStaticFiles(blogId) {
    staticFiles.value = await staticFileApi.list(blogId);
  }

  async function uploadStaticFile(blogId, file, options = {}) {
    const uploaded = await staticFileApi.upload(blogId, file, options);
    staticFiles.value.push(uploaded);
    return uploaded;
  }

  async function deleteStaticFile(blogId, fileId) {
    await staticFileApi.delete(blogId, fileId);
    staticFiles.value = staticFiles.value.filter(f => f.id !== fileId);
  }

  // Publish
  async function generateSite(blogId) {
    return await publishApi.generate(blogId);
  }

  async function downloadSite(blogId) {
    return await publishApi.download(blogId);
  }

  function clearBlogData() {
    currentBlog.value = null;
    posts.value = [];
    categories.value = [];
    tags.value = [];
    sidebarObjects.value = [];
    staticFiles.value = [];
  }

  return {
    // State
    blogs,
    currentBlog,
    posts,
    categories,
    tags,
    sidebarObjects,
    staticFiles,
    loading,
    error,

    // Getters
    publishedPosts,
    draftPosts,

    // Actions
    fetchBlogs,
    fetchBlog,
    createBlog,
    updateBlog,
    deleteBlog,
    fetchPosts,
    fetchPost,
    createPost,
    updatePost,
    deletePost,
    fetchCategories,
    createCategory,
    updateCategory,
    deleteCategory,
    fetchTags,
    createTag,
    updateTag,
    deleteTag,
    fetchSidebarObjects,
    createSidebarObject,
    updateSidebarObject,
    deleteSidebarObject,
    fetchStaticFiles,
    uploadStaticFile,
    deleteStaticFile,
    generateSite,
    downloadSite,
    clearBlogData
  };
});
