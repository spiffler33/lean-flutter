/**
 * Lean v2 - Utility Functions
 * Helper functions used throughout the app
 */

import type { Entry } from './types';

/**
 * Format relative time (e.g., "2m ago", "3h ago")
 */
export function getRelativeTime(date: Date): string {
  const now = new Date();
  const delta = now.getTime() - date.getTime();
  const seconds = Math.floor(delta / 1000);
  const minutes = Math.floor(seconds / 60);
  const hours = Math.floor(minutes / 60);
  const days = Math.floor(hours / 24);

  if (seconds < 60) return '◷ just now';
  if (minutes === 1) return '◷ 1m ago';
  if (minutes < 60) return `◷ ${minutes}m ago`;
  if (hours === 1) return '◷ 1h ago';
  if (hours < 24) return `◷ ${hours}h ago`;
  if (days === 1) return '◷ yesterday';
  if (days < 30) return `◷ ${days} days ago`;

  return `◷ ${date.toLocaleDateString('en-US', {
    month: 'short',
    day: 'numeric',
  })}`;
}

/**
 * Extract #tags from content
 */
export function extractTags(content: string): string[] {
  const matches = content.match(/#(\w+)/g);
  if (!matches) return [];

  return matches.map((tag) => tag.slice(1)).filter((tag, i, arr) => arr.indexOf(tag) === i);
}

/**
 * Format content with clickable tags
 */
export function formatContentWithTags(content: string): string {
  return content.replace(
    /#(\w+)/g,
    '<a href="#" class="tag" data-tag="$1">#$1</a>'
  );
}

/**
 * Format content for display (with line breaks and tags)
 */
export function formatContent(content: string): string {
  const withTags = formatContentWithTags(content);
  return withTags.replace(/\n/g, '<br>');
}

/**
 * Check if entry is a todo
 */
export function isTodo(content: string): boolean {
  return content.toLowerCase().includes('#todo');
}

/**
 * Check if todo is done
 */
export function isTodoDone(content: string): boolean {
  return content.toLowerCase().includes('#done');
}

/**
 * Toggle todo status
 */
export function toggleTodo(content: string): string {
  if (isTodoDone(content)) {
    return content.replace(/#done/gi, '#todo');
  }
  return content.replace(/#todo/gi, '#done');
}

/**
 * Debounce function
 */
export function debounce<T extends (...args: any[]) => any>(
  func: T,
  wait: number
): (...args: Parameters<T>) => void {
  let timeout: ReturnType<typeof setTimeout> | null = null;

  return (...args: Parameters<T>) => {
    if (timeout) clearTimeout(timeout);
    timeout = setTimeout(() => func(...args), wait);
  };
}

/**
 * Generate markdown export
 */
export function generateMarkdownExport(
  entries: Entry[],
  includeTimestamps: boolean = true
): string {
  let markdown = '# Lean Export\n\n';
  markdown += `*Exported on ${new Date().toLocaleDateString()}*\n\n`;
  markdown += '---\n\n';

  for (const entry of entries) {
    if (includeTimestamps) {
      const dateStr = new Date(entry.created_at).toLocaleString('en-US', {
        year: 'numeric',
        month: 'short',
        day: 'numeric',
        hour: '2-digit',
        minute: '2-digit',
      });
      markdown += `## ${dateStr}\n\n`;
    }

    markdown += `${entry.content}\n\n`;

    if (entry.mood || entry.tags?.length) {
      markdown += '*';
      if (entry.mood) markdown += `Mood: ${entry.mood}`;
      if (entry.tags?.length) {
        if (entry.mood) markdown += ' · ';
        markdown += `Tags: ${entry.tags.join(', ')}`;
      }
      markdown += '*\n\n';
    }

    markdown += '---\n\n';
  }

  return markdown;
}

/**
 * Copy text to clipboard
 */
export async function copyToClipboard(text: string): Promise<boolean> {
  try {
    await navigator.clipboard.writeText(text);
    return true;
  } catch (err) {
    console.error('Failed to copy:', err);
    return false;
  }
}

/**
 * Save draft to localStorage
 */
export function saveDraft(content: string): void {
  if (content.trim()) {
    localStorage.setItem('lean-draft', content);
  } else {
    localStorage.removeItem('lean-draft');
  }
}

/**
 * Load draft from localStorage
 */
export function loadDraft(): string | null {
  return localStorage.getItem('lean-draft');
}

/**
 * Clear draft
 */
export function clearDraft(): void {
  localStorage.removeItem('lean-draft');
}

/**
 * Auto-resize textarea
 */
export function autoResizeTextarea(textarea: HTMLTextAreaElement): void {
  textarea.style.height = 'auto';
  textarea.style.height = `${textarea.scrollHeight}px`;
}

/**
 * Generate entry ID
 */
export function generateId(): string {
  return crypto.randomUUID();
}

/**
 * Sleep/delay utility
 */
export function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
