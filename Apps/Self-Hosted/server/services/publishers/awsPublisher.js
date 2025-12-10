import { S3Client, PutObjectCommand, ListObjectsV2Command, DeleteObjectsCommand } from '@aws-sdk/client-s3';
import { CloudFrontClient, CreateInvalidationCommand } from '@aws-sdk/client-cloudfront';
import fs from 'fs';
import path from 'path';
import mime from 'mime-types';

/**
 * AWS S3 Publisher
 * Uploads generated site files to AWS S3 and optionally invalidates CloudFront cache
 */
export class AWSPublisher {
  constructor(config) {
    this.bucket = config.bucket;
    this.region = config.region;
    this.cloudFrontDistId = config.cloudFrontDistId;
    this.accessKeyId = config.accessKeyId;
    this.secretAccessKey = config.secretAccessKey;

    const credentials = {
      accessKeyId: this.accessKeyId,
      secretAccessKey: this.secretAccessKey
    };

    this.s3Client = new S3Client({
      region: this.region,
      credentials
    });

    if (this.cloudFrontDistId) {
      this.cloudFrontClient = new CloudFrontClient({
        region: this.region,
        credentials
      });
    }
  }

  /**
   * Publish files to S3
   * @param {string} sourceDir - Directory containing files to upload
   * @param {function} onProgress - Progress callback (current, total, filename)
   * @returns {Promise<Object>} - Result with uploaded and deleted file counts
   */
  async publish(sourceDir, onProgress = null) {
    const localFiles = this.getLocalFiles(sourceDir);
    const remoteFiles = await this.listRemoteFiles();

    const filesToUpload = [];
    const filesToDelete = [];

    // Find files to upload (new or modified)
    for (const localFile of localFiles) {
      const remoteFile = remoteFiles.find(f => f.key === localFile.key);
      if (!remoteFile) {
        filesToUpload.push(localFile);
      }
      // Note: Could add ETag comparison for modification detection
    }

    // Find files to delete (not in local)
    for (const remoteFile of remoteFiles) {
      const localFile = localFiles.find(f => f.key === remoteFile.key);
      if (!localFile) {
        filesToDelete.push(remoteFile);
      }
    }

    const totalOperations = filesToUpload.length + (filesToDelete.length > 0 ? 1 : 0);
    let currentOperation = 0;

    // Upload files
    for (const file of filesToUpload) {
      currentOperation++;
      if (onProgress) {
        onProgress(currentOperation, totalOperations, file.key);
      }

      const fileContent = fs.readFileSync(file.fullPath);
      const contentType = mime.lookup(file.key) || 'application/octet-stream';

      await this.s3Client.send(new PutObjectCommand({
        Bucket: this.bucket,
        Key: file.key,
        Body: fileContent,
        ContentType: contentType,
        CacheControl: this.getCacheControl(file.key)
      }));
    }

    // Delete removed files
    if (filesToDelete.length > 0) {
      currentOperation++;
      if (onProgress) {
        onProgress(currentOperation, totalOperations, 'Deleting old files...');
      }

      // S3 DeleteObjects can handle up to 1000 keys at once
      const batches = this.chunkArray(filesToDelete, 1000);
      for (const batch of batches) {
        await this.s3Client.send(new DeleteObjectsCommand({
          Bucket: this.bucket,
          Delete: {
            Objects: batch.map(f => ({ Key: f.key }))
          }
        }));
      }
    }

    // Invalidate CloudFront cache if configured
    if (this.cloudFrontClient && this.cloudFrontDistId && filesToUpload.length > 0) {
      await this.invalidateCloudFront(filesToUpload.map(f => '/' + f.key));
    }

    return {
      uploaded: filesToUpload.length,
      deleted: filesToDelete.length,
      total: localFiles.length
    };
  }

  /**
   * Get all local files recursively
   */
  getLocalFiles(dir, basePath = '') {
    const files = [];
    const entries = fs.readdirSync(dir, { withFileTypes: true });

    for (const entry of entries) {
      const fullPath = path.join(dir, entry.name);
      const key = basePath ? `${basePath}/${entry.name}` : entry.name;

      if (entry.isDirectory()) {
        files.push(...this.getLocalFiles(fullPath, key));
      } else {
        files.push({ key, fullPath });
      }
    }

    return files;
  }

  /**
   * List all files in S3 bucket
   */
  async listRemoteFiles() {
    const files = [];
    let continuationToken = null;

    do {
      const response = await this.s3Client.send(new ListObjectsV2Command({
        Bucket: this.bucket,
        ContinuationToken: continuationToken
      }));

      if (response.Contents) {
        for (const item of response.Contents) {
          files.push({ key: item.Key, etag: item.ETag });
        }
      }

      continuationToken = response.NextContinuationToken;
    } while (continuationToken);

    return files;
  }

  /**
   * Invalidate CloudFront cache for specified paths
   */
  async invalidateCloudFront(paths) {
    if (!this.cloudFrontClient || !this.cloudFrontDistId) return;

    // CloudFront has a limit on paths, use /* for large invalidations
    const invalidationPaths = paths.length > 100
      ? ['/*']
      : paths.map(p => p.startsWith('/') ? p : '/' + p);

    await this.cloudFrontClient.send(new CreateInvalidationCommand({
      DistributionId: this.cloudFrontDistId,
      InvalidationBatch: {
        CallerReference: Date.now().toString(),
        Paths: {
          Quantity: invalidationPaths.length,
          Items: invalidationPaths
        }
      }
    }));
  }

  /**
   * Get cache control header based on file type
   */
  getCacheControl(filename) {
    const ext = path.extname(filename).toLowerCase();

    // HTML files - no cache to ensure fresh content
    if (ext === '.html') {
      return 'no-cache, no-store, must-revalidate';
    }

    // RSS/XML - short cache
    if (ext === '.xml') {
      return 'public, max-age=3600';
    }

    // Static assets - long cache
    if (['.css', '.js', '.jpg', '.jpeg', '.png', '.gif', '.webp', '.svg', '.ico', '.woff', '.woff2'].includes(ext)) {
      return 'public, max-age=31536000, immutable';
    }

    // Default
    return 'public, max-age=86400';
  }

  /**
   * Split array into chunks
   */
  chunkArray(array, size) {
    const chunks = [];
    for (let i = 0; i < array.length; i += size) {
      chunks.push(array.slice(i, i + size));
    }
    return chunks;
  }
}

export default AWSPublisher;
