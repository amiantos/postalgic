import fs from 'fs';
import path from 'path';
import Mustache from 'mustache';
import { marked } from 'marked';
import { getDefaultTemplates } from './templates.js';
import { generateFavicons } from './imageProcessor.js';
import {
  formatDatePath,
  formatDate,
  formatShortDate,
  formatRFC822Date,
  formatISO8601Date,
  getMonthName,
  calculateHash,
  calculateBufferHash,
  getExcerpt,
  extractYouTubeId
} from '../utils/helpers.js';

const POSTS_PER_PAGE = 10;
const RSS_POST_COUNT = 20;
const INDEX_POST_COUNT = 10;

/**
 * Generate a static site for a blog
 * @param {Storage} storage - Storage instance
 * @param {string} blogId - Blog ID
 * @returns {Promise<Object>} - Generation result with outputDir and fileHashes
 */
export async function generateSite(storage, blogId) {
  const blog = storage.getBlog(blogId);
  if (!blog) {
    throw new Error('Blog not found');
  }

  // Get all data
  const rawPosts = storage.getAllPosts(blogId, false); // Published only
  const categories = storage.getAllCategories(blogId);
  const tags = storage.getAllTags(blogId);
  const sidebarObjects = storage.getAllSidebarObjects(blogId);
  const staticFiles = storage.getAllStaticFiles(blogId);

  // Populate posts with category and tag objects (storage returns IDs only)
  const categoryMap = new Map(categories.map(c => [c.id, c]));
  const tagMap = new Map(tags.map(t => [t.id, t]));

  const posts = rawPosts.map(post => ({
    ...post,
    category: post.categoryId ? categoryMap.get(post.categoryId) : null,
    tags: (post.tagIds || []).map(id => tagMap.get(id)).filter(Boolean)
  }));

  // Get theme templates
  let templates = getDefaultTemplates();
  if (blog.themeIdentifier && blog.themeIdentifier !== 'default') {
    const theme = storage.getTheme(blog.themeIdentifier);
    if (theme && theme.templates) {
      templates = { ...templates, ...theme.templates };
    }
  }

  // Prepare output directory
  const outputDir = storage.clearGeneratedSite(blogId);
  const fileHashes = {};

  // Build base context
  const baseContext = buildBaseContext(blog, categories, tags, sidebarObjects, staticFiles, templates);

  // Generate CSS
  await generateCSS(outputDir, templates, blog, fileHashes);

  // Copy static files and generate favicons
  await copyStaticFiles(outputDir, storage, blogId, staticFiles, posts, fileHashes);

  // Generate pages
  await generateIndexPage(outputDir, templates, baseContext, posts, fileHashes);
  await generatePostPages(outputDir, templates, baseContext, posts, storage, blogId, fileHashes);
  await generateArchivesPage(outputDir, templates, baseContext, posts, fileHashes);
  await generateMonthlyArchivePages(outputDir, templates, baseContext, posts, fileHashes);
  await generateTagPages(outputDir, templates, baseContext, posts, tags, fileHashes);
  await generateCategoryPages(outputDir, templates, baseContext, posts, categories, fileHashes);

  // Generate RSS, robots.txt, sitemap
  await generateRSSFeed(outputDir, templates, baseContext, posts, fileHashes);
  await generateRobotsTxt(outputDir, templates, baseContext, fileHashes);
  await generateSitemap(outputDir, templates, baseContext, posts, tags, categories, fileHashes);

  return {
    outputDir,
    fileHashes,
    fileCount: Object.keys(fileHashes).length
  };
}

/**
 * Build the base context shared across all pages
 */
