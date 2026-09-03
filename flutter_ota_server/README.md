# flutter_ota_server

Express + TypeScript backend for Flutter OTA. Patch metadata goes in a local
SQLite file; the artifacts themselves are written to disk, named by their
sha256.

## Run

```bash
npm install
npm run dev          # http://localhost:8080, reloads on change
# or: npm start
```

Configuration comes from the repo-root `.env`:

| Key | Default | What it does |
|-----|---------|--------------|
| `PORT` | `8080` | port to listen on |
| `UPLOAD_TOKEN` | `dev-secret` | required on uploads, as `Authorization: Bearer <token>` |

Real environment variables win over the file, so `UPLOAD_TOKEN=x npm run dev`
still works.

## API

| Method | Path | Who calls it | Purpose |
|--------|------|--------------|---------|
| POST | `/api/v1/apps/:appId/patches` | CLI | upload a patch |
| GET | `/api/v1/apps/:appId/patches` | — | list patches (`?release=`) |
| GET | `/api/v1/apps/:appId/updates` | device | is there anything newer? |
| GET | `/download/:artifactId` | device | download an artifact |
| GET | `/health` | — | health check |

There is no releases endpoint. A patch is filed under the version the app
reports for itself, and the update check reads only the patches table, so
nothing has to register a baseline first.

Uploads send the artifact as the raw `application/octet-stream` body with the
metadata in the query string. **Url-encode the `+` in a version as `%2B`** —
otherwise it arrives as a space.

```bash
curl -X POST "http://localhost:8080/api/v1/apps/com.example.app/patches?platform=android&release=1.0.0%2B1" \
  -H "Authorization: Bearer dev-secret" \
  -H "Content-Type: application/octet-stream" \
  --data-binary @build/.../libapp.so
```

The server assigns the patch number: the next one for that app, platform and
release.

`/download` sends a `Content-Length`, which is what lets the updater show a
real progress bar instead of a spinner.

## Layout

- `src/server.ts` — the Express app and every route
- `src/db.ts` — the `patches` table and its queries
- `src/storage.ts` — artifact files, addressed by sha256
- `src/env.ts` — reads the repo-root `.env`
- `data/flutter_ota.db`, `artifacts/` — created on first run, git-ignored
