const API_BASE = '/api';

async function fetchApi(url, options = {}) {
  const response = await fetch(`${API_BASE}${url}`, {
    headers: {
      'Content-Type': 'application/json',
      ...options.headers
    },
    ...options
  });

  if (!response.ok) {
    const error = await response.json().catch(() => ({ error: 'Unknown error' }));
    throw new Error(error.error || `HTTP ${response.status}`);
  }

  if (response.status === 204) {
    return null;
  }

  return response.json();
}

// Blog API
export const blogApi = {
  list: () => fetchApi('/blogs'),
  get: (id) => fetchApi(`/blogs/${id}`),
  create: (data) => fetchApi('/blogs', { method: 'POST', body: JSON.stringify(data) }),
  update: (id, data) => fetchApi(`/blogs/${id}`, { method: 'PUT', body: JSON.stringify(data) }),
  delete: (id) => fetchApi(`/blogs/${id}`, { method: 'DELETE' }),
  stats: (id) => fetchApi(`/blogs/${id}/stats`),
  analytics: (id) => fetchApi(`/blogs/${id}/analytics`),
  debugExport: async (id) => {
    const response = await fetch(`${API_BASE}/blogs/${id}/debug-export`);

    if (!response.ok) {
      const error = await response.json().catch(() => ({ error: 'Unknown error' }));
      throw new Error(error.error || `HTTP ${response.status}`);
    }

    const blob = await response.blob();
    const filename = response.headers.get('content-disposition')?.split('filename=')[1]?.replace(/"/g, '') || `debug-export-${id}.zip`;

    return { blob, filename };
  }
};

// Post API
export const postApi = {
  list: (blogId, { status = 'all', search = '', sort = 'date_desc', page = 1, limit = 10 } = {}) => {
    const params = new URLSearchParams({
      status,
      sort,
      page: page.toString(),
      limit: limit.toString()
    });
    if (search) params.append('search', search);
    return fetchApi(`/blogs/${blogId}/posts?${params.toString()}`);
  },
  get: (blogId, postId) => fetchApi(`/blogs/${blogId}/posts/${postId}`),
  create: (blogId, data) =>
    fetchApi(`/blogs/${blogId}/posts`, { method: 'POST', body: JSON.stringify(data) }),
  update: (blogId, postId, data) =>
    fetchApi(`/blogs/${blogId}/posts/${postId}`, { method: 'PUT', body: JSON.stringify(data) }),
  delete: (blogId, postId) =>
    fetchApi(`/blogs/${blogId}/posts/${postId}`, { method: 'DELETE' }),
  backfillYouTubeThumbnails: (blogId) =>
    fetchApi(`/blogs/${blogId}/posts/backfill-youtube-thumbnails`, { method: 'POST' })
};

// Category API
export const categoryApi = {
  list: (blogId) => fetchApi(`/blogs/${blogId}/categories`),
  get: (blogId, categoryId) => fetchApi(`/blogs/${blogId}/categories/${categoryId}`),
  create: (blogId, data) =>
    fetchApi(`/blogs/${blogId}/categories`, { method: 'POST', body: JSON.stringify(data) }),
  update: (blogId, categoryId, data) =>
    fetchApi(`/blogs/${blogId}/categories/${categoryId}`, { method: 'PUT', body: JSON.stringify(data) }),
  delete: (blogId, categoryId) =>
    fetchApi(`/blogs/${blogId}/categories/${categoryId}`, { method: 'DELETE' })
};

// Tag API
export const tagApi = {
  list: (blogId) => fetchApi(`/blogs/${blogId}/tags`),
  get: (blogId, tagId) => fetchApi(`/blogs/${blogId}/tags/${tagId}`),
  create: (blogId, data) =>
    fetchApi(`/blogs/${blogId}/tags`, { method: 'POST', body: JSON.stringify(data) }),
  update: (blogId, tagId, data) =>
    fetchApi(`/blogs/${blogId}/tags/${tagId}`, { method: 'PUT', body: JSON.stringify(data) }),
  delete: (blogId, tagId) =>
    fetchApi(`/blogs/${blogId}/tags/${tagId}`, { method: 'DELETE' })
};

// Sidebar API
export const sidebarApi = {
  list: (blogId) => fetchApi(`/blogs/${blogId}/sidebar`),
  get: (blogId, objectId) => fetchApi(`/blogs/${blogId}/sidebar/${objectId}`),
  create: (blogId, data) =>
    fetchApi(`/blogs/${blogId}/sidebar`, { method: 'POST', body: JSON.stringify(data) }),
  update: (blogId, objectId, data) =>
    fetchApi(`/blogs/${blogId}/sidebar/${objectId}`, { method: 'PUT', body: JSON.stringify(data) }),
  delete: (blogId, objectId) =>
    fetchApi(`/blogs/${blogId}/sidebar/${objectId}`, { method: 'DELETE' }),
  reorder: (blogId, order) =>
    fetchApi(`/blogs/${blogId}/sidebar/reorder`, { method: 'POST', body: JSON.stringify({ order }) })
};

// Static Files API
export const staticFileApi = {
  list: (blogId) => fetchApi(`/blogs/${blogId}/static-files`),
  get: (blogId, fileId) => fetchApi(`/blogs/${blogId}/static-files/${fileId}`),
  upload: async (blogId, file, options = {}) => {
    const formData = new FormData();
    formData.append('file', file);

    if (options.isSpecialFile) formData.append('isSpecialFile', 'true');
    if (options.specialFileType) formData.append('specialFileType', options.specialFileType);
    if (options.maxDimension) formData.append('maxDimension', options.maxDimension);
    if (options.quality) formData.append('quality', options.quality);

    const response = await fetch(`${API_BASE}/blogs/${blogId}/static-files`, {
      method: 'POST',
      body: formData
    });

    if (!response.ok) {
      const error = await response.json().catch(() => ({ error: 'Unknown error' }));
      throw new Error(error.error || `HTTP ${response.status}`);
    }

    return response.json();
  },
  uploadFavicon: async (blogId, file) => {
    const formData = new FormData();
    formData.append('file', file);

    const response = await fetch(`${API_BASE}/blogs/${blogId}/static-files/favicon`, {
      method: 'POST',
      body: formData
    });

    if (!response.ok) {
      const error = await response.json().catch(() => ({ error: 'Unknown error' }));
      throw new Error(error.error || `HTTP ${response.status}`);
    }

    return response.json();
  },
  uploadSocialShareImage: async (blogId, file) => {
    const formData = new FormData();
    formData.append('file', file);

    const response = await fetch(`${API_BASE}/blogs/${blogId}/static-files/social-share`, {
      method: 'POST',
      body: formData
    });

    if (!response.ok) {
      const error = await response.json().catch(() => ({ error: 'Unknown error' }));
      throw new Error(error.error || `HTTP ${response.status}`);
    }

    return response.json();
  },
  delete: (blogId, fileId) =>
    fetchApi(`/blogs/${blogId}/static-files/${fileId}`, { method: 'DELETE' })
};

// Publish API
export const publishApi = {
  generate: (blogId) =>
    fetchApi(`/blogs/${blogId}/publish/generate`, { method: 'POST' }),
  preview: (blogId) =>
    fetchApi(`/blogs/${blogId}/publish/preview`),
  download: async (blogId) => {
    const response = await fetch(`${API_BASE}/blogs/${blogId}/publish/download`, {
      method: 'POST'
    });

    if (!response.ok) {
      const error = await response.json().catch(() => ({ error: 'Unknown error' }));
      throw new Error(error.error || `HTTP ${response.status}`);
    }

    const blob = await response.blob();
    const filename = response.headers.get('content-disposition')?.split('filename=')[1]?.replace(/"/g, '') || 'site.zip';

    return { blob, filename };
  },
  status: (blogId) =>
    fetchApi(`/blogs/${blogId}/publish/status`),
  changes: (blogId) =>
    fetchApi(`/blogs/${blogId}/publish/changes`, { method: 'POST' }),
  markPublished: (blogId) =>
    fetchApi(`/blogs/${blogId}/publish/mark-published`, { method: 'POST' }),
  // Publisher-specific endpoints
  publishToAWS: (blogId, options = {}) =>
    fetchApi(`/blogs/${blogId}/publish/aws`, { method: 'POST', body: JSON.stringify(options) }),
  publishToSFTP: (blogId, options = {}) =>
    fetchApi(`/blogs/${blogId}/publish/sftp`, { method: 'POST', body: JSON.stringify(options) }),
  publishToGit: (blogId) =>
    fetchApi(`/blogs/${blogId}/publish/git`, { method: 'POST' })
};

// Theme API
export const themeApi = {
  list: () => fetchApi('/themes'),
  get: (id) => fetchApi(`/themes/${id}`),
  create: (data) => fetchApi('/themes', { method: 'POST', body: JSON.stringify(data) }),
  update: (id, data) => fetchApi(`/themes/${id}`, { method: 'PUT', body: JSON.stringify(data) }),
  delete: (id) => fetchApi(`/themes/${id}`, { method: 'DELETE' }),
  duplicate: (id, name) =>
    fetchApi(`/themes/${id}/duplicate`, { method: 'POST', body: JSON.stringify({ name }) })
};

// Metadata API
export const metadataApi = {
  fetch: (url) => fetchApi(`/metadata?url=${encodeURIComponent(url)}`)
};

// Share Destination API
export const shareDestinationApi = {
  list: (blogId) => fetchApi(`/blogs/${blogId}/share/destinations`),
  create: (blogId, data) =>
    fetchApi(`/blogs/${blogId}/share/destinations`, { method: 'POST', body: JSON.stringify(data) }),
  update: (blogId, destinationId, data) =>
    fetchApi(`/blogs/${blogId}/share/destinations/${destinationId}`, { method: 'PUT', body: JSON.stringify(data) }),
  delete: (blogId, destinationId) =>
    fetchApi(`/blogs/${blogId}/share/destinations/${destinationId}`, { method: 'DELETE' })
};

// Share Action API
export const shareApi = {
  history: (blogId, postId) => fetchApi(`/blogs/${blogId}/share/posts/${postId}/shares`),
  share: async (blogId, postId, destinationId, options = {}) => {
    const { force = false, ...params } = options;
    const response = await fetch(`${API_BASE}/blogs/${blogId}/share/posts/${postId}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ destinationId, force, ...params })
    });

    let data = null;
    try { data = await response.json(); } catch { data = {}; }

    if (response.status === 409 && data?.alreadyShared) {
      // Surface as a structured error so the UI can offer a "share again" prompt
      const err = new Error(data.error || 'Already shared');
      err.alreadyShared = true;
      err.lastSharedAt = data.lastSharedAt;
      throw err;
    }

    if (!response.ok) {
      throw new Error(data?.error || `HTTP ${response.status}`);
    }

    return data;
  },
  // Discourse helper proxies (server-side: API key stays on server).
  // Pre-save settings UI uses the test*/searchTopics* variants that accept config in body.
  discourseTest: (blogId, config) =>
    fetchApi(`/blogs/${blogId}/share/discourse/test`, { method: 'POST', body: JSON.stringify({ config }) }),
  discourseSearchTopicsByConfig: (blogId, config, q) =>
    fetchApi(`/blogs/${blogId}/share/discourse/search-topics`, { method: 'POST', body: JSON.stringify({ config, q }) }),
  discourseGetTopicByConfig: (blogId, config, topicId) =>
    fetchApi(`/blogs/${blogId}/share/discourse/topic`, { method: 'POST', body: JSON.stringify({ config, topicId }) }),
  // Saved-destination variants — used by ShareModal at share time
  discourseCategories: (blogId, destinationId) =>
    fetchApi(`/blogs/${blogId}/share/destinations/${destinationId}/discourse/categories`),
  discourseSearchTopics: (blogId, destinationId, query) =>
    fetchApi(`/blogs/${blogId}/share/destinations/${destinationId}/discourse/search?q=${encodeURIComponent(query || '')}`),
  discourseGetTopic: (blogId, destinationId, topicId) =>
    fetchApi(`/blogs/${blogId}/share/destinations/${destinationId}/discourse/topic/${encodeURIComponent(topicId)}`)
};

// Import API
export const importApi = {
  validate: async (file) => {
    const formData = new FormData();
    formData.append('file', file);

    const response = await fetch(`${API_BASE}/import/validate`, {
      method: 'POST',
      body: formData
    });

    if (!response.ok) {
      const error = await response.json().catch(() => ({ error: 'Unknown error' }));
      throw new Error(error.error || `HTTP ${response.status}`);
    }

    return response.json();
  },
  import: async (file) => {
    const formData = new FormData();
    formData.append('file', file);

    const response = await fetch(`${API_BASE}/import`, {
      method: 'POST',
      body: formData
    });

    if (!response.ok) {
      const error = await response.json().catch(() => ({ error: 'Unknown error' }));
      throw new Error(error.error || `HTTP ${response.status}`);
    }

    return response.json();
  }
};
