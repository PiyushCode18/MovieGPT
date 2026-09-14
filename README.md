# MovieGPT

**AI-Powered Cinematic Movie Discovery** — a premium, Netflix-style Flutter app
with Firebase Authentication, TMDB-powered movie discovery, and an in-app
YouTube trailer player.

---

## ✨ Features

- 🔐 **Firebase Authentication**
  - Google Sign-In
  - Phone Number Login with OTP
  - Persistent login across app restarts
  - Secure logout (Firebase + Google + local session)
- 🎬 **TMDB Movie Discovery**
  - Trending, Popular, Top Rated, Upcoming, Now Playing
  - Genre browsing, search, and AI-powered recommendations
  - Detailed movie screen with cast, trailers, and similar titles
- ▶️ **In-App Trailer Player**
  - `youtube_player_iframe` (never opens YouTube app/browser)
  - Trailer → teaser fallback
  - Landscape full-screen with immersive system UI
  - Trailer-only mode (no recommendations/comments)
- 🎨 **Premium Dark UI**
  - Material 3, Netflix-inspired design
  - Smooth animations, rounded buttons, glassmorphism
- 📱 **Optimized for Android**

---

## 🚀 Quick Start

### 1. Firebase Setup

Firebase is required for Google and Phone sign-in. Follow the comprehensive
guide in **[`FIREBASE_SETUP.md`](FIREBASE_SETUP.md)** which covers:

- Creating a Firebase project
- Registering the Android app (`com.piyushcode.moviegpt`)
- Adding `android/app/google-services.json`
- Registering SHA-1 / SHA-256 fingerprints
- Enabling Google Sign-In and Phone Authentication
- Generating `lib/firebase_options.dart` via `flutterfire configure`

### 2. TMDB API Key

For **local development**, add your TMDB Read Access Token to a `.env` file in
the project root (the `.env` file is gitignored):

```
TMDB_API_KEY=your_tmdb_read_access_token_here
```

For **release builds**, pass the key at build time via `--dart-define` (this
keeps the key out of plain `.env` and allows CI/CD injection):

```bash
flutter run --dart-define=TMDB_API_KEY=your_tmdb_read_access_token_here
flutter build apk --release --dart-define=TMDB_API_KEY=your_tmdb_read_access_token_here
```

### 3. Install & Run

```bash
flutter pub get
flutter run
```

### 4. Build a Release APK

```bash
flutter build apk --release --dart-define=TMDB_API_KEY=your_tmdb_read_access_token_here
```

The release build is signed with the upload keystore configured in
`android/key.properties` (gitignored) and uses the application ID
`com.piyushcode.moviegpt`.

---

## 🔄 App Flow

```
Splash Screen
   │
   ▼
Check Login Status (Firebase auth state)
   │
   ├── Logged In  ─────────────► Home Screen
   │
   └── Not Logged In ─────────► Login Screen
                                 ├── Continue with Google
                                 └── Continue with Mobile Number (OTP)
```

---

## 📁 Project Structure

```
lib/
├── main.dart                 # App entry + Firebase init
├── firebase_options.dart     # Generated Firebase config
├── config/
│   └── env_config.dart       # Environment/API key resolution
├── data/
│   └── movie_repository.dart # Repository pattern (caching)
├── models/
│   ├── app_user.dart         # Auth user model
│   └── movie_model.dart      # Movie, Cast, Trailer, Genre models
├── screens/
│   ├── splash_screen.dart    # Auth-state routing
│   ├── login_screen.dart     # Google + Phone login
│   ├── otp_screen.dart       # OTP verification
│   ├── home_screen.dart      # Home feed + Watch Trailer button
│   ├── movie_details_screen.dart
│   ├── trailer_screen.dart   # In-app trailer player
│   ├── main_navigation_screen.dart
│   ├── search_screen.dart
│   ├── watchlist_screen.dart
│   ├── ai_chat_screen.dart
│   ├── collection_screen.dart
│   └── profile_screen.dart   # Logout
├── services/
│   ├── auth_service.dart     # Firebase Auth logic
│   ├── api_client.dart       # Dio setup
│   └── tmdb_api_service.dart # TMDB endpoints
├── state/
│   ├── auth_providers.dart   # Auth state (Riverpod)
│   └── providers.dart        # Movie providers (Riverpod)
├── theme/
│   └── app_theme.dart        # Design system
└── widgets/                  # Reusable UI widgets
```

---

## 🛠️ Dependencies

| Package | Purpose |
|---------|---------|
| `firebase_core` | Firebase initialization |
| `firebase_auth` | Google + Phone authentication |
| `google_sign_in` | Google account sign-in |
| `youtube_player_iframe` | In-app trailer playback |
| `dio` | HTTP client for TMDB |
| `flutter_riverpod` | State management |
| `cached_network_image` | Image caching |
| `shared_preferences` | Local persistence (watchlist, session) |
| `flutter_dotenv` | `.env` loading |
| `google_fonts` | Typography |

---

## 🎨 Launcher Icon

The app uses a **premium circular adaptive icon** (dark purple-black clapperboard
with a white play button and neon ring). All density mipmaps are served from:

- `android/app/src/main/res/mipmap-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}/`
- Adaptive icon layers: `mipmap-anydpi-v26/`, `drawable/ic_launcher_foreground.xml`

To regenerate the icon from the master source, run:
```bash
powershell -ExecutionPolicy Bypass -File generate_launcher_icons.ps1
```

---

## 🧪 Testing & Analysis

```bash
flutter analyze       # 0 compile errors
flutter test          # run widget tests
```

---

## 📄 Documentation

- **[`FIREBASE_SETUP.md`](FIREBASE_SETUP.md)** — Full Firebase configuration guide.
- **[`TODO.md`](TODO.md)** — Project rebuild checklist & status.
