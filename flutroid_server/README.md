# flutroid_server

Plain **Express + TypeScript** backend for Flutroid OTA. Metadata lives in a local
**SQLite** file (`better-sqlite3`); artifacts are stored on the **local filesystem**,
content-addressed by sha256.

## Run

```bash
npm install
UPLOAD_TOKEN=dev-secret npm run dev     # http://localhost:8080  (auto-reload)
# or: npm start
```

Env vars: `PORT` (default `8080`), `UPLOAD_TOKEN` (default `dev-secret`).

## Layout

- `src/server.ts` — Express app + all routes
- `src/db.ts` — SQLite model (`releases`, `patches`) + query helpers
- `src/storage.ts` — local artifact storage (sha256-addressed)
- `data/flutroid.db` — SQLite database (gitignored, auto-created)
- `artifacts/` — uploaded artifact files (gitignored, auto-created)

## API

| Method | Path                              | Who    | Purpose                       |
|--------|-----------------------------------|--------|-------------------------------|
| POST   | `/api/v1/apps/:appId/releases`    | CLI    | upload a base release         |
| GET    | `/api/v1/apps/:appId/releases`    | —      | list releases                 |
| POST   | `/api/v1/apps/:appId/patches`     | CLI    | upload a patch                |
| GET    | `/api/v1/apps/:appId/patches`     | —      | list patches (`?release=`)    |
| GET    | `/api/v1/apps/:appId/updates`     | device | check for an update           |
| GET    | `/download/:artifactId`           | device | download an artifact          |
| GET    | `/health`                         | —      | health check                  |

Uploads require `Authorization: Bearer <UPLOAD_TOKEN>` and send the artifact as the
raw `application/octet-stream` body, with metadata in the query string:

```bash
# NOTE: url-encode the '+' in a version as %2B
curl -X POST "http://localhost:8080/api/v1/apps/com.example.app/releases?platform=android&version=1.0.0%2B1" \
  -H "Authorization: Bearer dev-secret" \
  -H "Content-Type: application/octet-stream" \
  --data-binary @build/.../libapp.so
```
