# API Keys and Secrets Setup

This document explains how to configure API keys and secrets for the PT Resources app.

## Quick Setup

1. **Copy the template**: Copy `Secrets.xcconfig` to your local environment
2. **Add your API keys**: Replace the placeholder values with your actual API keys
3. **Verify .gitignore**: Ensure `Secrets.xcconfig` is in your `.gitignore` file (already done)

## Required API Keys

### ESV API Key (Required for Bible passages)
1. Visit https://api.esv.org/
2. Sign up for a free account
3. Generate an API key
4. Add it to `Secrets.xcconfig`:
   ```
   ESV_API_KEY = your_actual_esv_api_key_here
   ```

### Optional API Keys

The following are optional and have fallback behavior:

- `TRANSCRIPTION_API_KEY` - For server-side transcription
- `TRANSCRIPTION_API_URL` - Custom transcription service endpoint
- `PROCLAMATION_API_BASE_URL` - Custom API base URL (if different from default)

## Configuration Priority

The app checks for API keys in this order:

1. **Environment Variables** (highest priority)
2. **Secrets.xcconfig file** 
3. **Default/placeholder values** (lowest priority)

## Security Best Practices

✅ **DO:**
- Keep `Secrets.xcconfig` in `.gitignore`
- Use different API keys for development and production
- Rotate API keys periodically
- Use environment variables in CI/CD

❌ **DON'T:**
- Commit API keys to version control
- Share API keys in chat/email
- Use production keys in development

## Troubleshooting

### "Invalid ESV API Key" Error
- Check your API key in `Secrets.xcconfig`
- Verify the key is active on https://api.esv.org/
- Ensure no extra spaces or quotes around the key

### App Using Mock Data
- This happens when no valid API key is found
- Check that `Secrets.xcconfig` exists and has the correct format
- Verify the key format: `ESV_API_KEY = your_key_here`

### File Not Found
- Ensure `Secrets.xcconfig` is in the project root directory
- Check the file is named exactly `Secrets.xcconfig` (case-sensitive)

## Example Configuration File

Your `Secrets.xcconfig` should look like this:

```bash
// ESV API Key - Required for Bible passage lookup
ESV_API_KEY = abcd1234efgh5678ijkl9012mnop3456

// Optional: Custom transcription service
// TRANSCRIPTION_API_URL = https://your-transcription-service.com/v1
// TRANSCRIPTION_API_KEY = your_transcription_key_here

// Optional: Custom API base URL
// PROCLAMATION_API_BASE_URL = https://custom-api.example.com/resources
```