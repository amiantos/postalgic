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

// Discourse-specific share-time state
const discourseMode = ref('reply');  // 'reply' | 'new_topic'
const discourseTopicId = ref(null);
const discourseTopicTitle = ref('');
const discourseTopicQuery = ref('');
const discourseTopicResults = ref([]);
const discourseTopicSearching = ref(false);
const discourseCategories = ref([]);
const discourseCategoryId = ref(null);
const discourseTopicTitleInput = ref('');
const discourseTagsInput = ref('');
let discourseTopicSearchTimeout = null;

const isWorking = computed(() => loading.value || sending.value);
const hasDestinations = computed(() => destinations.value.length > 0);

const selectedDestination = computed(() =>
  destinations.value.find(d => d.id === selectedId.value) || null
);

const isDiscourseSelected = computed(() => selectedDestination.value?.type === 'discourse');

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
  resetDiscourseState();
}

function resetDiscourseState() {
  discourseMode.value = 'reply';
  discourseTopicId.value = null;
  discourseTopicTitle.value = '';
  discourseTopicQuery.value = '';
  discourseTopicResults.value = [];
  discourseTopicSearching.value = false;
  discourseCategories.value = [];
  discourseCategoryId.value = null;
  discourseTopicTitleInput.value = '';
  discourseTagsInput.value = '';
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

// When a Discourse destination is picked, prime the share-time defaults from
// its config and (lazily) load categories so the user can change them.
watch(selectedId, async () => {
  resetDiscourseState();
  const dest = selectedDestination.value;
  if (!dest || dest.type !== 'discourse') return;

  const cfg = dest.config || {};
  if (cfg.defaultTopicId) {
    discourseMode.value = 'reply';
    discourseTopicId.value = cfg.defaultTopicId;
    discourseTopicTitle.value = cfg.defaultTopicTitle || '';
  } else {
    discourseMode.value = 'new_topic';
  }

  discourseCategoryId.value = cfg.defaultCategoryId ?? null;
  discourseTopicTitleInput.value = props.post?.title || props.post?.displayTitle || '';
  discourseTagsInput.value = (props.post?.tags || []).map(t => t.name || t).join(', ');

  // Lazy-fetch categories for the dropdown
  try {
    discourseCategories.value = await shareApi.discourseCategories(props.blogId, dest.id) || [];
  } catch (e) {
    addLog(`Could not load Discourse categories: ${e.message}`, 'warning');
  }
});

watch(discourseTopicQuery, (q) => {
  if (discourseTopicSearchTimeout) clearTimeout(discourseTopicSearchTimeout);
  if (!q || !q.trim() || !isDiscourseSelected.value) {
    discourseTopicResults.value = [];
    return;
  }
  discourseTopicSearchTimeout = setTimeout(searchDiscourseTopicsNow, 400);
});

async function searchDiscourseTopicsNow() {
  if (!isDiscourseSelected.value) return;
  discourseTopicSearching.value = true;
  try {
    const results = await shareApi.discourseSearchTopics(
      props.blogId,
      selectedDestination.value.id,
      discourseTopicQuery.value
    );
    discourseTopicResults.value = results || [];
  } catch (e) {
    addLog(`Search failed: ${e.message}`, 'warning');
    discourseTopicResults.value = [];
  } finally {
    discourseTopicSearching.value = false;
  }
}

function pickTopic(topic) {
  discourseTopicId.value = topic.id;
  discourseTopicTitle.value = topic.title;
  discourseTopicQuery.value = '';
  discourseTopicResults.value = [];
}

function clearTopic() {
  discourseTopicId.value = null;
  discourseTopicTitle.value = '';
}

function buildShareParams() {
  if (!isDiscourseSelected.value) return {};
  if (discourseMode.value === 'reply') {
    return {
      mode: 'reply',
      topicId: discourseTopicId.value
    };
  }
  return {
    mode: 'new_topic',
    title: discourseTopicTitleInput.value || (props.post?.title || ''),
    categoryId: discourseCategoryId.value || null,
    tags: discourseTagsInput.value
      .split(',')
      .map(t => t.trim())
      .filter(Boolean)
  };
}

function validateDiscourseInput() {
  if (!isDiscourseSelected.value) return null;
  if (discourseMode.value === 'reply' && !discourseTopicId.value) {
    return 'Pick a topic to reply to.';
  }
  if (discourseMode.value === 'new_topic' && !discourseTopicTitleInput.value.trim()) {
    return 'A new topic needs a title.';
  }
  return null;
}

async function doShare(force) {
  if (!selectedId.value) return;

  const validationError = validateDiscourseInput();
  if (validationError) {
    error.value = validationError;
    return;
  }

  sending.value = true;
  error.value = null;
  confirmReshare.value = false;

  addLog(`Verifying post URL...`, 'info');

  try {
    const data = await shareApi.share(props.blogId, props.post.id, selectedId.value, {
      force,
      ...buildShareParams()
    });
    addLog(`Sent to ${data.destinationName}`, 'success');
    if (data.result?.postUrl) addLog(data.result.postUrl, 'info');
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
            Add a webhook or Discourse integration in <span class="font-mono">Blog Settings &rarr; Sharing</span> to enable sharing.
          </p>
        </div>

        <!-- Done -->
        <div v-else-if="result" class="bg-white border border-site-light p-4 mb-4 space-y-2">
          <p class="font-mono text-sm text-green-600">
            &#10003; Shared to {{ result.destinationName }}
          </p>
          <p v-if="result.result?.postUrl" class="text-sm text-site-medium break-all">
            Discourse:
            <a :href="result.result.postUrl" target="_blank" class="hover:text-site-accent underline">
              {{ result.result.postUrl }}
            </a>
          </p>
          <p class="text-sm text-site-medium break-all">
            Permalink:
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

          <!-- Discourse sub-form -->
          <div v-if="isDiscourseSelected" class="bg-white border border-site-light p-3 mb-4 space-y-3">
            <div class="flex items-center gap-4">
              <label class="flex items-center gap-2 cursor-pointer">
                <input type="radio" value="reply" v-model="discourseMode" :disabled="sending" />
                <span class="font-mono text-xs uppercase tracking-wider text-site-dark">Reply to topic</span>
              </label>
              <label class="flex items-center gap-2 cursor-pointer">
                <input type="radio" value="new_topic" v-model="discourseMode" :disabled="sending" />
                <span class="font-mono text-xs uppercase tracking-wider text-site-dark">New topic</span>
              </label>
            </div>

            <!-- Reply mode -->
            <div v-if="discourseMode === 'reply'" class="space-y-2">
              <div v-if="discourseTopicId" class="flex items-center gap-2 px-2 py-1 border border-site-light bg-site-bg/40">
                <span class="font-mono text-xs text-site-dark truncate">#{{ discourseTopicId }} {{ discourseTopicTitle }}</span>
                <button @click="clearTopic" type="button" class="ml-auto font-mono text-xs text-site-medium hover:text-red-600 uppercase">Change</button>
              </div>
              <template v-else>
                <input
                  v-model="discourseTopicQuery"
                  type="text"
                  class="admin-input"
                  placeholder="Search Discourse topics..."
                  :disabled="sending"
                />
                <div v-if="discourseTopicSearching" class="text-xs text-site-medium font-mono">Searching...</div>
                <div v-if="discourseTopicResults.length > 0" class="border border-site-light max-h-48 overflow-y-auto">
                  <button
                    v-for="topic in discourseTopicResults"
                    :key="topic.id"
                    type="button"
                    @click="pickTopic(topic)"
                    class="block w-full text-left px-2 py-1.5 text-xs font-mono hover:bg-site-bg border-b border-site-light last:border-b-0"
                  >
                    #{{ topic.id }} {{ topic.title }}
                  </button>
                </div>
              </template>
            </div>

            <!-- New topic mode -->
            <div v-else class="space-y-2">
              <div>
                <label class="block text-xs font-semibold text-site-medium mb-1">Title</label>
                <input v-model="discourseTopicTitleInput" type="text" class="admin-input" :disabled="sending" />
              </div>
              <div>
                <label class="block text-xs font-semibold text-site-medium mb-1">Category</label>
                <select v-model="discourseCategoryId" class="admin-input" :disabled="sending">
                  <option :value="null">— none —</option>
                  <option v-for="cat in discourseCategories" :key="cat.id" :value="cat.id">{{ cat.name }}</option>
                </select>
              </div>
              <div>
                <label class="block text-xs font-semibold text-site-medium mb-1">Tags <span class="text-site-medium font-normal">(comma-separated)</span></label>
                <input v-model="discourseTagsInput" type="text" class="admin-input" :disabled="sending" />
              </div>
            </div>
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
