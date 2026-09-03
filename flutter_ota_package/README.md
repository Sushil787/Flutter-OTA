# flutter_ota_package

The Flutter OTA **updater** — the client half that ships inside your Flutter
app, plus the Android code that decides which Dart snapshot the engine loads.

Android only. See [Support](../README.md#support) for versions.

## Use

```yaml
dependencies:
  flutter_ota_package:
    path: ../flutter_ota_package
```

```dart
import 'package:flutter_ota_package/flutter_ota_package.dart';

Future<void> main() async {
  await FlutterOta.initialize(updateUrl: 'http://10.0.2.2:8080');
  runApp(const MyApp());
}
```

The package name and release version are read from the platform, so the backend
URL is all you have to supply. `initialize` also checks for an update in the
background and confirms the running patch after the first frame; pass
`checkOnStart: false` or `confirmLaunch: false` to drive those yourself.

Then run `flutter_ota init` once to add the Android override — without it the
updater will happily download and stage patches that never load.

```dart
final staged = await FlutterOta.instance.checkForUpdate();  // patch number, or null
await FlutterOta.instance.rollback();                        // back to the APK's code
FlutterOta.instance.state;                                   // what's running and staged
```

## Showing progress

`FlutterOta.instance.progress` is a `ValueListenable<FlutterOtaProgress>` that
moves through `checking → downloading → staging → staged`:

```dart
ValueListenableBuilder<FlutterOtaProgress>(
  valueListenable: FlutterOta.instance.progress,
  builder: (context, update, _) => LinearProgressIndicator(value: update.fraction),
)
```

| Field | What it gives you |
|-------|-------------------|
| `stage` | where the check has got to |
| `fraction` | 0 to 1, or null when the size is unknown — show a spinner then |
| `received`, `total` | bytes, for a "1.2 / 3.4 MB" line |
| `label` | a ready-made line, e.g. "Downloading patch 9…" |
| `isBusy` | whether anything is in flight |

Ticks smaller than a percent are dropped, so a large download does not rebuild
your UI hundreds of times.

## How the Android side works

`FlutterOtaPatch.applyTo` prepends the staged snapshot's path to the engine's
`--aot-shared-library-name` list, which is searched first-match-wins — so a
staged patch wins, and a missing or corrupt one falls back to the code in the
APK. It runs from the app's Activity before any plugin is registered, which is
why it can't live in the plugin's own lifecycle.

State lives in `filesDir/flutter_ota`:

```
state.json          currentPatch, stagedPatch, confirmed, bootAttempts
current/libapp.so   what this process was told to load
staged/libapp.so    downloaded; promoted to current at the next launch
```

A patch that never reaches a rendered frame in two launches is deleted, so a
crashing update rolls itself back.

## Layout

- `lib/flutter_ota_package.dart` — public exports
- `lib/src/flutter_ota.dart` — `FlutterOta.initialize(...)` entry point + instance
- `lib/src/update_client.dart` — HTTP client for the server API
- `lib/src/updater.dart` — download / verify / stage lifecycle
- `lib/src/flutter_ota_progress.dart` — the progress value type
- `lib/src/flutter_ota_platform.dart` — method channel, inert off Android
- `android/src/main/kotlin/dev/flutterota/FlutterOtaPatch.kt` — snapshot selection, staging, rollback
- `android/src/main/kotlin/dev/flutterota/FlutterOtaPlugin.kt` — channel handler
