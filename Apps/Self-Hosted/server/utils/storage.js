import fs from 'fs';
import path from 'path';
import { v4 as uuidv4 } from 'uuid';

/**
 * File-based storage utility for managing blog data.
 * Data is stored as JSON files in a structured directory hierarchy.
 *
 * Structure:
 * data/
 *   blogs/
 *     {blogId}/
 *       blog.json          - Blog metadata and settings
 *       posts/
 *         {postId}.json    - Individual post data
 *       categories/
 *         {categoryId}.json
 *       tags/
 *         {tagId}.json
 *       sidebar/
 *         {objectId}.json
 *       static-files/
 *         {fileId}.json    - File metadata
 *       uploads/
 *         {filename}       - Actual file data
 *       published-files.json - Hash tracking for smart publish
 *   themes/
 *     {themeId}.json       - Custom theme templates
 *   generated/
 *     {blogId}/            - Generated site files for preview
 */

class Storage {
  constructor(dataRoot) {
    this.dataRoot = dataRoot;
    this.blogsDir = path.join(dataRoot, 'blogs');
    this.themesDir = path.join(dataRoot, 'themes');
    this.generatedDir = path.join(dataRoot, 'generated');
    this.uploadsDir = path.join(dataRoot, 'uploads');

    // Ensure directories exist
    this.ensureDir(this.blogsDir);
    this.ensureDir(this.themesDir);
    this.ensureDir(this.generatedDir);
    this.ensureDir(this.uploadsDir);
  }

