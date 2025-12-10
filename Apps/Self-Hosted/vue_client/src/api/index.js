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
  stats: (id) => fetchApi(`/blogs/${id}/stats`)
};

// Post API
export const postApi = {
  list: (blogId, includeDrafts = true) =>
    fetchApi(`/blogs/${blogId}/posts?includeDrafts=${includeDrafts}`),
  get: (blogId, postId) => fetchApi(`/blogs/${blogId}/posts/${postId}`),
  create: (blogId, data) =>
    fetchApi(`/blogs/${blogId}/posts`, { method: 'POST', body: JSON.stringify(data) }),
  update: (blogId, postId, data) =>
    fetchApi(`/blogs/${blogId}/posts/${postId}`, { method: 'PUT', body: JSON.stringify(data) }),
  delete: (blogId, postId) =>
    fetchApi(`/blogs/${blogId}/posts/${postId}`, { method: 'DELETE' })
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
