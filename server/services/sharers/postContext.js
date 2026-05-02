import { formatDatePath, getExcerpt } from '../../utils/helpers.js';

function joinUrl(base, ...parts) {
  const trimmedBase = (base || '').replace(/\/+$/, '');
  const tail = parts
    .filter(Boolean)
    .map(p => String(p).replace(/^\/+|\/+$/g, ''))
    .join('/');
  return `${trimmedBase}/${tail}`;
}

export function buildPermalink(blog, post) {
  const datePath = formatDatePath(post.createdAt, blog.timezone || 'UTC');
  return `${joinUrl(blog.url, datePath, post.stub)}/`;
}

export function absolutizeEmbed(embed, blog) {
  if (!embed) return null;

  const out = {
    type: embed.type,
    position: embed.position || null
  };

  if (embed.type === 'youtube') {
    out.url = embed.url || null;
    out.video_id = embed.videoId || null;
    out.title = embed.title || null;
    out.image_url = embed.imageFilename
      ? joinUrl(blog.url, 'images/embeds', embed.imageFilename)
      : null;
  } else if (embed.type === 'link') {
    out.url = embed.url || null;
    out.title = embed.title || null;
    out.description = embed.description || null;
    if (embed.imageFilename) {
      out.image_url = joinUrl(blog.url, 'images/embeds', embed.imageFilename);
    } else if (embed.imageUrl && !embed.imageUrl.startsWith('file://')) {
      out.image_url = embed.imageUrl;
    } else {
      out.image_url = null;
    }
  } else if (embed.type === 'image') {
    out.images = (embed.images || [])
      .slice()
      .sort((a, b) => (a.order ?? 0) - (b.order ?? 0))
      .map(img => ({
        url: joinUrl(blog.url, 'images/embeds', img.filename),
        order: img.order ?? 0
      }));
  }

  return out;
}

export function buildPostContext({ post, blog, storage, blogId }) {
  let categoryName = null;
  if (post.categoryId) {
    const category = storage.getCategory(blogId, post.categoryId);
    if (category) categoryName = category.name;
  }

  let tags = [];
  if (post.tagIds && post.tagIds.length > 0) {
    tags = post.tagIds
      .map(tagId => storage.getTag(blogId, tagId))
      .filter(Boolean)
      .map(tag => tag.name);
  }

  return {
    permalink: buildPermalink(blog, post),
    excerpt: getExcerpt(post.content || '', 280),
    categoryName,
    tags,
    embed: absolutizeEmbed(post.embed, blog)
  };
}

// Template placeholder substitution for templates configured by the user.
// Empty/missing values resolve to ''.
export function renderTemplate(template, { post, blog, context }) {
  if (!template) return '';

  const embed = context.embed || {};
  let embedUrl = '';
  let embedImage = '';
  if (embed.type === 'youtube' || embed.type === 'link') {
    embedUrl = embed.url || '';
    embedImage = embed.image_url || '';
  } else if (embed.type === 'image' && Array.isArray(embed.images) && embed.images[0]) {
    embedImage = embed.images[0].url || '';
  }

  const replacements = {
    permalink: context.permalink || '',
    post_title: post.title || '',
    post_excerpt: context.excerpt || '',
    post_content: post.content || '',
    embed_url: embedUrl,
    embed_image: embedImage,
    author_name: blog.authorName || '',
    blog_name: blog.name || '',
    tags: (context.tags || []).join(', ')
  };

  return template.replace(/\{(\w+)\}/g, (match, key) => {
    return Object.prototype.hasOwnProperty.call(replacements, key)
      ? replacements[key]
      : match;
  });
}

export const TEMPLATE_PLACEHOLDERS = [
  'permalink',
  'post_title',
  'post_excerpt',
  'post_content',
  'embed_url',
  'embed_image',
  'author_name',
  'blog_name',
  'tags'
];
