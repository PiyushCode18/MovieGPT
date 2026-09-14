# Authentication and Account State Fix Plan

This plan addresses two critical bugs in MovieGPT's authentication flow:
1. **Email Sign-In Bug**: Users cannot reliably sign in with existing credentials after logging out, often getting stuck in a registration loop or seeing generic errors.
2. **Guest Mode Bug**: Authenticated users (Google/Email) are sometimes treated as guests, and the "Skip for now" choice is not persisted.

## User Review Required

> [!IMPORTANT]
> - **Email Confirmation**: If Supabase has email confirmation enabled, users will now be correctly prompted to confirm their email instead of being redirected to an empty "Guest" state.
> - **Guest Mode Persistence**: The "Skip for now" choice will now be remembered across app restarts until the user chooses to sign in.

## Proposed Changes

### State Management
#### [NEW] [guest_provider.dart](file:///C:/FLUTTER/FLUTTER PROJECTS/MovieGPT/lib/state/guest_provider.dart)
- Create a `guestModeProvider` using `StateNotifier` and `SharedPreferences` to persist the explicit guest choice.

### Authentication Service
#### [MODIFY] [auth_service.dart](file:///C:/FLUTTER/FLUTTER PROJECTS/MovieGPT/lib/services/auth_service.dart)
- Enhance `registerWithEmail` to explicitly return the `session` status.
- Improve `signInWithEmail` logging and error mapping.
- Add debug logs for session and user existence.
- Map `AuthException` codes to user-friendly messages for rate limits, network issues, and confirmation status.

### UI & Navigation
#### [MODIFY] [login_screen.dart](file:///C:/FLUTTER/FLUTTER PROJECTS/MovieGPT/lib/screens/login_screen.dart)
- Update `_continueGuest` to set `guestModeProvider = true`.
- Update `_signInWithGoogle` and `EmailAuthSheet` to set `guestModeProvider = false` upon successful session establishment.
- Prevent `EmailAuthSheet` from navigating to home if `session` is null (confirmation required). Show a clear instruction instead.

#### [MODIFY] [splash_screen.dart](file:///C:/FLUTTER/FLUTTER PROJECTS/MovieGPT/lib/screens/splash_screen.dart)
- Update `_navigateSafely` to check both `authStateProvider` and `guestModeProvider`.
- If either a valid session OR explicit guest mode exists, proceed to `MainNavigationScreen`.

#### [MODIFY] [profile_screen.dart](file:///C:/FLUTTER/FLUTTER PROJECTS/MovieGPT/lib/screens/profile_screen.dart)
- Update the `Logout` button to clear both the Supabase session and the `guestModeProvider` flag, returning the user to the `LoginScreen`.

## Verification Plan

### Automated Verification
- Run `flutter analyze` to ensure no regressions.

### Manual Verification
1. **Email Flow**:
   - Create Account -> Check for "Confirm Email" if enabled.
   - Login with existing account -> Verify authenticated state (isGuest=false).
   - Logout -> Verify return to Login screen.
   - Login again -> Verify success.
2. **Google Flow**:
   - Login with Google -> Verify authenticated state.
   - Restart App -> Verify session restoration and NOT Guest Mode.
3. **Guest Flow**:
   - Tap "Skip for now" -> Verify Guest Mode features.
   - Restart App -> Verify stay in Guest Mode (Home screen).
   - Sign In from Profile -> Verify transition from Guest to Authenticated.
