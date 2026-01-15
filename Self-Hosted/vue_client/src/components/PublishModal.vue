<script setup>
import { ref, computed, onMounted, nextTick, watch } from 'vue';
import { useBlogStore } from '@/stores/blog';
import { publishApi, syncApi } from '@/api';

const props = defineProps({
  blogId: { type: String, required: true },
  show: { type: Boolean, default: false },
  autoPublish: { type: Boolean, default: false }
});

const emit = defineEmits(['close']);

const blogStore = useBlogStore();

const publisherType = computed(() => blogStore.currentBlog?.publisherType || 'manual');
const hasPublishedPosts = computed(() => blogStore.publishedPosts.length > 0);

const generating = ref(false);
const downloading = ref(false);
const publishing = ref(false);
const error = ref(null);
const previewUrl = ref(null);
const publishComplete = ref(false);

// Terminal log state
const logMessages = ref([]);
const logContainer = ref(null);

// Pre-publish sync state
const prePublishSyncing = ref(false);

// Reset state when modal opens
watch(() => props.show, (newVal) => {
  if (newVal) {
    // Reset state when modal opens
    error.value = null;
    previewUrl.value = null;
    logMessages.value = [];
    publishComplete.value = false;

    // Auto-publish if requested
    if (props.autoPublish && hasPublishedPosts.value) {
      addLog('Auto-publishing...', 'info');
      triggerAutoPublish();
    } else {
      addLog('Ready to publish...', 'info');
    }
  }
}, { immediate: true });

function triggerAutoPublish() {
  switch (publisherType.value) {
    case 'aws':
      publishToAWS(false);
      break;
    case 'sftp':
      publishToSFTP(false);
      break;
    case 'git':
      publishToGit(false);
      break;
    case 'manual':
      downloadSite();
      break;
  }
}

function addLog(text, type = 'info') {
  const time = new Date().toLocaleTimeString('en-US', { hour12: false });
  logMessages.value.push({ text, type, time });
  nextTick(() => {
    if (logContainer.value) {
      logContainer.value.scrollTop = logContainer.value.scrollHeight;
    }
  });
}

function getLogClass(type) {
  switch (type) {
    case 'error': return 'text-red-400';
    case 'success': return 'text-green-400';
    case 'warning': return 'text-yellow-400';
    default: return 'text-gray-300';
  }
}

/**
 * Performs pre-publish sync if the blog has sync enabled (has a URL).
 * Returns true if sync succeeded or was not needed, false if sync failed.
 */
async function performPrePublishSync() {
  // Skip sync if blog has no URL configured
  if (!blogStore.currentBlog?.url) {
    return true;
  }

  prePublishSyncing.value = true;
  addLog('Checking for remote changes...', 'info');
  error.value = null;

  try {
    // Check for remote changes
    const checkResult = await syncApi.checkChanges(props.blogId);

    if (checkResult.hasChanges) {
      addLog(`Syncing remote changes: ${checkResult.changeSummary || 'updating...'}`, 'info');

      // Pull changes
      const pullResult = await syncApi.pull(props.blogId);

      if (!pullResult.success) {
        throw new Error(pullResult.message || 'Sync failed');
      }

      // Refresh store data after sync
      await Promise.all([
        blogStore.fetchBlog(props.blogId),
        blogStore.fetchPosts(props.blogId),
        blogStore.fetchCategories(props.blogId),
        blogStore.fetchTags(props.blogId)
      ]);
      addLog('Sync completed successfully', 'success');
    } else {
      addLog('No remote changes detected', 'success');
    }

    prePublishSyncing.value = false;
    return true;
  } catch (e) {
    prePublishSyncing.value = false;
    addLog(`Sync failed: ${e.message}`, 'error');
    error.value = `Sync failed: ${e.message}. Please resolve this before publishing.`;
    return false;
  }
}

async function generateSite() {
  generating.value = true;
  error.value = null;
  addLog('Generating site...', 'info');

  try {
    const result = await blogStore.generateSite(props.blogId);
    previewUrl.value = result.previewUrl;
    addLog(`Site generated: ${result.fileCount || 'unknown'} files`, 'success');
  } catch (e) {
    addLog(`Generation failed: ${e.message}`, 'error');
    error.value = e.message;
  } finally {
    generating.value = false;
  }
}

