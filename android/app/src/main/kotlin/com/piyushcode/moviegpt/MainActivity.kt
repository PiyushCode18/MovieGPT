package com.piyushcode.moviegpt

import io.flutter.embedding.android.FlutterActivity

/// Main Flutter activity for MovieGPT.
///
/// The package here MUST match the `namespace` (and `applicationId`) declared
/// in `android/app/build.gradle.kts` (com.piyushcode.moviegpt). The
/// AndroidManifest declares the launcher activity as `.MainActivity`, which is
/// resolved relative to this namespace. If the package name here differs from
/// the namespace, Android throws an ActivityNotFoundException and the app
/// crashes immediately on launch.
class MainActivity : FlutterActivity()
