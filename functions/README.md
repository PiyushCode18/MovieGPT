# MovieGPT AI Proxy — Firebase Cloud Function

This is a **secure backend proxy** for the MovieGPT AI chat feature. It forwards
AI API requests from the Flutter app to Google Gemini or OpenAI-compatible
APIs, injecting the API key server-side so it is **never** exposed in the
Flutter Web client or Network tab.

## Why this exists

For **Flutter Web** (Chrome), the Gemini/OpenAI API key cannot be safely placed
in the app bundle — anyone can inspect the Network tab and steal it. This
function keeps the key on the server and gives the browser a same-origin
endpoint that handles CORS correctly.

## Setup

### 1. Prerequisites

- Node.js >= 18
- Firebase CLI: `npm install -g firebase-tools`
- You are logged in: `firebase login`

### 2. Set the AI API keys (server-side only)

```bash
# Option A — runtime config (stored on the Firebase backend, NOT in source)
firebase functions:config gemini.key "YOUR_GEMINI_API_KEY"
firebase functions:config openai.key "YOUR_OPENAI_API_KEY"

# Option B — environment variables (for local emulator / gcloud deploy)
export GEMINI_API_KEY="YOUR_GEMINI_API_KEY"
export OPENAI_API_KEY="YOUR_OPENAI_API_KEY"
```

> Never commit real API keys to this file. Use `firebase functions:config` or
> the Firebase Console → Functions → Environment variables for production.

### 3. Local development (emulator)

```bash
cd functions
npm install
firebase emulators:start --only functions
```

The emulator prints the local URL (typically `http://localhost:5001/<project>/us-central1/aiProxy`).

### 4. Deploy

```bash
firebase deploy --only functions
```

After deployment, the Firebase Console provides the HTTPS URL, e.g.:

```
https://us-central1-moviegpt-2003.cloudfunctions.net/aiProxy
```

### 5. Configure the Flutter app

In your `.env` file (or via `--dart-define`), set the backend URL:

```
AI_BACKEND_URL=https://us-central1-moviegpt-2003.cloudfunctions.net/aiProxy
```

Or at build time:

```bash
flutter run -d chrome --dart-define=AI_BACKEND_URL=https://us-central1-moviegpt-2003.cloudfunctions.net/aiProxy
```

### 6. Verify

Send a message in the AI chat. In debug mode you will see logs like:

```
[MovieGPT AI] -> POST /aiProxy (provider: gemini)
[MovieGPT AI] <- HTTP 200
```

---

## Request / Response Format

**Request from the Flutter app:**

```http
POST https://<function-url>
Content-Type: application/json

{
  "provider": "gemini" | "openai",
  "model":    "gemini-2.0-flash" | "gpt-4o-mini" | ...,
  "baseUrl":  "https://api.openai.com/v1"   // optional, OpenAI only
  "body":     { ...the FULL AI API request body... }
}
```

**Response:** the raw JSON response from the AI API, forwarded with the
same HTTP status code and Content-Type.
