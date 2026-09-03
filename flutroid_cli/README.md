# flutroid_cli

The Flutroid OTA **command-line tool**. Runs on your dev/CI machine to wire
Flutroid into an app, cut releases, and ship patches to the
[backend](../flutroid_server).

## Commands

```bash
dart pub get
dart run bin/flutroid.dart --help
```

### `flutroid init`

Writes the patch loader into the app's own `MainActivity` — the one override
that lets a downloaded snapshot reach the engine:

```kotlin
override fun getFlutterShellArgs(): io.flutter.embedding.engine.FlutterShellArgs =
    dev.flutroid.FlutroidPatch.applyTo(this, super.getFlutterShellArgs())
```

```bash
dart run bin/flutroid.dart init --app ../flutroid_test
dart run bin/flutroid.dart init --app ../flutroid_test --dry-run
```

Handles Kotlin and Java, and a class with or without an existing body. The block
is fenced with `// flutroid:begin` / `// flutroid:end` markers, so re-running
regenerates it in place instead of duplicating it. When the class isn't a shape
it can rewrite confidently it refuses and prints the snippet to paste, rather
than guessing at your code.

### `flutroid release` / `flutroid patch`

```bash
export FLUTROID_TOKEN=dev-secret

dart run bin/flutroid.dart release --app ../flutroid_test \
  --app-id com.example.mybird_test --version 1.0.0+1

dart run bin/flutroid.dart patch --app ../flutroid_test \
  --app-id com.example.mybird_test --release 1.0.0+1
```

Both find `libapp.so` in the Gradle build output on their own; `--artifact`
overrides, `--abi` defaults to `arm64-v8a`. Build the app first —
`flutter build apk --release`.

## Layout

- `bin/flutroid.dart` — entry point
- `lib/src/command_runner.dart` — top-level `flutroid` command
- `lib/src/android_patcher.dart` — the `MainActivity` rewriter (unit-tested)
- `lib/src/uploader.dart` — artifact discovery + upload
- `lib/src/commands/` — `init`, `release`, `patch`

```bash
dart test
```