async function downloadSite() {
  downloading.value = true;
  error.value = null;
  addLog('Preparing ZIP download...', 'info');

  try {
    const { blob, filename } = await blogStore.downloadSite(props.blogId);

    // Create download link
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);

    // Mark as published
    await publishApi.markPublished(props.blogId);
    addLog('ZIP downloaded successfully', 'success');
    publishComplete.value = true;
  } catch (e) {
    addLog(`Download failed: ${e.message}`, 'error');
    error.value = e.message;
  } finally {
    downloading.value = false;
  }
}

/**
 * Helper to publish via SSE stream
 * @param {string} endpoint - The SSE endpoint path (e.g., 'aws/stream')
 * @param {Object} params - Query parameters
 * @returns {Promise} - Resolves with result data or rejects with error
 */
function publishWithSSE(endpoint, params = {}) {
  return new Promise((resolve, reject) => {
    const queryString = new URLSearchParams(params).toString();
    const url = `/api/blogs/${props.blogId}/publish/${endpoint}${queryString ? '?' + queryString : ''}`;

    const eventSource = new EventSource(url);

    eventSource.addEventListener('progress', (e) => {
      const data = JSON.parse(e.data);
      addLog(data.message, 'info');
    });

    eventSource.addEventListener('file', (e) => {
      const data = JSON.parse(e.data);
      addLog(`[${data.current}/${data.total}] ${data.filename}`, 'info');
    });

    eventSource.addEventListener('complete', (e) => {
      const data = JSON.parse(e.data);
      eventSource.close();
      resolve(data);
    });

    eventSource.addEventListener('error', (e) => {
      // Check if this is an SSE error event with data
      if (e.data) {
        const data = JSON.parse(e.data);
        eventSource.close();
        reject(new Error(data.message));
      } else {
        // Connection error
        eventSource.close();
        reject(new Error('Connection to server lost'));
      }
    });

    // Handle connection errors
    eventSource.onerror = () => {
      if (eventSource.readyState === EventSource.CLOSED) {
        // Normal close, already handled by 'complete' or 'error' event
        return;
      }
      eventSource.close();
      reject(new Error('Failed to connect to publish stream'));
    };
  });
}

async function publishToAWS(forceUploadAll = false, skipSync = false) {
  publishing.value = true;
  error.value = null;

  try {
    // Perform pre-publish sync first (unless skipped)
    if (!skipSync) {
      const syncOk = await performPrePublishSync();
      if (!syncOk) {
        publishing.value = false;
        return;
      }
    }

    addLog(forceUploadAll ? 'Full publish: uploading all files' : 'Smart publish: uploading changed files only', 'info');

    await publishWithSSE('aws/stream', { forceUploadAll });

    addLog('Publish complete!', 'success');
    publishComplete.value = true;
  } catch (e) {
    addLog(`Publish failed: ${e.message}`, 'error');
    error.value = e.message;
  } finally {
    publishing.value = false;
  }
}

async function publishToSFTP(forceUploadAll = false, skipSync = false) {
  publishing.value = true;
  error.value = null;

  try {
    // Perform pre-publish sync first (unless skipped)
    if (!skipSync) {
      const syncOk = await performPrePublishSync();
      if (!syncOk) {
        publishing.value = false;
        return;
      }
    }

    addLog(forceUploadAll ? 'Full publish: uploading all files' : 'Smart publish: uploading changed files only', 'info');

    await publishWithSSE('sftp/stream', { forceUploadAll });

    addLog('Publish complete!', 'success');
    publishComplete.value = true;
  } catch (e) {
    addLog(`Publish failed: ${e.message}`, 'error');
    error.value = e.message;
  } finally {
    publishing.value = false;
  }
}

async function publishToGit(skipSync = false) {
  publishing.value = true;
  error.value = null;

  try {
    // Perform pre-publish sync first (unless skipped)
    if (!skipSync) {
      const syncOk = await performPrePublishSync();
      if (!syncOk) {
        publishing.value = false;
        return;
      }
    }

    await publishWithSSE('git/stream');

    addLog('Publish complete!', 'success');
    publishComplete.value = true;
  } catch (e) {
    addLog(`Publish failed: ${e.message}`, 'error');
    error.value = e.message;
  } finally {
    publishing.value = false;
  }
}

