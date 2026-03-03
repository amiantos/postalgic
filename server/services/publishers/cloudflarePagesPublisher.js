import { spawn } from 'child_process';
import fs from 'fs';
import path from 'path';

const HASH_FILE_PATH = '.postalgic/hashes.json';

/**
 * Cloudflare Pages Publisher
 * Publishes generated site to Cloudflare Pages using the wrangler CLI (Direct Upload).
 * Auto-creates the Pages project if it doesn't exist.
 */
export class CloudflarePagesPublisher {
  constructor(config) {
    this.accountId = config.accountId;
    this.apiToken = config.apiToken;
    this.projectName = config.projectName;
  }

  /**
   * Run a wrangler command and return { stdout, stderr, code }
   */
  runWrangler(args, onOutput = null) {
    return new Promise((resolve, reject) => {
      const env = {
        ...process.env,
        CLOUDFLARE_ACCOUNT_ID: this.accountId,
        CLOUDFLARE_API_TOKEN: this.apiToken,
      };

      const proc = spawn('npx', ['wrangler', ...args], {
        env,
        stdio: ['ignore', 'pipe', 'pipe'],
        shell: true,
      });

      let stdout = '';
      let stderr = '';

      proc.stdout.on('data', (data) => {
        const text = data.toString();
        stdout += text;
        if (onOutput) onOutput(text);
      });

      proc.stderr.on('data', (data) => {
        const text = data.toString();
        stderr += text;
        if (onOutput) onOutput(text);
      });

      proc.on('error', (err) => {
        reject(new Error(`Failed to spawn wrangler: ${err.message}`));
      });

      proc.on('close', (code) => {
        resolve({ stdout, stderr, code });
      });
    });
  }

  /**
   * Ensure the Cloudflare Pages project exists, creating it if needed.
   */
  async ensureProject(onProgress = null) {
    if (onProgress) onProgress('Checking if Cloudflare Pages project exists...');

    // List projects and check if ours exists
    const listResult = await this.runWrangler(['pages', 'project', 'list']);

    if (listResult.code !== 0) {
      throw new Error(`Failed to list Cloudflare Pages projects: ${listResult.stderr}`);
    }

    // Check if project name appears in output
    if (listResult.stdout.includes(this.projectName)) {
      if (onProgress) onProgress(`Project "${this.projectName}" found`);
      return;
    }

    // Create the project
    if (onProgress) onProgress(`Creating project "${this.projectName}"...`);

    const createResult = await this.runWrangler([
      'pages', 'project', 'create', this.projectName,
      '--production-branch=production'
    ]);

    if (createResult.code !== 0) {
      // If it already exists (race condition), that's fine
      if (createResult.stderr.includes('already exists') || createResult.stdout.includes('already exists')) {
        if (onProgress) onProgress(`Project "${this.projectName}" already exists`);
        return;
      }
      throw new Error(`Failed to create Cloudflare Pages project: ${createResult.stderr}`);
    }

    if (onProgress) onProgress(`Project "${this.projectName}" created`);
  }

  /**
   * Write hash file to the source directory so it gets deployed with the site
   * @param {string} sourceDir - The generated site directory
   * @param {Object} fileHashes - Map of file paths to hashes
   * @param {string} publishedBy - Identifier of the publishing client
   */
  writeHashFile(sourceDir, fileHashes, publishedBy = 'self-hosted') {
    const hashData = {
      version: 1,
      lastPublishedDate: new Date().toISOString(),
      publishedBy,
      fileHashes
    };

    const hashDir = path.join(sourceDir, '.postalgic');
    if (!fs.existsSync(hashDir)) {
      fs.mkdirSync(hashDir, { recursive: true });
    }

    const hashFilePath = path.join(sourceDir, HASH_FILE_PATH);
    fs.writeFileSync(hashFilePath, JSON.stringify(hashData, null, 2));
  }

  /**
   * Publish files to Cloudflare Pages using wrangler
   * @param {string} sourceDir - Directory containing files to upload
   * @param {function} onProgress - Progress callback (message)
   * @returns {Promise<Object>} - Result with deployment info
   */
  async publish(sourceDir, onProgress = null) {
    // Ensure project exists
    await this.ensureProject(onProgress);

    if (onProgress) onProgress('Deploying to Cloudflare Pages...');

    let lastLine = '';
    const result = await this.runWrangler([
      'pages', 'deploy', sourceDir,
      `--project-name=${this.projectName}`,
      '--branch=production'
    ], (text) => {
      // Stream wrangler output as progress
      const lines = text.split('\n').filter(l => l.trim());
      for (const line of lines) {
        lastLine = line.trim();
        if (onProgress && lastLine) {
          onProgress(lastLine);
        }
      }
    });

    if (result.code !== 0) {
      const errorMsg = result.stderr || result.stdout || 'Unknown wrangler error';
      throw new Error(`Cloudflare Pages deploy failed: ${errorMsg}`);
    }

    // Try to extract the deployment URL from output
    let deploymentUrl = null;
    const urlMatch = (result.stdout + result.stderr).match(/https:\/\/[^\s]+\.pages\.dev[^\s]*/);
    if (urlMatch) {
      deploymentUrl = urlMatch[0];
    }

    return {
      success: true,
      deploymentUrl,
      message: deploymentUrl
        ? `Deployed to ${deploymentUrl}`
        : 'Deployed to Cloudflare Pages'
    };
  }
}

export default CloudflarePagesPublisher;
