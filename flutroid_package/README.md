# flutroid_package

The Flutroid OTA **updater** — the client half that ships inside your Flutter
app, plus the Android code that decides which Dart snapshot the engine loads.

Android only. See [Support](../README.md#support) for versions.

## Use

```yaml
dependencies:
  flutroid_package:
    path: ../flutroid_package
```

```dart
import 'package:flutroid_package/flutroid_package.dart';

Future<void> main() async {
  await Flutroid.initialize(updateUrl: 'http://10.0.2.2:8080');
  runApp(const MyApp());
}
```

The package name and release version are read from the platform, so the backend
URL is all you have to supply. `initialize` also checks for an update in the
background and confirms the running patch after the first frame; pass
`checkOnStart: false` or `confirmLaunch: false` to drive those yourself.

Then run `flutroid init` once to add the Android override — without it the
updater will happily download and stage patches that never load.

```dart
final staged = await Flutroid.instance.checkForUpdate();  // patch number, or null
await Flutroid.instance.rollback();                        // back to the APK's code
Flutroid.instance.state;                                   // what's running and staged
```

## How the Android side works

`FlutroidPatch.applyTo` prepends the staged snapshot's path to the engine's
`--aot-shared-library-name` list, which is searched first-match-wins — so a
staged patch wins, and a missing or corrupt one falls back to the code in the
APK. It runs from the app's Activity before any plugin is registered, which is
why it can't live in the plugin's own lifecycle.

State lives in `filesDir/flutroid`:

```
state.json          currentPatch, stagedPatch, confirmed, bootAttempts
current/libapp.so   what this process was told to load
staged/libapp.so    downloaded; promoted to current at the next launch
```

A patch that never reaches a rendered frame in two launches is deleted, so a
crashing update rolls itself back.

## Layout

- `lib/flutroid_package.dart` — public exports
- `lib/src/flutroid.dart` — `Flutroid.initialize(...)` entry point + instance
- `lib/src/update_client.dart` — HTTP client for the server API
- `lib/src/updater.dart` — download / verify / stage lifecycle
- `lib/src/flutroid_platform.dart` — method channel, inert off Android
- `android/src/main/kotlin/dev/flutroid/FlutroidPatch.kt` — snapshot selection, staging, rollback
- `android/src/main/kotlin/dev/flutroid/FlutroidPlugin.kt` — channel handler
