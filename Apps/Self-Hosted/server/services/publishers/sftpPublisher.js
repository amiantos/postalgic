import SftpClient from 'ssh2-sftp-client';
import fs from 'fs';
import path from 'path';

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
   * @returns {Promise<Object>} - Result with uploaded and deleted file counts
   */
  async publish(sourceDir, onProgress = null) {
    const sftp = new SftpClient();

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

      await sftp.connect(connectionConfig);

      // Ensure remote directory exists
      await this.ensureRemoteDir(sftp, this.remotePath);

      // Get local files
      const localFiles = this.getLocalFiles(sourceDir);

      // Get remote files
      const remoteFiles = await this.listRemoteFiles(sftp, this.remotePath);

      const filesToUpload = [];
      const filesToDelete = [];

      // Find files to upload (new or modified by size)
      for (const localFile of localFiles) {
        const remotePath = this.normalizeRemotePath(localFile.key);
        const remoteFile = remoteFiles.find(f => f.key === localFile.key);

        if (!remoteFile || remoteFile.size !== localFile.size) {
          filesToUpload.push(localFile);
        }
      }

      // Find files to delete (not in local)
      for (const remoteFile of remoteFiles) {
        if (!remoteFile.isDirectory) {
          const localFile = localFiles.find(f => f.key === remoteFile.key);
          if (!localFile) {
            filesToDelete.push(remoteFile);
          }
        }
      }

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
        await sftp.put(file.fullPath, remotePath);
      }

      // Delete removed files
      for (const file of filesToDelete) {
        currentOperation++;
        if (onProgress) {
          onProgress(currentOperation, totalOperations, `Deleting ${file.key}`);
        }

        const remotePath = path.posix.join(this.remotePath, file.key);
        try {
          await sftp.delete(remotePath);
        } catch (err) {
          // File might already be deleted, ignore
          console.warn(`Could not delete ${remotePath}: ${err.message}`);
        }
      }

      // Clean up empty directories
      await this.cleanEmptyDirs(sftp, this.remotePath);

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
}

export default SFTPPublisher;
