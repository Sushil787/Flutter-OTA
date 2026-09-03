import fs from "node:fs";
import path from "node:path";

/// Loads the nearest `.env`, so the server and the CLI share one file at the
/// repo root.
///
/// Real environment variables win; the file only fills in what the process was
/// not already given. That is what lets a container set UPLOAD_TOKEN with no
/// `.env` on disk.

/** Parses `KEY=value` lines, allowing `export`, `#` comments and quotes. */
export function parseDotEnv(source: string): Record<string, string> {
  const values: Record<string, string> = {};
  for (const raw of source.split("\n")) {
    let line = raw.trim();
    if (!line || line.startsWith("#")) continue;
    if (line.startsWith("export ")) line = line.slice(7).trim();

    const eq = line.indexOf("=");
    if (eq <= 0) continue;

    const key = line.slice(0, eq).trim();
    let value = line.slice(eq + 1).trim();

    const quoted =
      value.length >= 2 &&
      ((value.startsWith('"') && value.endsWith('"')) ||
        (value.startsWith("'") && value.endsWith("'")));
    if (quoted) {
      value = value.slice(1, -1);
    } else {
      const hash = value.indexOf(" #");
      if (hash >= 0) value = value.slice(0, hash).trim();
    }

    if (key) values[key] = value;
  }
  return values;
}

/** Finds the nearest `.env` at or above [start]. */
export function findDotEnv(start: string): string | null {
  let dir = path.resolve(start);
  for (;;) {
    const candidate = path.join(dir, ".env");
    if (fs.existsSync(candidate)) return candidate;

    const parent = path.dirname(dir);
    if (parent === dir) return null; // filesystem root
    dir = parent;
  }
}

/**
 * Merges the nearest `.env` into `process.env`, never overwriting what is
 * already set. Returns the path it read, for the startup log.
 */
export function loadDotEnv(start = process.cwd()): string | null {
  const file = findDotEnv(start);
  if (!file) return null;

  try {
    for (const [key, value] of Object.entries(parseDotEnv(fs.readFileSync(file, "utf8")))) {
      if (process.env[key] === undefined) process.env[key] = value;
    }
    return file;
  } catch (error) {
    console.warn(`Could not read ${file}:`, error);
    return null;
  }
}
