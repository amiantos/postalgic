/**
 * Publish Routes
 *
 * Handles publishing the generated static site to various destinations (AWS, SFTP, Git).
 *
 * IMPORTANT: This file interacts with TWO separate hash systems:
 * 1. Smart Publishing (.postalgic/hashes.json) - Full site hashes uploaded to remote
 * 2. Cross-Platform Sync (localFileHashes) - Sync data hashes stored locally
 *
 * See siteGenerator.js header for full explanation of these systems.
 */

import express from 'express';
import path from 'path';
import Storage from '../utils/storage.js';
import { generateSite } from '../services/siteGenerator.js';
import { createZipArchive } from '../services/archiver.js';
import { AWSPublisher, SFTPPublisher, GitPublisher } from '../services/publishers/index.js';

const router = express.Router({ mergeParams: true });

function getStorage(req) {
  return new Storage(req.app.locals.dataRoot);
}

/**
 * Extract sync file hashes from full site file hashes.
 * Filters to only sync/ prefixed files and strips the prefix.
 * @param {Object} fileHashes - Full site file hashes (includes sync/, css/, etc.)
 * @returns {Object} - Only sync file hashes with prefix stripped
 */
function extractSyncHashes(fileHashes) {
  const syncHashes = {};
  for (const [filePath, hash] of Object.entries(fileHashes)) {
    if (filePath.startsWith('sync/')) {
      // Strip the 'sync/' prefix to match manifest format
      const syncPath = filePath.slice(5);
      syncHashes[syncPath] = hash;
    }
  }
  return syncHashes;
}

// POST /api/blogs/:blogId/publish/generate - Generate static site
router.post('/generate', async (req, res) => {
  try {
    const storage = getStorage(req);
    const { blogId } = req.params;

    const blog = storage.getBlog(blogId);
    if (!blog) {
      return res.status(404).json({ error: 'Blog not found' });
    }

    // Generate the site
    const result = await generateSite(storage, blogId);

    res.json({
      success: true,
      message: 'Site generated successfully',
      outputDir: result.outputDir,
      fileCount: result.fileCount,
      previewUrl: `/preview/${blogId}/`
    });
  } catch (error) {
    console.error('Site generation error:', error);
    res.status(500).json({ error: error.message });
  }
});

