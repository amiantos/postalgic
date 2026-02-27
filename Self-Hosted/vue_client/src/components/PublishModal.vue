<script setup>
import { ref, computed, nextTick, watch } from 'vue';
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

// Full publish confirmation
const showFullPublishConfirm = ref(false);
const fullPublishType = ref(null); // 'aws' or 'sftp'

// Reset state when modal opens
watch(() => props.show, (newVal) => {
  if (newVal) {
    // Reset state when modal opens
    error.value = null;
    previewUrl.value = null;
    logMessages.value = [];
    publishComplete.value = false;
    showFullPublishConfirm.value = false;
    fullPublishType.value = null;

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
      publishToGit();
      break;
    case 'cloudflare':
      publishToCloudflare();
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
    case 'error': return 'text-red-600';
    case 'success': return 'text-green-600';
    case 'warning': return 'text-yellow-600';
    default: return 'text-site-dark';
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

async function publishToAWS(forceUploadAll = false) {
  publishing.value = true;
  error.value = null;

  try {
    // Perform pre-publish sync first
    const syncOk = await performPrePublishSync();
    if (!syncOk) {
      publishing.value = false;
      return;
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

async function publishToSFTP(forceUploadAll = false) {
  publishing.value = true;
  error.value = null;

  try {
    // Perform pre-publish sync first
    const syncOk = await performPrePublishSync();
    if (!syncOk) {
      publishing.value = false;
      return;
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

async function publishToGit() {
  publishing.value = true;
  error.value = null;

  try {
    // Perform pre-publish sync first
    const syncOk = await performPrePublishSync();
    if (!syncOk) {
      publishing.value = false;
      return;
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

async function publishToCloudflare() {
  publishing.value = true;
  error.value = null;

  try {
    // Perform pre-publish sync first
    const syncOk = await performPrePublishSync();
    if (!syncOk) {
      publishing.value = false;
      return;
    }

    await publishWithSSE('cloudflare/stream');

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

function visitSite() {
  if (blogStore.currentBlog?.url) {
    window.open(blogStore.currentBlog.url, '_blank');
  }
}

function confirmFullPublish(type) {
  fullPublishType.value = type;
  showFullPublishConfirm.value = true;
}

function cancelFullPublish() {
  showFullPublishConfirm.value = false;
  fullPublishType.value = null;
}

function executeFullPublish() {
  showFullPublishConfirm.value = false;
  if (fullPublishType.value === 'aws') {
    publishToAWS(true);
  } else if (fullPublishType.value === 'sftp') {
    publishToSFTP(true);
  }
  fullPublishType.value = null;
}

function getPublisherLabel(type) {
  const labels = {
    manual: 'Manual (ZIP)',
    aws: 'AWS S3',
    sftp: 'SFTP',
    git: 'Git',
    cloudflare: 'Cloudflare Pages'
  };
  return labels[type] || type;
}

const isWorking = computed(() => generating.value || downloading.value || publishing.value || prePublishSyncing.value);
</script>

<template>
  <Teleport to="body">
    <div
      v-if="show"
      class="fixed inset-0 bg-site-bg flex items-center justify-center z-50 p-6 overflow-hidden"
      @click.self="!isWorking && emit('close')"
    >
      <!-- Tiled DEPLOY background -->
      <div class="absolute inset-0 overflow-hidden select-none pointer-events-none" aria-hidden="true">
        <div class="absolute inset-0 flex flex-col justify-center -rotate-12 scale-150 origin-center">
          <div v-for="row in 12" :key="row" class="flex whitespace-nowrap">
            <span
              class="font-bold text-[6rem] md:text-[8rem] leading-none tracking-tighter text-site-light"
              :class="row % 2 === 0 ? '' : 'ml-32'"
            >
              DEPLOY DEPLOY DEPLOY DEPLOY DEPLOY DEPLOY DEPLOY DEPLOY DEPLOY DEPLOY
            </span>
          </div>
        </div>
      </div>

      <div class="relative max-w-lg w-full">
        <!-- Header -->
        <div class="flex items-end justify-between mb-6">
          <div>
            <h2 class="text-5xl md:text-6xl font-bold text-site-dark leading-none lowercase">
              deploy
            </h2>
            <p class="font-mono text-sm text-site-medium mt-2">
              via {{ getPublisherLabel(publisherType) }}
            </p>
          </div>
          <button
            @click="emit('close')"
            :disabled="isWorking"
            class="font-mono text-sm text-site-dark hover:text-site-accent uppercase tracking-wider disabled:opacity-50 disabled:cursor-not-allowed"
          >
            <span class="relative -top-px">&times;</span> Close
          </button>
        </div>

        <!-- Blog URL Warning -->
        <div v-if="!blogStore.currentBlog?.url" class="mb-4 p-3 border border-yellow-500 bg-yellow-500/10">
          <p class="font-mono text-sm text-yellow-500 uppercase">Warning: Blog URL not set</p>
          <p class="text-sm text-site-dark mt-1">
            Set your blog URL in Settings for correct links.
          </p>
        </div>

        <!-- Terminal Log -->
        <div
          ref="logContainer"
          class="bg-white border border-site-light p-4 h-48 overflow-y-auto font-mono text-sm mb-4"
        >
          <div
            v-for="(msg, index) in logMessages"
            :key="index"
            :class="getLogClass(msg.type)"
          >
            <span class="text-site-medium">{{ msg.time }}</span> {{ msg.text }}
          </div>
          <div v-if="isWorking" class="text-site-dark animate-pulse">
            <span class="text-site-medium">{{ new Date().toLocaleTimeString('en-US', { hour12: false }) }}</span> Working...
          </div>
        </div>

        <!-- Error Message -->
        <div v-if="error" class="mb-4 p-3 border border-red-500 bg-red-500/10">
          <p class="font-mono text-sm text-red-500">{{ error }}</p>
        </div>

        <!-- Preview Button -->
        <button
          v-if="previewUrl"
          @click="openPreview"
          class="w-full mb-4 px-4 py-3 border border-site-light text-site-dark font-mono text-sm uppercase tracking-wider hover:border-site-dark hover:text-site-dark transition-colors"
        >
          Open Preview <span class="relative -top-px">&gt;</span>
        </button>

        <!-- Actions -->
        <div class="space-y-3">
          <!-- Buttons after publish complete -->
          <div v-if="publishComplete" class="flex gap-3">
            <button
              v-if="blogStore.currentBlog?.url"
              @click="visitSite"
              class="flex-1 px-4 py-3 bg-site-accent text-white font-mono text-sm uppercase tracking-wider hover:bg-[#e89200] transition-colors"
            >
              Visit Site <span class="relative -top-px">&gt;</span>
            </button>
            <button
              @click="emit('close')"
              class="flex-1 px-4 py-3 border border-site-light text-site-dark font-mono text-sm uppercase tracking-wider hover:border-site-dark transition-colors"
            >
              Close
            </button>
          </div>

          <!-- Publish actions (hidden after complete) -->
          <template v-else>
            <!-- Generate Button (if no preview yet) -->
            <button
              v-if="!previewUrl && publisherType !== 'manual'"
              @click="generateSite"
              :disabled="isWorking"
              class="w-full px-4 py-3 border border-site-light text-site-dark font-mono text-sm uppercase tracking-wider hover:border-site-dark transition-colors disabled:opacity-50"
            >
              {{ generating ? 'Generating...' : 'Generate Preview' }}
            </button>

            <!-- Manual Download -->
            <template v-if="publisherType === 'manual'">
              <button
                @click="downloadSite"
                :disabled="isWorking || !hasPublishedPosts"
                class="w-full px-4 py-3 bg-site-accent text-white font-mono text-sm uppercase tracking-wider hover:bg-[#e89200] transition-colors disabled:opacity-50"
              >
                {{ downloading ? 'Downloading...' : 'Download ZIP' }}
              </button>
              <p v-if="!hasPublishedPosts" class="font-mono text-xs text-site-medium text-center">
                No published posts to deploy
              </p>
            </template>

            <!-- AWS Publish -->
            <template v-if="publisherType === 'aws'">
              <!-- Full publish confirmation -->
              <div v-if="showFullPublishConfirm && fullPublishType === 'aws'" class="space-y-3">
                <p class="text-sm text-site-dark">
                  Full publish will re-upload all files. This may take a long time for large sites.
                </p>
                <div class="flex gap-3">
                  <button
                    @click="cancelFullPublish"
                    class="flex-1 px-4 py-3 border border-site-light text-site-dark font-mono text-sm uppercase tracking-wider hover:border-site-dark transition-colors"
                  >
                    Cancel
                  </button>
                  <button
                    @click="executeFullPublish"
                    class="flex-1 px-4 py-3 bg-site-accent text-white font-mono text-sm uppercase tracking-wider hover:bg-[#e89200] transition-colors"
                  >
                    Continue
                  </button>
                </div>
              </div>
              <!-- Normal publish buttons -->
              <div v-else class="flex gap-3">
                <button
                  @click="publishToAWS(false)"
                  :disabled="isWorking || !hasPublishedPosts"
                  class="flex-1 px-4 py-3 bg-site-accent text-white font-mono text-sm uppercase tracking-wider hover:bg-[#e89200] transition-colors disabled:opacity-50"
                >
                  {{ publishing ? 'Publishing...' : 'Publish' }}
                </button>
                <button
                  @click="confirmFullPublish('aws')"
                  :disabled="isWorking || !hasPublishedPosts"
                  class="px-4 py-3 border border-site-accent text-site-accent font-mono text-sm uppercase tracking-wider hover:bg-site-accent hover:text-white transition-colors disabled:opacity-50"
                  title="Re-upload all files"
                >
                  Full
                </button>
              </div>
            </template>

            <!-- SFTP Publish -->
            <template v-if="publisherType === 'sftp'">
              <!-- Full publish confirmation -->
              <div v-if="showFullPublishConfirm && fullPublishType === 'sftp'" class="space-y-3">
                <p class="text-sm text-site-dark">
                  Full publish will re-upload all files. This may take a long time for large sites.
                </p>
                <div class="flex gap-3">
                  <button
                    @click="cancelFullPublish"
                    class="flex-1 px-4 py-3 border border-site-light text-site-dark font-mono text-sm uppercase tracking-wider hover:border-site-dark transition-colors"
                  >
                    Cancel
                  </button>
                  <button
                    @click="executeFullPublish"
                    class="flex-1 px-4 py-3 bg-site-accent text-white font-mono text-sm uppercase tracking-wider hover:bg-[#e89200] transition-colors"
                  >
                    Continue
                  </button>
                </div>
              </div>
              <!-- Normal publish buttons -->
              <div v-else class="flex gap-3">
                <button
                  @click="publishToSFTP(false)"
                  :disabled="isWorking || !hasPublishedPosts"
                  class="flex-1 px-4 py-3 bg-site-accent text-white font-mono text-sm uppercase tracking-wider hover:bg-[#e89200] transition-colors disabled:opacity-50"
                >
                  {{ publishing ? 'Publishing...' : 'Publish' }}
                </button>
                <button
                  @click="confirmFullPublish('sftp')"
                  :disabled="isWorking || !hasPublishedPosts"
                  class="px-4 py-3 border border-site-accent text-site-accent font-mono text-sm uppercase tracking-wider hover:bg-site-accent hover:text-white transition-colors disabled:opacity-50"
                  title="Re-upload all files"
                >
                  Full
                </button>
              </div>
            </template>

            <!-- Git Publish -->
            <template v-if="publisherType === 'git'">
              <button
                @click="publishToGit()"
                :disabled="isWorking || !hasPublishedPosts"
                class="w-full px-4 py-3 bg-site-accent text-white font-mono text-sm uppercase tracking-wider hover:bg-[#e89200] transition-colors disabled:opacity-50"
              >
                {{ publishing ? 'Publishing...' : 'Push to Git' }}
              </button>
            </template>

            <!-- Cloudflare Pages Publish -->
            <template v-if="publisherType === 'cloudflare'">
              <button
                @click="publishToCloudflare()"
                :disabled="isWorking || !hasPublishedPosts"
                class="w-full px-4 py-3 bg-site-accent text-white font-mono text-sm uppercase tracking-wider hover:bg-[#e89200] transition-colors disabled:opacity-50"
              >
                {{ publishing ? 'Publishing...' : 'Deploy to Cloudflare' }}
              </button>
            </template>

            <p v-if="!hasPublishedPosts && publisherType !== 'manual'" class="font-mono text-xs text-site-medium text-center">
              No published posts to deploy
            </p>
          </template>
        </div>
      </div>
    </div>
  </Teleport>
</template>