function buildBaseContext(blog, categories, tags, sidebarObjects, staticFiles, templates) {
  const currentYear = new Date().getFullYear();
  const buildDate = new Date().toISOString();

  // Generate sidebar HTML (matching iOS output exactly)
  const sidebarContent = sidebarObjects
    .sort((a, b) => a.order - b.order)
    .map(obj => {
      if (obj.type === 'text') {
        const contentHtml = marked(obj.content || '');
        return `<div class="sidebar-text">
    <h2>${obj.title}</h2>
    <div class="sidebar-text-content">
        ${contentHtml}
    </div>
</div>`;
      } else if (obj.type === 'linkList') {
        const links = (obj.links || [])
          .sort((a, b) => a.order - b.order)
          .map(link => `<li><a href="${link.url}">${link.title}</a></li>\n`)
          .join('');
        return `<div class="sidebar-links">
    <h2>${obj.title}</h2>
    <ul>
        ${links}
    </ul>
</div>`;
      }
      return '';
    }).join('');

  // Check if social share image exists
  const hasSocialShareImage = staticFiles.some(f => f.specialFileType === 'social-share');

  return {
    blogName: blog.name,
    blogUrl: blog.url || '',
    blogTagline: blog.tagline || '',
    blogAuthor: blog.authorName || '',
    blogAuthorUrl: blog.authorUrl || '',
    blogAuthorEmail: blog.authorEmail || '',
    currentYear,
    buildDate,
    accentColor: blog.accentColor || '#FFA100',
    backgroundColor: blog.backgroundColor || '#efefef',
    textColor: blog.textColor || '#2d3748',
    lightShade: blog.lightShade || '#dedede',
    mediumShade: blog.mediumShade || '#a0aec0',
    darkShade: blog.darkShade || '#4a5568',
    hasTags: tags.length > 0,
    hasCategories: categories.length > 0,
    hasSocialShareImage,
    sidebarContent
  };
}

/**
 * Build post context for rendering
 */
function buildPostContext(post, baseContext, inList = false) {
  const urlPath = `${formatDatePath(post.createdAt)}/${post.stub}`;

  // Convert markdown to HTML
  let contentHtml = marked(post.content || '');

  // Insert embed HTML (with newlines matching iOS)
  if (post.embed) {
    const embedHtml = generateEmbedHtml(post.embed, post.id);
    if (post.embed.position === 'above') {
      contentHtml = embedHtml + '\n' + contentHtml;
    } else {
      contentHtml = contentHtml + '\n' + embedHtml;
    }
  }

  const context = {
    ...baseContext,
    displayTitle: post.title || getExcerpt(post.content, 50),
    hasTitle: !!post.title,
    formattedDate: formatDate(post.createdAt),
    shortFormattedDate: formatShortDate(post.createdAt),
    urlPath,
    contentHtml,
    inList,
    lastmod: formatISO8601Date(post.updatedAt || post.createdAt),
    published: formatRFC822Date(post.createdAt),
    // Explicitly set per-post tag/category flags (don't inherit from baseContext)
    hasTags: post.tags && post.tags.length > 0,
    hasCategory: !!post.category,
  };

  // Add category details
  if (post.category) {
    context.categoryName = post.category.name;
    context.categoryUrlPath = post.category.stub;
  }

  // Add tag details
  if (post.tags && post.tags.length > 0) {
    context.tags = post.tags.map(tag => ({
      name: tag.name,
      urlPath: tag.stub
    }));
  }

  return context;
}

/**
 * Generate embed HTML
 */
function generateEmbedHtml(embed, postId) {
  if (!embed) return '';

  if (embed.type === 'youtube') {
    const videoId = embed.videoId || extractYouTubeId(embed.url);
    if (!videoId) return '';
    return `<div class="embed youtube-embed">
      <iframe width="560" height="315" src="https://www.youtube.com/embed/${videoId}"
        frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
        allowfullscreen></iframe>
    </div>`;
  }

  if (embed.type === 'link') {
    // Use stored imageFilename if available, otherwise fall back to imageUrl
    let imageSrc = null;
    if (embed.imageFilename) {
      imageSrc = `/images/embeds/${embed.imageFilename}`;
    } else if (embed.imageUrl && !embed.imageUrl.startsWith('file://')) {
      imageSrc = embed.imageUrl;
    }

    const imageHtml = imageSrc
      ? `<div class="link-image"><img src="${imageSrc}" alt="${embed.title || ''}"></div>`
      : '';
    return `<div class="embed link-embed">
    <a href="${embed.url}" target="_blank" rel="noopener noreferrer">
        ${imageHtml}
        <div class="link-title">${embed.title || ''}</div>
        <div class="link-description">${embed.description || ''}</div>
        <div class="link-url">${embed.url}</div>
    </a>
</div>`;
  }

  if (embed.type === 'image' && embed.images && embed.images.length > 0) {
    const embedId = embed.identifier || postId;
    if (embed.images.length === 1) {
      const img = embed.images[0];
      return `<div class="embed image-embed single-image">
    <a href="/images/embeds/${img.filename}" class="lightbox-trigger" data-lightbox="embed-${embedId}" data-title="">
        <img src="/images/embeds/${img.filename}" class="embed-image" alt="">
    </a>
</div>`;
    }

    const slides = embed.images.map((img, index) => `
        <div class="gallery-slide">
            <a href="/images/embeds/${img.filename}" class="lightbox-trigger" data-lightbox="embed-${embedId}" data-title="">
                <img src="/images/embeds/${img.filename}" alt="">
            </a>
        </div>`).join('');

    const dots = embed.images.map((_, index) => `
            <span class="gallery-dot" onclick="showSlide('gallery-${embedId}', ${index})"></span>`).join('');

    return `<div class="embed image-embed gallery" id="gallery-${embedId}">
    <div class="gallery-container">${slides}
        <div class="gallery-nav">
            <button class="gallery-prev" onclick="prevSlide('gallery-${embedId}')">❮</button>
            <button class="gallery-next" onclick="nextSlide('gallery-${embedId}')">❯</button>
        </div>
    </div>
    <div class="gallery-dots">${dots}
    </div>
</div>
<script>initGallery('gallery-${embedId}');</script>`;
  }

  return '';
}

