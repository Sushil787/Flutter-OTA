import path from "node:path";
import fs from "node:fs";
import crypto from "node:crypto";

/// Local, content-addressed artifact storage. Files land under ./artifacts,
/// named by their sha256 — so the same bytes are never stored twice.

const ARTIFACTS_DIR = path.resolve("artifacts");
fs.mkdirSync(ARTIFACTS_DIR, { recursive: true });

/// Writes the bytes and returns the sha256 hex (used as both id and hash).
export function putArtifact(bytes: Buffer): { id: string; hash: string } {
  const hash = crypto.createHash("sha256").update(bytes).digest("hex");
  const file = path.join(ARTIFACTS_DIR, `${hash}.bin`);
  if (!fs.existsSync(file)) fs.writeFileSync(file, bytes);
  return { id: hash, hash };
}

/// Resolves an artifact id to an on-disk path, or null if missing/invalid.
export function resolveArtifact(artifactId: string): string | null {
  if (!/^[a-f0-9]{64}$/.test(artifactId)) return null; // guard path traversal
  const file = path.join(ARTIFACTS_DIR, `${artifactId}.bin`);
  return fs.existsSync(file) ? file : null;
}
