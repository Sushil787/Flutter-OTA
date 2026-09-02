# flutroid_cli

The Flutroid OTA **command-line tool**. Runs on your dev/CI machine to build the
app, cut releases, create patches, and upload artifacts to the
[backend](../flutroid_server).

## Run

```bash
dart pub get
dart run bin/flutroid.dart --help

dart run bin/flutroid.dart release --app-id mybird_test --platform android
dart run bin/flutroid.dart patch   --app-id mybird_test --platform android --release 1.0.0+1
```

## Layout

- `bin/flutroid.dart` — entry point
- `lib/src/command_runner.dart` — top-level `flutroid` command
- `lib/src/commands/release_command.dart` — `flutroid release`
- `lib/src/commands/patch_command.dart` — `flutroid patch`
