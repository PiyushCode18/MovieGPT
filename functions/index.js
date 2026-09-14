/**
 * MovieGPT — Secure AI Proxy (Firebase Cloud Function)
 *
 * This HTTPS function acts as a transparent proxy to the Gemini and OpenAI
 * (compatible) APIs.  It injects the AI API key from Firebase Functions
 * runtime config / environment variables so the key is **never** exposed in
 * the Flutter Web client source or Network tab.
 *
 * Request format (from the Flutter app):
 *   POST /aiProxy
 *   Content-Type: application/json
 *   Body: {
 *     "provider": "gemini" | "openai",
 *     "model":   "gemini-2.0-flash" | "gpt-4o-mini" | ...,
 *     "baseUrl": "https://api.openai.com/v1" (optional, OpenAI only),
 *     "body":   <the FULL request body that would normally go to the AI API>
 *   }
 *
 * Response: the raw JSON response from the AI API, forwarded with the
 * same HTTP status code and Content-Type.
 */

'use strict';

const functions = require('firebase-functions');
const admin = require('firebase-admin');

// admin is not strictly required for an unauthenticated proxy, but keeping it
// initialized so future enhancements (auth verification, rate-limiting) are easy.
try {
  admin.initializeApp();
} catch (e) {
  // Already initialized or config missing — safe to continue.
}

const logger = functions.logger;

/**
 * Resolve the AI API key from Firebase Functions runtime config first
 * (`firebase functions:config gemini.key "..."`) then fall back to an
 * environment variable.  Returns `null` when neither is set.
 */
function resolveApiKey(provider) {
  const config = functions.config();
  if (provider === 'openai') {
    return config.openai?.key || process.env.OPENAI_API_KEY || null;
  }
  // Default to Gemini.
  return config.gemini?.key || process.env.GEMINI_API_KEY || null;
}

exports.aiProxy = functions.https.onRequest(async (req, res) => {
  // ---- CORS (Flutter Web needs this) ----
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    return res.status(204).send('');
  }

  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed. Use POST.' });
  }

  // ---- Parse request ----
  let requestBody;
  try {
    requestBody = typeof req.body === 'string'
      ? JSON.parse(req.body)
      : req.body;
  } catch (e) {
    logger.error('[AI Proxy] Failed to parse request body', e);
    return res.status(400).json({ error: 'Invalid JSON body' });
  }

  const provider = requestBody?.provider;
  if (provider && provider !== 'gemini' && provider !== 'openai') {
    return res.status(400).json({ error: `Unknown provider: ${provider}` });
  }

  const useProvider = provider || 'gemini';
  const model = requestBody?.model || (
    useProvider === 'openai' ? 'gpt-4o-mini' : 'gemini-2.0-flash'
  );
  const aiBody = requestBody?.body;

  if (!aiBody) {
    return res.status(400).json({ error: 'Missing "body" field in request' });
  }

  // ---- Resolve API key (server-side, never sent to client) ----
  let apiKey;
  let targetUrl;
  let headers;

  if (useProvider === 'openai') {
    apiKey = resolveApiKey('openai');
    if (!apiKey) {
      logger.error('[AI Proxy] OPENAI_API_KEY is not configured on the server');
      return res.status(500).json({
        error: 'The AI backend is not configured. Ask the admin to set OPENAI_API_KEY.',
      });
    }
    const baseUrl = (requestBody?.baseUrl || 'https://api.openai.com/v1')
      .replace(/\/+$/, '');
    targetUrl = `${baseUrl}/chat/completions`;
    headers = {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${apiKey}`,
    };
  } else {
    // Gemini
    apiKey = resolveApiKey('gemini');
    if (!apiKey) {
      logger.error('[AI Proxy] GEMINI_API_KEY is not configured on the server');
      return res.status(500).json({
        error: 'The AI backend is not configured. Ask the admin to set GEMINI_API_KEY.',
      });
    }
    targetUrl = `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(model)}:generateContent`;
    headers = {
      'Content-Type': 'application/json',
      'x-goog-api-key': apiKey,
    };
  }

  logger.info(`[AI Proxy] -> POST ${targetUrl} (provider=${useProvider}, model=${model})`);

  // ---- Forward to the AI API ----
  let aiResponse;
  let responseText;

  try {
    aiResponse = await fetch(targetUrl, {
      method: 'POST',
      headers: headers,
      body: JSON.stringify(aiBody),
      // 90-second timeout for the AI API call.
      signal: AbortSignal.timeout(90000),
    });
    responseText = await aiResponse.text();
  } catch (error) {
    const timeoutError = error.name === 'TimeoutError';
    const reason = timeoutError
      ? 'AI API timed out (90s)'
      : `Fetch error: ${error.message || error.toString()}`;

    logger.error(`[AI Proxy] <— ERROR: ${reason}`);
    return res.status(502).json({ error: reason });
  }

  logger.info(`[AI Proxy] <- HTTP ${aiResponse.status}`);

  // ---- Forward the AI API response to the Flutter client ----
  res.status(aiResponse.status);

  const contentType = aiResponse.headers.get('content-type');
  if (contentType) {
    res.set('Content-Type', contentType);
  }

  // Try to return parsed JSON; fall back to raw text.
  try {
    res.json(JSON.parse(responseText));
  } catch (_) {
    res.send(responseText);
  }
});