/**
 * Generate common meta tags for head (favicons, social share, etc.)
 * This matches iOS behavior where these are added to customHead for all pages
 */
function generateCommonHeadMeta(baseContext) {
  const blogUrl = baseContext.blogUrl;
  let meta = `<meta name="apple-mobile-web-app-title" content="${baseContext.blogName}"/>`;
  meta += `<link rel="icon" href="/favicon-32x32.png" sizes="32x32" type="image/png">\n`;
  meta += `<link rel="icon" href="/favicon-192x192.png" sizes="192x192" type="image/png">\n`;
  meta += `<link rel="apple-touch-icon" href="/apple-touch-icon.png" sizes="180x180">\n`;

  if (baseContext.hasSocialShareImage) {
    meta += `<meta property="og:image" content="${blogUrl}/social-share.png">\n`;
    meta += `<meta name="twitter:image" content="${blogUrl}/social-share.png">\n`;
  }

  meta += `<link rel="sitemap" type="application/xml" title="Sitemap" href="/sitemap.xml" />`;
  return meta;
}

/**
 * Generate custom meta tags for a post page (matching iOS output)
 */
function generatePostMeta(post, baseContext) {
  const blogUrl = baseContext.blogUrl;
  const postUrl = `${blogUrl}/${formatDatePath(post.createdAt)}/${post.stub}`;
  const pageTitle = `${post.title || getExcerpt(post.content, 50)} - ${baseContext.blogName}`;

  // Generate description from post content (excerpt)
  const description = getExcerpt(post.content, 200);

  let meta = `<meta name="apple-mobile-web-app-title" content="${baseContext.blogName}"/>`;
  meta += `<link rel="icon" href="/favicon-32x32.png" sizes="32x32" type="image/png">\n`;
  meta += `<link rel="icon" href="/favicon-192x192.png" sizes="192x192" type="image/png">\n`;
  meta += `<link rel="apple-touch-icon" href="/apple-touch-icon.png" sizes="180x180">\n`;

  if (baseContext.hasSocialShareImage) {
    meta += `<meta property="og:image" content="${blogUrl}/social-share.png">\n`;
    meta += `<meta name="twitter:image" content="${blogUrl}/social-share.png">\n`;
  }

  meta += `<!-- Primary Meta Tags -->\n`;
  meta += `<meta name="description" content="${escapeHtml(description)}">\n\n`;
  meta += `<!-- Open Graph / Facebook -->\n`;
  meta += `<meta property="og:type" content="article">\n`;
  meta += `<meta property="og:url" content="${postUrl}">\n`;
  meta += `<meta property="og:title" content="${escapeHtml(pageTitle)}">\n`;
  meta += `<meta property="og:description" content="${escapeHtml(description)}">\n\n`;
  meta += `<!-- Twitter -->\n`;
  meta += `<meta property="twitter:card" content="${baseContext.hasSocialShareImage ? 'summary_large_image' : 'summary'}">\n`;
  meta += `<meta property="twitter:url" content="${postUrl}">\n`;
  meta += `<meta property="twitter:title" content="${escapeHtml(pageTitle)}">\n`;
  meta += `<meta property="twitter:description" content="${escapeHtml(description)}">`;

  return meta;
}

