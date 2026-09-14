# MovieGPT - Crash Fix Task List

## Root Cause
`lib/main.dart` → `_setupGlobalErrorHandling()`:
`FlutterError.presentError(details)` inside the overridden `FlutterError.onError`
causes infinite recursion → `StackOverflowError` → native Android crash
("MovieGPT closed because this app has a bug").

## Steps
- [x] 1. Fix `lib/main.dart` - remove recursive `presentError` call in `FlutterError.onError`
- [x] 2. Add `.env.example` (documentation only, no secrets)
- [x] 3. Run `flutter clean`
- [x] 4. Run `flutter pub get`
- [x] 5. Run `flutter analyze` (0 issues)
- [x] 6. Run `flutter test` (27/27 passed)
- [x] 7. Run `flutter build apk --debug` (app-debug.apk produced)
- [x] 8. Final report
