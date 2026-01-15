import simpleGit from 'simple-git';
import fs from 'fs';
import path from 'path';
import os from 'os';

const HASH_FILE_PATH = '.postalgic/hashes.json';

/**
 * Git Publisher
 * Publishes generated site to a Git repository (e.g., GitHub Pages)
 * Supports both HTTPS (with username/token) and SSH (with private key) authentication
 */
export class GitPublisher {
  constructor(config) {
    this.repositoryUrl = config.repositoryUrl;
    this.username = config.username;
    this.token = config.token; // Personal access token (for HTTPS)
    this.privateKey = config.privateKey; // SSH private key (for SSH URLs)
    this.branch = config.branch || 'main';
    this.commitMessage = config.commitMessage || 'Update blog';
    this.authorName = config.authorName || 'Postalgic';
    this.authorEmail = config.authorEmail || 'postalgic@localhost';
    this.sshKeyPath = null; // Temp file path for SSH key during operations
  }

  /**
   * Check if the repository URL is an SSH URL
   * SSH URLs: git@github.com:user/repo.git or ssh://git@github.com/user/repo.git
   */
  isSSHUrl() {
    const url = this.repositoryUrl || '';
    return url.startsWith('git@') || url.startsWith('ssh://');
  }

  /**
   * Create a temporary SSH key file for git operations
   * @returns {string} Path to the temporary key file
   */
  createTempSSHKey() {
    if (!this.privateKey) {
      throw new Error('SSH private key is required for SSH URLs');
    }

    const keyPath = path.join(os.tmpdir(), `postalgic-ssh-key-${Date.now()}`);
    // Ensure the key has a trailing newline (required by SSH)
    const keyContent = this.privateKey.trim() + '\n';
    fs.writeFileSync(keyPath, keyContent, { mode: 0o600 });
    this.sshKeyPath = keyPath;
    return keyPath;
  }

  /**
   * Clean up the temporary SSH key file
   */
  cleanupSSHKey() {
    if (this.sshKeyPath && fs.existsSync(this.sshKeyPath)) {
      try {
        fs.unlinkSync(this.sshKeyPath);
      } catch (e) {
        console.warn('[Git Publisher] Could not clean up SSH key file:', e.message);
      }
      this.sshKeyPath = null;
    }
  }

  /**
   * Create a simple-git instance configured for SSH or HTTPS
   * @param {string} workDir - Working directory for git operations
   * @returns {SimpleGit} Configured simple-git instance
   */
  createGitInstance(workDir) {
    if (this.isSSHUrl() && this.privateKey) {
      const keyPath = this.sshKeyPath || this.createTempSSHKey();
      // Configure git to use the SSH key
      // StrictHostKeyChecking=accept-new automatically accepts new host keys
      return simpleGit(workDir, {
        config: [
          `core.sshCommand=ssh -i "${keyPath}" -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/dev/null`
        ]
      });
    }
    return simpleGit(workDir);
  }

  /**
   * Get the repository URL for cloning
   * For HTTPS, embeds credentials; for SSH, returns the URL as-is
   */
  getCloneUrl() {
    if (this.isSSHUrl()) {
      return this.repositoryUrl;
    }
    return this.buildAuthenticatedUrl();
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
      // Create SSH key file if using SSH authentication
      if (this.isSSHUrl() && this.privateKey) {
        this.createTempSSHKey();
      }

      const git = this.createGitInstance(tempDir);
      const repoUrl = this.getCloneUrl();

      if (onProgress) onProgress(1, 5, 'Cloning repository...');

      // Clone repository
      await git.clone(repoUrl, tempDir, ['--branch', this.branch, '--single-branch']);

      // Reinitialize git instance after clone (with same SSH config if applicable)
      const repoGit = this.createGitInstance(tempDir);

      // Configure git user
      await repoGit.addConfig('user.name', this.authorName);
      await repoGit.addConfig('user.email', this.authorEmail);

      if (onProgress) onProgress(2, 5, 'Preparing files...');

      // Read previous hash file to know which files Postalgic manages
      const hashFilePath = path.join(tempDir, HASH_FILE_PATH);
      let previouslyManagedFiles = new Set();

      if (fs.existsSync(hashFilePath)) {
        try {
          const hashData = JSON.parse(fs.readFileSync(hashFilePath, 'utf8'));
          if (hashData.fileHashes) {
            previouslyManagedFiles = new Set(Object.keys(hashData.fileHashes));
          }
          console.log('[Git Publisher] Found', previouslyManagedFiles.size, 'previously managed files');
        } catch (e) {
          console.warn('[Git Publisher] Could not parse previous hash file:', e.message);
        }
      } else {
        console.log('[Git Publisher] No previous hash file found (first publish)');
      }

      // Get list of new files being published
      const newFiles = this.getLocalFiles(sourceDir);
      const newFilePaths = new Set(newFiles.map(f => f.key));

      // Delete files that were previously managed by Postalgic but are no longer in the new publish
      // This preserves files like CNAME, README.md, LICENSE that weren't created by Postalgic
      let deletedCount = 0;
      for (const oldFile of previouslyManagedFiles) {
        if (!newFilePaths.has(oldFile)) {
          const oldFilePath = path.join(tempDir, oldFile);
          if (fs.existsSync(oldFilePath)) {
            fs.rmSync(oldFilePath, { recursive: true, force: true });
            deletedCount++;
            console.log('[Git Publisher] Deleted removed file:', oldFile);
          }
        }
      }

      // Also always clean the .postalgic directory since we'll rewrite it
      const postalgicDir = path.join(tempDir, '.postalgic');
      if (fs.existsSync(postalgicDir)) {
        fs.rmSync(postalgicDir, { recursive: true, force: true });
      }

      if (deletedCount > 0) {
        console.log('[Git Publisher] Deleted', deletedCount, 'files no longer in publish');
      }

      // Copy new files (will overwrite existing files with same name)
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
      // Clean up SSH key file
      this.cleanupSSHKey();

      // Clean up temp directory
      try {
        fs.rmSync(tempDir, { recursive: true, force: true });
      } catch (err) {
        console.warn(`Could not clean up temp directory: ${err.message}`);
      }
    }
  }

  /**
   * Get all local files recursively with relative paths
   * @param {string} dir - Directory to scan
   * @param {string} basePath - Base path for relative paths
   * @returns {Array<{key: string, fullPath: string}>}
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
      // Create SSH key file if using SSH authentication
      if (this.isSSHUrl() && this.privateKey) {
        this.createTempSSHKey();
      }

      const git = this.createGitInstance(tempDir);
      const repoUrl = this.getCloneUrl();

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
      // Clean up SSH key file
      this.cleanupSSHKey();

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
