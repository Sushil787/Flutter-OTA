import { Hono } from "hono";
import type { Bindings } from "../index";

/// POST /api/v1/apps/:appId/patches  — upload a patch artifact for a release.
/// GET  /api/v1/apps/:appId/patches  — list patches.
///
/// Uploaded by the CLI (`flutroid patch`). Contract:
///   Authorization: Bearer <UPLOAD_TOKEN>
///   Content-Type:  application/octet-stream
///   ?platform=android&release=1.0.0+1
///   body: raw patch bytes (new snapshot / diff against the release)
export const patches = new Hono<{ Bindings: Bindings }>();

patches.post("/", async (c) => {
  // TODO: reject if Authorization !== `Bearer ${c.env.UPLOAD_TOKEN}`
  // TODO: read platform/release from query; hash the body -> artifactId (R2 key)
  // TODO: next patch number = max(number) + 1 for (appId, platform, release)
  // TODO: c.env.ARTIFACTS.put(artifactId, c.req.raw.body)
  // TODO: INSERT INTO patches (...) in D1
  return c.text("TODO: upload patch", 501);
});

patches.get("/", async (c) => {
  // TODO: SELECT patches for appId (optionally ?release=) from D1
  return c.text("TODO: list patches", 501);
});
