// Supabase Edge Function to proxy Claude API calls for entry enrichment
// This keeps the API key secure on the server side

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
    const { entryText, entryId, userContext } = await req.json()

    if (!entryText || !entryId) {
      throw new Error('Missing required parameters: entryText and entryId')
    }

    // Build the enrichment prompt
    const prompt = buildEnrichmentPrompt(entryText, userContext || '')

    // Call Claude API
    const anthropicResponse = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'x-api-key': ANTHROPIC_API_KEY,
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json',
      },
      body: JSON.stringify({
        model: 'claude-3-haiku-20240307', // Fast & affordable model (10x cheaper than Sonnet)
        max_tokens: 512, // Reduced since our JSON responses are ~150-200 tokens
        temperature: 0.3,
        messages: [
          {
            role: 'user',
            content: prompt,
          }
        ],
      }),
    })

    if (!anthropicResponse.ok) {
      const error = await anthropicResponse.text()
      console.error('Anthropic API error:', error)
      throw new Error(`Anthropic API error: ${anthropicResponse.status}`)
    }

    const anthropicData = await anthropicResponse.json()
    const content = anthropicData.content[0].text

    // Parse Claude's JSON response
    let enrichmentData
    try {
      enrichmentData = JSON.parse(content)
    } catch (parseError) {
      console.error('Failed to parse Claude response:', content)
      throw new Error('Invalid response format from Claude')
    }

    // Transform the data into the format expected by the Flutter app
    const enrichment = {
      entryId: parseInt(entryId),
      emotion: enrichmentData.sentiment || 'neutral',
      themes: enrichmentData.topics || [],
      technologies: enrichmentData.technologies || [],
      people: Array.isArray(enrichmentData.people) ?
        enrichmentData.people.map(name => ({ name, context: 'mentioned' })) :
        transformPeople(enrichmentData.people),
      urgency: enrichmentData.priority === 'high' ? 'high' :
               enrichmentData.priority === 'medium' ? 'medium' :
               enrichmentData.priority === 'low' ? 'low' : 'none',
      actions: enrichmentData.insights || [],
      questions: Array.isArray(enrichmentData.questions) ?
        enrichmentData.questions.map(q => ({ text: q, type: 'open-ended', answered: false })) :
        transformQuestions(enrichmentData.questions),
      decisions: [],
      confidenceScores: {
        emotion: 0.85,
        themes: 0.85,
        people: 0.85,
        urgency: 0.85,
      },
      summary: enrichmentData.summary || '',
      processingStatus: 'completed',
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    }

    // Process extracted events
    const events = enrichmentData.events || []
    const processedEvents = events.map((event: any) => ({
      type: event.type,
      subtype: event.subtype,
      metrics: event.metrics || {},
      confidence: event.confidence || 0.5,
    }))

    return new Response(
      JSON.stringify({
        success: true,
        enrichment,
        events: processedEvents
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      }
    )
  } catch (error) {
    console.error('Edge function error:', error)

    // Return a fallback mock enrichment on error
    const fallbackEnrichment = generateMockEnrichment(
      await req.json().then(d => d.entryText).catch(() => ''),
      await req.json().then(d => d.entryId).catch(() => '0')
    )

    return new Response(
      JSON.stringify({
        success: false,
        error: error.message,
        enrichment: fallbackEnrichment,
        events: fallbackEnrichment.events || []
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200, // Return 200 even on error so app can use fallback
      }
    )
  }
})

function buildEnrichmentPrompt(entryText: string, contextString: string): string {
  return `${contextString}

Analyze this journal entry and extract structured information including trackable events.

Entry: "${entryText}"

Previous context about user: ${contextString}

Extract:
1. Primary sentiment (one word: positive, negative, neutral, excited, anxious, frustrated, contemplative, etc.)
2. Main topics discussed (up to 3 general categories like work, personal, health, relationships)
3. Technologies mentioned (programming languages, frameworks, tools, platforms - e.g. Python, React, Kubernetes, Redis)
4. People mentioned (full names when possible)
5. Any questions the user is asking themselves
6. Priority/importance (high, medium, low)
7. Key insights or decisions made

8. TRACKABLE EVENTS:
   Extract ONLY concrete, completed activities (NOT intentions, plans, or references):
   - Exercise: running, swimming, cycling, gym, yoga (with distance/duration if mentioned)
   - Consumption: coffee, tea, alcohol, meals (with counts/amounts if mentioned)
   - Spend: purchases, groceries, bills (with amounts if mentioned)
   - Sleep: sleep duration/quality
   - Meetings: meetings, calls, appointments (with duration/people if mentioned)

   For each event provide:
   - type: "exercise" | "consumption" | "spend" | "sleep" | "meeting"
   - subtype: specific activity (e.g., "run", "swim", "coffee", "lunch")
   - metrics: relevant measurements as object
   - confidence: 0.0-1.0 score based on:
     * 0.9-1.0: Explicit past tense with clear metrics ("ran 5km", "had 3 coffees")
     * 0.7-0.9: Past tense activity, no metrics ("went running", "had coffee")
     * 0.5-0.7: Ambiguous mention ("coffee break", "gym day")
     * 0.0-0.3: Future intent or reference ("will run", "planning to swim")

Return as JSON:
{
  "sentiment": "string",
  "topics": ["string"],
  "technologies": ["string"],
  "people": ["string"],
  "questions": ["string"],
  "priority": "high|medium|low",
  "insights": ["string"],
  "summary": "one sentence summary",
  "events": [
    {
      "type": "string",
      "subtype": "string",
      "metrics": {
        "distance_km": number,
        "duration_min": number,
        "amount": number,
        "count": number,
        "hours_slept": number,
        "attendees": ["string"]
      },
      "confidence": number
    }
  ]
}`
}