/**
 * Render a template with layout
 */
function renderWithLayout(templates, baseContext, pageTitle, content, customMeta = null, isHomePage = false) {
  // If no custom meta provided, generate common head meta (favicons, social share, sitemap)
  const customHead = customMeta || generateCommonHeadMeta(baseContext);

  // Home page uses just blog name as title, other pages use "pageTitle - blogName"
  const finalPageTitle = isHomePage ? baseContext.blogName : `${pageTitle} - ${baseContext.blogName}`;

  const context = {
    ...baseContext,
    pageTitle: finalPageTitle,
    content,
    hasCustomMeta: !!customMeta,
    customHead
  };

  return Mustache.render(templates.layout, context, { post: templates.post });
}

/**
 * Write file and track hash
 */
function writeFile(outputDir, relativePath, content, fileHashes) {
  const fullPath = path.join(outputDir, relativePath);
  const dir = path.dirname(fullPath);

  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }

  fs.writeFileSync(fullPath, content);
  fileHashes[relativePath] = calculateHash(content);
}

/**
 * Write binary file and track hash
 */
function writeBinaryFile(outputDir, relativePath, buffer, fileHashes) {
  const fullPath = path.join(outputDir, relativePath);
  const dir = path.dirname(fullPath);

  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }

  fs.writeFileSync(fullPath, buffer);
  fileHashes[relativePath] = calculateBufferHash(buffer);
}

/**
 * Generate CSS file
 */
async function generateCSS(outputDir, templates, blog, fileHashes) {
  const cssContext = {
    accentColor: blog.accentColor || '#FFA100',
    backgroundColor: blog.backgroundColor || '#efefef',
    textColor: blog.textColor || '#2d3748',
    lightShade: blog.lightShade || '#dedede',
    mediumShade: blog.mediumShade || '#a0aec0',
    darkShade: blog.darkShade || '#4a5568'
  };

  const css = Mustache.render(templates.css, cssContext);
  writeFile(outputDir, 'css/style.css', css, fileHashes);
}

/**
 * Copy static files and embed images
 */
async function copyStaticFiles(outputDir, storage, blogId, staticFiles, posts, fileHashes) {
  // Create directories
  fs.mkdirSync(path.join(outputDir, 'images', 'embeds'), { recursive: true });

  // Copy static files (favicon, social-share, etc.)
  for (const file of staticFiles) {
    const buffer = storage.getStaticFileBuffer(blogId, file.id);
    if (!buffer) continue;

    if (file.specialFileType === 'favicon') {
      // Generate all favicon sizes
      try {
        const favicons = await generateFavicons(buffer);
        for (const [filename, faviconBuffer] of Object.entries(favicons)) {
          writeBinaryFile(outputDir, filename, faviconBuffer, fileHashes);
        }
      } catch (err) {
        console.warn('Favicon generation failed:', err.message);
      }
    } else if (file.specialFileType === 'social-share') {
      writeBinaryFile(outputDir, 'social-share.png', buffer, fileHashes);
    } else {
      // Regular static file
      writeBinaryFile(outputDir, file.filename, buffer, fileHashes);
    }
  }

  // Copy embed images from posts (both image embeds and link embed preview images)
  const copiedEmbedImages = new Set();

  for (const post of posts) {
    if (!post.embed) continue;

    // Image embeds - copy all gallery images
    if (post.embed.type === 'image' && post.embed.images) {
      for (const img of post.embed.images) {
        if (copiedEmbedImages.has(img.filename)) continue;

        const buffer = storage.getEmbedImageBuffer(blogId, img.filename);
        if (buffer) {
          writeBinaryFile(outputDir, `images/embeds/${img.filename}`, buffer, fileHashes);
          copiedEmbedImages.add(img.filename);
        }
      }
    }

    // Link embeds - copy preview image if stored locally
    if (post.embed.type === 'link' && post.embed.imageFilename) {
      const filename = post.embed.imageFilename;
      if (!copiedEmbedImages.has(filename)) {
        const buffer = storage.getEmbedImageBuffer(blogId, filename);
        if (buffer) {
          writeBinaryFile(outputDir, `images/embeds/${filename}`, buffer, fileHashes);
          copiedEmbedImages.add(filename);
        }
      }
    }
  }
}

/**
 * Generate index page
 */
