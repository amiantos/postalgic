import sharp from 'sharp';

/**
 * Process and optimize an image
 * @param {Buffer} buffer - Image buffer
 * @param {Object} options - Processing options
 * @returns {Promise<Buffer>} - Processed image buffer
 */
export async function processImage(buffer, options = {}) {
  const {
    maxDimension = 1024,
    quality = 80,
    resize = null,
    format = null,
    stripMetadata = true
  } = options;

  let image = sharp(buffer);

  // Get metadata
  const metadata = await image.metadata();

  // Strip EXIF and other metadata
  if (stripMetadata) {
    image = image.rotate(); // Auto-rotate based on EXIF then strip
  }

  // Resize if specific dimensions provided
  if (resize) {
    image = image.resize({
      width: resize.width,
      height: resize.height,
      fit: resize.fit || 'inside',
      withoutEnlargement: resize.withoutEnlargement !== false
    });
  }
  // Otherwise constrain to max dimension
  else if (maxDimension && (metadata.width > maxDimension || metadata.height > maxDimension)) {
    image = image.resize({
      width: maxDimension,
      height: maxDimension,
      fit: 'inside',
      withoutEnlargement: true
    });
  }

  // Convert to specified format or optimize existing format
  const outputFormat = format || metadata.format;

  switch (outputFormat) {
    case 'jpeg':
    case 'jpg':
      image = image.jpeg({ quality, mozjpeg: true });
      break;
    case 'png':
      image = image.png({ compressionLevel: 9 });
      break;
    case 'webp':
      image = image.webp({ quality });
      break;
    case 'gif':
      // Convert GIF to PNG for static images
      image = image.png({ compressionLevel: 9 });
      break;
    default:
      // Default to JPEG for unknown formats
      image = image.jpeg({ quality, mozjpeg: true });
  }

  return image.toBuffer();
}

/**
 * Generate favicon sizes from source image
 * @param {Buffer} buffer - Source image buffer
 * @returns {Promise<Object>} - Object with different favicon sizes
 */
export async function generateFavicons(buffer) {
  const sizes = [
    { name: 'favicon-32x32.png', width: 32, height: 32 },
    { name: 'favicon-192x192.png', width: 192, height: 192 },
    { name: 'apple-touch-icon.png', width: 180, height: 180 }
  ];

  const favicons = {};

  for (const size of sizes) {
    favicons[size.name] = await sharp(buffer)
      .resize(size.width, size.height, { fit: 'cover' })
      .png()
      .toBuffer();
  }

  return favicons;
}

/**
 * Get image dimensions
 * @param {Buffer} buffer - Image buffer
 * @returns {Promise<Object>} - { width, height, format }
 */
export async function getImageMetadata(buffer) {
  const metadata = await sharp(buffer).metadata();
  return {
    width: metadata.width,
    height: metadata.height,
    format: metadata.format
  };
}
