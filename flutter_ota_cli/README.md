# flutter_ota_cli

The Flutter OTA command-line tool. Runs on your machine or in CI to wire the
patch loader into an app and ship new Dart code to the
[backend](../flutter_ota_server).

```bash
dart pub get
dart run bin/flutter_ota.dart --help
```

## `flutter_ota init`

Writes the patch loader into the app's own `MainActivity`. This is the one
override that lets a downloaded snapshot reach the engine:

```kotlin
override fun getFlutterShellArgs(): io.flutter.embedding.engine.FlutterShellArgs =
    dev.flutterota.FlutterOtaPatch.applyTo(this, super.getFlutterShellArgs())
```

```bash
dart run bin/flutter_ota.dart init --app ../flutter_ota_test
dart run bin/flutter_ota.dart init --app ../flutter_ota_test --dry-run
```

Handles Kotlin and Java, with or without an existing class body. The block is
fenced with `// flutter_ota:begin` / `// flutter_ota:end`, so re-running
regenerates it in place. If the class is not a shape it can rewrite
confidently, it refuses and prints the snippet to paste rather than guessing.

## `flutter_ota patch`

```bash
cd ../flutter_ota_test
flutter build apk --release
dart run ../flutter_ota_cli/bin/flutter_ota.dart patch
```

No arguments, because it works everything out:

```
app id: com.example.mybird_test  (from android/app/build.gradle)
release: 1.0.0+1  (from pubspec.yaml)
✓ uploaded   "number": 9
```

| Value | Comes from |
|-------|------------|
| app id | the Android `applicationId` |
| release | `version:` in `pubspec.yaml` |
| patch number | the server, which assigns the next one |
| token, server URL | the repo-root `.env` |

The first two are exactly what the device reports for itself. Typing them by
hand files a patch under a release nobody has installed, and nothing errors —
the app just stays on old code. The CLI prints what it used so a mismatch is
visible.

Override any of it with `--app-id`, `--release`, `--token`, `--server`. It
finds `libapp.so` in the Gradle output on its own; `--artifact` overrides and
`--abi` defaults to `arm64-v8a`.

Do not bump `pubspec.yaml` to ship a patch. That files it against a release
nobody is running. Bump the version only when you ship a new APK.

## Layout

- `bin/flutter_ota.dart` — entry point
- `lib/src/command_runner.dart` — the `flutter_ota` command
- `lib/src/android_patcher.dart` — the `MainActivity` rewriter (unit-tested)
- `lib/src/app_info.dart` — reads the app id and version from the project
- `lib/src/env.dart` — reads `.env`
- `lib/src/uploader.dart` — finds `libapp.so` and uploads it
- `lib/src/commands/` — `init`, `patch`

```bash
dart test
```