async function generateIndexPage(outputDir, templates, baseContext, posts, fileHashes) {
  const recentPosts = posts.slice(0, INDEX_POST_COUNT);
  const hasMorePosts = posts.length > INDEX_POST_COUNT;

  const postsContext = recentPosts.map(post => buildPostContext(post, baseContext, true));

  // Get most recent archive URL
  let recentArchiveUrl = '/archives/';
  if (posts.length > 0) {
    const mostRecent = posts[0];
    const date = new Date(mostRecent.createdAt);
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, '0');
    recentArchiveUrl = `/${year}/${month}/`;
  }

  const indexContent = Mustache.render(templates.index, {
    posts: postsContext,
    hasMorePosts,
    recentArchiveUrl
  }, { post: templates.post });

  const html = renderWithLayout(templates, baseContext, 'Home', indexContent, null, true);
  writeFile(outputDir, 'index.html', html, fileHashes);
}

/**
 * Generate individual post pages
 */
async function generatePostPages(outputDir, templates, baseContext, posts, storage, blogId, fileHashes) {
  for (const post of posts) {
    const postContext = buildPostContext(post, baseContext, false);
    const postContent = Mustache.render(templates.post, postContext);
    const customMeta = generatePostMeta(post, baseContext);
    const html = renderWithLayout(templates, baseContext, postContext.displayTitle, postContent, customMeta);

    const postPath = `${formatDatePath(post.createdAt)}/${post.stub}/index.html`;
    writeFile(outputDir, postPath, html, fileHashes);
  }
}

/**
 * Generate archives page
 */
async function generateArchivesPage(outputDir, templates, baseContext, posts, fileHashes) {
  // Group posts by year and month
  const grouped = {};

  for (const post of posts) {
    const date = new Date(post.createdAt);
    const year = date.getFullYear();
    const month = date.getMonth() + 1;

    if (!grouped[year]) {
      grouped[year] = {};
    }
    if (!grouped[year][month]) {
      grouped[year][month] = [];
    }
    grouped[year][month].push(post);
  }

  // Convert to template structure
  const years = Object.keys(grouped)
    .sort((a, b) => b - a)
    .map(year => {
      const months = Object.keys(grouped[year])
        .sort((a, b) => b - a)
        .map(month => {
          const monthPosts = grouped[year][month].map(post => {
            const date = new Date(post.createdAt);
            return {
              displayTitle: post.title || getExcerpt(post.content, 50),
              urlPath: `${formatDatePath(post.createdAt)}/${post.stub}`,
              dayPadded: String(date.getDate()).padStart(2, '0'),
              monthAbbr: date.toLocaleDateString('en-US', { month: 'short' })
            };
          });

          const date = new Date(parseInt(year), parseInt(month) - 1);
          return {
            monthName: date.toLocaleDateString('en-US', { month: 'long' }),
            monthPadded: String(month).padStart(2, '0'),
            posts: monthPosts
          };
        });

      return { year, months };
    });

  const archivesContent = Mustache.render(templates.archives, { years });
  const html = renderWithLayout(templates, baseContext, 'Archives', archivesContent);
  writeFile(outputDir, 'archives/index.html', html, fileHashes);
}

/**
 * Generate monthly archive pages
 */
