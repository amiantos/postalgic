import express from 'express';
import { fetchMetadata, fetchYouTubeTitle } from '../services/metadataService.js';
import { extractYouTubeId } from '../utils/helpers.js';

const router = express.Router();

// GET /api/metadata?url=... - Fetch metadata for a URL
router.get('/', async (req, res) => {
  try {
    const { url } = req.query;

    if (!url) {
      return res.status(400).json({ error: 'URL parameter is required' });
    }

    // Validate URL
    try {
      new URL(url);
    } catch {
      return res.status(400).json({ error: 'Invalid URL format' });
    }

    // Check if it's a YouTube URL
    const youtubeId = extractYouTubeId(url);

    if (youtubeId) {
      // Fetch YouTube title
      const title = await fetchYouTubeTitle(url);
      return res.json({
        type: 'youtube',
        videoId: youtubeId,
        title,
        description: null,
        imageUrl: null,
        imageData: null
      });
    }

    // Fetch general metadata
    const metadata = await fetchMetadata(url);

    res.json({
      type: 'link',
      ...metadata
    });
  } catch (error) {
    console.error('Metadata fetch error:', error);
    res.status(500).json({ error: 'Failed to fetch metadata' });
  }
});

export default router;