  ensureDir(dir) {
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }
  }

  // ============ Blog Operations ============

  getBlogDir(blogId) {
    return path.join(this.blogsDir, blogId);
  }

  getAllBlogs() {
    if (!fs.existsSync(this.blogsDir)) return [];

    const blogDirs = fs.readdirSync(this.blogsDir, { withFileTypes: true })
      .filter(dirent => dirent.isDirectory())
      .map(dirent => dirent.name);

    return blogDirs
      .map(blogId => this.getBlog(blogId))
      .filter(blog => blog !== null)
      .sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));
  }

  getBlog(blogId) {
    const blogFile = path.join(this.getBlogDir(blogId), 'blog.json');
    if (!fs.existsSync(blogFile)) return null;

    try {
      const data = JSON.parse(fs.readFileSync(blogFile, 'utf-8'));
      return { id: blogId, ...data };
    } catch (e) {
      console.error(`Error reading blog ${blogId}:`, e);
      return null;
    }
  }

  createBlog(blogData) {
    const blogId = uuidv4();
    const blogDir = this.getBlogDir(blogId);

    this.ensureDir(blogDir);
    this.ensureDir(path.join(blogDir, 'posts'));
    this.ensureDir(path.join(blogDir, 'categories'));
    this.ensureDir(path.join(blogDir, 'tags'));
    this.ensureDir(path.join(blogDir, 'sidebar'));
    this.ensureDir(path.join(blogDir, 'static-files'));
    this.ensureDir(path.join(blogDir, 'uploads'));

    const blog = {
      ...blogData,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString()
    };

    fs.writeFileSync(
      path.join(blogDir, 'blog.json'),
      JSON.stringify(blog, null, 2)
    );

    return { id: blogId, ...blog };
  }

  updateBlog(blogId, blogData) {
    const blogDir = this.getBlogDir(blogId);
    const blogFile = path.join(blogDir, 'blog.json');

    if (!fs.existsSync(blogFile)) {
      throw new Error(`Blog ${blogId} not found`);
    }

    const existing = JSON.parse(fs.readFileSync(blogFile, 'utf-8'));
    const updated = {
      ...existing,
      ...blogData,
      updatedAt: new Date().toISOString()
    };

    fs.writeFileSync(blogFile, JSON.stringify(updated, null, 2));
    return { id: blogId, ...updated };
  }

  deleteBlog(blogId) {
    const blogDir = this.getBlogDir(blogId);
    if (fs.existsSync(blogDir)) {
      fs.rmSync(blogDir, { recursive: true });
    }
  }

  // ============ Post Operations ============

  getPostsDir(blogId) {
    return path.join(this.getBlogDir(blogId), 'posts');
  }

  getAllPosts(blogId, includeDrafts = false) {
    const postsDir = this.getPostsDir(blogId);
    if (!fs.existsSync(postsDir)) return [];

    const postFiles = fs.readdirSync(postsDir)
      .filter(f => f.endsWith('.json'));

    const posts = postFiles
      .map(f => {
        const postId = f.replace('.json', '');
        return this.getPost(blogId, postId);
      })
      .filter(post => post !== null)
      .filter(post => includeDrafts || !post.isDraft)
      .sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));

    return posts;
  }

  getPost(blogId, postId) {
    const postFile = path.join(this.getPostsDir(blogId), `${postId}.json`);
    if (!fs.existsSync(postFile)) return null;

    try {
      const data = JSON.parse(fs.readFileSync(postFile, 'utf-8'));
      return { id: postId, ...data };
    } catch (e) {
      console.error(`Error reading post ${postId}:`, e);
      return null;
    }
  }

  createPost(blogId, postData) {
    const postId = uuidv4();
    const postsDir = this.getPostsDir(blogId);
    this.ensureDir(postsDir);

    const post = {
      ...postData,
      createdAt: postData.createdAt || new Date().toISOString(),
      updatedAt: new Date().toISOString()
    };

    fs.writeFileSync(
      path.join(postsDir, `${postId}.json`),
      JSON.stringify(post, null, 2)
    );

    return { id: postId, ...post };
  }

  updatePost(blogId, postId, postData) {
    const postFile = path.join(this.getPostsDir(blogId), `${postId}.json`);

    if (!fs.existsSync(postFile)) {
      throw new Error(`Post ${postId} not found`);
    }

    const existing = JSON.parse(fs.readFileSync(postFile, 'utf-8'));
    const updated = {
      ...existing,
      ...postData,
      updatedAt: new Date().toISOString()
    };

    fs.writeFileSync(postFile, JSON.stringify(updated, null, 2));
    return { id: postId, ...updated };
  }

  deletePost(blogId, postId) {
    const postFile = path.join(this.getPostsDir(blogId), `${postId}.json`);
    if (fs.existsSync(postFile)) {
      fs.unlinkSync(postFile);
    }
  }

  // ============ Category Operations ============

  getCategoriesDir(blogId) {
    return path.join(this.getBlogDir(blogId), 'categories');
  }

  getAllCategories(blogId) {
    const categoriesDir = this.getCategoriesDir(blogId);
    if (!fs.existsSync(categoriesDir)) return [];

    const categoryFiles = fs.readdirSync(categoriesDir)
      .filter(f => f.endsWith('.json'));

    return categoryFiles
      .map(f => {
        const categoryId = f.replace('.json', '');
        return this.getCategory(blogId, categoryId);
      })
      .filter(category => category !== null)
      .sort((a, b) => a.name.localeCompare(b.name));
  }

  getCategory(blogId, categoryId) {
    const categoryFile = path.join(this.getCategoriesDir(blogId), `${categoryId}.json`);
    if (!fs.existsSync(categoryFile)) return null;

    try {
      const data = JSON.parse(fs.readFileSync(categoryFile, 'utf-8'));
      return { id: categoryId, ...data };
    } catch (e) {
      console.error(`Error reading category ${categoryId}:`, e);
      return null;
    }
  }

  createCategory(blogId, categoryData) {
    const categoryId = uuidv4();
    const categoriesDir = this.getCategoriesDir(blogId);
    this.ensureDir(categoriesDir);

    const category = {
      ...categoryData,
      createdAt: new Date().toISOString()
    };

    fs.writeFileSync(
      path.join(categoriesDir, `${categoryId}.json`),
      JSON.stringify(category, null, 2)
    );

    return { id: categoryId, ...category };
  }

  updateCategory(blogId, categoryId, categoryData) {
    const categoryFile = path.join(this.getCategoriesDir(blogId), `${categoryId}.json`);

    if (!fs.existsSync(categoryFile)) {
      throw new Error(`Category ${categoryId} not found`);
    }

    const existing = JSON.parse(fs.readFileSync(categoryFile, 'utf-8'));
    const updated = { ...existing, ...categoryData };

    fs.writeFileSync(categoryFile, JSON.stringify(updated, null, 2));
    return { id: categoryId, ...updated };
  }

  deleteCategory(blogId, categoryId) {
    const categoryFile = path.join(this.getCategoriesDir(blogId), `${categoryId}.json`);
    if (fs.existsSync(categoryFile)) {
      fs.unlinkSync(categoryFile);
    }
  }

  // ============ Tag Operations ============

  getTagsDir(blogId) {
    return path.join(this.getBlogDir(blogId), 'tags');
  }

  getAllTags(blogId) {
    const tagsDir = this.getTagsDir(blogId);
    if (!fs.existsSync(tagsDir)) return [];

    const tagFiles = fs.readdirSync(tagsDir)
      .filter(f => f.endsWith('.json'));

    return tagFiles
      .map(f => {
        const tagId = f.replace('.json', '');
        return this.getTag(blogId, tagId);
      })
      .filter(tag => tag !== null)
      .sort((a, b) => a.name.localeCompare(b.name));
  }

  getTag(blogId, tagId) {
    const tagFile = path.join(this.getTagsDir(blogId), `${tagId}.json`);
    if (!fs.existsSync(tagFile)) return null;

    try {
      const data = JSON.parse(fs.readFileSync(tagFile, 'utf-8'));
      return { id: tagId, ...data };
    } catch (e) {
      console.error(`Error reading tag ${tagId}:`, e);
      return null;
    }
  }

  createTag(blogId, tagData) {
    const tagId = uuidv4();
    const tagsDir = this.getTagsDir(blogId);
    this.ensureDir(tagsDir);

    const tag = {
      ...tagData,
      name: tagData.name.toLowerCase(),
      createdAt: new Date().toISOString()
    };

    fs.writeFileSync(
      path.join(tagsDir, `${tagId}.json`),
      JSON.stringify(tag, null, 2)
    );

    return { id: tagId, ...tag };
  }

  updateTag(blogId, tagId, tagData) {
    const tagFile = path.join(this.getTagsDir(blogId), `${tagId}.json`);

    if (!fs.existsSync(tagFile)) {
      throw new Error(`Tag ${tagId} not found`);
    }

    const existing = JSON.parse(fs.readFileSync(tagFile, 'utf-8'));
    const updated = { ...existing, ...tagData };

    fs.writeFileSync(tagFile, JSON.stringify(updated, null, 2));
    return { id: tagId, ...updated };
  }

  deleteTag(blogId, tagId) {
    const tagFile = path.join(this.getTagsDir(blogId), `${tagId}.json`);
    if (fs.existsSync(tagFile)) {
      fs.unlinkSync(tagFile);
    }
  }

  // ============ Sidebar Object Operations ============

  getSidebarDir(blogId) {
    return path.join(this.getBlogDir(blogId), 'sidebar');
  }

  getAllSidebarObjects(blogId) {
    const sidebarDir = this.getSidebarDir(blogId);
    if (!fs.existsSync(sidebarDir)) return [];

    const sidebarFiles = fs.readdirSync(sidebarDir)
      .filter(f => f.endsWith('.json'));

    return sidebarFiles
      .map(f => {
        const objectId = f.replace('.json', '');
        return this.getSidebarObject(blogId, objectId);
      })
      .filter(obj => obj !== null)
      .sort((a, b) => a.order - b.order);
  }

  getSidebarObject(blogId, objectId) {
    const objectFile = path.join(this.getSidebarDir(blogId), `${objectId}.json`);
    if (!fs.existsSync(objectFile)) return null;

    try {
      const data = JSON.parse(fs.readFileSync(objectFile, 'utf-8'));
      return { id: objectId, ...data };
    } catch (e) {
      console.error(`Error reading sidebar object ${objectId}:`, e);
      return null;
    }
  }

  createSidebarObject(blogId, objectData) {
    const objectId = uuidv4();
    const sidebarDir = this.getSidebarDir(blogId);
    this.ensureDir(sidebarDir);

    const existing = this.getAllSidebarObjects(blogId);
    const maxOrder = existing.length > 0
      ? Math.max(...existing.map(o => o.order))
      : -1;

    const sidebarObject = {
      ...objectData,
      order: objectData.order ?? maxOrder + 1,
      createdAt: new Date().toISOString()
    };

    fs.writeFileSync(
      path.join(sidebarDir, `${objectId}.json`),
      JSON.stringify(sidebarObject, null, 2)
    );

    return { id: objectId, ...sidebarObject };
  }

  updateSidebarObject(blogId, objectId, objectData) {
    const objectFile = path.join(this.getSidebarDir(blogId), `${objectId}.json`);

    if (!fs.existsSync(objectFile)) {
      throw new Error(`Sidebar object ${objectId} not found`);
    }

    const existing = JSON.parse(fs.readFileSync(objectFile, 'utf-8'));
    const updated = { ...existing, ...objectData };

    fs.writeFileSync(objectFile, JSON.stringify(updated, null, 2));
    return { id: objectId, ...updated };
  }

  deleteSidebarObject(blogId, objectId) {
    const objectFile = path.join(this.getSidebarDir(blogId), `${objectId}.json`);
    if (fs.existsSync(objectFile)) {
      fs.unlinkSync(objectFile);
    }
  }

  // ============ Static File Operations ============

  getStaticFilesDir(blogId) {
    return path.join(this.getBlogDir(blogId), 'static-files');
  }

  getBlogUploadsDir(blogId) {
    return path.join(this.getBlogDir(blogId), 'uploads');
  }

  getAllStaticFiles(blogId) {
    const staticFilesDir = this.getStaticFilesDir(blogId);
    if (!fs.existsSync(staticFilesDir)) return [];

    const metaFiles = fs.readdirSync(staticFilesDir)
      .filter(f => f.endsWith('.json'));

    return metaFiles
      .map(f => {
        const fileId = f.replace('.json', '');
        return this.getStaticFile(blogId, fileId);
      })
      .filter(file => file !== null);
  }

  getStaticFile(blogId, fileId) {
    const metaFile = path.join(this.getStaticFilesDir(blogId), `${fileId}.json`);
    if (!fs.existsSync(metaFile)) return null;

    try {
      const data = JSON.parse(fs.readFileSync(metaFile, 'utf-8'));
      return { id: fileId, ...data };
    } catch (e) {
      console.error(`Error reading static file ${fileId}:`, e);
      return null;
    }
  }

  createStaticFile(blogId, fileData, fileBuffer) {
    const fileId = uuidv4();
    const staticFilesDir = this.getStaticFilesDir(blogId);
    const uploadsDir = this.getBlogUploadsDir(blogId);

    this.ensureDir(staticFilesDir);
    this.ensureDir(uploadsDir);

    // Save file data
    const storedFilename = `${fileId}-${fileData.filename}`;
    fs.writeFileSync(path.join(uploadsDir, storedFilename), fileBuffer);

    // Save metadata
    const metadata = {
      ...fileData,
      storedFilename,
      createdAt: new Date().toISOString()
    };

    fs.writeFileSync(
      path.join(staticFilesDir, `${fileId}.json`),
      JSON.stringify(metadata, null, 2)
    );

    return { id: fileId, ...metadata };
  }

  deleteStaticFile(blogId, fileId) {
    const metaFile = path.join(this.getStaticFilesDir(blogId), `${fileId}.json`);

    if (fs.existsSync(metaFile)) {
      const metadata = JSON.parse(fs.readFileSync(metaFile, 'utf-8'));

      // Delete actual file
      const filePath = path.join(this.getBlogUploadsDir(blogId), metadata.storedFilename);
      if (fs.existsSync(filePath)) {
        fs.unlinkSync(filePath);
      }

      // Delete metadata
      fs.unlinkSync(metaFile);
    }
  }

  getStaticFileBuffer(blogId, fileId) {
    const staticFile = this.getStaticFile(blogId, fileId);
    if (!staticFile) return null;

    const filePath = path.join(this.getBlogUploadsDir(blogId), staticFile.storedFilename);
    if (!fs.existsSync(filePath)) return null;

    return fs.readFileSync(filePath);
  }

  getEmbedImageBuffer(blogId, filename) {
    const filePath = path.join(this.getBlogUploadsDir(blogId), filename);
    if (!fs.existsSync(filePath)) return null;

    return fs.readFileSync(filePath);
  }

  // ============ Published Files Tracking ============

  getPublishedFilesPath(blogId) {
    return path.join(this.getBlogDir(blogId), 'published-files.json');
  }

  getPublishedFiles(blogId) {
    const filePath = this.getPublishedFilesPath(blogId);
    if (!fs.existsSync(filePath)) {
      return { fileHashes: {}, lastPublishedDate: null };
    }

    try {
      return JSON.parse(fs.readFileSync(filePath, 'utf-8'));
    } catch (e) {
      return { fileHashes: {}, lastPublishedDate: null };
    }
  }

  savePublishedFiles(blogId, publishedData) {
    const filePath = this.getPublishedFilesPath(blogId);
    fs.writeFileSync(filePath, JSON.stringify(publishedData, null, 2));
  }

  // ============ Theme Operations ============

  getAllThemes() {
    if (!fs.existsSync(this.themesDir)) return [];

    const themeFiles = fs.readdirSync(this.themesDir)
      .filter(f => f.endsWith('.json'));

    return themeFiles
      .map(f => {
        const themeId = f.replace('.json', '');
        return this.getTheme(themeId);
      })
      .filter(theme => theme !== null);
  }

  getTheme(themeId) {
    const themeFile = path.join(this.themesDir, `${themeId}.json`);
    if (!fs.existsSync(themeFile)) return null;

    try {
      const data = JSON.parse(fs.readFileSync(themeFile, 'utf-8'));
      return { id: themeId, ...data };
    } catch (e) {
      console.error(`Error reading theme ${themeId}:`, e);
      return null;
    }
  }

  createTheme(themeData) {
    const themeId = uuidv4();
    this.ensureDir(this.themesDir);

    const theme = {
      ...themeData,
      createdAt: new Date().toISOString()
    };

    fs.writeFileSync(
      path.join(this.themesDir, `${themeId}.json`),
      JSON.stringify(theme, null, 2)
    );

    return { id: themeId, ...theme };
  }

  updateTheme(themeId, themeData) {
    const themeFile = path.join(this.themesDir, `${themeId}.json`);

    if (!fs.existsSync(themeFile)) {
      throw new Error(`Theme ${themeId} not found`);
    }

    const existing = JSON.parse(fs.readFileSync(themeFile, 'utf-8'));
    const updated = { ...existing, ...themeData };

    fs.writeFileSync(themeFile, JSON.stringify(updated, null, 2));
    return { id: themeId, ...updated };
  }

  deleteTheme(themeId) {
    const themeFile = path.join(this.themesDir, `${themeId}.json`);
    if (fs.existsSync(themeFile)) {
      fs.unlinkSync(themeFile);
    }
  }

  // ============ Generated Site Directory ============

  getGeneratedSiteDir(blogId) {
    return path.join(this.generatedDir, blogId);
  }

  clearGeneratedSite(blogId) {
    const siteDir = this.getGeneratedSiteDir(blogId);
    if (fs.existsSync(siteDir)) {
      fs.rmSync(siteDir, { recursive: true });
    }
    this.ensureDir(siteDir);
    return siteDir;
  }
}

export default Storage;
