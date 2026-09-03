/// Flutroid OTA updater — the client half that runs inside the app.
///
/// Initialize once early in `main()`:
///
/// ```dart
/// void main() async {
///   await Flutroid.initialize(updateUrl: 'http://10.0.2.2:8080');
///   runApp(const MyApp());
/// }
/// ```
///
/// It asks the backend whether a newer patch exists for this app's release,
/// downloads it, verifies its sha256, and stages it. The engine picks the
/// staged snapshot up at the next launch, because the snapshot path is read
/// once before the Dart VM starts.
///
/// The Android side of that — an override in your `MainActivity` — is written
/// for you by `flutroid init`.
library;

export 'src/flutroid.dart';
export 'src/flutroid_platform.dart';
export 'src/flutroid_progress.dart';
export 'src/update_client.dart';
export 'src/updater.dart';