function openPreview() {
  if (previewUrl.value) {
    window.open(previewUrl.value, '_blank');
  }
}

function getPublisherLabel(type) {
  const labels = {
    manual: 'Manual (ZIP)',
    aws: 'AWS S3',
    sftp: 'SFTP',
    git: 'Git'
  };
  return labels[type] || type;
}

const isWorking = computed(() => generating.value || downloading.value || publishing.value || prePublishSyncing.value);
</script>

<template>
  <Teleport to="body">
    <div
      v-if="show"
      class="fixed inset-0 bg-black/60 backdrop-blur-sm flex items-center justify-center z-50"
      @click.self="!isWorking && emit('close')"
    >
      <div class="bg-white dark:bg-gray-900 rounded-2xl max-w-lg w-full mx-4 shadow-2xl max-h-[90vh] flex flex-col">
        <!-- Header -->
        <div class="flex items-center justify-between p-4 border-b border-gray-200 dark:border-gray-700">
          <div>
            <h2 class="text-lg font-semibold text-gray-900 dark:text-gray-100">Deploy Site</h2>
            <p class="text-sm text-gray-500 dark:text-gray-400">via {{ getPublisherLabel(publisherType) }}</p>
          </div>
          <button
            @click="emit('close')"
            :disabled="isWorking"
            class="p-2 text-gray-400 hover:text-gray-600 dark:hover:text-gray-300 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-800 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>

        <!-- Content -->
        <div class="flex-1 overflow-y-auto p-4 space-y-4">
          <!-- Blog URL Warning -->
          <div v-if="!blogStore.currentBlog?.url" class="p-3 bg-yellow-50 dark:bg-yellow-900/30 border border-yellow-200 dark:border-yellow-700 rounded-lg">
            <div class="flex items-start gap-2">
              <svg class="w-5 h-5 text-yellow-600 dark:text-yellow-400 mt-0.5 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
              </svg>
              <div>
                <p class="text-yellow-800 dark:text-yellow-300 font-medium text-sm">Blog URL not set</p>
                <p class="text-yellow-700 dark:text-yellow-400 text-xs mt-0.5">
                  Set your blog URL in Settings for correct links.
                </p>
              </div>
            </div>
          </div>

          <!-- Terminal Log -->
          <div
            ref="logContainer"
            class="bg-gray-900 dark:bg-black rounded-lg p-3 h-48 overflow-y-auto font-mono text-sm"
          >
            <div
              v-for="(msg, index) in logMessages"
              :key="index"
              :class="getLogClass(msg.type)"
            >
              <span class="text-gray-500">{{ msg.time }}</span> {{ msg.text }}
            </div>
            <div v-if="isWorking" class="text-gray-400 animate-pulse">
              <span class="text-gray-500">{{ new Date().toLocaleTimeString('en-US', { hour12: false }) }}</span> Working...
            </div>
          </div>

          <!-- Error Message -->
          <div v-if="error" class="p-3 bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded-lg text-red-800 dark:text-red-400 text-sm">
            {{ error }}
          </div>

          <!-- Preview Button -->
          <div v-if="previewUrl" class="flex gap-2">
            <button
              @click="openPreview"
              class="flex-1 px-4 py-2 bg-gray-100 dark:bg-gray-700 text-gray-700 dark:text-gray-300 rounded-lg hover:bg-gray-200 dark:hover:bg-gray-600 transition-colors text-sm font-medium flex items-center justify-center gap-2"
            >
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
              </svg>
              Open Preview
            </button>
          </div>
        </div>

        <!-- Footer Actions -->
        <div class="p-4 border-t border-gray-200 dark:border-gray-700 space-y-3">
          <!-- Close button after publish complete -->
          <div v-if="publishComplete">
            <button
              @click="emit('close')"
              class="w-full px-4 py-2 bg-primary-600 text-white rounded-lg hover:bg-primary-700 transition-colors text-sm font-medium"
            >
              Close
            </button>
          </div>

          <!-- Publish actions (hidden after complete) -->
          <template v-else>
            <!-- Generate Button (if no preview yet) -->
            <div v-if="!previewUrl && publisherType !== 'manual'" class="flex gap-2">
              <button
                @click="generateSite"
                :disabled="isWorking"
                class="flex-1 px-4 py-2 bg-gray-100 dark:bg-gray-700 text-gray-700 dark:text-gray-300 rounded-lg hover:bg-gray-200 dark:hover:bg-gray-600 transition-colors disabled:opacity-50 text-sm font-medium"
              >
                {{ generating ? 'Generating...' : 'Generate Preview' }}
              </button>
            </div>

            <!-- Manual Download -->
            <div v-if="publisherType === 'manual'" class="flex flex-col gap-2">
              <button
                @click="downloadSite"
                :disabled="isWorking || !hasPublishedPosts"
                class="w-full px-4 py-2 bg-primary-600 text-white rounded-lg hover:bg-primary-700 transition-colors disabled:opacity-50 text-sm font-medium"
              >
                {{ downloading ? 'Downloading...' : 'Download ZIP' }}
              </button>
              <p v-if="!hasPublishedPosts" class="text-xs text-gray-500 dark:text-gray-400 text-center">
                No published posts to deploy
              </p>
            </div>

            <!-- AWS Publish -->
            <div v-if="publisherType === 'aws'" class="space-y-2">
              <div class="flex gap-2">
                <button
                  @click="publishToAWS(false)"
                  :disabled="isWorking || !hasPublishedPosts"
                  class="flex-1 px-4 py-2 bg-orange-600 text-white rounded-lg hover:bg-orange-700 transition-colors disabled:opacity-50 text-sm font-medium"
                >
                  {{ publishing ? 'Publishing...' : 'Publish' }}
                </button>
                <button
                  @click="publishToAWS(true)"
                  :disabled="isWorking || !hasPublishedPosts"
                  class="px-4 py-2 bg-orange-800 text-white rounded-lg hover:bg-orange-900 transition-colors disabled:opacity-50 text-sm font-medium"
                  title="Re-upload all files"
                >
                  Full
                </button>
              </div>
              <button
                @click="publishToAWS(true, true)"
                :disabled="isWorking || !hasPublishedPosts"
                class="w-full text-xs text-gray-500 dark:text-gray-400 hover:text-red-600 dark:hover:text-red-400 underline disabled:opacity-50"
              >
                Force Publish (Skip Sync)
              </button>
            </div>

            <!-- SFTP Publish -->
            <div v-if="publisherType === 'sftp'" class="space-y-2">
              <div class="flex gap-2">
                <button
                  @click="publishToSFTP(false)"
                  :disabled="isWorking || !hasPublishedPosts"
                  class="flex-1 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors disabled:opacity-50 text-sm font-medium"
                >
                  {{ publishing ? 'Publishing...' : 'Publish' }}
                </button>
                <button
                  @click="publishToSFTP(true)"
                  :disabled="isWorking || !hasPublishedPosts"
                  class="px-4 py-2 bg-blue-800 text-white rounded-lg hover:bg-blue-900 transition-colors disabled:opacity-50 text-sm font-medium"
                  title="Re-upload all files"
                >
                  Full
                </button>
              </div>
              <button
                @click="publishToSFTP(true, true)"
                :disabled="isWorking || !hasPublishedPosts"
                class="w-full text-xs text-gray-500 dark:text-gray-400 hover:text-red-600 dark:hover:text-red-400 underline disabled:opacity-50"
              >
                Force Publish (Skip Sync)
              </button>
            </div>

            <!-- Git Publish -->
            <div v-if="publisherType === 'git'" class="space-y-2">
              <button
                @click="publishToGit()"
                :disabled="isWorking || !hasPublishedPosts"
                class="w-full px-4 py-2 bg-gray-800 dark:bg-gray-600 text-white rounded-lg hover:bg-gray-900 dark:hover:bg-gray-500 transition-colors disabled:opacity-50 text-sm font-medium"
              >
                {{ publishing ? 'Publishing...' : 'Push to Git' }}
              </button>
              <button
                @click="publishToGit(true)"
                :disabled="isWorking || !hasPublishedPosts"
                class="w-full text-xs text-gray-500 dark:text-gray-400 hover:text-red-600 dark:hover:text-red-400 underline disabled:opacity-50"
              >
                Force Publish (Skip Sync)
              </button>
            </div>

            <p v-if="!hasPublishedPosts && publisherType !== 'manual'" class="text-xs text-gray-500 dark:text-gray-400 text-center">
              No published posts to deploy
            </p>
          </template>
        </div>
      </div>
    </div>
  </Teleport>
</template>
