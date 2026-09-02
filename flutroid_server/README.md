# flutroid_server

Simple backend for the Flutroid OTA system: stores release/patch artifacts and
serves the update-check API that the [`flutroid_package`](../flutroid_package)
updater talks to.

## Run

```bash
dart pub get
dart run bin/server.dart   # PORT=8080 by default
```

## Layout

- `bin/server.dart` — entry point (shelf server)
- `lib/src/routes.dart` — API endpoints (upload, update-check, download)
- `lib/src/storage.dart` — artifact storage (filesystem to start)
- `lib/src/models.dart` — `Release` / `Patch` models
- `storage/` — uploaded artifacts (gitignored)

## API sketch

| Method | Path                              | Purpose                       |
|--------|-----------------------------------|-------------------------------|
| POST   | `/api/v1/apps/<appId>/releases`   | upload a base release         |
| POST   | `/api/v1/apps/<appId>/patches`    | upload a patch                |
| GET    | `/api/v1/apps/<appId>/updates`    | check for an available update |
| GET    | `/download/<artifactId>`          | download an artifact          |
