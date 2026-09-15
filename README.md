# MovieGPT 🎬

**MovieGPT** is an AI-powered cinematic movie discovery application. It combines real-time movie data from TMDB with the intelligence of Google Gemini to provide a personalized discovery experience.

## 🚀 Features

- 🍿 **Browse & Search**: Explore popular, trending, top-rated, and upcoming movies.
- 🤖 **AI Concierge**: Chat with different AI personalities to get tailored movie recommendations.
- 🎞️ **Real Trailers**: Watch official trailers directly in the app with intelligent language fallback.
- 🔐 **Authentication**: Secure login and registration powered by **Supabase Auth**.
- ❤️ **Watchlist & Favorites**: Save movies you love for later.
- 📱 **Premium UI**: Dark, cinematic design with smooth animations and glassmorphism.

## 🛠️ Technologies Used

- **Flutter**: Cross-platform application framework.
- **Riverpod**: Robust state management.
- **Google Gemini**: Large Language Model for intelligent chat and recommendations.
- **TMDB API**: The primary source for movie metadata, posters, and trailers.
- **Supabase**: Backend for authentication and persistent data.
- **Dio**: Powerful HTTP client for API requests.
- **Shared Preferences**: Local disk caching for offline-first experience.

## ⚙️ Environment Variables

The application requires a `.env` file in the project root. Create one based on `.env.example`:

```env
TMDB_API_KEY=your_tmdb_api_key
GEMINI_API_KEY=your_gemini_api_key
SUPABASE_URL=your_supabase_project_url
SUPABASE_ANON_KEY=your_supabase_anon_key
AI_PROVIDER=gemini
GEMINI_MODEL=gemini-2.0-flash
```

> **IMPORTANT**: Ensure `.env` is added to your `assets` section in `pubspec.yaml` to be loaded at runtime.

## 🗄️ Database Setup (Supabase)

If you are setting up the project for the first time or need to restore the database, run the SQL script provided in **`supabase_schema.sql`** in your Supabase SQL Editor. This will create:

1. `profiles`: User profile data.
2. `watchlists`: Movies saved for later.
3. `favorites`: Movies marked as favorites.
4. `chat_history`: (Optional) Persistent AI chat logs.

## 🏃 Running Locally

1. **Install Dependencies**:
   ```bash
   flutter pub get
   ```

2. **Configure Environment**:
   Create your `.env` file as described above.

3. **Run the App**:
   ```bash
   flutter run
   ```

## 🧪 Testing

Run the test suite to verify the logic and AI integrations:
```bash
flutter test
```

## 🔐 Security

- **No Hardcoded Secrets**: All API keys are managed via environment variables.
- **Offline First**: Movie lists and session data are cached locally to ensure stability without network.
- **Defensive Parsing**: Models are designed to never crash on malformed API responses.

## 📜 License

This project is licensed under the MIT License.
