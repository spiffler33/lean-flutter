/**
 * Lean v2 - Complete port of original implementation
 * Offline-first PWA with IndexedDB storage
 */

// Import styles
import './styles/lean.css';

import { db, addEntry, updateEntry, getRecentEntries, getDeviceId } from './lib/db';
import type { Entry } from './lib/types';
import {
  getRelativeTime,
  saveDraft as saveDraftUtil,
  loadDraft as loadDraftUtil,
  clearDraft as clearDraftUtil,
  isTodo,
  isTodoDone,
  toggleTodo as toggleTodoContent,
  extractTags,
  generateMarkdownExport,
} from './lib/utils';
import { getCurrentUser, signIn, signUp, signOut, onAuthStateChange, resetPassword } from './lib/auth';
import { sync, startAutoSync, stopAutoSync, isSyncing } from './lib/sync';
import { enrichEntry } from './lib/ai';
import { getUserFacts, addFact, removeFact, clearAllFacts, getContextString } from './lib/context';
import { getPatternInsights, formatEntityPattern, formatTemporalPattern } from './lib/patterns';

// Lean App - Complete implementation
const LeanApp = (function() {
  'use strict';

  // ============ State ============
  const state = {
    editingEntryId: null as string | null,
    draftTimer: null as ReturnType<typeof setTimeout> | null,
    currentTheme: localStorage.getItem('lean-theme') || 'minimal',
    todoFilterActive: false,
    currentExportFormat: 'markdown'
  };

  // ============ DOM Elements ============
  const elements = {} as {
    input: HTMLTextAreaElement;
    entries: HTMLDivElement;
    charCounter: HTMLDivElement;
    draftIndicator: HTMLDivElement;
    todoCounter: HTMLDivElement;
    authButton: HTMLElement;
    syncIndicator: HTMLElement;
  };

  // ============ Key Bindings ============
  const KEYS = {
    ENTER: 'Enter',
    ESCAPE: 'Escape',
    ARROW_UP: 'ArrowUp',
    SLASH: '/',
    modifiers: {
      shift: 'shiftKey',
      meta: 'metaKey',
      ctrl: 'ctrlKey',
      alt: 'altKey'
    }
  };

  // ============ Commands ============
  const COMMANDS: Record<string, { handler: string; needsParam?: boolean }> = {
    '/search': { handler: 'handleSearch', needsParam: true },
    '/today': { handler: 'handleToday' },
    '/yesterday': { handler: 'handleYesterday' },
    '/week': { handler: 'handleWeek' },
    '/clear': { handler: 'handleClear' },
    '/stats': { handler: 'handleStats' },
    '/export': { handler: 'handleExport' },
    '/help': { handler: 'handleHelp' },
    '/essay': { handler: 'handleEssay' },
    '/idea': { handler: 'handleIdea' },
    '/theme': { handler: 'handleTheme', needsParam: false },
    '/context': { handler: 'handleContext', needsParam: false },
    '/patterns': { handler: 'handlePatterns' },
  };

  // ============ Core Functions ============

  function init() {
    // Cache DOM elements
    elements.input = document.getElementById('thought-input') as HTMLTextAreaElement;
    elements.entries = document.getElementById('entries') as HTMLDivElement;
    elements.charCounter = document.getElementById('char-counter') as HTMLDivElement;
    elements.draftIndicator = document.getElementById('draft-indicator') as HTMLDivElement;
    elements.todoCounter = document.getElementById('todo-counter') as HTMLDivElement;
    elements.authButton = document.getElementById('auth-button') as HTMLElement;
    elements.syncIndicator = document.getElementById('sync-indicator') as HTMLElement;

    // Set up event listeners
    setupEventListeners();

    // Initialize theme and features
    applyTheme(state.currentTheme);
    loadDraft();
    elements.input.focus();

    // Start observers
    setupObservers();

    // Check auth state
    initAuth();

    // Initial load and updates
    loadEntries().then(() => {
      updateTodoCounter();
      // Delay to ensure DOM is fully rendered, then insert time divider
      setTimeout(() => {
        console.log('Attempting to insert time divider...');
        TimeDivider.insert();
      }, 200);
    });
  }

  // ============ Auth Functions ============

  async function initAuth() {
    console.log('initAuth called');
    console.log('authButton element:', elements.authButton);

    // Set up auth state listener
    onAuthStateChange(async (user) => {
      if (user) {
        // User is signed in
        elements.authButton.textContent = user.email?.split('@')[0] || 'Account';
        elements.syncIndicator.classList.remove('offline');
        elements.syncIndicator.classList.add('synced');
        elements.syncIndicator.textContent = '●';

        // Start auto-sync
        startAutoSync();

        // Initial sync
        await performSync();
      } else {
        // User is signed out
        elements.authButton.textContent = 'Sign In';
        elements.syncIndicator.classList.add('offline');
        elements.syncIndicator.classList.remove('synced', 'syncing');
        elements.syncIndicator.textContent = '○';

        // Stop auto-sync
        stopAutoSync();
      }
    });

    // Set up click handlers
    elements.authButton.addEventListener('click', handleAuthButtonClick);
    elements.syncIndicator.addEventListener('click', handleSyncClick);

    // Check current user
    const user = await getCurrentUser();
    if (user) {
      elements.authButton.textContent = user.email?.split('@')[0] || 'Account';
      elements.syncIndicator.classList.remove('offline');
      elements.syncIndicator.classList.add('synced');
      elements.syncIndicator.textContent = '●';
      startAutoSync();
    }
  }

  function handleAuthButtonClick() {
    console.log('Auth button clicked!');
    getCurrentUser().then(user => {
      console.log('Current user:', user);
      if (user) {
        // Show sign out confirmation
        if (confirm('Sign out?')) {
          signOut().then(() => {
            showNotification('Signed out successfully');
          }).catch(error => {
            console.error('Sign out error:', error);
            showNotification('Failed to sign out');
          });
        }
      } else {
        // Show sign in modal
        showAuthModal();
      }
    });
  }

  async function handleSyncClick() {
    const user = await getCurrentUser();
    if (!user) {
      showNotification('Sign in to sync');
      showAuthModal();
      return;
    }

    if (isSyncing()) {
      showNotification('Sync already in progress');
      return;
    }

    await performSync();
  }

  async function performSync() {
    try {
      elements.syncIndicator.classList.add('syncing');
      elements.syncIndicator.classList.remove('synced');

      const result = await sync();

      elements.syncIndicator.classList.remove('syncing');
      elements.syncIndicator.classList.add('synced');

      if (result.pulled > 0 || result.pushed > 0) {
        // Reload entries after sync
        await loadEntries();
        updateTodoCounter();
        showNotification(`Synced: ${result.pulled} down, ${result.pushed} up`);
      }
    } catch (error) {
      elements.syncIndicator.classList.remove('syncing');
      console.error('Sync error:', error);
      showNotification('Sync failed');
    }
  }

  // ============ Auth Modal Functions ============

  function showAuthModal() {
    console.log('showAuthModal called');
    const modal = document.getElementById('auth-modal');
    console.log('Modal element:', modal);
    if (!modal) {
      console.error('Auth modal not found!');
      return;
    }

    // Reset form
    const emailInput = document.getElementById('auth-email') as HTMLInputElement;
    const passwordInput = document.getElementById('auth-password') as HTMLInputElement;
    const errorDiv = document.getElementById('auth-error') as HTMLDivElement;
    const authForm = document.getElementById('auth-form') as HTMLDivElement;
    const authSuccess = document.getElementById('auth-success') as HTMLDivElement;

    if (emailInput) emailInput.value = '';
    if (passwordInput) passwordInput.value = '';
    if (errorDiv) {
      errorDiv.style.display = 'none';
      errorDiv.textContent = '';
    }
    if (authForm) authForm.style.display = 'block';
    if (authSuccess) authSuccess.style.display = 'none';

    modal.classList.add('show');

    // Focus email input
    setTimeout(() => emailInput?.focus(), 100);
  }

  function closeAuthModal() {
    const modal = document.getElementById('auth-modal');
    if (modal) {
      modal.classList.remove('show');
    }
  }

  async function handleSignIn() {
    const emailInput = document.getElementById('auth-email') as HTMLInputElement;
    const passwordInput = document.getElementById('auth-password') as HTMLInputElement;
    const errorDiv = document.getElementById('auth-error') as HTMLDivElement;
    const authForm = document.getElementById('auth-form') as HTMLDivElement;
    const authSuccess = document.getElementById('auth-success') as HTMLDivElement;

    const email = emailInput?.value.trim();
    const password = passwordInput?.value;

    if (!email || !password) {
      if (errorDiv) {
        errorDiv.textContent = 'Please enter email and password';
        errorDiv.style.display = 'block';
      }
      return;
    }

    try {
      await signIn(email, password);

      // Show success
      if (authForm) authForm.style.display = 'none';
      if (authSuccess) authSuccess.style.display = 'block';

      // Close modal after delay
      setTimeout(() => {
        closeAuthModal();
      }, 1500);
    } catch (error: any) {
      console.error('Sign in error:', error);
      if (errorDiv) {
        errorDiv.textContent = error.message || 'Sign in failed';
        errorDiv.style.display = 'block';
      }
    }
  }

  async function handleSignUp() {
    const emailInput = document.getElementById('auth-email') as HTMLInputElement;
    const passwordInput = document.getElementById('auth-password') as HTMLInputElement;
    const errorDiv = document.getElementById('auth-error') as HTMLDivElement;
    const authForm = document.getElementById('auth-form') as HTMLDivElement;
    const authSuccess = document.getElementById('auth-success') as HTMLDivElement;

    const email = emailInput?.value.trim();
    const password = passwordInput?.value;

    if (!email || !password) {
      if (errorDiv) {
        errorDiv.textContent = 'Please enter email and password';
        errorDiv.style.display = 'block';
      }
      return;
    }

    if (password.length < 6) {
      if (errorDiv) {
        errorDiv.textContent = 'Password must be at least 6 characters';
        errorDiv.style.display = 'block';
      }
      return;
    }

    try {
      await signUp(email, password);

      // Show success
      if (authForm) authForm.style.display = 'none';
      if (authSuccess) {
        authSuccess.innerHTML = `
          <div style="font-size: 32px; margin-bottom: 12px;">✓</div>
          <div style="color: #4CAF50; font-weight: 500;">Account created!</div>
          <div style="font-size: 12px; color: #666; margin-top: 8px;">Check your email to verify your account</div>
        `;
        authSuccess.style.display = 'block';
      }

      // Close modal after delay
      setTimeout(() => {
        closeAuthModal();
      }, 3000);
    } catch (error: any) {
      console.error('Sign up error:', error);
      if (errorDiv) {
        errorDiv.textContent = error.message || 'Sign up failed';
        errorDiv.style.display = 'block';
      }
    }
  }

  async function handleForgotPassword() {
    const emailInput = document.getElementById('auth-email') as HTMLInputElement;
    const email = emailInput?.value.trim();

    if (!email) {
      alert('Please enter your email address');
      return;
    }

    try {
      await resetPassword(email);
      alert('Password reset email sent! Check your inbox.');
    } catch (error: any) {
      console.error('Reset password error:', error);
      alert(error.message || 'Failed to send reset email');
    }
  }

  function setupEventListeners() {
    // Input events
    elements.input.addEventListener('input', handleInput);
    elements.input.addEventListener('keydown', handleInputKeydown);

    // Global keyboard shortcuts
    document.addEventListener('keydown', handleGlobalKeydown);

    // Modal close on escape or outside click
    const statsModal = document.getElementById('stats-modal');
    const exportModal = document.getElementById('export-modal');
    if (statsModal) statsModal.addEventListener('click', handleModalOutsideClick);
    if (exportModal) exportModal.addEventListener('click', handleModalOutsideClick);

    // Reload entries when tab becomes visible (for background sync)
    document.addEventListener('visibilitychange', async () => {
      if (!document.hidden) {
        console.log('Tab visible - forcing immediate sync...');
        const user = await getCurrentUser();
        if (user && !isSyncing()) {
          await performSync();
        } else {
          await loadEntries();
        }
        updateTodoCounter();
        setTimeout(() => TimeDivider.insert(), 100);
      }
    });
  }

  function setupObservers() {
    const observer = new MutationObserver(() => {
      updateTodoCounter();
      // Don't update localStorage here - it gets updated when creating new entries only
    });

    observer.observe(elements.entries, {
      childList: true,
      subtree: true
    });
  }

  // ============ Input Handling ============

  function handleInput() {
    autoResize();
    updateCharCounter();

    clearTimeout(state.draftTimer!);
    state.draftTimer = setTimeout(saveDraft, 3000);
  }

  async function handleInputKeydown(e: KeyboardEvent) {
    // Arrow Up - Edit last entry
    if (e.key === KEYS.ARROW_UP && elements.input.value === '') {
      e.preventDefault();
      editLastEntry();
      return;
    }

    // Escape - Clear or blur
    if (e.key === KEYS.ESCAPE) {
      handleEscapeInInput();
      return;
    }

    // Enter - Submit or new line
    if (e.key === KEYS.ENTER && !e.shiftKey) {
      e.preventDefault();
      await handleSubmit();
    }
  }

  function handleGlobalKeydown(e: KeyboardEvent) {
    const target = e.target as HTMLElement;

    // Skip if in input or using modifiers
    if (target === elements.input ||
        target.tagName === 'INPUT' ||
        target.tagName === 'TEXTAREA' ||
        e.metaKey ||
        e.ctrlKey ||
        e.altKey) return;

    // Jump to input on /
    if (e.key === KEYS.SLASH) {
      e.preventDefault();
      elements.input.focus();
      elements.input.value = '/';
    }

    // Escape handling
    if (e.key === KEYS.ESCAPE) {
      handleGlobalEscape();
    }
  }

  // ============ Command Processing ============

  async function handleSubmit() {
    const content = elements.input.value.trim();
    if (!content) return;

    // Check for commands
    for (const [cmd, config] of Object.entries(COMMANDS)) {
      if (content.startsWith(cmd)) {
        await (CommandHandlers as any)[config.handler](content);
        return;
      }
    }

    // Handle editing or new entry
    if (state.editingEntryId) {
      await saveEdit(state.editingEntryId, content);
    } else {
      await createEntry(content);
    }
  }

  // ============ Command Handlers ============

  const CommandHandlers = {
    async handleSearch(content: string) {
      const searchTerm = content.substring(8).trim();
      let entries: Entry[];

      if (searchTerm) {
        // Search by content or tag
        entries = await db.entries
          .filter(entry => {
            const contentMatch = entry.content.toLowerCase().includes(searchTerm.toLowerCase());
            const tagMatch = entry.tags ? entry.tags.some(tag =>
              tag.toLowerCase().includes(searchTerm.toLowerCase())
            ) : false;
            return contentMatch || tagMatch;
          })
          .reverse()
          .sortBy('created_at');
      } else {
        entries = await getRecentEntries(50);
      }

      renderEntries(entries);
      const displayTerm = searchTerm || 'all entries';
      addSearchIndicator(`search: ${displayTerm}`);
      clearInput();
      updateTodoCounter();
    },

    async handleToday() {
      const today = new Date();
      today.setHours(0, 0, 0, 0);

      const entries = await db.entries
        .where('created_at')
        .above(today)
        .reverse()
        .sortBy('created_at');

      renderEntries(entries);
      addSearchIndicator("today's entries");
      clearInput();
      updateTodoCounter();
    },

    async handleYesterday() {
      const yesterday = new Date();
      yesterday.setDate(yesterday.getDate() - 1);
      yesterday.setHours(0, 0, 0, 0);

      const today = new Date();
      today.setHours(0, 0, 0, 0);

      const entries = await db.entries
        .where('created_at')
        .between(yesterday, today)
        .reverse()
        .sortBy('created_at');

      renderEntries(entries);
      addSearchIndicator("yesterday's entries");
      clearInput();
      updateTodoCounter();
    },

    async handleWeek() {
      const weekAgo = new Date();
      weekAgo.setDate(weekAgo.getDate() - 7);
      weekAgo.setHours(0, 0, 0, 0);

      const entries = await db.entries
        .where('created_at')
        .above(weekAgo)
        .reverse()
        .sortBy('created_at');

      renderEntries(entries);
      addSearchIndicator("last 7 days");
      clearInput();
      updateTodoCounter();
    },

    handleClear() {
      elements.entries.innerHTML = '<div class="no-entries">View cleared. Start typing to add new thoughts!</div>';
      state.todoFilterActive = false;
      elements.todoCounter.classList.remove('filtered');
      TimeDivider.insertForClear();
      clearInput();
      updateTodoCounter();
    },

    handleStats() {
      showStatsModal();
      clearInput();
    },

    handleExport() {
      showExportModal();
      clearInput();
    },

    handleHelp() {
      showHelpTooltip();
      clearInput();
    },

    handleEssay() {
      const template = `# [Title Here]

*[One-line hook that captures the essence]*

## The Problem
[What's broken? What tension exists? Why should anyone care?]

## The Insight
[The key realization. What you see that others don't]

## The Evidence
[Examples, data, observations that support your insight]

## The Implications
[What changes if this is true? What should we do differently?]

## The Takeaway
[One memorable line that captures the transformation]

---
#essay #draft`;

      elements.input.value = template;
      elements.input.rows = 20;
      autoResize();

      const titlePos = template.indexOf('# [') + 2;
      elements.input.setSelectionRange(titlePos, titlePos + 12);

      elements.input.classList.add('saving');
      setTimeout(() => elements.input.classList.remove('saving'), 300);
    },

    handleIdea() {
      const template = `[Title]

[Describe the idea]

Next step: [Action]

#idea`;

      elements.input.value = template;
      elements.input.rows = 8;
      autoResize();

      const titlePos = template.indexOf('[Title]');
      elements.input.setSelectionRange(titlePos, titlePos + 7);

      elements.input.classList.add('saving');
      setTimeout(() => elements.input.classList.remove('saving'), 300);
    },

    handleTheme(content: string) {
      const parts = content.split(' ');
      if (parts.length > 1) {
        const theme = parts[1].toLowerCase();
        const validThemes = ['minimal', 'matrix', 'paper', 'midnight', 'mono'];

        if (validThemes.includes(theme)) {
          applyTheme(theme);
          showNotification(`Theme switched to ${theme}`);
        } else {
          showThemeOptions();
        }
      } else {
        showThemeInfo();
      }
      clearInput();
    },

    async handleContext(content: string) {
      const user = await getCurrentUser();
      if (!user) {
        showNotification('Sign in to use /context');
        showAuthModal();
        clearInput();
        return;
      }

      const parts = content.trim().split(' ');
      const subcommand = parts[1];

      try {
        if (content === '/context') {
          // Display all facts
          const facts = await getUserFacts();

          if (facts.length === 0) {
            showNotification('No context facts yet. Use /context [text] to add facts.');
            clearInput();
            return;
          }

          // Group by category
          const categorized: Record<string, typeof facts> = {
            work: [],
            personal: [],
            people: [],
            location: [],
            other: [],
          };

          facts.forEach(fact => {
            const category = fact.fact_category || 'other';
            categorized[category].push(fact);
          });

          // Build HTML
          let html = '<div class="entry"><div class="entry-content"><strong>Your Context Facts:</strong><br><br>';
          for (const [category, items] of Object.entries(categorized)) {
            if (items.length > 0) {
              html += `<strong>${category.charAt(0).toUpperCase() + category.slice(1)}:</strong><br>`;
              for (const fact of items) {
                html += `[${fact.fact_id.substring(0, 8)}] ${fact.fact_text}<br>`;
              }
              html += '<br>';
            }
          }
          html += '<em>Use /context remove [id] to delete a fact</em></div></div>';

          elements.entries.insertBefore(
            createHTMLElement(html),
            elements.entries.firstChild
          );
        } else if (subcommand === 'clear') {
          // Clear all facts
          await clearAllFacts();
          showNotification('All context facts cleared.');
        } else if (subcommand === 'remove' && parts[2]) {
          // Remove specific fact
          await removeFact(parts[2]);
          showNotification(`Removed fact.`);
        } else if (content.startsWith('/context ')) {
          // Add new fact
          const factText = content.substring(9).trim();
          const fact = await addFact(factText);
          showNotification(`Added to context (${fact.fact_category}): ${factText}`);
        }
      } catch (error: any) {
        console.error('Context command error:', error);
        showNotification(error.message || 'Failed to process context command');
      }

      clearInput();
    },

    async handlePatterns() {
      const user = await getCurrentUser();
      if (!user) {
        showNotification('Sign in to use /patterns');
        showAuthModal();
        clearInput();
        return;
      }

      try {
        const { entities, temporal, summary } = await getPatternInsights();

        // Build HTML display
        let html = '<div class="entry"><div class="entry-content"><strong>AI-Learned Patterns:</strong><br><br>';

        html += `<em>${summary}</em><br><br>`;

        if (entities.length > 0) {
          html += '<strong>People & Entities:</strong><br>';
          entities.forEach(entity => {
            html += formatEntityPattern(entity).replace(/\n/g, '<br>') + '<br>';
          });
          html += '<br>';
        }

        if (temporal.length > 0) {
          html += '<strong>Writing Rhythms:</strong><br>';
          temporal.forEach(pattern => {
            html += formatTemporalPattern(pattern).replace(/\n/g, '<br>') + '<br>';
          });
        }

        html += '</div></div>';

        elements.entries.insertBefore(
          createHTMLElement(html),
          elements.entries.firstChild
        );
      } catch (error: any) {
        console.error('Patterns command error:', error);
        showNotification(error.message || 'Failed to load patterns');
      }

      clearInput();
    },
  };

  // ============ Entry Operations ============

  async function createEntry(content: string) {
    // Remove any existing time divider (user is writing, session continues)
    const existingDivider = document.querySelector('.time-divider');
    if (existingDivider) {
      existingDivider.remove();
    }

    // Visual feedback
    elements.input.classList.add('saving');
    setTimeout(() => elements.input.classList.remove('saving'), 300);

    // Optimistic UI
    const tempEntry = createTempEntry(content);
    insertEntry(tempEntry);

    // Clear input immediately
    clearInput();
    clearDraftUtil();

    // Save to IndexedDB
    const entry = await addEntry({
      content,
      created_at: new Date(),
      synced: false,
      device_id: getDeviceId(),
      tags: extractTags(content),
    });

    // Update last entry time for time divider calculation
    if (entry) {
      localStorage.setItem('lean-last-entry-time', entry.created_at.toISOString());
    }

    // Remove temp entry and add real one
    setTimeout(() => {
      tempEntry.remove();
      if (entry) {
        const realEntry = createEntryElement(entry, true);
        insertEntry(realEntry);
      }
    }, 500);

    // Background enrichment (async, don't block UI)
    if (entry && entry.id) {
      performEnrichment(entry.id, content).catch(err => {
        console.error('Enrichment failed:', err);
      });
    }
  }

  async function performEnrichment(entryId: string, content: string) {
    // Show AI indicator
    const indicator = document.querySelector(`.ai-indicator[data-entry-id="${entryId}"]`) as HTMLElement;
    if (indicator) {
      indicator.style.display = 'inline';
      indicator.title = 'AI enrichment in progress...';
    }

    try {
      // Get user context for AI prompting
      const userContext = await getContextString();

      // Call Claude API for enrichment
      const enrichment = await enrichEntry(content, userContext);

      // Update entry with enrichment results
      await updateEntry(entryId, {
        mood: enrichment.emotion,
        themes: enrichment.themes,
        people: enrichment.people,
        actions: enrichment.actions,
        urgency: enrichment.urgency,
      });

      console.log(`✨ Enriched entry ${entryId}:`, enrichment);

      // Update the entry element with new badges
      const entry = await db.entries.get(entryId);
      if (entry) {
        const entryEl = document.querySelector(`.entry[data-id="${entryId}"]`);
        if (entryEl) {
          const newEntryEl = createEntryElement(entry);
          entryEl.replaceWith(newEntryEl);
        }
      }

      // Hide indicator after a brief success animation
      setTimeout(() => {
        const updatedIndicator = document.querySelector(`.ai-indicator[data-entry-id="${entryId}"]`) as HTMLElement;
        if (updatedIndicator) {
          updatedIndicator.textContent = '✓';
          updatedIndicator.title = 'AI enrichment complete';
          setTimeout(() => {
            updatedIndicator.style.display = 'none';
          }, 2000);
        }
      }, 100);
    } catch (error) {
      console.error('Failed to enrich entry:', error);
      // Hide indicator on error
      if (indicator) {
        indicator.textContent = '✗';
        indicator.title = 'AI enrichment failed';
        indicator.style.color = '#ef4444';
        setTimeout(() => {
          indicator.style.display = 'none';
        }, 3000);
      }
    }
  }

  async function saveEdit(entryId: string, content: string) {
    await updateEntry(entryId, {
      content,
      tags: extractTags(content),
    });

    // Re-render entry
    const entry = await db.entries.get(entryId);
    if (entry) {
      const entryEl = document.querySelector(`.entry[data-id="${entryId}"]`);
      if (entryEl) {
        entryEl.outerHTML = createEntryElement(entry).outerHTML;
      }
    }

    state.editingEntryId = null;
    clearInput();
    clearDraftUtil();

    // Remove editing class from all entries
    document.querySelectorAll('.entry.editing').forEach(entry => {
      entry.classList.remove('editing');
    });
  }

  // ============ Entry Rendering ============

  async function loadEntries() {
    const entries = await getRecentEntries(50);

    if (entries.length === 0) {
      elements.entries.innerHTML = '<div class="no-entries">No entries yet. Start typing!</div>';
      return;
    }

    renderEntries(entries);
  }

  function renderEntries(entries: Entry[]) {
    if (entries.length === 0) {
      elements.entries.innerHTML = '<div class="no-entries">No entries found.</div>';
      return;
    }

    elements.entries.innerHTML = '';
    entries.forEach(entry => {
      const entryEl = createEntryElement(entry);
      elements.entries.appendChild(entryEl);
    });
  }

  function createEntryElement(entry: Entry, isNew: boolean = false): HTMLElement {
    const div = document.createElement('div');
    div.className = 'entry';
    if (isNew) div.classList.add('new-entry');

    // Check if it's a todo and add classes
    const isTodoItem = isTodo(entry.content);
    const isTodoDoneItem = isTodoDone(entry.content);
    if (isTodoItem && isTodoDoneItem) {
      div.classList.add('todo-done');
    }

    div.dataset.id = entry.id;
    div.dataset.created = entry.created_at.toISOString();

    // Format content with tags
    let formattedContent = formatContentWithTags(entry.content);

    // Add todo checkbox if needed
    if (isTodoItem) {
      const checkbox = isTodoDoneItem ? '☑' : '□';
      const todoText = formattedContent.replace(/#todo|#done/g, '').trim();
      formattedContent = `<span class="todo-checkbox" onclick="window.toggleTodo('${entry.id}')">${checkbox}</span><span class="todo-text">${todoText}</span>`;
    }

    // Build AI enrichment badges
    let aiBadges = '';
    if (entry.mood || entry.themes || entry.people || entry.actions) {
      const badges = [];
      if (entry.mood) badges.push(`<span class="ai-badge mood" title="Detected emotion">${entry.mood}</span>`);
      if (entry.themes && entry.themes.length > 0) {
        badges.push(`<span class="ai-badge theme" title="Detected themes">${entry.themes.join(', ')}</span>`);
      }
      if (entry.people && entry.people.length > 0) {
        badges.push(`<span class="ai-badge people" title="People mentioned">${entry.people.join(', ')}</span>`);
      }
      if (entry.urgency && entry.urgency !== 'none') {
        badges.push(`<span class="ai-badge urgency-${entry.urgency}" title="Urgency">${entry.urgency}</span>`);
      }
      if (badges.length > 0) {
        aiBadges = `<div class="ai-badges">${badges.join('')}</div>`;
      }
    }

    div.innerHTML = `
      <div class="entry-content">${formattedContent}</div>
      ${aiBadges}
      <div class="entry-meta">
        ${getRelativeTime(entry.created_at)}
        ${entry.synced ? '' : '<span style="color:#f59e0b;margin-left:8px;">•</span>'}
        <span class="ai-indicator" data-entry-id="${entry.id}" style="display:none;margin-left:8px;color:#8b5cf6;">◐</span>
      </div>
      <div class="entry-actions">
        <button class="entry-action" onclick="window.editEntry('${entry.id}')" title="Edit">⋮</button>
        <button class="entry-action delete" onclick="window.deleteEntry('${entry.id}')" title="Delete">×</button>
      </div>
    `;

    return div;
  }

  function formatContentWithTags(content: string): string {
    // Replace tags with clickable links
    let formatted = content.replace(
      /#(\w+)/g,
      '<a href="#" class="tag" onclick="window.searchTag(\'#$1\'); return false;">#$1</a>'
    );
    // Replace newlines with <br>
    formatted = formatted.replace(/\n/g, '<br>');
    return formatted;
  }

  // ============ UI Components ============

  const TimeDivider = {
    insert() {
      // ALWAYS insert divider on page load - it indicates "page was refreshed"
      // Gets removed when user writes a new entry
      const firstEntry = elements.entries.querySelector<HTMLElement>('.entry[data-id]');

      if (!firstEntry) {
        console.log('No entries found, skipping divider');
        return;
      }

      const now = new Date();
      const dividerText = this.formatDividerText(now);
      const divider = this.createDividerElement(dividerText);
      elements.entries.insertBefore(divider, firstEntry);

      console.log('Inserted page refresh divider');
    },

    insertForClear() {
      // Insert divider on /clear command
      const now = new Date();
      const dividerText = this.formatDividerText(now);
      const divider = this.createDividerElement(dividerText);
      elements.entries.insertBefore(divider, elements.entries.firstChild);
    },

    formatDividerText(now: Date): string {
      const dayName = now.toLocaleDateString('en-US', { weekday: 'long' });
      const monthDay = now.toLocaleDateString('en-US', { month: 'long', day: 'numeric' });
      const time = now.toLocaleTimeString('en-US', {
        hour: 'numeric',
        minute: '2-digit',
        hour12: true
      }).toLowerCase();

      return `${dayName}, ${monthDay}, ${time}`;
    },

    createDividerElement(text: string): HTMLElement {
      const textLength = text.length;
      const totalWidth = 50;
      const paddingLength = Math.max(3, Math.floor((totalWidth - textLength - 2) / 2));
      const leftLine = '━'.repeat(paddingLength);
      const rightLine = '━'.repeat(paddingLength);

      const divider = document.createElement('div');
      divider.className = 'time-divider';
      divider.innerHTML = `${leftLine} ${text} ${rightLine}`;
      return divider;
    }
  };

  // ============ Utility Functions ============

  function autoResize() {
    elements.input.style.height = 'auto';
    elements.input.style.height = elements.input.scrollHeight + 'px';
  }

  function updateCharCounter() {
    const length = elements.input.value.length;

    if (length < 200) {
      elements.charCounter.classList.remove('visible');
      return;
    }

    elements.charCounter.classList.add('visible');

    if (length < 280) {
      elements.charCounter.textContent = `${length}`;
      elements.charCounter.className = 'char-counter visible';
    } else if (length < 400) {
      elements.charCounter.textContent = `${length} / 280`;
      elements.charCounter.className = 'char-counter visible warning';
    } else {
      elements.charCounter.textContent = `${length} / 400`;
      elements.charCounter.className = 'char-counter visible danger';
    }
  }

  function saveDraft() {
    if (elements.input.value.trim()) {
      saveDraftUtil(elements.input.value);
      elements.draftIndicator.classList.add('visible');
      setTimeout(() => elements.draftIndicator.classList.remove('visible'), 1000);
    } else {
      clearDraftUtil();
    }
  }

  function loadDraft() {
    const draft = loadDraftUtil();
    if (draft) {
      elements.input.value = draft;
      autoResize();
      updateCharCounter();
    }
  }

  function clearInput() {
    elements.input.value = '';
    autoResize();
    updateCharCounter();
  }

  function applyTheme(theme: string) {
    document.body.classList.remove('theme-minimal', 'theme-matrix', 'theme-paper', 'theme-midnight', 'theme-mono');
    document.body.classList.add(`theme-${theme}`);
    localStorage.setItem('lean-theme', theme);
    state.currentTheme = theme;
  }

  // ============ Todo Functions ============

  async function toggleTodo(entryId: string) {
    const entry = await db.entries.get(entryId);
    if (!entry) return;

    const newContent = toggleTodoContent(entry.content);
    await updateEntry(entryId, { content: newContent });

    // Re-render
    const entryEl = document.querySelector(`.entry[data-id="${entryId}"]`);
    if (entryEl) {
      const updatedEntry = { ...entry, content: newContent };
      entryEl.outerHTML = createEntryElement(updatedEntry).outerHTML;
    }

    setTimeout(updateTodoCounter, 100);
  }

  async function toggleTodoFilter() {
    const entries = document.querySelectorAll<HTMLElement>('.entry[data-id]');

    if (entries.length === 0 && !state.todoFilterActive) {
      await fetchAndShowTodos();
      return;
    }

    state.todoFilterActive = !state.todoFilterActive;

    if (state.todoFilterActive) {
      filterTodos(entries);
    } else {
      showAllEntries(entries);
    }
  }

  async function updateTodoCounter() {
    try {
      const allEntries = await db.entries.toArray();
      const todoEntries = allEntries.filter((entry): entry is Entry =>
        !!entry.content && entry.content.includes('#todo') && !entry.content.includes('#done')
      );

      if (todoEntries.length > 0) {
        elements.todoCounter.textContent = `□ ${todoEntries.length}`;
        elements.todoCounter.classList.add('visible');

        // Check if any todos are old (more than 2 days)
        const twoDaysAgo = new Date();
        twoDaysAgo.setDate(twoDaysAgo.getDate() - 2);
        const hasOld = todoEntries.some(entry => entry.created_at < twoDaysAgo);
        elements.todoCounter.classList.toggle('has-old', hasOld);
      } else {
        elements.todoCounter.classList.remove('visible');
        state.todoFilterActive = false;
        elements.todoCounter.classList.remove('filtered');
      }
    } catch (error) {
      console.error('Failed to fetch todo count:', error);
    }
  }

  // ============ Modal Functions ============

  async function showStatsModal() {
    const modal = document.getElementById('stats-modal');
    const statsContent = document.getElementById('stats-content');

    if (!modal || !statsContent) return;

    statsContent.innerHTML = '<div style="text-align:center;padding:40px;color:#888;">Loading stats...</div>';
    modal.classList.add('show');

    try {
      const allEntries = await db.entries.toArray();

      if (allEntries.length === 0) {
        statsContent.innerHTML = '<div style="text-align:center;padding:40px;color:#888;">No entries yet. Start writing!</div>';
        return;
      }

      const data = calculateStats(allEntries);
      statsContent.innerHTML = formatStatsDisplay(data);
    } catch (error) {
      statsContent.innerHTML = '<div style="text-align:center;padding:40px;color:#ef4444;">Failed to load stats</div>';
      console.error('Failed to load stats:', error);
    }
  }

  function calculateStats(entries: Entry[]) {
    const now = new Date();
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const weekAgo = new Date(today);
    weekAgo.setDate(weekAgo.getDate() - 7);
    const monthAgo = new Date(today);
    monthAgo.setDate(monthAgo.getDate() - 30);

    const todayCount = entries.filter(e => e.created_at >= today).length;
    const weekCount = entries.filter(e => e.created_at >= weekAgo).length;
    const monthCount = entries.filter(e => e.created_at >= monthAgo).length;

    const totalWords = entries.reduce((sum, e) => sum + e.content.split(/\s+/).length, 0);
    const avgWords = Math.round(totalWords / entries.length);

    // Calculate activity for last 7 days
    const activity7days = [];
    for (let i = 6; i >= 0; i--) {
      const day = new Date(today);
      day.setDate(day.getDate() - i);
      const nextDay = new Date(day);
      nextDay.setDate(nextDay.getDate() + 1);
      const count = entries.filter(e => e.created_at >= day && e.created_at < nextDay).length;
      activity7days.push({
        day: day.toLocaleDateString('en-US', { weekday: 'short' }),
        count
      });
    }

    // Top tags
    const tagCounts: Record<string, number> = {};
    entries.forEach(entry => {
      if (entry.tags) {
        entry.tags.forEach(tag => {
          tagCounts[tag] = (tagCounts[tag] || 0) + 1;
        });
      }
    });
    const topTags = Object.entries(tagCounts)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 5)
      .map(([tag, count]) => ({ tag, count }));

    // Heatmap for last 30 days
    const heatmap = [];
    for (let i = 29; i >= 0; i--) {
      const day = new Date(today);
      day.setDate(day.getDate() - i);
      const nextDay = new Date(day);
      nextDay.setDate(nextDay.getDate() + 1);
      const count = entries.filter(e => e.created_at >= day && e.created_at < nextDay).length;
      heatmap.push(count);
    }

    // Streak calculation
    let currentStreak = 0;
    let longestStreak = 0;
    let checkDate = new Date(today);
    while (true) {
      const nextDay = new Date(checkDate);
      nextDay.setDate(nextDay.getDate() + 1);
      const hasEntry = entries.some(e => e.created_at >= checkDate && e.created_at < nextDay);
      if (hasEntry) {
        currentStreak++;
        longestStreak = Math.max(longestStreak, currentStreak);
        checkDate.setDate(checkDate.getDate() - 1);
      } else {
        break;
      }
    }

    // Best day
    const dayCounts: Record<string, number> = {};
    entries.forEach(entry => {
      const dayKey = entry.created_at.toLocaleDateString();
      dayCounts[dayKey] = (dayCounts[dayKey] || 0) + 1;
    });
    const bestDayEntry = Object.entries(dayCounts).sort((a, b) => b[1] - a[1])[0];
    const bestDay = bestDayEntry ? `${bestDayEntry[1]} entries` : '0 entries';

    return {
      total_entries: entries.length,
      today_count: todayCount,
      week_count: weekCount,
      month_count: monthCount,
      total_words: totalWords,
      daily_avg: avgWords,
      best_day: bestDay,
      activity_7days: activity7days,
      top_tags: topTags,
      heatmap,
      current_streak: currentStreak,
      longest_streak: longestStreak,
      trend: weekCount > monthCount / 4 ? '▲ Up' : '▼ Down'
    };
  }

  function formatStatsDisplay(data: any): string {
    const fmt = (n: number) => n.toLocaleString();

    const maxCount = Math.max(...data.activity_7days.map((d: any) => d.count));
    const activityBars = data.activity_7days.map((d: any) => {
      const barLength = maxCount > 0 ? Math.round((d.count / maxCount) * 20) : 0;
      const bar = '█'.repeat(barLength) || '▁';
      return `   ${d.day} ${bar} (${d.count})`;
    }).join('\n');

    const heatChars = ['□','▤','▥','▦','▧','▨','▩','█'];
    const maxHeat = Math.max(...data.heatmap);
    const heatmap = data.heatmap.map((count: number) => {
      if (count === 0) return heatChars[0];
      const level = Math.min(7, Math.ceil((count / maxHeat) * 7));
      return heatChars[level];
    }).join('');

    const maxTagCount = data.top_tags[0]?.count || 0;
    const tagBars = data.top_tags.map((tag: any, i: number) => {
      const num = ['①','②','③','④','⑤'][i];
      const barLength = maxTagCount > 0 ? Math.round((tag.count / maxTagCount) * 12) : 0;
      const bar = '█'.repeat(barLength);
      return `   ${num} ${tag.tag.padEnd(10)} ${bar} (${tag.count})`;
    }).join('\n');

    return `<pre style="font-family:monospace;color:#333;line-height:1.6;">
╔═══════════════════════════════════════╗
║      ▊ Your Thought Patterns          ║
╚═══════════════════════════════════════╝

<strong>STREAK</strong>
   Current Streak: ${'▲'.repeat(Math.min(data.current_streak, 10))} ${data.current_streak} day${data.current_streak !== 1 ? 's' : ''}
   Longest Streak: ★ ${data.longest_streak} day${data.longest_streak !== 1 ? 's' : ''}

<strong>STATS OVERVIEW</strong>
   Entries ··········· ${fmt(data.total_entries)}
   Today ············· ${data.today_count}
   This Week ········· ${data.week_count}
   This Month ········ ${data.month_count}
   Total Words ······· ${fmt(data.total_words)}
   Daily Average ····· ${data.daily_avg}
   Best Day ·········· ${data.best_day}

<strong>ACTIVITY (Last 7 days)</strong>
${activityBars}

<strong>TOP TAGS</strong>
${tagBars || '   No tags yet'}

<strong>30-DAY HEATMAP</strong>
   Last 30 days: ${heatmap}

<strong>TREND</strong>
   Productivity: ${data.trend} this week
</pre>`;
  }

  function closeStatsModal() {
    const modal = document.getElementById('stats-modal');
    if (modal) {
      modal.classList.remove('show');
    }
    elements.input.focus();
  }

  async function showExportModal() {
    const modal = document.getElementById('export-modal');
    if (!modal) return;

    modal.classList.add('show');

    const dateRangeSelect = document.getElementById('export-date-range') as HTMLSelectElement;
    const tagFilter = document.getElementById('export-tag-filter') as HTMLInputElement;
    const includeTimestamps = document.getElementById('export-include-timestamps') as HTMLInputElement;

    if (dateRangeSelect) dateRangeSelect.value = 'all';
    if (tagFilter) tagFilter.value = '';
    if (includeTimestamps) includeTimestamps.checked = true;

    state.currentExportFormat = 'markdown';
    document.getElementById('format-markdown')?.classList.add('active');
    document.getElementById('format-writeas')?.classList.remove('active');

    await updateExport();
  }

  async function updateExport() {
    const dateRangeSelect = document.getElementById('export-date-range') as HTMLSelectElement;
    const tagFilter = document.getElementById('export-tag-filter') as HTMLInputElement;
    const includeTimestamps = document.getElementById('export-include-timestamps') as HTMLInputElement;
    const exportContent = document.getElementById('export-content') as HTMLTextAreaElement;

    if (!dateRangeSelect || !exportContent) return;

    const dateRange = dateRangeSelect.value;
    const tagFilterValue = tagFilter?.value || '';
    const includeTimestampsValue = includeTimestamps?.checked ?? true;

    // Get entries based on date range
    let entries: Entry[];
    const now = new Date();

    switch (dateRange) {
      case 'day': {
        const dayAgo = new Date(now);
        dayAgo.setDate(dayAgo.getDate() - 1);
        entries = await db.entries.where('created_at').above(dayAgo).sortBy('created_at');
        break;
      }
      case 'week': {
        const weekAgo = new Date(now);
        weekAgo.setDate(weekAgo.getDate() - 7);
        entries = await db.entries.where('created_at').above(weekAgo).sortBy('created_at');
        break;
      }
      case 'month': {
        const monthAgo = new Date(now);
        monthAgo.setDate(monthAgo.getDate() - 30);
        entries = await db.entries.where('created_at').above(monthAgo).sortBy('created_at');
        break;
      }
      default:
        entries = await db.entries.toArray();
        entries.sort((a, b) => a.created_at.getTime() - b.created_at.getTime());
    }

    // Filter by tag if specified
    if (tagFilterValue) {
      entries = entries.filter(entry =>
        entry.tags && entry.tags.some(tag => tag.includes(tagFilterValue.replace('#', '')))
      );
    }

    // Generate markdown
    const markdown = generateMarkdownExport(entries, includeTimestampsValue);
    exportContent.value = markdown;

    const copyBtn = document.querySelector('.modal-button.primary') as HTMLButtonElement;
    if (copyBtn) {
      copyBtn.textContent = state.currentExportFormat === 'writeas'
        ? 'Copy as write.as Draft'
        : 'Copy to Clipboard';
    }
  }

  function setExportFormat(format: string) {
    state.currentExportFormat = format;

    document.getElementById('format-markdown')?.classList.toggle('active', format === 'markdown');
    document.getElementById('format-writeas')?.classList.toggle('active', format === 'writeas');

    updateExport();
  }

  function closeExportModal() {
    const modal = document.getElementById('export-modal');
    if (modal) {
      modal.classList.remove('show');
    }
    elements.input.focus();
  }

  function copyExportContent() {
    const exportContent = document.getElementById('export-content') as HTMLTextAreaElement;
    if (!exportContent) return;

    exportContent.select();
    navigator.clipboard.writeText(exportContent.value).then(() => {
      const button = document.querySelector('.modal-button.primary') as HTMLButtonElement;
      if (button) {
        const originalText = button.textContent || '';
        button.textContent = 'Copied!';
        button.style.background = '#4CAF50';
        setTimeout(() => {
          button.textContent = originalText;
          button.style.background = '';
        }, 1500);
      }
    });
  }

  // ============ Helper Functions ============

  function createTempEntry(content: string): HTMLElement {
    const formattedContent = formatContentWithTags(content);

    const tempEntry = document.createElement('div');
    tempEntry.className = 'entry new-entry';
    tempEntry.dataset.tempId = 'temp-' + Date.now();
    tempEntry.innerHTML = `
      <div class="entry-content">${formattedContent}</div>
      <div class="entry-meta">◷ just now<span class="success-indicator">✓</span></div>
    `;

    return tempEntry;
  }

  function insertEntry(entry: HTMLElement) {
    const indicator = elements.entries.querySelector('.search-indicator');
    if (indicator) {
      elements.entries.insertBefore(entry, elements.entries.children[1]);
    } else {
      elements.entries.insertBefore(entry, elements.entries.firstChild);
    }
  }

  function addSearchIndicator(searchTerm: string) {
    const indicator = document.createElement('div');
    indicator.className = 'search-indicator';
    indicator.textContent = `Showing: ${searchTerm} (press Esc to clear)`;
    elements.entries.insertBefore(indicator, elements.entries.firstChild);
  }

  function showNotification(message: string) {
    const notif = document.createElement('div');
    notif.className = 'entry';
    notif.innerHTML = `
      <div class="entry-content">▪ ${message}</div>
      <div class="entry-meta">◷ just now</div>
    `;
    elements.entries.insertBefore(notif, elements.entries.firstChild);
    setTimeout(() => notif.remove(), 3000);
  }

  function createHTMLElement(html: string): HTMLElement {
    const temp = document.createElement('div');
    temp.innerHTML = html;
    return temp.firstElementChild as HTMLElement;
  }

  function showHelpTooltip() {
    const existingHelp = document.querySelector('.help-tooltip');
    if (existingHelp) existingHelp.remove();

    const helpDiv = document.createElement('div');
    helpDiv.className = 'help-tooltip';
    helpDiv.innerHTML = `
      <h4>Commands</h4>
      <div class="command"><span class="cmd">◎ /search term</span><span class="desc">Search entries</span></div>
      <div class="command"><span class="cmd">▦ /today</span><span class="desc">Today's entries</span></div>
      <div class="command"><span class="cmd">≈ /yesterday</span><span class="desc">Yesterday's entries</span></div>
      <div class="command"><span class="cmd">▤ /week</span><span class="desc">Last 7 days</span></div>
      <div class="command"><span class="cmd">▨ /clear</span><span class="desc">Clear view</span></div>
      <div class="command"><span class="cmd">▨ /export</span><span class="desc">Export as markdown</span></div>
      <div class="command"><span class="cmd">▊ /stats</span><span class="desc">View statistics</span></div>
      <div class="command"><span class="cmd">◆ /theme [name]</span><span class="desc">Change theme</span></div>
      <div class="command"><span class="cmd">✎ /essay</span><span class="desc">Essay template</span></div>
      <div class="command"><span class="cmd">▪ /idea</span><span class="desc">Idea template</span></div>
      <div class="command"><span class="cmd">◎ /help</span><span class="desc">Show this help</span></div>

      <h4 style="margin-top: 12px;">AI Features</h4>
      <div class="command"><span class="cmd">● /context [text]</span><span class="desc">Manage user context</span></div>
      <div class="command"><span class="cmd">◆ /patterns</span><span class="desc">View AI insights</span></div>

      <h4 style="margin-top: 12px;">Todos</h4>
      <div class="command"><span class="cmd">#todo</span><span class="desc">Creates checkbox</span></div>
      <div class="command"><span class="cmd">Click □</span><span class="desc">Mark as done</span></div>

      <h4 style="margin-top: 12px;">Keyboard</h4>
      <div class="command"><span class="cmd">↑</span><span class="desc">Edit last entry</span></div>
      <div class="command"><span class="cmd">/</span><span class="desc">Focus input</span></div>
      <div class="command"><span class="cmd">Esc</span><span class="desc">Clear/close</span></div>

      <div style="margin-top: 12px; color: #999; font-size: 11px;">Press Esc to close</div>
    `;
    document.body.appendChild(helpDiv);

    setTimeout(() => {
      if (helpDiv.parentNode) helpDiv.remove();
    }, 10000);
  }

  function editLastEntry() {
    const firstEntry = elements.entries.querySelector<HTMLElement>('.entry[data-id]');
    if (!firstEntry) return;

    const entryId = firstEntry.dataset.id;
    if (!entryId) return;

    editEntry(entryId);
  }

  async function editEntry(entryId: string) {
    const entry = await db.entries.get(entryId);
    if (!entry) return;

    elements.input.value = entry.content;
    state.editingEntryId = entryId;
    autoResize();
    updateCharCounter();

    // Highlight the entry being edited
    const entryEl = document.querySelector(`.entry[data-id="${entryId}"]`);
    entryEl?.classList.add('editing');

    // Remove editing class from any other entries
    document.querySelectorAll('.entry.editing').forEach(e => {
      if (e !== entryEl) e.classList.remove('editing');
    });

    // Focus input
    elements.input.focus();
  }

  async function deleteEntry(entryId: string) {
    const entryEl = document.querySelector(`.entry[data-id="${entryId}"]`);
    if (!entryEl) return;

    // Simple confirmation
    if (!confirm('Delete this entry?')) return;

    try {
      await db.entries.delete(entryId);

      // Animate out then remove
      (entryEl as HTMLElement).style.opacity = '0';
      (entryEl as HTMLElement).style.transform = 'translateX(-20px)';
      setTimeout(() => {
        entryEl.remove();
        // Update todo counter after deletion
        updateTodoCounter();
      }, 300);
    } catch (error) {
      console.error('Failed to delete entry:', error);
    }
  }

  function handleEscapeInInput() {
    if (elements.input.value) {
      elements.input.value = '';
      autoResize();
      updateCharCounter();
      state.editingEntryId = null;

      document.querySelectorAll('.entry.editing').forEach(entry => {
        entry.classList.remove('editing');
      });
    } else {
      elements.input.blur();
    }
  }

  async function handleGlobalEscape() {
    // Check if FAB menu is open
    const fabMenu = document.getElementById('fab-menu');
    if (fabMenu?.classList.contains('show')) {
      closeFabMenu();
      return;
    }

    const helpTooltip = document.querySelector('.help-tooltip');
    if (helpTooltip) {
      helpTooltip.remove();
      elements.input.focus();
      return;
    }

    const indicator = document.querySelector('.search-indicator');
    if (indicator) {
      // Reload all entries
      await loadEntries();
      state.todoFilterActive = false;
      elements.todoCounter.classList.remove('filtered');
      elements.input.focus();
    }
  }

  function handleModalOutsideClick(e: MouseEvent) {
    if (e.target === e.currentTarget) {
      const target = e.currentTarget as HTMLElement;
      if (target.id === 'stats-modal') {
        closeStatsModal();
      } else if (target.id === 'export-modal') {
        closeExportModal();
      }
    }
  }

  async function searchTag(tag: string) {
    const entries = await db.entries
      .filter(entry => entry.content.includes(tag))
      .reverse()
      .sortBy('created_at');

    renderEntries(entries);
    addSearchIndicator(`Searching for: ${tag}`);
    elements.input.focus();
  }

  function showThemeOptions() {
    const themesDiv = document.createElement('div');
    themesDiv.className = 'entry';
    themesDiv.innerHTML = `
      <div class="entry-content">
        <strong>▪ Available themes:</strong><br>
        /theme minimal - Clean and minimal (default)<br>
        /theme matrix - Green phosphor terminal<br>
        /theme paper - Warm paper-like colors<br>
        /theme midnight - Deep blues and purples<br>
        /theme mono - Pure black and white
      </div>
      <div class="entry-meta">◷ just now</div>
    `;
    elements.entries.insertBefore(themesDiv, elements.entries.firstChild);
  }

  function showThemeInfo() {
    const infoDiv = document.createElement('div');
    infoDiv.className = 'entry';
    infoDiv.innerHTML = `
      <div class="entry-content">
        <strong>▪ Current theme: ${state.currentTheme}</strong><br><br>
        Available themes:<br>
        /theme minimal - Clean and minimal (default)<br>
        /theme matrix - Green phosphor terminal<br>
        /theme paper - Warm paper-like colors<br>
        /theme midnight - Deep blues and purples<br>
        /theme mono - Pure black and white
      </div>
      <div class="entry-meta">◷ just now</div>
    `;
    elements.entries.insertBefore(infoDiv, elements.entries.firstChild);
  }

  async function fetchAndShowTodos() {
    try {
      const entries = await db.entries
        .filter(entry => entry.content.includes('#todo'))
        .reverse()
        .sortBy('created_at');

      renderEntries(entries);
      addSearchIndicator('Showing: todos');

      state.todoFilterActive = true;
      elements.todoCounter.classList.add('filtered');

      setTimeout(updateTodoCounter, 100);
    } catch (error) {
      console.error('Failed to fetch todos:', error);
    }
  }

  function filterTodos(entries: NodeListOf<HTMLElement>) {
    let hasTodos = false;
    entries.forEach(entry => {
      const content = entry.querySelector('.entry-content')?.textContent || '';
      const isTodoItem = content.includes('#todo') || content.includes('#done');

      if (isTodoItem) {
        hasTodos = true;
        entry.style.display = 'block';
      } else {
        entry.style.display = 'none';
      }
    });

    if (!hasTodos) {
      fetchAndShowTodos();
    } else {
      elements.todoCounter.classList.add('filtered');
    }
  }

  function showAllEntries(entries: NodeListOf<HTMLElement>) {
    const hasSearchIndicator = elements.entries.querySelector('.search-indicator');

    if (hasSearchIndicator) {
      loadEntries().catch(error => console.error('Failed to reload entries:', error));
    } else {
      entries.forEach(entry => {
        entry.style.display = 'block';
      });
    }

    elements.todoCounter.classList.remove('filtered');
  }

  // ============ FAB Command Menu ============

  function toggleFabMenu() {
    const fabMenu = document.getElementById('fab-menu');
    if (!fabMenu) return;

    if (fabMenu.classList.contains('show')) {
      closeFabMenu();
    } else {
      fabMenu.classList.add('show');
    }
  }

  function closeFabMenu() {
    const fabMenu = document.getElementById('fab-menu');
    if (fabMenu) {
      fabMenu.classList.remove('show');
    }
  }

  async function executeFabCommand(command: string) {
    closeFabMenu();

    // For search, focus input and pre-fill command
    if (command === '/search') {
      elements.input.value = '/search ';
      elements.input.focus();
      return;
    }

    // Execute command by calling handleSubmit with the command
    const originalValue = elements.input.value;
    elements.input.value = command;
    await handleSubmit();
    // Don't restore if command was template (essay/idea)
    if (command !== '/essay' && command !== '/idea') {
      elements.input.value = originalValue;
    }
  }

  // ============ Public API ============

  return {
    init,
    toggleTodo,
    toggleTodoFilter,
    searchTag,
    editEntry,
    deleteEntry,
    showStatsModal,
    closeStatsModal,
    showExportModal,
    closeExportModal,
    updateExport,
    setExportFormat,
    copyExportContent,
    closeAuthModal,
    handleSignIn,
    handleSignUp,
    handleForgotPassword,
    toggleFabMenu,
    closeFabMenu,
    executeFabCommand
  };
})();

// Global functions for onclick handlers
(window as any).toggleTodo = LeanApp.toggleTodo;
(window as any).searchTag = LeanApp.searchTag;
(window as any).editEntry = LeanApp.editEntry;
(window as any).deleteEntry = LeanApp.deleteEntry;
(window as any).toggleTodoFilter = LeanApp.toggleTodoFilter;
(window as any).closeStatsModal = LeanApp.closeStatsModal;
(window as any).closeExportModal = LeanApp.closeExportModal;
(window as any).updateExport = LeanApp.updateExport;
(window as any).setExportFormat = LeanApp.setExportFormat;
(window as any).copyExportContent = LeanApp.copyExportContent;
(window as any).closeAuthModal = LeanApp.closeAuthModal;
(window as any).handleSignIn = LeanApp.handleSignIn;
(window as any).handleSignUp = LeanApp.handleSignUp;
(window as any).handleForgotPassword = LeanApp.handleForgotPassword;
(window as any).toggleFabMenu = LeanApp.toggleFabMenu;
(window as any).closeFabMenu = LeanApp.closeFabMenu;
(window as any).executeFabCommand = LeanApp.executeFabCommand;

// Initialize app when DOM is ready
window.addEventListener('load', () => LeanApp.init());
