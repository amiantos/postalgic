import simpleGit from 'simple-git';
import fs from 'fs';
import path from 'path';
import os from 'os';

const HASH_FILE_PATH = '.postalgic/hashes.json';

/**
 * Git Publisher
 * Publishes generated site to a Git repository (e.g., GitHub Pages)
 */
export class GitPublisher {
  constructor(config) {
    this.repositoryUrl = config.repositoryUrl;
    this.username = config.username;
    this.token = config.token; // Personal access token
    this.branch = config.branch || 'main';
    this.commitMessage = config.commitMessage || 'Update blog';
    this.authorName = config.authorName || 'Postalgic';
    this.authorEmail = config.authorEmail || 'postalgic@localhost';
  }

  /**
   * Publish files to Git repository
   * @param {string} sourceDir - Directory containing files to upload
   * @param {function} onProgress - Progress callback (current, total, message)
   * @returns {Promise<Object>} - Result with commit info
   */
  async publish(sourceDir, onProgress = null) {
    // Create temp directory for git operations
    const tempDir = path.join(os.tmpdir(), `postalgic-git-${Date.now()}`);
    fs.mkdirSync(tempDir, { recursive: true });

    try {
      const git = simpleGit(tempDir);

      // Build authenticated URL
      const repoUrl = this.buildAuthenticatedUrl();

      if (onProgress) onProgress(1, 5, 'Cloning repository...');

      // Clone repository
      await git.clone(repoUrl, tempDir, ['--branch', this.branch, '--single-branch']);

      // Reinitialize git instance after clone
      const repoGit = simpleGit(tempDir);

      // Configure git user
      await repoGit.addConfig('user.name', this.authorName);
      await repoGit.addConfig('user.email', this.authorEmail);

      if (onProgress) onProgress(2, 5, 'Preparing files...');

      // Clear existing files (except .git)
      const existingFiles = fs.readdirSync(tempDir);
      for (const file of existingFiles) {
        if (file !== '.git') {
          const fullPath = path.join(tempDir, file);
          fs.rmSync(fullPath, { recursive: true, force: true });
        }
      }

      // Copy new files
      this.copyDirectory(sourceDir, tempDir);

      if (onProgress) onProgress(3, 5, 'Staging changes...');

      // Add all changes
      await repoGit.add('-A');

      // Check if there are changes
      const status = await repoGit.status();
      if (status.files.length === 0) {
        return {
          success: true,
          committed: false,
          message: 'No changes to publish'
        };
      }

      if (onProgress) onProgress(4, 5, 'Committing changes...');

      // Commit changes
      const commitResult = await repoGit.commit(this.commitMessage);

      if (onProgress) onProgress(5, 5, 'Pushing to remote...');

      // Push to remote
      await repoGit.push('origin', this.branch);

      return {
        success: true,
        committed: true,
        commit: commitResult.commit,
        summary: {
          insertions: commitResult.summary.insertions,
          deletions: commitResult.summary.deletions,
          changed: status.files.length
        }
      };
    } finally {
      // Clean up temp directory
      try {
        fs.rmSync(tempDir, { recursive: true, force: true });
      } catch (err) {
        console.warn(`Could not clean up temp directory: ${err.message}`);
      }
    }
  }

  /**
   * Build authenticated URL with credentials
   */
  buildAuthenticatedUrl() {
    // Parse the repository URL
    let url = this.repositoryUrl;

    // Remove any existing credentials from URL
    url = url.replace(/\/\/[^@]+@/, '//');

    // Handle HTTPS URLs
    if (url.startsWith('https://')) {
      const [protocol, rest] = url.split('://');
      if (this.username && this.token) {
        return `${protocol}://${encodeURIComponent(this.username)}:${encodeURIComponent(this.token)}@${rest}`;
      }
    }

    return url;
  }

  /**
   * Copy directory recursively
   */
  copyDirectory(src, dest) {
    const entries = fs.readdirSync(src, { withFileTypes: true });

    for (const entry of entries) {
      const srcPath = path.join(src, entry.name);
      const destPath = path.join(dest, entry.name);

      if (entry.isDirectory()) {
        fs.mkdirSync(destPath, { recursive: true });
        this.copyDirectory(srcPath, destPath);
      } else {
        fs.copyFileSync(srcPath, destPath);
      }
    }
  }

  /**
   * Fetch remote hash file by cloning repo and reading the file
   * @returns {Promise<Object|null>} - Hash data or null if not found
   */
  async fetchRemoteHashes() {
    const tempDir = path.join(os.tmpdir(), `postalgic-git-fetch-${Date.now()}`);
    fs.mkdirSync(tempDir, { recursive: true });

    console.log('[Git Publisher] Fetching remote hashes from repo...');

    try {
      const git = simpleGit(tempDir);
      const repoUrl = this.buildAuthenticatedUrl();

      // Clone only the specific file if possible, otherwise shallow clone
      await git.clone(repoUrl, tempDir, ['--branch', this.branch, '--single-branch', '--depth', '1']);

      // Check if hash file exists
      const hashFilePath = path.join(tempDir, HASH_FILE_PATH);
      if (!fs.existsSync(hashFilePath)) {
        console.log('[Git Publisher] No remote hash file found (first publish or old version)');
        return null;
      }

      // Read and parse the hash file
      const content = fs.readFileSync(hashFilePath, 'utf8');
      const hashData = JSON.parse(content);
      console.log('[Git Publisher] Remote hashes found, published by:', hashData.publishedBy || 'unknown');
      console.log('[Git Publisher] Remote hash count:', Object.keys(hashData.fileHashes || {}).length);
      return hashData;
    } catch (error) {
      console.error('[Git Publisher] Error fetching remote hashes:', error.message);
      return null;
    } finally {
      try {
        fs.rmSync(tempDir, { recursive: true, force: true });
      } catch (e) { /* ignore */ }
    }
  }

  /**
   * Write hash file to the source directory so it gets committed with the site
   * @param {string} sourceDir - The generated site directory
   * @param {Object} fileHashes - Map of file paths to hashes
   * @param {string} publishedBy - Identifier of the publishing client
   */
  writeHashFile(sourceDir, fileHashes, publishedBy = 'self-hosted') {
    console.log('[Git Publisher] Writing hash file with', Object.keys(fileHashes).length, 'entries');

    const hashData = {
      version: 1,
      lastPublishedDate: new Date().toISOString(),
      publishedBy,
      fileHashes
    };

    // Ensure .postalgic directory exists
    const hashDir = path.join(sourceDir, '.postalgic');
    if (!fs.existsSync(hashDir)) {
      fs.mkdirSync(hashDir, { recursive: true });
    }

    // Write the hash file
    const hashFilePath = path.join(sourceDir, HASH_FILE_PATH);
    fs.writeFileSync(hashFilePath, JSON.stringify(hashData, null, 2));
    console.log('[Git Publisher] Hash file written to:', hashFilePath);
  }
}

export default GitPublisher;
