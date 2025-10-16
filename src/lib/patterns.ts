/**
 * Lean v2 - Pattern Intelligence Service
 * Manages entity patterns and temporal patterns
 */

import { supabase } from './supabase';
import type { EntityPattern, TemporalPattern } from './types';

/**
 * Get entity patterns (people tracking)
 */
export async function getEntityPatterns(limit: number = 10): Promise<EntityPattern[]> {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) throw new Error('Not authenticated');

  const { data, error } = await supabase
    .from('entity_patterns')
    .select('*')
    .eq('user_id', user.id)
    .order('confidence_score', { ascending: false })
    .order('mention_count', { ascending: false })
    .limit(limit);

  if (error) throw error;

  return (data || []).map(pattern => ({
    ...pattern,
    first_seen: new Date(pattern.first_seen),
    last_seen: new Date(pattern.last_seen),
  }));
}

/**
 * Get temporal patterns (writing rhythms)
 */
export async function getTemporalPatterns(): Promise<TemporalPattern[]> {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) throw new Error('Not authenticated');

  const { data, error } = await supabase
    .from('temporal_patterns')
    .select('*')
    .eq('user_id', user.id)
    .order('confidence', { ascending: false });

  if (error) throw error;

  return (data || []).map(pattern => ({
    ...pattern,
    created_at: new Date(pattern.created_at),
    updated_at: new Date(pattern.updated_at),
  }));
}

/**
 * Format entity pattern for display
 */
export function formatEntityPattern(pattern: EntityPattern): string {
  const { entity, entity_type, mention_count, theme_correlations, emotion_correlations } = pattern;

  let output = `<strong>${entity}</strong> (${entity_type}, ${mention_count} mentions)\n`;

  // Top themes
  const topThemes = Object.entries(theme_correlations)
    .sort(([, a], [, b]) => b - a)
    .slice(0, 3)
    .filter(([, count]) => count > 0);

  if (topThemes.length > 0) {
    output += `  Themes: ${topThemes.map(([theme]) => theme).join(', ')}\n`;
  }

  // Top emotions
  const topEmotions = Object.entries(emotion_correlations)
    .sort(([, a], [, b]) => b - a)
    .slice(0, 3)
    .filter(([, count]) => count > 0);

  if (topEmotions.length > 0) {
    output += `  Emotions: ${topEmotions.map(([emotion]) => emotion).join(', ')}\n`;
  }

  return output;
}

/**
 * Format temporal pattern for display
 */
export function formatTemporalPattern(pattern: TemporalPattern): string {
  const { time_block, weekday, common_themes, common_emotions, sample_count, confidence } = pattern;

  let timeDesc = time_block === 'all' ? '' : `${time_block}`;
  let dayDesc = weekday === 'all' ? '' : `${weekday}s`;

  let label = [timeDesc, dayDesc].filter(x => x).join(' ');
  if (!label) label = 'overall';

  let output = `<strong>${label.charAt(0).toUpperCase() + label.slice(1)}</strong> (${sample_count} entries, ${Math.round(confidence * 100)}% confidence)\n`;

  if (common_themes.length > 0) {
    output += `  Themes: ${common_themes.slice(0, 3).join(', ')}\n`;
  }

  if (common_emotions.length > 0) {
    output += `  Emotions: ${common_emotions.slice(0, 3).join(', ')}\n`;
  }

  return output;
}

/**
 * Get pattern insights summary
 */
export async function getPatternInsights(): Promise<{
  entities: EntityPattern[];
  temporal: TemporalPattern[];
  summary: string;
}> {
  const [entities, temporal] = await Promise.all([
    getEntityPatterns(5),
    getTemporalPatterns(),
  ]);

  let summary = '';

  if (entities.length === 0 && temporal.length === 0) {
    summary = 'No patterns learned yet. Keep writing and the AI will discover insights!';
  } else {
    if (entities.length > 0) {
      summary += `Tracking ${entities.length} people/entities. `;
    }
    if (temporal.length > 0) {
      summary += `Discovered ${temporal.length} writing rhythm patterns.`;
    }
  }

  return { entities, temporal, summary };
}
