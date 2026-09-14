# MovieGPT — Firebase Setup Guide

This guide walks you through connecting the **MovieGPT** Flutter app to Firebase so
that **Google Sign-In** and **Phone (OTP) Authentication** work on Android.

> **Already implemented in the project**
> - `lib/firebase_options.dart` (placeholder values — replace via `flutterfire configure`)
> - `lib/services/auth_service.dart` (Google + Phone auth logic)
> - `lib/screens/login_screen.dart`, `otp_screen.dart`, `splash_screen.dart`, `profile_screen.dart`
> - Gradle applies the Google Services plugin automatically **when** `android/app/google-services.json` exists

---

## 1. Prerequisites

- Flutter SDK (3.7+ recommended, this project uses Dart `^3.12.2`).
- Android Studio (or the Android SDK) so you can generate SHA fingerprints.
- A Google account.
- A physical Android device (required for **Phone Authentication** — SMS OTP does
  not work reliably on the Android emulator).

---

## 2. Create a Firebase Project

1. Go to the [Firebase Console](https://console.firebase.google.com/).
2. Click **Add project**.
3. Enter a project name, e.g. `moviegpt`.
4. (Optional) Enable Google Analytics — you can leave it off.
5. Click **Create Project** and wait for it to finish.

---

## 3. Add an Android App

1. In the Firebase project dashboard, click the **Android** icon (add platform).
2. **Package name** must match your app's `applicationId` exactly:
   ```
   com.example.movie_gpt_app_new
   ```
   > This is defined in `android/app/build.gradle.kts` → `applicationId`.
   > Do **not** change this unless you also update the Gradle file.
3. **App nickname** (optional): `MovieGPT`.
4. **Debug signing certificate** (SHA-1): leave blank for now — you'll add it in step 5.
5. Click **Register app**.
6. Firebase will offer to download **`google-services.json`**. Download it.

---

## 4. Place `google-services.json`

Copy the downloaded `google-services.json` into:

```
android/app/google-services.json
```

That is the **only** location the Gradle plugin looks for it. The project's
`android/app/build.gradle.kts` already detects this file and applies the Google
Services plugin automatically, so no manual Gradle edit is required.

---

## 5. Add SHA-1 and SHA-256 Fingerprints

Firebase uses the **SHA-1** fingerprint to authorize Google Sign-In and the
**SHA-256** fingerprint for some production APIs. Generate them from your signing key.

### Debug keystore (bundled with Flutter / Android Studio)

Open a terminal in the project root and run:

```bash
keytool -list -v -alias androiddebugkey -keystore "%USERPROFILE%\.android\debug.keystore" -storepass android -keypass android
```

> On macOS/Linux the keystore is at `~/.android/debug.keystore`.

Copy the **SHA1** and **SHA-256** lines.

### Add fingerprints to Firebase

1. Back in the Firebase Console → your Android app → **Settings**.
2. Under **Your apps** → click **Add fingerprint**.
3. Paste the **SHA-1** and click **Save**.
4. Add the **SHA-256** the same way.

> For a **release** build you must repeat this with your production `.jks` keystore.

---

## 6. Enable Google Sign-In

1. In the Firebase Console, go to **Authentication → Sign-in method**.
2. Find **Google** and click the pencil/edit icon.
3. Toggle **Enable**.
4. (Optional) set a **Support email** for the OAuth consent screen.
5. Click **Save**.

---

## 7. Enable Phone Authentication

1. In the same **Authentication → Sign-in method** page:
2. Find **Phone** and enable it.
3. Click **Save**.

> **Troubleshooting phone auth:**
> - Works best on a **physical device**.
> - Requires the **SHA-1** fingerprint to be registered (step 5).
> - The package name must match exactly.
> - If you see `operation-not-allowed`, the Phone provider is not enabled.

---

## 8. Generate `firebase_options.dart` (Recommended)

The provided `lib/firebase_options.dart` contains **placeholder** values. The
easiest way to generate real values is the FlutterFire CLI:

1. Install the CLI (once):
   ```bash
   dart pub global activate flutterfire_cli
   ```
2. Log in to Firebase from the terminal:
   ```bash
   firebase login
   ```
3. Run (from the project root):
   ```bash
   flutterfire configure --project=moviegpt
   ```
   - Select the Android platform (and iOS if you want).
   - This regenerates `lib/firebase_options.dart` with real keys **and** redownloads
     `google-services.json`.

> **No CLI?** You can also paste the values from the Firebase console
> (Project settings → Your apps → SDK setup) into `lib/firebase_options.dart`
> manually. The fields are: `apiKey`, `appId`, `messagingSenderId`, `projectId`,
> `storageBucket`.

---

## 9. Gradle Configuration (already set up)

The project already handles Gradle correctly:

- **Root** `android/settings.gradle.kts` declares the Google Services plugin:
  ```kotlin
  id("com.google.gms.google-services") version "4.4.2" apply false
  ```
- **App** `android/app/build.gradle.kts` applies it only when
  `google-services.json` is present:
  ```kotlin
  val googleServicesFile = File(rootProject.projectDir, "app/google-services.json")
  if (googleServicesFile.exists()) {
      apply(plugin = "com.google.gms.google-services")
  }
  ```
- `minSdk = 23` is used (required for Firebase Phone verification).

No additional Gradle changes are needed.

---

## 10. Required Dependencies

These are already in `pubspec.yaml`:

```yaml
firebase_core: ^3.12.0
firebase_auth: ^5.5.0
google_sign_in: ^6.2.2
```

Run `flutter pub get` to install them.

---

## 11. Build & Run

```bash
flutter pub get
flutter run
```

### Expected flow
1. **Splash screen** → checks Firebase auth state.
2. If **not signed in** → `LoginScreen` (Google + Phone).
3. If **signed in** → `MainNavigationScreen` (Home).
4. **Google**: tap "Continue with Google" → pick account → returns to Home.
5. **Phone**: enter number → OTP screen → verify → returns to Home.
6. **Logout** (Profile tab) → returns to Login.

---

## 12. Troubleshooting

| Symptom | Fix |
|---------|-----|
| `Firebase initialization failed` | Ensure `google-services.json` is in `android/app/` and `firebase_options.dart` has real values. |
| `com.google.gms.google-services` plugin not found | Run `flutter pub get` and rebuild. The plugin is declared in `settings.gradle.kts`. |
| Google button does nothing / 10 error | Register the correct **SHA-1** for the signing key you are using. |
| `operation-not-allowed` on phone | Enable **Phone** provider in Firebase Console. |
| SMS never arrives | Use a real device; re-check the package name and SHA-1; quota/cooldown may apply. |
| `invalid-verification-code` | The OTP expired or was mistyped — tap **Resend Code**. |
| Project builds but auth fails at runtime | Re-run `flutterfire configure` to refresh `firebase_options.dart`. |

---

## 13. Release Build Notes

- Add your **release** keystore SHA-1/SHA-256 fingerprints to Firebase.
- Sign the release build properly (the current `build.gradle.kts` uses debug keys
  for `flutter run --release` convenience — replace with your own signing config
  before publishing).
- Enable **Phone** auth on the same Firebase project for the release package.

---

## Summary — Files You Must Edit

| File | Action |
|------|--------|
| `android/app/google-services.json` | **Add** the downloaded file (from Firebase). |
| `lib/firebase_options.dart` | Replace placeholders via `flutterfire configure` (or manually). |
| Firebase Console | Register Android app, add SHA-1/SHA-256, enable Google + Phone sign-in. |

That's it — the code, Gradle config, and UI are already production-ready.
