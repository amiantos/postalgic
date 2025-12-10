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

    console.log('[AWS Publisher] Initializing with config:', {
      bucket: this.bucket,
      region: this.region,
      cloudFrontDistId: this.cloudFrontDistId || '(not configured)',
      accessKeyId: this.accessKeyId ? `${this.accessKeyId.substring(0, 4)}...` : '(missing)'
    });

    const credentials = {
      accessKeyId: this.accessKeyId,
      secretAccessKey: this.secretAccessKey
    };

    this.s3Client = new S3Client({
      region: this.region,
      credentials
    });
    console.log('[AWS Publisher] S3 client initialized');

    if (this.cloudFrontDistId) {
      this.cloudFrontClient = new CloudFrontClient({
        region: this.region,
        credentials
      });
      console.log('[AWS Publisher] CloudFront client initialized');
    } else {
      console.log('[AWS Publisher] CloudFront not configured, skipping invalidation setup');
    }
  }

  /**
   * Publish files to S3
   * @param {string} sourceDir - Directory containing files to upload
   * @param {function} onProgress - Progress callback (current, total, filename)
   * @returns {Promise<Object>} - Result with uploaded and deleted file counts
   */
  async publish(sourceDir, onProgress = null, options = {}) {
    const { forceUploadAll = false, currentHashes = {}, previousHashes = {} } = options;
    console.log('[AWS Publisher] Starting publish from:', sourceDir);
    console.log('[AWS Publisher] Force upload all:', forceUploadAll);
    console.log('[AWS Publisher] Using hash-based change detection:', Object.keys(previousHashes).length > 0);

    console.log('[AWS Publisher] Scanning local files...');
    const localFiles = this.getLocalFiles(sourceDir);
    console.log(`[AWS Publisher] Found ${localFiles.length} local files`);

    console.log('[AWS Publisher] Listing remote files from S3...');
    const remoteFiles = await this.listRemoteFiles();
    console.log(`[AWS Publisher] Found ${remoteFiles.length} remote files in S3`);

    const filesToUpload = [];
    const filesToDelete = [];

    // Find files to upload (new or modified, or all if forced)
    for (const localFile of localFiles) {
      const remoteFile = remoteFiles.find(f => f.key === localFile.key);

      if (forceUploadAll) {
        // Force upload all files
        filesToUpload.push(localFile);
      } else if (!remoteFile) {
        // New file - doesn't exist in S3
        console.log(`[AWS Publisher] New file: ${localFile.key}`);
        filesToUpload.push(localFile);
      } else if (Object.keys(previousHashes).length > 0) {
        // Use hash comparison if we have previous hashes
        const currentHash = currentHashes[localFile.key];
        const previousHash = previousHashes[localFile.key];

        if (!previousHash) {
          // File exists in S3 but we don't have a previous hash - upload it
          console.log(`[AWS Publisher] No previous hash for: ${localFile.key}`);
          filesToUpload.push(localFile);
        } else if (currentHash !== previousHash) {
          // File content has changed
          console.log(`[AWS Publisher] Modified file: ${localFile.key}`);
          filesToUpload.push(localFile);
        }
      }
      // If no previous hashes and file exists in S3, skip upload (legacy behavior)
    }

    // Find files to delete (not in local)
    for (const remoteFile of remoteFiles) {
      const localFile = localFiles.find(f => f.key === remoteFile.key);
      if (!localFile) {
        filesToDelete.push(remoteFile);
      }
    }

    console.log(`[AWS Publisher] Files to upload: ${filesToUpload.length}, Files to delete: ${filesToDelete.length}`);

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

      console.log(`[AWS Publisher] Uploading (${currentOperation}/${filesToUpload.length}): ${file.key} (${contentType})`);
      try {
        await this.s3Client.send(new PutObjectCommand({
          Bucket: this.bucket,
          Key: file.key,
          Body: fileContent,
          ContentType: contentType,
          CacheControl: this.getCacheControl(file.key)
        }));
      } catch (uploadError) {
        console.error(`[AWS Publisher] Failed to upload ${file.key}:`, uploadError.message);
        throw uploadError;
      }
    }

    if (filesToUpload.length > 0) {
      console.log('[AWS Publisher] All uploads completed successfully');
    } else {
      console.log('[AWS Publisher] No files needed uploading (all up to date)');
    }

    // Delete removed files
    if (filesToDelete.length > 0) {
      currentOperation++;
      if (onProgress) {
        onProgress(currentOperation, totalOperations, 'Deleting old files...');
      }

      console.log(`[AWS Publisher] Deleting ${filesToDelete.length} old files from S3...`);
      // S3 DeleteObjects can handle up to 1000 keys at once
      const batches = this.chunkArray(filesToDelete, 1000);
      for (const batch of batches) {
        try {
          await this.s3Client.send(new DeleteObjectsCommand({
            Bucket: this.bucket,
            Delete: {
              Objects: batch.map(f => ({ Key: f.key }))
            }
          }));
          console.log(`[AWS Publisher] Deleted batch of ${batch.length} files`);
        } catch (deleteError) {
          console.error('[AWS Publisher] Failed to delete files:', deleteError.message);
          throw deleteError;
        }
      }
    }

    // Invalidate CloudFront cache if configured and there were any changes
    const hasChanges = filesToUpload.length > 0 || filesToDelete.length > 0;
    if (this.cloudFrontClient && this.cloudFrontDistId && hasChanges) {
      console.log('[AWS Publisher] Triggering CloudFront invalidation...');
      // Invalidate both uploaded and deleted paths
      const pathsToInvalidate = [
        ...filesToUpload.map(f => '/' + f.key),
        ...filesToDelete.map(f => '/' + f.key)
      ];
      await this.invalidateCloudFront(pathsToInvalidate);
    } else if (!this.cloudFrontDistId) {
      console.log('[AWS Publisher] Skipping CloudFront invalidation (not configured)');
    } else if (!hasChanges) {
      console.log('[AWS Publisher] Skipping CloudFront invalidation (no changes)');
    }

    console.log(`[AWS Publisher] Publish complete: ${filesToUpload.length} uploaded, ${filesToDelete.length} deleted, ${localFiles.length} total`);

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
    let pageCount = 0;

    try {
      do {
        pageCount++;
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
        if (continuationToken) {
          console.log(`[AWS Publisher] Listed page ${pageCount}, ${files.length} files so far, fetching more...`);
        }
      } while (continuationToken);
    } catch (listError) {
      console.error('[AWS Publisher] Failed to list S3 bucket contents:', listError.message);
      throw listError;
    }

    return files;
  }

  /**
   * Invalidate CloudFront cache for specified paths
   */
  async invalidateCloudFront(paths) {
    if (!this.cloudFrontClient || !this.cloudFrontDistId) {
      console.log('[AWS Publisher] CloudFront invalidation skipped - client or distribution ID not configured');
      return;
    }

    // CloudFront has a limit on paths, use /* for large invalidations
    const invalidationPaths = paths.length > 100
      ? ['/*']
      : paths.map(p => p.startsWith('/') ? p : '/' + p);

    console.log(`[AWS Publisher] Creating CloudFront invalidation for ${invalidationPaths.length} paths (distribution: ${this.cloudFrontDistId})`);
    if (invalidationPaths.length <= 10) {
      console.log('[AWS Publisher] Invalidation paths:', invalidationPaths);
    } else {
      console.log(`[AWS Publisher] Invalidation paths (first 10): ${invalidationPaths.slice(0, 10).join(', ')}...`);
    }

    try {
      const result = await this.cloudFrontClient.send(new CreateInvalidationCommand({
        DistributionId: this.cloudFrontDistId,
        InvalidationBatch: {
          CallerReference: Date.now().toString(),
          Paths: {
            Quantity: invalidationPaths.length,
            Items: invalidationPaths
          }
        }
      }));
      console.log('[AWS Publisher] CloudFront invalidation created successfully, ID:', result.Invalidation?.Id);
    } catch (invalidationError) {
      console.error('[AWS Publisher] CloudFront invalidation failed:', invalidationError.message);
      throw invalidationError;
    }
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
