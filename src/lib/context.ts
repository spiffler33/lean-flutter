/**
 * Lean v2 - Context Service
 * Manages user facts (/context command)
 */

import { supabase } from './supabase';
import type { UserFact } from './types';

/**
 * Categorize a fact based on keywords
 */
export function categorizeFact(factText: string): 'work' | 'personal' | 'people' | 'location' | 'other' {
  const textLower = factText.toLowerCase();

  // Work keywords
  if (/work at|job|office|company|employed|career/.test(textLower)) {
    return 'work';
  }

  // Location keywords
  if (/live in|from|based in|located in|city|country/.test(textLower)) {
    return 'location';
  }

  // Personal keywords
  if (/married|kids|family|spouse|children|partner/.test(textLower)) {
    return 'personal';
  }

  // People keywords
  if (/manager|colleague|friend|boss|coworker|is my|is a/.test(textLower)) {
    return 'people';
  }

  return 'other';
}

/**
 * Get all active facts for the current user
 */
export async function getUserFacts(): Promise<UserFact[]> {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) throw new Error('Not authenticated');

  const { data, error } = await supabase
    .from('user_facts')
    .select('*')
    .eq('user_id', user.id)
    .eq('active', true)
    .order('created_at', { ascending: true });

  if (error) throw error;

  return (data || []).map(fact => ({
    ...fact,
    created_at: new Date(fact.created_at),
    updated_at: new Date(fact.updated_at),
  }));
}

/**
 * Add a new fact
 */
export async function addFact(factText: string): Promise<UserFact> {
  if (!factText || factText.length > 200) {
    throw new Error('Fact must be 1-200 characters');
  }

  const { data: { user } } = await supabase.auth.getUser();
  if (!user) throw new Error('Not authenticated');

  const category = categorizeFact(factText);

  const { data, error } = await supabase
    .from('user_facts')
    .insert({
      user_id: user.id,
      fact_text: factText,
      fact_category: category,
    })
    .select()
    .single();

  if (error) throw error;

  return {
    ...data,
    created_at: new Date(data.created_at),
    updated_at: new Date(data.updated_at),
  };
}

/**
 * Remove a fact (soft delete)
 */
export async function removeFact(factId: string): Promise<void> {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) throw new Error('Not authenticated');

  const { error } = await supabase
    .from('user_facts')
    .update({ active: false })
    .eq('fact_id', factId)
    .eq('user_id', user.id);

  if (error) throw error;
}

/**
 * Clear all facts (soft delete all)
 */
export async function clearAllFacts(): Promise<void> {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) throw new Error('Not authenticated');

  const { error } = await supabase
    .from('user_facts')
    .update({ active: false })
    .eq('user_id', user.id)
    .eq('active', true);

  if (error) throw error;
}

/**
 * Get formatted context string for AI enrichment
 */
export async function getContextString(): Promise<string> {
  try {
    const facts = await getUserFacts();

    if (facts.length === 0) {
      return '';
    }

    // Group by category
    const categorized: Record<string, string[]> = {
      work: [],
      personal: [],
      people: [],
      location: [],
      other: [],
    };

    facts.forEach(fact => {
      const category = fact.fact_category || 'other';
      categorized[category].push(fact.fact_text.substring(0, 200));
    });

    // Build context string
    const contextParts: string[] = [];
    for (const [category, items] of Object.entries(categorized)) {
      if (items.length > 0) {
        contextParts.push(...items);
      }
    }

    // Limit to 500 words total
    const context = contextParts.join(' | ');
    const words = context.split(' ');
    if (words.length > 500) {
      return words.slice(0, 500).join(' ') + '...';
    }

    return context;
  } catch (error) {
    console.error('Failed to get context string:', error);
    return '';
  }
}