async function generateMonthlyArchivePages(outputDir, templates, baseContext, posts, fileHashes) {
  // Group posts by year/month
  const grouped = {};

  for (const post of posts) {
    const date = new Date(post.createdAt);
    const month = date.getMonth() + 1;
    const key = `${date.getFullYear()}-${String(month).padStart(2, '0')}`;

    if (!grouped[key]) {
      grouped[key] = {
        year: date.getFullYear(),
        month: month,
        posts: []
      };
    }
    grouped[key].posts.push(post);
  }

  const sortedKeys = Object.keys(grouped).sort().reverse();

  for (let i = 0; i < sortedKeys.length; i++) {
    const { year, month, posts: monthPosts } = grouped[sortedKeys[i]];
    const date = new Date(year, month - 1);
    const monthName = date.toLocaleDateString('en-US', { month: 'long' });

    const postsContext = monthPosts.map(post => buildPostContext(post, baseContext, true));

    const context = {
      year,
      monthName,
      postCount: monthPosts.length,
      postCountText: monthPosts.length === 1 ? 'post' : 'posts',
      posts: postsContext
    };

    // Add navigation (sortedKeys is reverse chronological: newest first)
    // i - 1 = newer month (next →), i + 1 = older month (← previous)
    if (i > 0) {
      const newer = grouped[sortedKeys[i - 1]];
      context.hasNextMonth = true;
      context.nextMonthUrl = `/${newer.year}/${String(newer.month).padStart(2, '0')}/`;
      context.nextMonthName = new Date(newer.year, newer.month - 1).toLocaleDateString('en-US', { month: 'long' });
      context.nextYear = newer.year;
    }

    if (i < sortedKeys.length - 1) {
      const older = grouped[sortedKeys[i + 1]];
      context.hasPreviousMonth = true;
      context.previousMonthUrl = `/${older.year}/${String(older.month).padStart(2, '0')}/`;
      context.previousMonthName = new Date(older.year, older.month - 1).toLocaleDateString('en-US', { month: 'long' });
      context.previousYear = older.year;
    }

    const monthContent = Mustache.render(templates['monthly-archive'], context, { post: templates.post });
    const html = renderWithLayout(templates, baseContext, `${monthName} ${year}`, monthContent);

    const monthPath = `${year}/${String(month).padStart(2, '0')}/index.html`;
    writeFile(outputDir, monthPath, html, fileHashes);
  }
}

/**
 * Generate tag pages
 */
async function generateTagPages(outputDir, templates, baseContext, posts, tags, fileHashes) {
  // Generate tags index
  const tagsWithCount = tags.map(tag => {
    const tagPosts = posts.filter(p => p.tags && p.tags.some(t => t.id === tag.id));
    return {
      name: tag.name,
      urlPath: tag.stub,
      postCount: tagPosts.length
    };
  }).filter(t => t.postCount > 0);

  const tagsContent = Mustache.render(templates.tags, { tags: tagsWithCount });
  const tagsHtml = renderWithLayout(templates, baseContext, 'Tags', tagsContent);
  writeFile(outputDir, 'tags/index.html', tagsHtml, fileHashes);

  // Generate individual tag pages (with pagination)
  for (const tag of tags) {
    const tagPosts = posts.filter(p => p.tags && p.tags.some(t => t.id === tag.id));
    if (tagPosts.length === 0) continue;

    const totalPages = Math.ceil(tagPosts.length / POSTS_PER_PAGE);

    for (let page = 1; page <= totalPages; page++) {
      const startIdx = (page - 1) * POSTS_PER_PAGE;
      const pagePosts = tagPosts.slice(startIdx, startIdx + POSTS_PER_PAGE);
      const postsContext = pagePosts.map(post => buildPostContext(post, baseContext, true));

      const context = {
        tagName: tag.name,
        totalPosts: tagPosts.length,
        postCountText: tagPosts.length === 1 ? 'post' : 'posts',
        posts: postsContext,
        hasPagination: totalPages > 1,
        currentPage: page,
        totalPages,
        hasPreviousPage: page > 1,
        hasNextPage: page < totalPages,
        previousPageUrl: page === 2 ? `/tags/${tag.stub}/` : `/tags/${tag.stub}/page/${page - 1}/`,
        nextPageUrl: `/tags/${tag.stub}/page/${page + 1}/`
      };

      const tagContent = Mustache.render(templates.tag, context, { post: templates.post });
      const html = renderWithLayout(templates, baseContext, `Posts tagged "${tag.name}"`, tagContent);

      const pagePath = page === 1
        ? `tags/${tag.stub}/index.html`
        : `tags/${tag.stub}/page/${page}/index.html`;
      writeFile(outputDir, pagePath, html, fileHashes);
    }
  }
}

/**
 * Generate category pages
 */
