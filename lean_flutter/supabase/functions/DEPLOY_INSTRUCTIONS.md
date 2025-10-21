# Deploying the Enrich Entry Edge Function

## Prerequisites
1. Install Supabase CLI: `brew install supabase/tap/supabase`
2. Login to Supabase: `supabase login`
3. Link your project: `supabase link --project-ref elamvfzkztkquqdkovcs`

## Set up the Anthropic API Key

### Option 1: Via Supabase Dashboard (Recommended)
1. Go to your Supabase Dashboard
2. Navigate to Project Settings → Edge Functions
3. Click on "Secrets" tab
4. Add a new secret:
   - Name: `ANTHROPIC_API_KEY`
   - Value: Your actual Claude API key from https://console.anthropic.com/

### Option 2: Via CLI
```bash
supabase secrets set ANTHROPIC_API_KEY=your-actual-api-key-here
```

## Deploy the Edge Function

From the `lean_flutter` directory, run:

```bash
# Deploy the function
supabase functions deploy enrich-entry

# Or deploy with environment variables inline
supabase functions deploy enrich-entry --no-verify-jwt
```

## Test the Edge Function

### Test locally first:
```bash
# Start local Supabase
supabase start

# Serve the function locally
supabase functions serve enrich-entry --env-file .env.local

# In another terminal, test it:
curl -i --location --request POST \
  'http://localhost:54321/functions/v1/enrich-entry' \
  --header 'Authorization: Bearer YOUR_ANON_KEY' \
  --header 'Content-Type: application/json' \
  --data '{"entryText":"I had a great meeting with Sarah today about the new project","entryId":"1","userContext":""}'
```

### Test deployed function:
```bash
curl -i --location --request POST \
  'https://elamvfzkztkquqdkovcs.supabase.co/functions/v1/enrich-entry' \
  --header 'Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVsYW12ZnprenRrcXVxZGtvdmNzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA0NDMwODUsImV4cCI6MjA3NjAxOTA4NX0.DEc9k2msWuX5qL0uhdJvmNpu1tS97PGSPmrHk5n9B-Q' \
  --header 'Content-Type: application/json' \
  --data '{"entryText":"I had a great meeting with Sarah today about the new project","entryId":"1","userContext":""}'
```

## Monitor Logs

View function logs in real-time:
```bash
supabase functions logs enrich-entry --tail
```

## Troubleshooting

### Common Issues:

1. **"Anthropic API key not configured" error**
   - Make sure you've set the `ANTHROPIC_API_KEY` secret in Supabase
   - Verify it's set: `supabase secrets list`

2. **CORS errors in Flutter app**
   - The Edge Function includes CORS headers
   - Make sure you're using the correct URL format: `https://YOUR_PROJECT_REF.supabase.co/functions/v1/enrich-entry`

3. **Authentication errors**
   - Ensure you're passing the Supabase anon key in the Authorization header
   - Format: `Authorization: Bearer YOUR_ANON_KEY`

4. **Function not found**
   - Make sure the function is deployed: `supabase functions list`
   - Check the function name matches exactly: `enrich-entry`

## Security Notes

- The Anthropic API key is stored securely as a Supabase secret
- It's never exposed to the client application
- The Edge Function validates all requests using Supabase authentication
- Rate limiting is handled by Supabase automatically

## Cost Considerations

- Edge Functions have execution limits based on your Supabase plan
- Claude API calls are billed separately by Anthropic
- Consider implementing caching if you have repeated enrichment requests
- Monitor usage in both Supabase and Anthropic dashboards