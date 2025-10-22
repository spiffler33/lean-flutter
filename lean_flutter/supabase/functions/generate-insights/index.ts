// Supabase Edge Function to generate personalized insights using Claude
// Provides natural, conversational insights about patterns, streaks, and daily data

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { corsHeaders } from '../_shared/cors.ts'

serve(async (req: Request) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Get the API key from environment variables
    const ANTHROPIC_API_KEY = Deno.env.get('ANTHROPIC_API_KEY')

    if (!ANTHROPIC_API_KEY) {
      throw new Error('Anthropic API key not configured')
    }

    // Parse the request body
    const {
      userId,
      userContext,
      todayData,
      recentData,
      patterns,
      streaks
    } = await req.json()

    if (!userId) {
      throw new Error('Missing required parameter: userId')
    }

    // Build the insights prompt with user context
    const prompt = buildInsightsPrompt(
      userContext || '',
      todayData,
      recentData,
      patterns,
      streaks
    )

    console.log('[INSIGHTS-EDGE] ====================================')
    console.log('[INSIGHTS-EDGE] Generate insights request received')
    console.log('[INSIGHTS-EDGE] User ID:', userId)
    console.log('[INSIGHTS-EDGE] Data summary:')
    console.log('[INSIGHTS-EDGE]   Context length:', userContext?.length || 0, 'chars')
    console.log('[INSIGHTS-EDGE]   Today enrichments:', todayData?.enrichments?.length || 0)
    console.log('[INSIGHTS-EDGE]   Today events:', todayData?.events?.length || 0)
    console.log('[INSIGHTS-EDGE]   Recent enrichments:', recentData?.enrichments?.length || 0)
    console.log('[INSIGHTS-EDGE]   Recent events:', recentData?.events?.length || 0)
    console.log('[INSIGHTS-EDGE]   Active patterns:', patterns?.length || 0)
    console.log('[INSIGHTS-EDGE]   Active streaks:', streaks?.length || 0)
    console.log('[INSIGHTS-EDGE] ====================================]')

    // Call Claude API
    console.log('[INSIGHTS-EDGE] Calling Claude API...')
    console.log('[INSIGHTS-EDGE] Prompt length:', prompt.length, 'chars')

    const anthropicResponse = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'x-api-key': ANTHROPIC_API_KEY,
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json',
      },
      body: JSON.stringify({
        model: 'claude-3-haiku-20240307', // Fast & affordable for quick insights
        max_tokens: 800, // Enough for 3-5 insights with context
        temperature: 0.7, // Slightly more creative for natural language
        messages: [
          {
            role: 'user',
            content: prompt,
          }
        ],
      }),
    })

    console.log('[INSIGHTS-EDGE] Claude API response status:', anthropicResponse.status)

    if (!anthropicResponse.ok) {
      const error = await anthropicResponse.text()
      console.error('[INSIGHTS-EDGE] ❌ Anthropic API error:', error)
      throw new Error(`Anthropic API error: ${anthropicResponse.status}`)
    }

    const anthropicData = await anthropicResponse.json()
    const insights = anthropicData.content[0].text

    console.log('[INSIGHTS-EDGE] ✅ Insights generated successfully')
    console.log('[INSIGHTS-EDGE] Response length:', insights.length, 'chars')

    return new Response(
      JSON.stringify({
        success: true,
        insights
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      }
    )
  } catch (error) {
    console.error('[INSIGHTS-EDGE] ====================================')
    console.error('[INSIGHTS-EDGE] ❌ ERROR in Edge Function')
    console.error('[INSIGHTS-EDGE] Error:', error)
    console.error('[INSIGHTS-EDGE] Error message:', error.message)
    console.error('[INSIGHTS-EDGE] Returning fallback insights')
    console.error('[INSIGHTS-EDGE] ====================================')

    // Return a fallback response on error
    return new Response(
      JSON.stringify({
        success: false,
        error: error.message,
        insights: generateFallbackInsights()
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200, // Return 200 even on error so app can use fallback
      }
    )
  }
})

