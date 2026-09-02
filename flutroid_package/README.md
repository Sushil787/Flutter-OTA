# flutroid_package

The Flutroid OTA **updater** — the client half that ships inside your Flutter app.
On launch it asks the [backend](../flutroid_server) whether a newer patch exists,
downloads it, verifies it, and stages it for the patched engine to load.

## Use (from your app)

Initialize once with your **package name** and **update URL**, early in `main()`:

```dart
import 'package:flutroid_package/flutroid_package.dart';

await Flutroid.initialize(
  packageName: 'com.example.mybird_test',
  updateUrl: 'http://localhost:8080',
);

await Flutroid.instance.checkForUpdate(
  platform: 'android',
  releaseVersion: '1.0.0+1',
);
```

## Layout

- `lib/flutroid_package.dart` — public exports
- `lib/src/flutroid.dart` — `Flutroid.initialize(...)` entry point + instance
- `lib/src/update_client.dart` — HTTP client for the server API
- `lib/src/updater.dart` — download / verify / stage lifecycle

> Note: this is a plain Dart package. The pieces that touch the app sandbox
> (writing to the engine's staging path, e.g. via `path_provider`) are left for
> you to wire in on the app side.
