<script setup>
import { ref, computed, watch, nextTick } from 'vue';
import { shareDestinationApi, shareApi } from '@/api';

const props = defineProps({
  blogId: { type: String, required: true },
  post: { type: Object, default: null },
  show: { type: Boolean, default: false }
});

const emit = defineEmits(['close', 'shared']);

const destinations = ref([]);
const history = ref([]);
const loading = ref(false);
const sending = ref(false);
const selectedId = ref(null);
const error = ref(null);
const result = ref(null);
const confirmReshare = ref(false);
const logMessages = ref([]);
const logContainer = ref(null);

const isWorking = computed(() => loading.value || sending.value);
const hasDestinations = computed(() => destinations.value.length > 0);

const selectedDestination = computed(() =>
  destinations.value.find(d => d.id === selectedId.value) || null
);

const selectedLastShared = computed(() => {
  if (!selectedId.value) return null;
  const successes = history.value.filter(
    h => h.destinationId === selectedId.value && h.status === 'success'
  );
  return successes.length > 0 ? successes[0] : null;
});

watch(() => props.show, (val) => {
  if (val) {
    reset();
    loadData();
  }
});

function reset() {
  destinations.value = [];
  history.value = [];
  selectedId.value = null;
  error.value = null;
  result.value = null;
  confirmReshare.value = false;
  logMessages.value = [];
  sending.value = false;
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

async function loadData() {
  loading.value = true;
  try {
    const [dests, hist] = await Promise.all([
      shareDestinationApi.list(props.blogId),
      props.post ? shareApi.history(props.blogId, props.post.id) : Promise.resolve([])
    ]);
    destinations.value = dests || [];
    history.value = hist || [];
  } catch (e) {
    error.value = e.message;
  } finally {
    loading.value = false;
  }
}

function destinationStatus(destination) {
  const entries = history.value.filter(h => h.destinationId === destination.id);
  if (entries.length === 0) return { kind: 'none', label: 'Not yet shared' };
  const lastSuccess = entries.find(e => e.status === 'success');
  if (lastSuccess) {
    return { kind: 'success', label: `Shared ${formatRelative(lastSuccess.sharedAt)}` };
  }
  const lastAttempt = entries[0];
  return { kind: 'failed', label: `Last attempt failed: ${lastAttempt.error || 'unknown error'}` };
}

function formatRelative(iso) {
  const now = Date.now();
  const then = new Date(iso).getTime();
  const diff = Math.max(0, now - then);
  const seconds = Math.floor(diff / 1000);
  if (seconds < 60) return 'just now';
  const minutes = Math.floor(seconds / 60);
  if (minutes < 60) return `${minutes}m ago`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours}h ago`;
  const days = Math.floor(hours / 24);
  if (days < 30) return `${days}d ago`;
  return new Date(iso).toLocaleDateString();
}

async function doShare(force) {
  if (!selectedId.value) return;

  sending.value = true;
  error.value = null;
  confirmReshare.value = false;

  addLog(`Verifying post URL...`, 'info');

  try {
    const data = await shareApi.share(props.blogId, props.post.id, selectedId.value, { force });
    addLog(`Sent to ${data.destinationName}`, 'success');
    result.value = data;
    history.value = await shareApi.history(props.blogId, props.post.id).catch(() => history.value);
    emit('shared', { destinationId: selectedId.value });
  } catch (e) {
    if (e.alreadyShared && !force) {
      confirmReshare.value = true;
      sending.value = false;
      return;
    }
    addLog(`Share failed: ${e.message}`, 'error');
    error.value = e.message;
  } finally {
    sending.value = false;
  }
}

function clickShare() {
  if (selectedLastShared.value) {
    confirmReshare.value = true;
    return;
  }
  doShare(false);
}

function close() {
  if (isWorking.value) return;
  emit('close');
}
</script>

<template>
  <Teleport to="body">
    <div
      v-if="show"
      class="fixed inset-0 bg-site-bg flex items-center justify-center z-50 p-6 overflow-hidden"
      @click.self="close"
    >
      <!-- Tiled SHARE background -->
      <div class="absolute inset-0 overflow-hidden select-none pointer-events-none" aria-hidden="true">
        <div class="absolute inset-0 flex flex-col justify-center -rotate-12 scale-150 origin-center">
          <div v-for="row in 12" :key="row" class="flex whitespace-nowrap">
            <span
              class="font-bold text-[6rem] md:text-[8rem] leading-none tracking-tighter text-site-light"
              :class="row % 2 === 0 ? '' : 'ml-32'"
            >
              SHARE SHARE SHARE SHARE SHARE SHARE SHARE SHARE SHARE SHARE
            </span>
          </div>
        </div>
      </div>

      <div class="relative max-w-lg w-full">
        <!-- Header -->
        <div class="flex items-end justify-between mb-6">
          <div>
            <h2 class="text-5xl md:text-6xl font-bold text-site-dark leading-none lowercase">
              share
            </h2>
            <p v-if="post" class="font-mono text-sm text-site-medium mt-2 truncate max-w-[24rem]">
              {{ post.displayTitle || post.title || 'untitled post' }}
            </p>
          </div>
          <button
            @click="close"
            :disabled="isWorking"
            class="font-mono text-sm text-site-dark hover:text-site-accent uppercase tracking-wider disabled:opacity-50 disabled:cursor-not-allowed"
          >
            <span class="relative -top-px">&times;</span> Close
          </button>
        </div>

        <!-- Loading -->
        <div v-if="loading" class="bg-white border border-site-light p-4 mb-4 font-mono text-sm text-site-medium">
          Loading destinations...
        </div>

        <!-- No destinations CTA -->
        <div v-else-if="!hasDestinations" class="bg-white border border-site-light p-6 mb-4">
          <p class="font-mono text-sm text-site-dark mb-3">
            No share destinations configured.
          </p>
          <p class="text-sm text-site-medium">
            Add a webhook in <span class="font-mono">Blog Settings &rarr; Sharing</span> to enable sharing.
          </p>
        </div>

        <!-- Done -->
        <div v-else-if="result" class="bg-white border border-site-light p-4 mb-4">
          <p class="font-mono text-sm text-green-600 mb-2">
            &#10003; Shared to {{ result.destinationName }}
          </p>
          <p class="text-sm text-site-medium break-all">
            <a :href="result.permalink" target="_blank" class="hover:text-site-accent underline">
              {{ result.permalink }}
            </a>
          </p>
        </div>

        <!-- Picking + sharing -->
        <template v-else>
          <!-- Destination list -->
          <div class="bg-white border border-site-light mb-4">
            <label
              v-for="d in destinations"
              :key="d.id"
              class="flex items-start gap-3 p-3 border-b border-site-light last:border-b-0 cursor-pointer hover:bg-site-bg/40"
              :class="{ 'bg-site-bg/60': selectedId === d.id }"
            >
              <input
                type="radio"
                :value="d.id"
                v-model="selectedId"
                :disabled="sending"
                class="mt-1"
              />
              <div class="flex-1 min-w-0">
                <div class="flex items-center gap-2">
                  <span class="font-mono text-sm text-site-dark truncate">{{ d.name }}</span>
                  <span class="font-mono text-[0.65rem] uppercase tracking-wider text-site-medium border border-site-light px-1.5 py-0.5">
                    {{ d.type }}
                  </span>
                </div>
                <p
                  class="text-xs mt-1"
                  :class="{
                    'text-green-600': destinationStatus(d).kind === 'success',
                    'text-red-600': destinationStatus(d).kind === 'failed',
                    'text-site-medium': destinationStatus(d).kind === 'none'
                  }"
                >
                  {{ destinationStatus(d).label }}
                </p>
              </div>
            </label>
          </div>

          <!-- Re-share confirmation -->
          <div v-if="confirmReshare && selectedLastShared" class="mb-4 p-3 border border-yellow-500 bg-yellow-500/10">
            <p class="font-mono text-sm text-yellow-700 uppercase mb-2">Already shared</p>
            <p class="text-sm text-site-dark mb-3">
              This post was shared to "{{ selectedDestination?.name }}" {{ formatRelative(selectedLastShared.sharedAt) }}.
              Share again?
            </p>
            <div class="flex gap-2">
              <button
                @click="confirmReshare = false"
                :disabled="sending"
                class="flex-1 px-3 py-2 border border-site-light text-site-dark font-mono text-xs uppercase tracking-wider hover:border-site-dark transition-colors"
              >
                Cancel
              </button>
              <button
                @click="doShare(true)"
                :disabled="sending"
                class="flex-1 px-3 py-2 bg-site-accent text-white font-mono text-xs uppercase tracking-wider hover:bg-[#e89200] transition-colors"
              >
                Share Again
              </button>
            </div>
          </div>

          <!-- Log -->
          <div
            v-if="logMessages.length > 0"
            ref="logContainer"
            class="bg-white border border-site-light p-3 h-32 overflow-y-auto font-mono text-xs mb-4"
          >
            <div
              v-for="(msg, i) in logMessages"
              :key="i"
              :class="getLogClass(msg.type)"
            >
              <span class="text-site-medium">{{ msg.time }}</span> {{ msg.text }}
            </div>
            <div v-if="sending" class="text-site-dark animate-pulse">
              <span class="text-site-medium">{{ new Date().toLocaleTimeString('en-US', { hour12: false }) }}</span> Working...
            </div>
          </div>

          <!-- Error -->
          <div v-if="error" class="mb-4 p-3 border border-red-500 bg-red-500/10">
            <p class="font-mono text-sm text-red-500">{{ error }}</p>
          </div>

          <!-- Action -->
          <button
            v-if="!confirmReshare"
            @click="clickShare"
            :disabled="!selectedId || sending"
            class="w-full px-4 py-3 bg-site-accent text-white font-mono text-sm uppercase tracking-wider hover:bg-[#e89200] transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {{ sending ? 'Sharing...' : 'Share Now' }}
          </button>
        </template>
      </div>
    </div>
  </Teleport>
</template>
