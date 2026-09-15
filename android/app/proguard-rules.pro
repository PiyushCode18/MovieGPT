# Flutter / Android ProGuard rules for MovieGPT release builds.
#
# The Flutter engine ships its own consumer rules (referenced automatically).
# This file adds explicit keep rules for the reflection-based third-party
# libraries used by MovieGPT (Supabase, Google Sign-In, Dio) so the minified
# release build does NOT crash at runtime with NoSuchMethodError / missing
# classes. These keep rules are safe, additive, and standard across Android.

# --- Kotlin metadata (needed by several reflection-based libs) ---
-keep class kotlin.Metadata { *; }

# --- Google Sign-In ---
-keep class com.google.android.gms.auth.api.signin.** { *; }
-keep class com.google.android.gms.common.** { *; }
-dontwarn com.google.android.gms.**

# --- Dio / OkHttp (networking) ---
# OkHttp uses reflection for some response-body adapters; keep its model classes.
-keep class okhttp3.** { *; }
-keep class okio.** { *; }
-keep class com.squareup.** { *; }
-dontwarn okhttp3.**
-dontwarn okio.**

# --- Gson (used by some libraries) ---
-keep class com.google.gson.** { *; }
-dontwarn com.google.gson.**

# --- Keep the Flutter engine + app entry points (usually covered by Flutter's
#     own rules), included here defensively ---
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.app.** { *; }

# --- Keep the app's MainActivity and any classes referenced by name ---
-keep class com.piyushcode.moviegpt.MainActivity { *; }
