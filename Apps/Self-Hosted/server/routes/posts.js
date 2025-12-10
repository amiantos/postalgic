import express from 'express';
import Storage from '../utils/storage.js';
import {
  generateStub,
  makeStubUnique,
  formatDatePath,
  formatDate,
  formatShortDate,
  getExcerpt,
  extractYouTubeId
} from '../utils/helpers.js';

const router = express.Router({ mergeParams: true });

function getStorage(req) {
  return new Storage(req.app.locals.dataRoot);
}

// GET /api/blogs/:blogId/posts - List all posts
// Query params:
//   - includeDrafts: 'true' to include drafts
//   - search: search term for title, content, category, tags
//   - sort: 'date_desc' (default), 'date_asc', 'title_asc', 'title_desc'
router.get('/', (req, res) => {
  try {
    const storage = getStorage(req);
    const { blogId } = req.params;
    const includeDrafts = req.query.includeDrafts === 'true';
    const search = req.query.search || '';
    const sort = req.query.sort || 'date_desc';

    let posts;

    // Use searchPosts if there's a search term, otherwise use getAllPosts
    if (search.trim()) {
      posts = storage.searchPosts(blogId, search, { includeDrafts, sort });
    } else {
      posts = storage.getAllPosts(blogId, includeDrafts);

      // Apply sorting for non-search queries
      posts = sortPosts(posts, sort);
    }

    // Enrich posts with computed properties
    const enrichedPosts = posts.map(post => enrichPost(post, storage, blogId));

    res.json(enrichedPosts);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Helper: Sort posts
function sortPosts(posts, sort) {
  switch (sort) {
    case 'date_asc':
      return posts.sort((a, b) => new Date(a.createdAt) - new Date(b.createdAt));
    case 'title_asc':
      return posts.sort((a, b) => {
        const titleA = a.title || a.content;
        const titleB = b.title || b.content;
        return titleA.localeCompare(titleB);
      });
    case 'title_desc':
      return posts.sort((a, b) => {
        const titleA = a.title || a.content;
        const titleB = b.title || b.content;
        return titleB.localeCompare(titleA);
      });
    case 'date_desc':
    default:
      return posts.sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));
  }
}

// GET /api/blogs/:blogId/posts/:id - Get single post
router.get('/:id', (req, res) => {
  try {
    const storage = getStorage(req);
    const { blogId, id } = req.params;

    const post = storage.getPost(blogId, id);

    if (!post) {
      return res.status(404).json({ error: 'Post not found' });
    }

    res.json(enrichPost(post, storage, blogId));
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// POST /api/blogs/:blogId/posts - Create new post
router.post('/', (req, res) => {
  try {
    const storage = getStorage(req);
    const { blogId } = req.params;
    const { title, content, isDraft, categoryId, tagIds, embed, createdAt } = req.body;

    if (!content) {
      return res.status(400).json({ error: 'Post content is required' });
    }

    // Generate stub from title or content
    const baseStub = generateStub(title || content);
    const existingPosts = storage.getAllPosts(blogId, true);
    const existingStubs = existingPosts.map(p => p.stub);
    const stub = makeStubUnique(baseStub, existingStubs);

    const postData = {
      title: title || null,
      content,
      stub,
      isDraft: isDraft !== false,
      categoryId: categoryId || null,
      tagIds: tagIds || [],
      embed: processEmbed(embed),
      createdAt: createdAt || new Date().toISOString()
    };

    const post = storage.createPost(blogId, postData);
    res.status(201).json(enrichPost(post, storage, blogId));
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// PUT /api/blogs/:blogId/posts/:id - Update post
router.put('/:id', (req, res) => {
  try {
    const storage = getStorage(req);
    const { blogId, id } = req.params;
    const { title, content, ...rest } = req.body;

    const existingPost = storage.getPost(blogId, id);
    if (!existingPost) {
      return res.status(404).json({ error: 'Post not found' });
    }

    // Regenerate stub if title or content changed
    let stub = existingPost.stub;
    const newTitle = title !== undefined ? title : existingPost.title;
    const newContent = content !== undefined ? content : existingPost.content;

    if (title !== undefined || content !== undefined) {
      const baseStub = generateStub(newTitle || newContent);
      const existingPosts = storage.getAllPosts(blogId, true);
      const existingStubs = existingPosts
        .filter(p => p.id !== id)
        .map(p => p.stub);
      stub = makeStubUnique(baseStub, existingStubs);
    }

    const updateData = {
      ...rest,
      title: newTitle,
      content: newContent,
      stub
    };

    if (rest.embed !== undefined) {
      updateData.embed = processEmbed(rest.embed);
    }

    const post = storage.updatePost(blogId, id, updateData);
    res.json(enrichPost(post, storage, blogId));
  } catch (error) {
    if (error.message.includes('not found')) {
      return res.status(404).json({ error: error.message });
    }
    res.status(500).json({ error: error.message });
  }
});

// DELETE /api/blogs/:blogId/posts/:id - Delete post
router.delete('/:id', (req, res) => {
  try {
    const storage = getStorage(req);
    const { blogId, id } = req.params;

    storage.deletePost(blogId, id);
    res.status(204).send();
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Helper: Process embed data
function processEmbed(embed) {
  if (!embed) return null;

  const processed = {
    type: embed.type,
    url: embed.url || '',
    position: embed.position || 'below'
  };

  if (embed.type === 'youtube') {
    processed.videoId = extractYouTubeId(embed.url);
  } else if (embed.type === 'link') {
    processed.title = embed.title || '';
    processed.description = embed.description || '';
    processed.imageUrl = embed.imageUrl || '';
    processed.imageData = embed.imageData || null;
  } else if (embed.type === 'image') {
    processed.images = embed.images || [];
  }

  return processed;
}

// Helper: Enrich post with computed properties
function enrichPost(post, storage, blogId) {
  const enriched = {
    ...post,
    urlPath: `${formatDatePath(post.createdAt)}/${post.stub}`,
    displayTitle: post.title || getExcerpt(post.content, 50),
    formattedDate: formatDate(post.createdAt),
    shortFormattedDate: formatShortDate(post.createdAt)
  };

  // Add category info
  if (post.categoryId) {
    const category = storage.getCategory(blogId, post.categoryId);
    if (category) {
      enriched.category = {
        id: category.id,
        name: category.name,
        stub: category.stub
      };
    }
  }

  // Add tags info
  if (post.tagIds && post.tagIds.length > 0) {
    enriched.tags = post.tagIds
      .map(tagId => storage.getTag(blogId, tagId))
      .filter(tag => tag !== null)
      .map(tag => ({
        id: tag.id,
        name: tag.name,
        stub: tag.stub
      }));
  } else {
    enriched.tags = [];
  }

  return enriched;
}

export default router;
