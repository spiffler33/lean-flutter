/**
 * Lean v2 - AI Enrichment Service
 * Claude API integration for entry enrichment
 */

import Anthropic from '@anthropic-ai/sdk';

const ANTHROPIC_API_KEY = import.meta.env.VITE_ANTHROPIC_API_KEY;

let anthropic: Anthropic | null = null;

if (ANTHROPIC_API_KEY) {
  anthropic = new Anthropic({
    apiKey: ANTHROPIC_API_KEY,
    dangerouslyAllowBrowser: true, // For client-side usage
  });
}

export interface EnrichmentResult {
  emotion: string;
  themes: string[];
  people: string[];
  actions: string[];
  urgency: 'none' | 'low' | 'medium' | 'high';
}

const EMOTION_VOCABULARY = [
  'frustrated', 'anxious', 'excited', 'content', 'melancholic',
  'hopeful', 'angry', 'contemplative', 'tired', 'energetic',
  'confused', 'grateful', 'overwhelmed', 'calm', 'nostalgic',
  'curious', 'determined', 'focused', 'scattered', 'neutral'
];

const THEME_TAXONOMY = [
  'work', 'personal', 'health', 'finance', 'relationships',
  'learning', 'daily', 'creative', 'tech', 'leisure'
];

/**
 * Fallback emotion detection using keyword matching
 */
function detectEmotionFallback(text: string): string {
  const textLower = text.toLowerCase();

  const emotionMap: Record<string, string[]> = {
    frustrated: ['frustrated', 'frustrating', 'annoyed', 'annoying'],
    anxious: ['anxious', 'worried', 'nervous', 'stress', 'stressed'],
    excited: ['excited', 'exciting', 'thrilled', 'pumped'],
    content: ['content', 'satisfied', 'happy', 'good'],
    melancholic: ['melancholic', 'sad', 'down', 'blue'],
    hopeful: ['hopeful', 'optimistic', 'positive'],
    angry: ['angry', 'mad', 'furious', 'pissed', 'hate', 'horrible'],
    contemplative: ['contemplative', 'thinking', 'wondering', 'pondering'],
    tired: ['tired', 'exhausted', 'drained'],
    energetic: ['energetic', 'energized', 'motivated'],
    confused: ['confused', 'puzzled', 'unclear', 'lost'],
    grateful: ['grateful', 'thankful', 'blessed', 'appreciative'],
    overwhelmed: ['overwhelmed', 'swamped', 'drowning'],
    calm: ['calm', 'peaceful', 'relaxed', 'serene'],
    nostalgic: ['nostalgic', 'remember', 'miss'],
    curious: ['curious', 'interested', 'intrigued'],
    determined: ['determined', 'focused', 'driven', 'committed'],
    scattered: ['scattered', 'unfocused', 'distracted'],
  };

  for (const [emotion, keywords] of Object.entries(emotionMap)) {
    for (const keyword of keywords) {
      if (textLower.includes(keyword)) {
        return emotion;
      }
    }
  }

  return 'neutral';
}

/**
 * Fallback theme detection using keyword matching
 */
function extractThemesFallback(text: string): string[] {
  const textLower = text.toLowerCase();
  const themes: string[] = [];

  const themeKeywords: Record<string, string[]> = {
    work: ['meeting', 'project', 'deadline', 'boss', 'colleague', 'office', 'work', 'client'],
    health: ['exercise', 'sick', 'doctor', 'workout', 'gym', 'tired', 'pain'],
    relationships: ['friend', 'family', 'wife', 'husband', 'partner', 'mom', 'dad'],
    tech: ['coding', 'bug', 'server', 'deploy', 'git', 'database', 'api'],
    finance: ['money', 'budget', 'expense', 'bill', 'payment', 'salary'],
    learning: ['study', 'learn', 'course', 'tutorial', 'book', 'reading'],
    creative: ['write', 'design', 'art', 'music', 'paint', 'create'],
    leisure: ['movie', 'game', 'relax', 'fun', 'vacation', 'hobby'],
  };

  for (const [theme, keywords] of Object.entries(themeKeywords)) {
    for (const keyword of keywords) {
      if (textLower.includes(keyword)) {
        if (!themes.includes(theme)) {
          themes.push(theme);
        }
        break;
      }
    }
    if (themes.length >= 3) break;
  }

  return themes.slice(0, 3);
}

/**
 * Fallback people extraction using capitalization
 */
function extractPeopleFallback(text: string): string[] {
  const words = text.split(/\s+/);
  const people: string[] = [];

  const excludeWords = new Set([
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
    'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August',
    'September', 'October', 'November', 'December', 'I', 'The', 'A', 'An'
  ]);

  for (let i = 0; i < words.length; i++) {
    const word = words[i].replace(/[.,!?;:]$/, '');

    if (word.length > 1 &&
        word[0] === word[0].toUpperCase() &&
        !excludeWords.has(word) &&
        (i === 0 || words[i - 1].slice(-1) !== '.')) {
      if (!people.includes(word)) {
        people.push(word);
      }
    }
  }

  return people.slice(0, 5);
}

/**
 * Fallback urgency detection
 */
function extractUrgencyFallback(text: string): 'none' | 'low' | 'medium' | 'high' {
  const textLower = text.toLowerCase();

  const highKeywords = ['asap', 'urgent', 'immediately', 'now', 'critical', 'emergency'];
  const mediumKeywords = ['today', 'tomorrow', 'soon', 'deadline', 'this week'];
  const lowKeywords = ['someday', 'eventually', 'maybe', 'later', 'sometime'];

  for (const keyword of highKeywords) {
    if (textLower.includes(keyword)) return 'high';
  }
  for (const keyword of mediumKeywords) {
    if (textLower.includes(keyword)) return 'medium';
  }
  for (const keyword of lowKeywords) {
    if (textLower.includes(keyword)) return 'low';
  }

  return 'none';
}