async function generateCategoryPages(outputDir, templates, baseContext, posts, categories, fileHashes) {
  // Generate categories index
  const categoriesWithCount = categories.map(category => {
    const categoryPosts = posts.filter(p => p.category && p.category.id === category.id);
    return {
      name: category.name,
      urlPath: category.stub,
      postCount: categoryPosts.length,
      hasDescription: !!category.description,
      description: category.description
    };
  }).filter(c => c.postCount > 0);

  const categoriesContent = Mustache.render(templates.categories, { categories: categoriesWithCount });
  const categoriesHtml = renderWithLayout(templates, baseContext, 'Categories', categoriesContent);
  writeFile(outputDir, 'categories/index.html', categoriesHtml, fileHashes);

  // Generate individual category pages (with pagination)
  for (const category of categories) {
    const categoryPosts = posts.filter(p => p.category && p.category.id === category.id);
    if (categoryPosts.length === 0) continue;

    const totalPages = Math.ceil(categoryPosts.length / POSTS_PER_PAGE);

    for (let page = 1; page <= totalPages; page++) {
      const startIdx = (page - 1) * POSTS_PER_PAGE;
      const pagePosts = categoryPosts.slice(startIdx, startIdx + POSTS_PER_PAGE);
      const postsContext = pagePosts.map(post => buildPostContext(post, baseContext, true));

      const context = {
        categoryName: category.name,
        hasDescription: !!category.description,
        description: category.description,
        totalPosts: categoryPosts.length,
        postCountText: categoryPosts.length === 1 ? 'post' : 'posts',
        posts: postsContext,
        hasPagination: totalPages > 1,
        currentPage: page,
        totalPages,
        hasPreviousPage: page > 1,
        hasNextPage: page < totalPages,
        previousPageUrl: page === 2 ? `/categories/${category.stub}/` : `/categories/${category.stub}/page/${page - 1}/`,
        nextPageUrl: `/categories/${category.stub}/page/${page + 1}/`
      };

      const categoryContent = Mustache.render(templates.category, context, { post: templates.post });
      const html = renderWithLayout(templates, baseContext, `Posts in "${category.name}"`, categoryContent);

      const pagePath = page === 1
        ? `categories/${category.stub}/index.html`
        : `categories/${category.stub}/page/${page}/index.html`;
      writeFile(outputDir, pagePath, html, fileHashes);
    }
  }
}

/**
 * Generate RSS feed
 */
async function generateRSSFeed(outputDir, templates, baseContext, posts, fileHashes) {
  const rssPosts = posts.slice(0, RSS_POST_COUNT).map(post => {
    const context = buildPostContext(post, baseContext, false);
    return {
      ...context,
      published: formatRFC822Date(post.createdAt)
    };
  });

  const rssContent = Mustache.render(templates.rss, {
    ...baseContext,
    buildDate: formatRFC822Date(new Date()),
    posts: rssPosts
  });

  writeFile(outputDir, 'rss.xml', rssContent, fileHashes);
}

/**
 * Generate robots.txt
 */
async function generateRobotsTxt(outputDir, templates, baseContext, fileHashes) {
  const robotsContent = Mustache.render(templates.robots, baseContext);
  writeFile(outputDir, 'robots.txt', robotsContent, fileHashes);
}

/**
 * Generate sitemap
 */
async function generateSitemap(outputDir, templates, baseContext, posts, tags, categories, fileHashes) {
  const now = formatISO8601Date(new Date());

  const postsData = posts.map(post => ({
    urlPath: `${formatDatePath(post.createdAt)}/${post.stub}`,
    lastmod: formatISO8601Date(post.updatedAt || post.createdAt)
  }));

  const tagsData = tags
    .filter(tag => posts.some(p => p.tags && p.tags.some(t => t.id === tag.id)))
    .map(tag => ({
      urlPath: tag.stub,
      lastmod: now
    }));

  const categoriesData = categories
    .filter(category => posts.some(p => p.category && p.category.id === category.id))
    .map(category => ({
      urlPath: category.stub,
      lastmod: now
    }));

  // Monthly archives
  const monthlyArchives = [];
  const seenMonths = new Set();
  for (const post of posts) {
    const date = new Date(post.createdAt);
    const key = `${date.getFullYear()}-${date.getMonth() + 1}`;
    if (!seenMonths.has(key)) {
      seenMonths.add(key);
      monthlyArchives.push({
        url: `/${date.getFullYear()}/${String(date.getMonth() + 1).padStart(2, '0')}/`,
        lastmod: formatISO8601Date(post.updatedAt || post.createdAt)
      });
    }
  }

  const sitemapContent = Mustache.render(templates.sitemap, {
    ...baseContext,
    buildDate: now,
    posts: postsData,
    tags: tagsData,
    categories: categoriesData,
    monthlyArchives
  });

  writeFile(outputDir, 'sitemap.xml', sitemapContent, fileHashes);
}

/**
 * Escape HTML special characters
 */
function escapeHtml(text) {
  if (!text) return '';
  return text
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}
