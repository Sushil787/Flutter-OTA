import { Hono } from "hono";
import type { Bindings } from "../index";

/// GET /api/v1/apps/:appId/updates?platform=&release=&patch=
///
/// The updater on the device calls this. Return the newest patch for the given
/// release (if newer than the device's current patch), or 204 if up to date.
export const updates = new Hono<{ Bindings: Bindings }>();

updates.get("/", async (c) => {
  const appId = c.req.param("appId");
  const platform = c.req.query("platform");
  const release = c.req.query("release");
  const currentPatch = Number(c.req.query("patch") ?? "0");

  // TODO: SELECT the latest patch for (appId, platform, release) from D1.
  // TODO: if latest > currentPatch -> return { patchNumber, downloadUrl, hash }
  //       else -> return 204 No Content.
  return c.json(
    { todo: "check updates", appId, platform, release, currentPatch },
    501,
  );
});
