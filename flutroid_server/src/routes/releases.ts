import { Hono } from "hono";
import type { Bindings } from "../index";

/// POST /api/v1/apps/:appId/releases  — upload a base release artifact.
/// GET  /api/v1/apps/:appId/releases  — list releases.
///
/// Uploaded by the CLI (`flutroid release`). Contract:
///   Authorization: Bearer <UPLOAD_TOKEN>
///   Content-Type:  application/octet-stream
///   ?platform=android&version=1.0.0+1
///   body: raw artifact bytes (libapp.so / AOT snapshot)
export const releases = new Hono<{ Bindings: Bindings }>();

releases.post("/", async (c) => {
  // TODO: reject if Authorization !== `Bearer ${c.env.UPLOAD_TOKEN}`
  // TODO: read platform/version from query; hash the body -> artifactId (R2 key)
  // TODO: c.env.ARTIFACTS.put(artifactId, c.req.raw.body)
  // TODO: INSERT INTO releases (...) in D1
  return c.text("TODO: upload release", 501);
});

releases.get("/", async (c) => {
  // TODO: SELECT releases for appId from D1
  return c.text("TODO: list releases", 501);
});
