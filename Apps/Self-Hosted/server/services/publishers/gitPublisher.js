import simpleGit from 'simple-git';
import fs from 'fs';
import path from 'path';
import os from 'os';

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
}

export default GitPublisher;