/**
 * Extract action items from text
 */
function extractActions(text: string): string[] {
  const actions: string[] = [];
  const textLower = text.toLowerCase();

  // Pattern 1: "need to"
  if (textLower.includes('need to') || textLower.includes('needs to')) {
    const match = text.match(/(?:need|needs)\s+to\s+(.+?)(?:\.|$)/i);
    if (match) {
      const action = match[1].trim().replace(/#\w+/g, '').trim();
      if (action.length > 3) actions.push(action);
    }
  }

  // Pattern 2: "must"
  if (textLower.includes('must ')) {
    const match = text.match(/must\s+(.+?)(?:\.|$)/i);
    if (match) {
      const action = match[1].trim().replace(/#\w+/g, '').trim();
      if (action.length > 3 && !actions.includes(action)) actions.push(action);
    }
  }

  // Pattern 3: "have to"
  if (textLower.includes('have to') || textLower.includes('has to')) {
    const match = text.match(/(?:have|has)\s+to\s+(.+?)(?:\.|$)/i);
    if (match) {
      const action = match[1].trim().replace(/#\w+/g, '').trim();
      if (action.length > 3 && !actions.includes(action)) actions.push(action);
    }
  }

  // Pattern 4: "todo:"
  if (textLower.includes('todo:') || textLower.includes('todo ')) {
    const match = text.match(/todo:\s*(.+?)(?:\.|$)/i);
    if (match) {
      const actionText = match[1].trim().replace(/#\w+/g, '').trim();
      if (actionText.includes(' and ')) {
        actionText.split(' and ').forEach(part => {
          const clean = part.trim();
          if (clean.length > 3 && !actions.includes(clean)) actions.push(clean);
        });
      } else if (actionText.length > 3 && !actions.includes(actionText)) {
        actions.push(actionText);
      }
    }
  }

  // Pattern 5: "should"
  if (textLower.includes('should ')) {
    const match = text.match(/should\s+(.+?)(?:\.|$)/i);
    if (match) {
      const action = match[1].trim().replace(/#\w+/g, '').trim();
      if (action.length > 3 && !actions.includes(action)) actions.push(action);
    }
  }

  return actions.slice(0, 5);
}

/**
 * Enrich entry with AI analysis using Claude API
 */
export async function enrichEntry(
  content: string,
  userContext?: string
): Promise<EnrichmentResult> {
  // If no API key, use fallback
  if (!anthropic || !ANTHROPIC_API_KEY) {
    console.log('Claude API not configured, using fallback extraction');
    return {
      emotion: detectEmotionFallback(content),
      themes: extractThemesFallback(content),
      people: extractPeopleFallback(content),
      actions: extractActions(content),
      urgency: extractUrgencyFallback(content),
    };
  }

  try {
    const contextPrefix = userContext ? `User context: ${userContext}\n\n` : '';

    const prompt = `${contextPrefix}Analyze this journal entry and extract the following in JSON format:

1. emotion: ONE word from this list: ${EMOTION_VOCABULARY.join(', ')}
2. themes: 1-3 themes from this list: ${THEME_TAXONOMY.join(', ')}
3. people: Any people's names mentioned (proper nouns)
4. actions: Any task items or action items mentioned
5. urgency: one of: none, low, medium, high

IMPORTANT:
- Only extract what's EXPLICITLY in the text
- Don't infer from context unless clearly mentioned
- For emotion, choose the single best match
- For themes, only include if clearly present in the text
- For people, extract proper names (capitalized)
- For urgency, look for explicit time signals (asap, today, deadline, etc.)

Entry: "${content}"

Respond with ONLY valid JSON in this exact format:
{
  "emotion": "neutral",
  "themes": ["work"],
  "people": ["Sarah"],
  "actions": ["finish report"],
  "urgency": "medium"
}`;

    const message = await anthropic.messages.create({
      model: 'claude-3-5-haiku-20241022',
      max_tokens: 500,
      messages: [
        {
          role: 'user',
          content: prompt,
        },
      ],
    });

    const responseText = message.content[0].type === 'text'
      ? message.content[0].text
      : '';

    // Extract JSON from response
    const jsonMatch = responseText.match(/\{[\s\S]*\}/);
    if (jsonMatch) {
      const result = JSON.parse(jsonMatch[0]);

      // Validate and clean result
      return {
        emotion: EMOTION_VOCABULARY.includes(result.emotion)
          ? result.emotion
          : detectEmotionFallback(content),
        themes: Array.isArray(result.themes)
          ? result.themes.filter(t => THEME_TAXONOMY.includes(t)).slice(0, 3)
          : extractThemesFallback(content),
        people: Array.isArray(result.people)
          ? result.people.slice(0, 5)
          : extractPeopleFallback(content),
        actions: Array.isArray(result.actions)
          ? result.actions.slice(0, 5)
          : extractActions(content),
        urgency: ['none', 'low', 'medium', 'high'].includes(result.urgency)
          ? result.urgency
          : extractUrgencyFallback(content),
      };
    }

    throw new Error('No JSON found in response');
  } catch (error) {
    console.error('Claude API enrichment failed, using fallback:', error);

    // Fallback to pattern-based extraction
    return {
      emotion: detectEmotionFallback(content),
      themes: extractThemesFallback(content),
      people: extractPeopleFallback(content),
      actions: extractActions(content),
      urgency: extractUrgencyFallback(content),
    };
  }
}

/**
 * Check if AI enrichment is available
 */
export function isAIAvailable(): boolean {
  return !!(anthropic && ANTHROPIC_API_KEY);
}
