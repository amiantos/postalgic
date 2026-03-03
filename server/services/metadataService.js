import ogs from 'open-graph-scraper';
import { extractYouTubeId } from '../utils/helpers.js';

// Timeout for outbound fetch requests (10 seconds)
const FETCH_TIMEOUT_MS = 10000;

/**
 * Fetches OpenGraph metadata for a given URL
 * @param {string} urlString - The URL to fetch metadata for
 * @returns {Promise<{title: string|null, description: string|null, imageUrl: string|null, imageData: string|null}>}
 */
export async function fetchMetadata(urlString) {
  try {
    const options = {
      url: urlString,
      timeout: 10000,
      fetchOptions: {
        headers: {
          'user-agent': 'Mozilla/5.0 (compatible; Postalgic/1.0; +https://postalgic.app)'
        }
      }
    };

    const { result } = await ogs(options);

    const title = result.ogTitle || result.twitterTitle || result.dcTitle || null;
    const description = result.ogDescription || result.twitterDescription || result.dcDescription || null;

    // Get the best available image
    let imageUrl = null;
    if (result.ogImage && result.ogImage.length > 0) {
      imageUrl = result.ogImage[0].url;
    } else if (result.twitterImage && result.twitterImage.length > 0) {
      imageUrl = result.twitterImage[0].url;
    }

    // Fetch and convert image to base64 if available
    let imageData = null;
    if (imageUrl) {
      imageData = await fetchImageAsBase64(imageUrl);
    }

    return { title, description, imageUrl, imageData };
  } catch (error) {
    console.error('Error fetching metadata:', error.message);
    return { title: null, description: null, imageUrl: null, imageData: null };
  }
}

/**
 * Fetches YouTube video title
 * @param {string} urlString - The YouTube video URL
 * @returns {Promise<string|null>}
 */
export async function fetchYouTubeTitle(urlString) {
  const videoId = extractYouTubeId(urlString);
  if (!videoId) {
    return null;
  }

  try {
    // Use oEmbed API to get video title (no API key required)
    const oembedUrl = `https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v=${videoId}&format=json`;

    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), FETCH_TIMEOUT_MS);

    try {
      const response = await fetch(oembedUrl, {
        headers: {
          'user-agent': 'Mozilla/5.0 (compatible; Postalgic/1.0; +https://postalgic.app)'
        },
        signal: controller.signal
      });

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`);
      }

      const data = await response.json();
      return data.title || null;
    } finally {
      clearTimeout(timeoutId);
    }
  } catch (error) {
    console.error('Error fetching YouTube title:', error.message);

    // Fallback: try OpenGraph
    try {
      const { title } = await fetchMetadata(urlString);
      return title;
    } catch {
      return null;
    }
  }
}

/**
 * Fetches an image and converts it to base64
 * @param {string} imageUrl - The image URL to fetch
 * @returns {Promise<string|null>} - Base64 encoded image data with data URI prefix
 */
async function fetchImageAsBase64(imageUrl) {
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), FETCH_TIMEOUT_MS);

  try {
    const response = await fetch(imageUrl, {
      headers: {
        'user-agent': 'Mozilla/5.0 (compatible; Postalgic/1.0; +https://postalgic.app)'
      },
      signal: controller.signal
    });

    if (!response.ok) {
      throw new Error(`HTTP ${response.status}`);
    }

    const contentType = response.headers.get('content-type') || 'image/jpeg';
    const arrayBuffer = await response.arrayBuffer();
    const buffer = Buffer.from(arrayBuffer);
    const base64 = buffer.toString('base64');

    return `data:${contentType};base64,${base64}`;
  } catch (error) {
    console.error('Error fetching image:', error.message);
    return null;
  } finally {
    clearTimeout(timeoutId);
  }
}

export { fetchImageAsBase64 };

export default {
  fetchMetadata,
  fetchYouTubeTitle,
  fetchImageAsBase64
};