// GET /api/blogs/:blogId/publish/preview - Get preview URL
router.get('/preview', (req, res) => {
  try {
    const storage = getStorage(req);
    const { blogId } = req.params;

    const blog = storage.getBlog(blogId);
    if (!blog) {
      return res.status(404).json({ error: 'Blog not found' });
    }

    res.json({
      previewUrl: `/preview/${blogId}/`
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// POST /api/blogs/:blogId/publish/download - Download site as ZIP
router.post('/download', async (req, res) => {
  try {
    const storage = getStorage(req);
    const { blogId } = req.params;

    const blog = storage.getBlog(blogId);
    if (!blog) {
      return res.status(404).json({ error: 'Blog not found' });
    }

    // Generate the site first
    const generateResult = await generateSite(storage, blogId);

    // Create ZIP archive
    const zipBuffer = await createZipArchive(generateResult.outputDir);

    // Generate filename with timestamp
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-').slice(0, 19);
    const filename = `${blog.name.toLowerCase().replace(/\s+/g, '-')}-${timestamp}.zip`;

    res.setHeader('Content-Type', 'application/zip');
    res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
    res.send(zipBuffer);
  } catch (error) {
    console.error('Download error:', error);
    res.status(500).json({ error: error.message });
  }
});

// GET /api/blogs/:blogId/publish/status - Get publish status
router.get('/status', (req, res) => {
  try {
    const storage = getStorage(req);
    const { blogId } = req.params;

    const blog = storage.getBlog(blogId);
    if (!blog) {
      return res.status(404).json({ error: 'Blog not found' });
    }

    const syncConfig = storage.getSyncConfig(blogId);

    res.json({
      publisherType: blog.publisherType || 'manual',
      lastPublishedDate: syncConfig.lastSyncedAt,
      syncVersion: syncConfig.lastSyncedVersion
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// GET /api/blogs/:blogId/publish/debug-hashes - Debug endpoint to show current file hashes
router.get('/debug-hashes', async (req, res) => {
  try {
    const storage = getStorage(req);
    const { blogId } = req.params;

    const blog = storage.getBlog(blogId);
    if (!blog) {
      return res.status(404).json({ error: 'Blog not found' });
    }

    // Generate site to get current hashes
    const generateResult = await generateSite(storage, blogId);
    const currentHashes = generateResult.fileHashes;

    const syncConfig = storage.getSyncConfig(blogId);

    res.json({
      blogId,
      publisherType: blog.publisherType || 'manual',
      lastSyncedAt: syncConfig.lastSyncedAt,
      syncVersion: syncConfig.lastSyncedVersion,
      fileCount: Object.keys(currentHashes).length,
      // Include sample of current hashes
      sampleHashes: Object.entries(currentHashes).slice(0, 20).map(([path, hash]) => ({
        path,
        hash: hash.substring(0, 16)
      }))
    });
  } catch (error) {
    console.error('Debug hashes error:', error);
    res.status(500).json({ error: error.message });
  }
});

// POST /api/blogs/:blogId/publish/changes - Get list of files that will be published
router.post('/changes', async (req, res) => {
  try {
    const storage = getStorage(req);
    const { blogId } = req.params;

    const blog = storage.getBlog(blogId);
    if (!blog) {
      return res.status(404).json({ error: 'Blog not found' });
    }

    // Generate the site to get current file hashes
    const generateResult = await generateSite(storage, blogId);
    const currentHashes = generateResult.fileHashes;

    // Without remote hashes, we can only show total files
    // Change detection happens during actual publish using remote hash file
    res.json({
      totalFiles: Object.keys(currentHashes).length,
      files: Object.keys(currentHashes),
      message: 'Change detection occurs during publish using remote hash file'
    });
  } catch (error) {
    console.error('Changes check error:', error);
    res.status(500).json({ error: error.message });
  }
});

// Helper to send SSE event
function sendSSE(res, event, data) {
  res.write(`event: ${event}\n`);
  res.write(`data: ${JSON.stringify(data)}\n\n`);
}

// GET /api/blogs/:blogId/publish/aws/stream - Publish to AWS S3 with SSE progress
router.get('/aws/stream', async (req, res) => {
  // Set up SSE headers
  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.flushHeaders();

  try {
    const storage = getStorage(req);
    const { blogId } = req.params;
    const forceUploadAll = req.query.forceUploadAll === 'true';

    const blog = storage.getBlog(blogId);
    if (!blog) {
      sendSSE(res, 'error', { message: 'Blog not found' });
      res.end();
      return;
    }

    if (!blog.awsS3Bucket || !blog.awsRegion || !blog.awsAccessKeyId || !blog.awsSecretAccessKey) {
      sendSSE(res, 'error', { message: 'AWS configuration incomplete' });
      res.end();
      return;
    }

    sendSSE(res, 'progress', { phase: 'init', message: 'Initializing AWS publisher...' });

    const publisher = new AWSPublisher({
      bucket: blog.awsS3Bucket,
      region: blog.awsRegion,
      cloudFrontDistId: blog.awsCloudFrontDistId,
      accessKeyId: blog.awsAccessKeyId,
      secretAccessKey: blog.awsSecretAccessKey
    });

    sendSSE(res, 'progress', { phase: 'fetch-hashes', message: 'Fetching remote file hashes...' });

    const remoteHashData = await publisher.fetchRemoteHashes();
    const previousHashes = (remoteHashData && remoteHashData.fileHashes) ? remoteHashData.fileHashes : {};

    if (Object.keys(previousHashes).length > 0) {
      sendSSE(res, 'progress', { phase: 'fetch-hashes', message: `Found ${Object.keys(previousHashes).length} remote files` });
    } else {
      sendSSE(res, 'progress', { phase: 'fetch-hashes', message: 'No remote hashes found - will upload all files' });
    }

    sendSSE(res, 'progress', { phase: 'generate', message: 'Generating site...' });

    const generateResult = await generateSite(storage, blogId);

    sendSSE(res, 'progress', { phase: 'generate', message: `Generated ${generateResult.fileCount} files` });

    sendSSE(res, 'progress', { phase: 'upload', message: 'Starting upload...' });

    // Progress callback for file-by-file updates
    const onProgress = (current, total, filename) => {
      sendSSE(res, 'file', { current, total, filename });
    };

    const result = await publisher.publish(generateResult.outputDir, onProgress, {
      forceUploadAll,
      currentHashes: generateResult.fileHashes,
      previousHashes
    });

    sendSSE(res, 'progress', { phase: 'hash-upload', message: 'Uploading hash file...' });

    await publisher.uploadHashFile(generateResult.fileHashes, 'self-hosted');

    storage.updateSyncVersion(blogId, generateResult.syncVersion, extractSyncHashes(generateResult.fileHashes));

    sendSSE(res, 'complete', {
      success: true,
      message: `Published to S3: ${result.uploaded} uploaded, ${result.deleted} deleted`,
      ...result
    });

    res.end();
  } catch (error) {
    console.error('AWS publish error:', error);
    sendSSE(res, 'error', { message: error.message });
    res.end();
  }
});

// POST /api/blogs/:blogId/publish/aws - Publish to AWS S3 (non-streaming fallback)
router.post('/aws', async (req, res) => {
  try {
    const storage = getStorage(req);
    const { blogId } = req.params;
    const { forceUploadAll = false } = req.body || {};

    const blog = storage.getBlog(blogId);
    if (!blog) {
      return res.status(404).json({ error: 'Blog not found' });
    }

    if (!blog.awsS3Bucket || !blog.awsRegion || !blog.awsAccessKeyId || !blog.awsSecretAccessKey) {
      return res.status(400).json({
        error: 'AWS configuration incomplete. Please set bucket, region, access key ID, and secret access key in settings.'
      });
    }

    // Create publisher
    const publisher = new AWSPublisher({
      bucket: blog.awsS3Bucket,
      region: blog.awsRegion,
      cloudFrontDistId: blog.awsCloudFrontDistId,
      accessKeyId: blog.awsAccessKeyId,
      secretAccessKey: blog.awsSecretAccessKey
    });

    // Fetch remote hashes - if none found, previousHashes stays empty (full upload)
    const remoteHashData = await publisher.fetchRemoteHashes();
    const previousHashes = (remoteHashData && remoteHashData.fileHashes) ? remoteHashData.fileHashes : {};

    if (Object.keys(previousHashes).length > 0) {
      console.log('[Publish] Using remote hashes from server');
    } else {
      console.log('[Publish] No remote hashes found - will upload all files');
    }

    // Generate site
    const generateResult = await generateSite(storage, blogId);

    // Publish with hash-based change detection
    const result = await publisher.publish(generateResult.outputDir, null, {
      forceUploadAll,
      currentHashes: generateResult.fileHashes,
      previousHashes
    });

    // Upload hash file to remote after successful publish
    await publisher.uploadHashFile(generateResult.fileHashes, 'self-hosted');

    // Update sync version and store SYNC file hashes locally (not full site hashes)
    // See siteGenerator.js header for explanation of the two hash systems
    storage.updateSyncVersion(blogId, generateResult.syncVersion, extractSyncHashes(generateResult.fileHashes));

    res.json({
      success: true,
      message: `Published to S3: ${result.uploaded} uploaded, ${result.deleted} deleted`,
      ...result
    });
  } catch (error) {
    console.error('AWS publish error:', error);
    res.status(500).json({ error: error.message });
  }
});

// GET /api/blogs/:blogId/publish/sftp/stream - Publish via SFTP with SSE progress
router.get('/sftp/stream', async (req, res) => {
  // Set up SSE headers
  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.flushHeaders();

  try {
    const storage = getStorage(req);
    const { blogId } = req.params;
    const forceUploadAll = req.query.forceUploadAll === 'true';

    const blog = storage.getBlog(blogId);
    if (!blog) {
      sendSSE(res, 'error', { message: 'Blog not found' });
      res.end();
      return;
    }

    if (!blog.ftpHost || !blog.ftpUsername) {
      sendSSE(res, 'error', { message: 'SFTP configuration incomplete' });
      res.end();
      return;
    }

    if (!blog.ftpPassword && !blog.ftpPrivateKey) {
      sendSSE(res, 'error', { message: 'SFTP credentials incomplete' });
      res.end();
      return;
    }

    sendSSE(res, 'progress', { phase: 'init', message: 'Initializing SFTP publisher...' });

    const publisher = new SFTPPublisher({
      host: blog.ftpHost,
      port: blog.ftpPort || 22,
      username: blog.ftpUsername,
      password: blog.ftpPassword,
      privateKey: blog.ftpPrivateKey,
      remotePath: blog.ftpPath || '/'
    });

    sendSSE(res, 'progress', { phase: 'fetch-hashes', message: 'Fetching remote file hashes...' });

    const remoteHashData = await publisher.fetchRemoteHashes();
    const previousHashes = (remoteHashData && remoteHashData.fileHashes) ? remoteHashData.fileHashes : {};

    if (Object.keys(previousHashes).length > 0) {
      sendSSE(res, 'progress', { phase: 'fetch-hashes', message: `Found ${Object.keys(previousHashes).length} remote files` });
    } else {
      sendSSE(res, 'progress', { phase: 'fetch-hashes', message: 'No remote hashes found - will upload all files' });
    }

    sendSSE(res, 'progress', { phase: 'generate', message: 'Generating site...' });

    const generateResult = await generateSite(storage, blogId);

    sendSSE(res, 'progress', { phase: 'generate', message: `Generated ${generateResult.fileCount} files` });

    sendSSE(res, 'progress', { phase: 'upload', message: 'Connecting to SFTP server...' });

    // Progress callback for file-by-file updates
    const onProgress = (current, total, filename) => {
      sendSSE(res, 'file', { current, total, filename });
    };

    const result = await publisher.publish(generateResult.outputDir, onProgress, {
      forceUploadAll,
      currentHashes: generateResult.fileHashes,
      previousHashes
    });

    sendSSE(res, 'progress', { phase: 'hash-upload', message: 'Uploading hash file...' });

    await publisher.uploadHashFile(generateResult.fileHashes, 'self-hosted');

    storage.updateSyncVersion(blogId, generateResult.syncVersion, extractSyncHashes(generateResult.fileHashes));

    sendSSE(res, 'complete', {
      success: true,
      message: `Published via SFTP: ${result.uploaded} uploaded, ${result.deleted} deleted`,
      ...result
    });

    res.end();
  } catch (error) {
    console.error('SFTP publish error:', error);
    sendSSE(res, 'error', { message: error.message });
    res.end();
  }
});

// POST /api/blogs/:blogId/publish/sftp - Publish via SFTP (non-streaming fallback)
router.post('/sftp', async (req, res) => {
  try {
    const storage = getStorage(req);
    const { blogId } = req.params;
    const { forceUploadAll = false } = req.body || {};

    const blog = storage.getBlog(blogId);
    if (!blog) {
      return res.status(404).json({ error: 'Blog not found' });
    }

    if (!blog.ftpHost || !blog.ftpUsername) {
      return res.status(400).json({
        error: 'SFTP configuration incomplete. Please set host and username in settings.'
      });
    }

    if (!blog.ftpPassword && !blog.ftpPrivateKey) {
      return res.status(400).json({
        error: 'SFTP credentials incomplete. Please set password or private key in settings.'
      });
    }

    // Create publisher
    const publisher = new SFTPPublisher({
      host: blog.ftpHost,
      port: blog.ftpPort || 22,
      username: blog.ftpUsername,
      password: blog.ftpPassword,
      privateKey: blog.ftpPrivateKey,
      remotePath: blog.ftpPath || '/'
    });

    // Fetch remote hashes - if none found, previousHashes stays empty (full upload)
    const remoteHashData = await publisher.fetchRemoteHashes();
    const previousHashes = (remoteHashData && remoteHashData.fileHashes) ? remoteHashData.fileHashes : {};

    if (Object.keys(previousHashes).length > 0) {
      console.log('[Publish] Using remote hashes from server');
    } else {
      console.log('[Publish] No remote hashes found - will upload all files');
    }

    // Generate site
    const generateResult = await generateSite(storage, blogId);

    // Publish with hash-based change detection
    const result = await publisher.publish(generateResult.outputDir, null, {
      forceUploadAll,
      currentHashes: generateResult.fileHashes,
      previousHashes
    });

    // Upload hash file to remote after successful publish
    await publisher.uploadHashFile(generateResult.fileHashes, 'self-hosted');

    // Update sync version and store SYNC file hashes locally (not full site hashes)
    // See siteGenerator.js header for explanation of the two hash systems
    storage.updateSyncVersion(blogId, generateResult.syncVersion, extractSyncHashes(generateResult.fileHashes));

    res.json({
      success: true,
      message: `Published via SFTP: ${result.uploaded} uploaded, ${result.deleted} deleted`,
      ...result
    });
  } catch (error) {
    console.error('SFTP publish error:', error);
    res.status(500).json({ error: error.message });
  }
});

// GET /api/blogs/:blogId/publish/git/stream - Publish to Git with SSE progress
router.get('/git/stream', async (req, res) => {
  // Set up SSE headers
  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.flushHeaders();

  try {
    const storage = getStorage(req);
    const { blogId } = req.params;

    const blog = storage.getBlog(blogId);
    if (!blog) {
      sendSSE(res, 'error', { message: 'Blog not found' });
      res.end();
      return;
    }

    if (!blog.gitRepositoryUrl || !blog.gitUsername || !blog.gitToken) {
      sendSSE(res, 'error', { message: 'Git configuration incomplete' });
      res.end();
      return;
    }

    sendSSE(res, 'progress', { phase: 'init', message: 'Initializing Git publisher...' });

    const publisher = new GitPublisher({
      repositoryUrl: blog.gitRepositoryUrl,
      username: blog.gitUsername,
      token: blog.gitToken,
      branch: blog.gitBranch || 'main',
      commitMessage: blog.gitCommitMessage || 'Update blog',
      authorName: blog.authorName || 'Postalgic',
      authorEmail: blog.authorEmail || 'postalgic@localhost'
    });

    sendSSE(res, 'progress', { phase: 'generate', message: 'Generating site...' });

    const generateResult = await generateSite(storage, blogId);

    sendSSE(res, 'progress', { phase: 'generate', message: `Generated ${generateResult.fileCount} files` });

    // Write hash file to the generated site directory (it will be committed with the rest)
    publisher.writeHashFile(generateResult.outputDir, generateResult.fileHashes, 'self-hosted');

    // Progress callback for git operations
    const onProgress = (current, total, message) => {
      sendSSE(res, 'file', { current, total, filename: message });
    };

    const result = await publisher.publish(generateResult.outputDir, onProgress);

    storage.updateSyncVersion(blogId, generateResult.syncVersion, extractSyncHashes(generateResult.fileHashes));

    sendSSE(res, 'complete', {
      success: true,
      message: result.committed
        ? `Published to Git: ${result.summary.changed} files changed`
        : 'No changes to publish',
      ...result
    });

    res.end();
  } catch (error) {
    console.error('Git publish error:', error);
    sendSSE(res, 'error', { message: error.message });
    res.end();
  }
});

// POST /api/blogs/:blogId/publish/git - Publish to Git repository (non-streaming fallback)
router.post('/git', async (req, res) => {
  try {
    const storage = getStorage(req);
    const { blogId } = req.params;

    const blog = storage.getBlog(blogId);
    if (!blog) {
      return res.status(404).json({ error: 'Blog not found' });
    }

    if (!blog.gitRepositoryUrl || !blog.gitUsername || !blog.gitToken) {
      return res.status(400).json({
        error: 'Git configuration incomplete. Please set repository URL, username, and personal access token in settings.'
      });
    }

    // Create publisher
    const publisher = new GitPublisher({
      repositoryUrl: blog.gitRepositoryUrl,
      username: blog.gitUsername,
      token: blog.gitToken,
      branch: blog.gitBranch || 'main',
      commitMessage: blog.gitCommitMessage || 'Update blog',
      authorName: blog.authorName || 'Postalgic',
      authorEmail: blog.authorEmail || 'postalgic@localhost'
    });

    // Generate site
    const generateResult = await generateSite(storage, blogId);

    // Write hash file to the generated site directory (it will be committed with the rest)
    publisher.writeHashFile(generateResult.outputDir, generateResult.fileHashes, 'self-hosted');

    // Publish (hash file is included in the commit)
    const result = await publisher.publish(generateResult.outputDir);

    // Update sync version and store SYNC file hashes locally (not full site hashes)
    // See siteGenerator.js header for explanation of the two hash systems
    storage.updateSyncVersion(blogId, generateResult.syncVersion, extractSyncHashes(generateResult.fileHashes));

    res.json({
      success: true,
      message: result.committed
        ? `Published to Git: ${result.summary.changed} files changed`
        : 'No changes to publish',
      ...result
    });
  } catch (error) {
    console.error('Git publish error:', error);
    res.status(500).json({ error: error.message });
  }
});

export default router;
