import SftpClient from 'ssh2-sftp-client';
import fs from 'fs';
import path from 'path';

const HASH_FILE_PATH = '.postalgic/hashes.json';

/**
 * SFTP Publisher
 * Uploads generated site files to a remote server via SFTP
 */
export class SFTPPublisher {
  constructor(config) {
    this.host = config.host;
    this.port = config.port || 22;
    this.username = config.username;
    this.password = config.password;
    this.privateKey = config.privateKey;
    this.remotePath = config.remotePath || '/';
  }

  /**
   * Publish files via SFTP
   * @param {string} sourceDir - Directory containing files to upload
   * @param {function} onProgress - Progress callback (current, total, filename)
   * @param {Object} options - Publishing options
   * @param {boolean} options.forceUploadAll - Force upload all files
   * @param {Object} options.currentHashes - Current file hashes from site generator
   * @param {Object} options.previousHashes - Previous file hashes from last publish
   * @returns {Promise<Object>} - Result with uploaded and deleted file counts
   */
  async publish(sourceDir, onProgress = null, options = {}) {
    const { forceUploadAll = false, currentHashes = {}, previousHashes = {} } = options;
    const sftp = new SftpClient();

    console.log('[SFTP Publisher] Starting publish to:', `${this.host}:${this.port}${this.remotePath}`);
    console.log('[SFTP Publisher] Force upload all:', forceUploadAll);
    console.log('[SFTP Publisher] Using hash-based change detection:', Object.keys(previousHashes).length > 0);

    try {
      // Connect to SFTP server
      const connectionConfig = {
        host: this.host,
        port: this.port,
        username: this.username
      };

      if (this.privateKey) {
        connectionConfig.privateKey = this.privateKey;
      } else if (this.password) {
        connectionConfig.password = this.password;
      }

      console.log('[SFTP Publisher] Connecting...');
      await sftp.connect(connectionConfig);
      console.log('[SFTP Publisher] Connected successfully');

      // Ensure remote directory exists
      await this.ensureRemoteDir(sftp, this.remotePath);

      // Get local files
      console.log('[SFTP Publisher] Scanning local files...');
      const localFiles = this.getLocalFiles(sourceDir);
      console.log(`[SFTP Publisher] Found ${localFiles.length} local files`);

      // Get remote files
      console.log('[SFTP Publisher] Listing remote files...');
      const remoteFiles = await this.listRemoteFiles(sftp, this.remotePath);
      console.log(`[SFTP Publisher] Found ${remoteFiles.length} remote files`);

      const filesToUpload = [];
      const filesToDelete = [];

      // Find files to upload (new or modified)
      for (const localFile of localFiles) {
        const remoteFile = remoteFiles.find(f => f.key === localFile.key);

        if (forceUploadAll) {
          // Force upload all files
          filesToUpload.push(localFile);
        } else if (!remoteFile) {
          // New file - doesn't exist on remote
          console.log(`[SFTP Publisher] New file: ${localFile.key}`);
          filesToUpload.push(localFile);
        } else if (Object.keys(previousHashes).length > 0) {
          // Use hash comparison if we have previous hashes
          const currentHash = currentHashes[localFile.key];
          const previousHash = previousHashes[localFile.key];

          if (!previousHash) {
            // File exists on remote but we don't have a previous hash - upload it
            console.log(`[SFTP Publisher] No previous hash for: ${localFile.key}`);
            filesToUpload.push(localFile);
          } else if (currentHash !== previousHash) {
            // File content has changed
            console.log(`[SFTP Publisher] Modified file: ${localFile.key}`);
            filesToUpload.push(localFile);
          }
        } else {
          // Fallback to size comparison if no hashes available
          if (remoteFile.size !== localFile.size) {
            console.log(`[SFTP Publisher] Size changed: ${localFile.key}`);
            filesToUpload.push(localFile);
          }
        }
      }

      // Find files to delete (not in local, excluding .postalgic/ which is managed separately)
      for (const remoteFile of remoteFiles) {
        if (!remoteFile.isDirectory && !remoteFile.key.startsWith('.postalgic/')) {
          const localFile = localFiles.find(f => f.key === remoteFile.key);
          if (!localFile) {
            filesToDelete.push(remoteFile);
          }
        }
      }

      console.log(`[SFTP Publisher] Files to upload: ${filesToUpload.length}, Files to delete: ${filesToDelete.length}`);

      const totalOperations = filesToUpload.length + filesToDelete.length;
      let currentOperation = 0;

      // Upload files
      for (const file of filesToUpload) {
        currentOperation++;
        if (onProgress) {
          onProgress(currentOperation, totalOperations, file.key);
        }

        const remotePath = path.posix.join(this.remotePath, file.key);
        const remoteDir = path.posix.dirname(remotePath);

        // Ensure directory exists
        await this.ensureRemoteDir(sftp, remoteDir);

        // Upload file
        console.log(`[SFTP Publisher] Uploading (${currentOperation}/${filesToUpload.length}): ${file.key}`);
        try {
          await sftp.put(file.fullPath, remotePath);
        } catch (uploadError) {
          console.error(`[SFTP Publisher] Failed to upload ${file.key}:`, uploadError.message);
          throw uploadError;
        }
      }

      if (filesToUpload.length > 0) {
        console.log('[SFTP Publisher] All uploads completed successfully');
      } else {
        console.log('[SFTP Publisher] No files needed uploading (all up to date)');
      }

      // Delete removed files
      for (const file of filesToDelete) {
        currentOperation++;
        if (onProgress) {
          onProgress(currentOperation, totalOperations, `Deleting ${file.key}`);
        }

        const remotePath = path.posix.join(this.remotePath, file.key);
        console.log(`[SFTP Publisher] Deleting: ${file.key}`);
        try {
          await sftp.delete(remotePath);
        } catch (err) {
          // File might already be deleted, ignore
          console.warn(`[SFTP Publisher] Could not delete ${remotePath}: ${err.message}`);
        }
      }

      // Clean up empty directories
      await this.cleanEmptyDirs(sftp, this.remotePath);

      console.log(`[SFTP Publisher] Publish complete: ${filesToUpload.length} uploaded, ${filesToDelete.length} deleted, ${localFiles.length} total`);

      return {
        uploaded: filesToUpload.length,
        deleted: filesToDelete.length,
        total: localFiles.length
      };
    } finally {
      await sftp.end();
    }
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
        const stats = fs.statSync(fullPath);
        files.push({ key, fullPath, size: stats.size });
      }
    }

    return files;
  }

  /**
   * List all remote files recursively
   */
  async listRemoteFiles(sftp, dir, basePath = '') {
    const files = [];

    try {
      const entries = await sftp.list(dir);

      for (const entry of entries) {
        const key = basePath ? `${basePath}/${entry.name}` : entry.name;

        if (entry.type === 'd') {
          // Directory - recurse
          const subDir = path.posix.join(dir, entry.name);
          files.push(...await this.listRemoteFiles(sftp, subDir, key));
        } else {
          files.push({
            key,
            size: entry.size,
            isDirectory: false
          });
        }
      }
    } catch (err) {
      // Directory might not exist
      if (err.code !== 2) { // ENOENT
        throw err;
      }
    }

    return files;
  }

  /**
   * Ensure remote directory exists
   */
  async ensureRemoteDir(sftp, dirPath) {
    try {
      await sftp.mkdir(dirPath, true);
    } catch (err) {
      // Directory might already exist
      if (!err.message.includes('already exists')) {
        throw err;
      }
    }
  }

  /**
   * Clean up empty directories
   */
  async cleanEmptyDirs(sftp, dir) {
    try {
      const entries = await sftp.list(dir);

      for (const entry of entries) {
        if (entry.type === 'd') {
          const subDir = path.posix.join(dir, entry.name);
          await this.cleanEmptyDirs(sftp, subDir);

          // Check if directory is now empty
          const subEntries = await sftp.list(subDir);
          if (subEntries.length === 0) {
            await sftp.rmdir(subDir);
          }
        }
      }
    } catch (err) {
      // Ignore errors during cleanup
      console.warn(`Error cleaning directories: ${err.message}`);
    }
  }

  /**
   * Normalize remote path (ensure forward slashes)
   */
  normalizeRemotePath(filePath) {
    return filePath.replace(/\\/g, '/');
  }

  /**
   * Fetch remote hash file from SFTP server
   * @returns {Promise<Object|null>} - Hash data or null if not found
   */
  async fetchRemoteHashes() {
    const sftp = new SftpClient();
    console.log('[SFTP Publisher] Fetching remote hashes from:', HASH_FILE_PATH);

    try {
      const connectionConfig = {
        host: this.host,
        port: this.port,
        username: this.username
      };

      if (this.privateKey) {
        connectionConfig.privateKey = this.privateKey;
      } else if (this.password) {
        connectionConfig.password = this.password;
      }

      await sftp.connect(connectionConfig);
      const remotePath = path.posix.join(this.remotePath, HASH_FILE_PATH);

      // Check if file exists
      const exists = await sftp.exists(remotePath);
      if (!exists) {
        console.log('[SFTP Publisher] No remote hash file found (first publish or old version)');
        await sftp.end();
        return null;
      }

      // Download and parse the file
      const buffer = await sftp.get(remotePath);
      const hashData = JSON.parse(buffer.toString());
      console.log('[SFTP Publisher] Remote hashes found, published by:', hashData.publishedBy || 'unknown');
      console.log('[SFTP Publisher] Remote hash count:', Object.keys(hashData.fileHashes || {}).length);
      await sftp.end();
      return hashData;
    } catch (error) {
      console.error('[SFTP Publisher] Error fetching remote hashes:', error.message);
      try { await sftp.end(); } catch (e) { /* ignore */ }
      return null;
    }
  }

  /**
   * Upload hash file to SFTP server after successful publish
   * @param {Object} fileHashes - Map of file paths to hashes
   * @param {string} publishedBy - Identifier of the publishing client
   */
  async uploadHashFile(fileHashes, publishedBy = 'self-hosted') {
    const sftp = new SftpClient();
    console.log('[SFTP Publisher] Uploading hash file with', Object.keys(fileHashes).length, 'entries');

    const hashData = {
      version: 1,
      lastPublishedDate: new Date().toISOString(),
      publishedBy,
      fileHashes
    };

    try {
      const connectionConfig = {
        host: this.host,
        port: this.port,
        username: this.username
      };

      if (this.privateKey) {
        connectionConfig.privateKey = this.privateKey;
      } else if (this.password) {
        connectionConfig.password = this.password;
      }

      await sftp.connect(connectionConfig);

      // Ensure .postalgic directory exists
      const hashDir = path.posix.join(this.remotePath, '.postalgic');
      await this.ensureRemoteDir(sftp, hashDir);

      // Upload the hash file
      const remotePath = path.posix.join(this.remotePath, HASH_FILE_PATH);
      const content = Buffer.from(JSON.stringify(hashData, null, 2));
      await sftp.put(content, remotePath);

      console.log('[SFTP Publisher] Hash file uploaded successfully');
      await sftp.end();
    } catch (error) {
      console.error('[SFTP Publisher] Error uploading hash file:', error.message);
      try { await sftp.end(); } catch (e) { /* ignore */ }
      // Don't throw - hash file upload failure shouldn't fail the whole publish
    }
  }
}

export default SFTPPublisher;
