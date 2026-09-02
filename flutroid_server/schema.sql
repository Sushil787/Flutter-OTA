-- D1 schema for the Flutroid OTA backend.
-- Apply: `npm run db:init` (remote) or `npm run db:init:local` (local dev).

CREATE TABLE IF NOT EXISTS releases (
  app_id        TEXT    NOT NULL,
  platform      TEXT    NOT NULL,            -- android | ios
  version       TEXT    NOT NULL,            -- e.g. 1.0.0+1
  artifact_id   TEXT    NOT NULL,            -- R2 object key
  hash          TEXT    NOT NULL,
  created_at    INTEGER NOT NULL,
  PRIMARY KEY (app_id, platform, version)
);

CREATE TABLE IF NOT EXISTS patches (
  app_id          TEXT    NOT NULL,
  platform        TEXT    NOT NULL,
  release_version TEXT    NOT NULL,
  number          INTEGER NOT NULL,          -- monotonically increasing per release
  artifact_id     TEXT    NOT NULL,          -- R2 object key
  hash            TEXT    NOT NULL,
  created_at      INTEGER NOT NULL,
  PRIMARY KEY (app_id, platform, release_version, number)
);

CREATE INDEX IF NOT EXISTS idx_patches_lookup
  ON patches (app_id, platform, release_version, number DESC);
