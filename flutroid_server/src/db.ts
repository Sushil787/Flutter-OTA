import Database from "better-sqlite3";
import path from "node:path";
import fs from "node:fs";

/// SQLite data model + query helpers for the Flutroid OTA server.

export interface ReleaseRow {
  app_id: string;
  platform: string;
  version: string;
  artifact_id: string | null;
  hash: string | null;
  created_at: number;
}

export interface PatchRow {
  app_id: string;
  platform: string;
  release_version: string;
  number: number;
  artifact_id: string | null;
  hash: string | null;
  created_at: number;
}

const DATA_DIR = path.resolve("data");
fs.mkdirSync(DATA_DIR, { recursive: true });

export const db = new Database(path.join(DATA_DIR, "flutroid.db"));
db.pragma("journal_mode = WAL");

db.exec(`
  CREATE TABLE IF NOT EXISTS releases (
    app_id      TEXT    NOT NULL,
    platform    TEXT    NOT NULL,
    version     TEXT    NOT NULL,
    artifact_id TEXT,
    hash        TEXT,
    created_at  INTEGER NOT NULL,
    PRIMARY KEY (app_id, platform, version)
  );
  CREATE TABLE IF NOT EXISTS patches (
    app_id          TEXT    NOT NULL,
    platform        TEXT    NOT NULL,
    release_version TEXT    NOT NULL,
    number          INTEGER NOT NULL,
    artifact_id     TEXT,
    hash            TEXT,
    created_at      INTEGER NOT NULL,
    PRIMARY KEY (app_id, platform, release_version, number)
  );
  CREATE INDEX IF NOT EXISTS idx_patches_lookup
    ON patches (app_id, platform, release_version, number DESC);
`);

// --- Releases ---------------------------------------------------------------

export function insertRelease(r: ReleaseRow): void {
  db.prepare(
    `INSERT OR REPLACE INTO releases (app_id, platform, version, artifact_id, hash, created_at)
     VALUES (@app_id, @platform, @version, @artifact_id, @hash, @created_at)`,
  ).run(r);
}

export function listReleases(appId: string): ReleaseRow[] {
  return db
    .prepare(`SELECT * FROM releases WHERE app_id = ? ORDER BY created_at DESC`)
    .all(appId) as ReleaseRow[];
}

// --- Patches ----------------------------------------------------------------

export function latestPatchNumber(appId: string, platform: string, release: string): number {
  const row = db
    .prepare(
      `SELECT MAX(number) AS max FROM patches
       WHERE app_id = ? AND platform = ? AND release_version = ?`,
    )
    .get(appId, platform, release) as { max: number | null } | undefined;
  return row?.max ?? 0;
}

export function insertPatch(p: PatchRow): void {
  db.prepare(
    `INSERT INTO patches
       (app_id, platform, release_version, number, artifact_id, hash, created_at)
     VALUES (@app_id, @platform, @release_version, @number, @artifact_id, @hash, @created_at)`,
  ).run(p);
}

export function latestPatch(appId: string, platform: string, release: string): PatchRow | undefined {
  return db
    .prepare(
      `SELECT * FROM patches
       WHERE app_id = ? AND platform = ? AND release_version = ?
       ORDER BY number DESC LIMIT 1`,
    )
    .get(appId, platform, release) as PatchRow | undefined;
}

export function listPatches(appId: string, release?: string): PatchRow[] {
  if (release) {
    return db
      .prepare(
        `SELECT * FROM patches WHERE app_id = ? AND release_version = ?
         ORDER BY number DESC`,
      )
      .all(appId, release) as PatchRow[];
  }
  return db
    .prepare(`SELECT * FROM patches WHERE app_id = ? ORDER BY created_at DESC`)
    .all(appId) as PatchRow[];
}
