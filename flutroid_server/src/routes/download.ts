import { Hono } from "hono";
import type { Bindings } from "../index";

/// GET /download/:artifactId  — stream an artifact's bytes from R2.
export const download = new Hono<{ Bindings: Bindings }>();

download.get("/:artifactId", async (c) => {
  const artifactId = c.req.param("artifactId");
  const object = await c.env.ARTIFACTS.get(artifactId);
  if (!object) return c.notFound();

  // TODO: set appropriate headers (etag, content-length) and return the stream.
  return new Response(object.body, {
    headers: { "content-type": "application/octet-stream" },
  });
});
