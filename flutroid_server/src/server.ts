import express, { type Request } from "express";
import fs from "node:fs";
import {
  insertRelease,
  listReleases,
  insertPatch,
  latestPatchNumber,
  latestPatch,
  listPatches,
} from "./db";
import { putArtifact, resolveArtifact } from "./storage";

const PORT = Number(process.env.PORT ?? 8080);
const UPLOAD_TOKEN = process.env.UPLOAD_TOKEN ?? "dev-secret";

const app = express();

// Raw binary body for uploads — the CLI POSTs application/octet-stream.
const rawBody = express.raw({ type: "*/*", limit: "1gb" });

function authed(req: Request): boolean {
  return req.header("authorization") === `Bearer ${UPLOAD_TOKEN}`;
}

function bodyBytes(req: Request): Buffer | null {
  return Buffer.isBuffer(req.body) && req.body.length > 0 ? req.body : null;
}

app.get("/health", (_req, res) => {
  res.send("ok");
});

// --- Releases ---------------------------------------------------------------

app.post("/api/v1/apps/:appId/releases", rawBody, (req, res) => {
  if (!authed(req)) return res.status(401).send("unauthorized");
  const { appId } = req.params;
  const platform = req.query.platform as string | undefined;
  const version = req.query.version as string | undefined;
  if (!platform || !version) return res.status(400).send("platform and version are required");

  const art = bodyBytes(req) ? putArtifact(req.body) : null;
  insertRelease({
    app_id: appId,
    platform,
    version,
    artifact_id: art?.id ?? null,
    hash: art?.hash ?? null,
    created_at: Date.now(),
  });
  res.status(201).json({ appId, platform, version, artifactId: art?.id ?? null, hash: art?.hash ?? null });
});

app.get("/api/v1/apps/:appId/releases", (req, res) => {
  res.json(listReleases(req.params.appId));
});

// --- Patches ----------------------------------------------------------------

app.post("/api/v1/apps/:appId/patches", rawBody, (req, res) => {
  if (!authed(req)) return res.status(401).send("unauthorized");
  const { appId } = req.params;
  const platform = req.query.platform as string | undefined;
  const release = req.query.release as string | undefined;
  if (!platform || !release) return res.status(400).send("platform and release are required");

  const art = bodyBytes(req) ? putArtifact(req.body) : null;
  const number = latestPatchNumber(appId, platform, release) + 1;
  insertPatch({
    app_id: appId,
    platform,
    release_version: release,
    number,
    artifact_id: art?.id ?? null,
    hash: art?.hash ?? null,
    created_at: Date.now(),
  });
  res.status(201).json({ appId, platform, release, number, artifactId: art?.id ?? null, hash: art?.hash ?? null });
});

app.get("/api/v1/apps/:appId/patches", (req, res) => {
  const release = req.query.release as string | undefined;
  res.json(listPatches(req.params.appId, release));
});

// --- Update check (device) --------------------------------------------------

app.get("/api/v1/apps/:appId/updates", (req, res) => {
  const { appId } = req.params;
  const platform = req.query.platform as string | undefined;
  const release = req.query.release as string | undefined;
  const currentPatch = Number(req.query.patch ?? "0");
  if (!platform || !release) return res.status(400).send("platform and release are required");

  const patch = latestPatch(appId, platform, release);
  if (!patch || patch.number <= currentPatch) return res.status(204).end();

  res.json({
    patchNumber: patch.number,
    hash: patch.hash,
    downloadUrl: patch.artifact_id ? `/download/${patch.artifact_id}` : null,
  });
});

// --- Download artifact (device) ---------------------------------------------

app.get("/download/:artifactId", (req, res) => {
  const file = resolveArtifact(req.params.artifactId);
  if (!file) return res.status(404).send("not found");
  res.type("application/octet-stream");
  fs.createReadStream(file).pipe(res);
});

app.listen(PORT, () => {
  console.log(`Flutroid server on http://localhost:${PORT}  (token: ${UPLOAD_TOKEN})`);
});
