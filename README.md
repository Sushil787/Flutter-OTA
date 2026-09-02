# Flutroid

Your own **OTA (over-the-air) code-push for Flutter** — ship Dart code updates to
installed apps without going through the app store. Shorebird-style, self-hosted
on a plain local server.

## How it works

```
                        flutroid CLI                         device
   ┌──────────────┐   (build + upload)   ┌──────────────┐  (check + download)  ┌──────────────┐
   │  your app +  │ ───────────────────▶ │   flutroid   │ ◀─────────────────── │ flutroid_pkg │
   │ local engine │   artifact bytes     │    server    │   patch + artifact   │  (in the app)│
   └──────────────┘                      │  Express +   │                      └──────────────┘
                                         │  SQLite +    │                              │
                                         │  local files │                     patched engine loads
                                         └──────────────┘                     the staged patch on boot
```

1. You build the app against the **patched engine** and cut a **base release** with the CLI.
2. Later you change Dart code and push a **patch** with the CLI.
3. The app embeds **`flutroid_package`**, which asks the server if a newer patch exists,
   downloads + verifies it, and stages it.
4. The patched engine loads the staged patch on the next launch.

## Repo layout

| Path                 | What it is                                                        |
|----------------------|-------------------------------------------------------------------|
| `flutroid_server/`   | Backend — **Express + TypeScript**, **SQLite** metadata, artifacts on local disk |
| `flutroid_package/`  | Dart updater that ships inside the app (`Flutroid.initialize(...)`) |
| `flutroid_cli/`      | `flutroid` CLI — build, release, patch, upload                    |
| `mybird_test/`       | Example Flutter app                                               |
| `engine/`            | Patched Flutter engine source (git-ignored — built separately)    |

> Status: the **server is functional** (upload / list / update-check / download all work).
> The **CLI** and **updater package** are scaffolds with `TODO` stubs to fill in.

---

## User procedure

### 0. Prerequisites

- Flutter SDK + the **patched engine** built locally (see `LEARNING.md`).
- Node.js (for the server) and the Dart SDK (bundled with Flutter).

### 1. Run the backend

```bash
cd flutroid_server
npm install
UPLOAD_TOKEN=dev-secret npm run dev     # http://localhost:8080
```

Metadata is written to `data/flutroid.db` (SQLite); uploaded artifacts land in
`artifacts/` (both git-ignored, auto-created).

### 2. Integrate the updater into your app

Add the package and initialize it early in `main()`:

```dart
import 'package:flutroid_package/flutroid_package.dart';

Future<void> main() async {
  await Flutroid.initialize(
    packageName: 'com.example.mybird_test',
    updateUrl: 'http://localhost:8080',
  );

  await Flutroid.instance.checkForUpdate(
    platform: 'android',
    releaseVersion: '1.0.0+1',
  );

  runApp(const MyApp());
}
```

### 3. Cut a base release

Build against the patched engine, then upload the base artifact:

```bash
export FLUTROID_TOKEN=dev-secret          # must match the server's UPLOAD_TOKEN

cd flutroid_cli
dart pub get

dart run bin/flutroid.dart release \
  --server http://localhost:8080 \
  --app-id com.example.mybird_test \
  --platform android \
  --version 1.0.0+1 \
  --artifact ../mybird_test/build/app/intermediates/.../libapp.so
```

Ship this build to users through the store as usual.

### 4. Push a patch (the actual OTA update)

Change some Dart code, rebuild, and upload it as a patch against the release:

```bash
dart run bin/flutroid.dart patch \
  --server http://localhost:8080 \
  --app-id com.example.mybird_test \
  --platform android \
  --release 1.0.0+1 \
  --artifact ../mybird_test/build/.../patch.bin
```

Next time an installed app checks in, it downloads the patch and applies it on the
following launch — no store update required.

---

## API reference

| Method | Path                              | Who calls it | Purpose                       |
|--------|-----------------------------------|--------------|-------------------------------|
| POST   | `/api/v1/apps/:appId/releases`    | CLI          | upload a base release         |
| GET    | `/api/v1/apps/:appId/releases`    | —            | list releases                 |
| POST   | `/api/v1/apps/:appId/patches`     | CLI          | upload a patch                |
| GET    | `/api/v1/apps/:appId/patches`     | —            | list patches                  |
| GET    | `/api/v1/apps/:appId/updates`     | device       | check for an available update |
| GET    | `/download/:artifactId`           | device       | download an artifact          |
| GET    | `/health`                         | anyone       | health check                  |

Uploads require `Authorization: Bearer <UPLOAD_TOKEN>` and send the artifact as the
raw request body. **Url-encode `+` as `%2B`** in version/release query params.

See each subproject's own `README.md` for details.