function transformPeople(peopleData: any): any[] {
  if (!peopleData || typeof peopleData !== 'object') return []
  return Object.entries(peopleData).map(([name, context]) => ({
    name,
    context,
  }))
}

function transformQuestions(questionsData: any): any[] {
  if (!questionsData || typeof questionsData !== 'object') return []
  return Object.entries(questionsData).map(([text, type]) => ({
    text,
    type,
    answered: false,
  }))
}

function transformDecisions(decisionsData: any): any[] {
  if (!decisionsData || typeof decisionsData !== 'object') return []
  return Object.entries(decisionsData).map(([text, status]) => ({
    text,
    status,
    options: [],
  }))
}

function generateMockEnrichment(entryText: string, entryId: string): any {
  const text = entryText.toLowerCase()

  // Basic emotion detection
  let emotion = 'neutral'
  if (text.includes('excited') || text.includes('proud') || text.includes('finally hit') ||
      text.includes('goal') || text.includes('amazing')) {
    emotion = 'excited'
  } else if (text.includes('frustrated') || text.includes('failed') ||
             text.includes('furious') || text.includes('angry')) {
    emotion = 'frustrated'
  } else if (text.includes('anxious') || text.includes('worried') ||
             text.includes('stress') || text.includes('breathing down')) {
    emotion = 'anxious'
  } else if (text.includes('quiet') || text.includes('calm') ||
             text.includes('peaceful') || text.includes('no urgency')) {
    emotion = 'calm'
  } else if (text.includes('sad') || text.includes('worse') ||
             text.includes('wish')) {
    emotion = 'contemplative'
  }

  // Basic theme detection
  const themes = []
  if (text.includes('work') || text.includes('deadline') || text.includes('client') ||
      text.includes('deployment') || text.includes('meeting')) {
    themes.push('work')
  }
  if (text.includes('mom') || text.includes('dad') || text.includes('family')) {
    themes.push('relationships')
  }
  if (text.includes('weight') || text.includes('run') || text.includes('health') ||
      text.includes('pounds')) {
    themes.push('health')
  }
  if (text.includes('kubernetes') || text.includes('deployment') || text.includes('database') ||
      text.includes('script') || text.includes('ci/cd')) {
    themes.push('tech')
  }
  if (text.includes('budget') || text.includes('credit card') || text.includes('rent') ||
      text.includes('$')) {
    themes.push('finance')
  }
  if (themes.length === 0) {
    themes.push('personal')
  }

  // Basic urgency detection
  let urgency = 'none'
  if (text.includes('asap') || text.includes('immediately') || text.includes('urgent') ||
      text.includes('production is down')) {
    urgency = 'high'
  } else if (text.includes('deadline') || text.includes('by friday') ||
             text.includes('next month')) {
    urgency = 'medium'
  } else if (text.includes('maybe') || text.includes('no urgency')) {
    urgency = 'low'
  }

  // Basic people extraction - only obvious names
  const people = []
  const knownNames = ['Sarah', 'Mike', 'Mom', 'Dad', 'Alex', 'Kerem', 'CEO']
  for (const name of knownNames) {
    if (entryText.includes(name)) {
      people.push({ name, context: 'mentioned' })
    }
  }

  // Basic event extraction using simple regex patterns
  const events = []

  // Check for running/exercise
  const runMatch = text.match(/(?:ran|run|jogged|walked|swam|cycled)\s+(\d+(?:\.\d+)?)\s*(?:km|mi|miles?|kilometers?|laps?)/i)
  if (runMatch) {
    events.push({
      type: 'exercise',
      subtype: 'run',
      metrics: { distance_km: parseFloat(runMatch[1]) },
      confidence: 0.8
    })
  }

  // Check for coffee
  const coffeeMatch = text.match(/(?:had|drank|coffee)\s*#?(\d+)|(\d+)\s*(?:coffees?|cups?)/i)
  if (coffeeMatch) {
    const count = parseInt(coffeeMatch[1] || coffeeMatch[2])
    events.push({
      type: 'consumption',
      subtype: 'coffee',
      metrics: { count },
      confidence: 0.8
    })
  }

  // Check for spending
  const spendMatch = text.match(/(?:spent|paid|bought)\s+\$?(\d+(?:\.\d{2})?)/i)
  if (spendMatch) {
    events.push({
      type: 'spend',
      subtype: 'purchase',
      metrics: { amount: parseFloat(spendMatch[1]) },
      confidence: 0.8
    })
  }

  return {
    entryId: parseInt(entryId),
    emotion,
    themes: themes.slice(0, 3), // Limit to 3
    people,
    urgency,
    actions: [],
    questions: [],
    decisions: [],
    confidenceScores: {
      emotion: 0.5,
      themes: 0.5,
      people: 0.5,
      urgency: 0.5,
    },
    processingStatus: 'completed',
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
    events, // Include basic events in fallback
  }
}