import { defineStore } from 'pinia';
import { ref } from 'vue';
import { syncApi } from '@/api';

export const useSyncStore = defineStore('sync', () => {
  // State
  const changesAvailable = ref(false);
  const lastCheckTime = ref(null);
  const syncCheckResult = ref(null);
  const isChecking = ref(false);
  const checkIntervalMs = ref(60 * 60 * 1000); // 1 hour default
  const currentBlogId = ref(null);

  let checkIntervalId = null;

  // Actions

  /**
   * Check for remote sync changes for a blog
   * @param {string} blogId - The blog ID to check
   */
  async function checkForChanges(blogId) {
    if (isChecking.value) return;

    isChecking.value = true;
    try {
      const result = await syncApi.checkChanges(blogId);
      syncCheckResult.value = result;
      changesAvailable.value = result.hasChanges;
      lastCheckTime.value = new Date();
    } catch (e) {
      console.error('Sync check failed:', e);
      // Don't update changesAvailable on error - keep previous state
    } finally {
      isChecking.value = false;
    }
  }

  /**
   * Start periodic sync checking for a blog
   * @param {string} blogId - The blog ID to check periodically
   */
  function startPeriodicCheck(blogId) {
    stopPeriodicCheck();
    currentBlogId.value = blogId;

    // Initial check
    checkForChanges(blogId);

    // Set up interval
    checkIntervalId = setInterval(() => {
      checkForChanges(blogId);
    }, checkIntervalMs.value);
  }

  /**
   * Stop periodic sync checking
   */
  function stopPeriodicCheck() {
    if (checkIntervalId) {
      clearInterval(checkIntervalId);
      checkIntervalId = null;
    }
  }

  /**
   * Clear the changes available state (after sync is performed)
   */
  function clearChanges() {
    changesAvailable.value = false;
    syncCheckResult.value = null;
  }

  /**
   * Update the check interval
   * @param {number} ms - Interval in milliseconds
   */
  function setCheckInterval(ms) {
    checkIntervalMs.value = ms;
    // Restart interval if active
    if (checkIntervalId && currentBlogId.value) {
      startPeriodicCheck(currentBlogId.value);
    }
  }

  /**
   * Reset all sync state (e.g., when switching blogs)
   */
  function reset() {
    stopPeriodicCheck();
    changesAvailable.value = false;
    lastCheckTime.value = null;
    syncCheckResult.value = null;
    isChecking.value = false;
    currentBlogId.value = null;
  }

  return {
    // State
    changesAvailable,
    lastCheckTime,
    syncCheckResult,
    isChecking,
    checkIntervalMs,
    currentBlogId,
    // Actions
    checkForChanges,
    startPeriodicCheck,
    stopPeriodicCheck,
    clearChanges,
    setCheckInterval,
    reset
  };
});
