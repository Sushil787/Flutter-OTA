/// Flutroid OTA updater — the client half that runs inside the app.
///
/// Initialize once early in `main()`:
///
/// ```dart
/// await Flutroid.initialize(
///   packageName: 'com.example.mybird_test',
///   updateUrl: 'https://flutroid-ota.<account>.workers.dev',
/// );
/// ```
///
/// Then it can check the backend for a newer patch for this package, download
/// it, verify it, and stage it for the (patched) engine to load on next boot.
library;

export 'src/flutroid.dart';
export 'src/updater.dart';
export 'src/update_client.dart';