function buildInsightsPrompt(
  userContext: string,
  todayData: any,
  recentData: any,
  patterns: any[],
  streaks: any[]
): string {
  // Process today's data
  const todayEmotions = todayData?.enrichments?.map((e: any) => e.emotion).filter(Boolean) || []
  const todayThemes = todayData?.enrichments?.flatMap((e: any) => e.themes || []) || []
  const todayPeople = todayData?.enrichments?.flatMap((e: any) =>
    e.people?.map((p: any) => typeof p === 'string' ? p : p.name)
  ).filter(Boolean) || []
  const todayEvents = todayData?.events || []

  // Process recent data for trend analysis
  const recentEmotions = recentData?.enrichments?.map((e: any) => ({
    emotion: e.emotion,
    date: e.createdAt
  })).filter((e: any) => e.emotion) || []

  const recentEvents = recentData?.events || []

  // Log pattern data for debugging
  console.log('[INSIGHTS-EDGE] Pattern data received:')
  patterns?.forEach((p: any, i: number) => {
    console.log(`[INSIGHTS-EDGE] Pattern ${i+1}:`)
    console.log(`[INSIGHTS-EDGE]   Type: ${p.type}`)
    console.log(`[INSIGHTS-EDGE]   Signature: ${p.signature}`)
    console.log(`[INSIGHTS-EDGE]   Trigger: ${JSON.stringify(p.triggerConditions)}`)
    console.log(`[INSIGHTS-EDGE]   Outcome: ${JSON.stringify(p.outcomeConditions)}`)
    console.log(`[INSIGHTS-EDGE]   Confidence: ${p.confidence}`)
  })

  // Format patterns for readability - fix the data access
  const patternDescriptions = patterns?.map((p: any) => {
    const confidence = Math.round((p.confidence || 0) * 100)
    const occurrences = p.occurrences || 0

    if (p.type === 'temporal') {
      const trigger = p.triggerConditions || {}
      const outcome = p.outcomeConditions || {}

      if (trigger.time_period) {
        return {
          text: `${trigger.time_period}: ${outcome.dominant_emotion || 'emotional shift'}`,
          confidence,
          occurrences
        }
      }
    } else if (p.type === 'correlation') {
      const trigger = p.triggerConditions || {}
      const outcome = p.outcomeConditions || {}

      if (trigger.person) {
        return {
          text: `${trigger.person} appears in ${confidence}% of ${outcome.emotion || 'emotional'} entries`,
          confidence,
          occurrences
        }
      } else if (trigger.theme) {
        return {
          text: `${trigger.theme}: ${outcome.emotion || 'pattern detected'}`,
          confidence,
          occurrences
        }
      }
    }
    return null
  }).filter(Boolean) || []

  // Format streaks
  const streakDescriptions = streaks?.map((s: any) => {
    const type = s.type
    const count = s.currentCount
    const best = s.bestCount
    if (type === 'exercise') {
      return { type: 'exercise', count, best, active: s.isActive }
    } else if (type === 'mood' && s.name) {
      return { type: 'mood', emotion: s.name, count, best, active: s.isActive }
    } else if (type === 'productivity') {
      return { type: 'productivity', count, best, active: s.isActive }
    }
    return null
  }).filter(Boolean) || []

  return `You are Lean - a stoic observer that provides minimal, factual insights.

PERSONALITY:
- Stoic observer, not a life coach
- Minimal words, maximum clarity
- ASCII aesthetic only - no emojis, no exclamation marks
- Pattern reporter, not cheerleader
- 3-4 insights max, each 1-2 sentences

${userContext ? `User context:\n${userContext}\n` : ''}

Today's data:
- Emotions: ${todayEmotions.join(', ') || 'None recorded'}
- People: ${todayPeople.join(', ') || 'None'}
- Events: ${todayEvents.length} logged

Detected patterns:
${patternDescriptions.length > 0 ? patternDescriptions.map(p => `- ${p.text}`).join('\n') : '- No patterns detected'}

Current streaks:
${streakDescriptions.map(s => {
  if (s.type === 'exercise') {
    return `- Exercise: ${s.count} days. Previous best: ${s.best} days.`
  } else if (s.type === 'mood') {
    return `- ${s.emotion} mood: ${s.count} consecutive days.`
  } else if (s.type === 'productivity') {
    return `- Productivity: ${s.count} days.`
  }
  return null
}).filter(Boolean).join('\n') || '- No active streaks'}

INSTRUCTIONS:
Generate 3-4 factual observations. Each should be one sentence, citing real data.

Good examples:
- "Sarah appears in 38% of stressful entries."
- "2-day exercise streak. Previous best: 7 days."
- "Morning anxiety pattern detected. 5 of 7 days."
- "Meetings average 2 hours. Consider time-boxing."

Bad examples (avoid these):
- "Great job on your exercise streak!"
- "I noticed something interesting..."
- "You're doing wonderful!"
- Any use of emojis or exclamation marks

Rules:
1. Always cite specific numbers from the data
2. Never invent patterns not present in the data
3. Keep each insight to one factual statement
4. No emotional language or encouragement
5. If data shows "person -> negative emotion", report it exactly

Format: Simple markdown. No headers. Just observations.`
}

function generateFallbackInsights(): string {
  return `Unable to generate insights.

Run /analyze first to detect patterns.
Then run /insights again.

Alternative commands:
- /patterns: View detected patterns directly
- /streaks: Check active streaks
- /events: Review recent events`
}