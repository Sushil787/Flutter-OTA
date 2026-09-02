import { Hono } from "hono";
import { releases } from "./routes/releases";
import { patches } from "./routes/patches";
import { updates } from "./routes/updates";
import { download } from "./routes/download";

/// Cloudflare bindings available on `c.env`.
export type Bindings = {
  ARTIFACTS: R2Bucket; // artifact storage
  DB: D1Database; // release/patch metadata
  UPLOAD_TOKEN: string; // secret guarding uploads
};

const app = new Hono<{ Bindings: Bindings }>();

app.get("/health", (c) => c.text("ok"));

// Uploads (guarded by UPLOAD_TOKEN) + reads.
app.route("/api/v1/apps/:appId/releases", releases);
app.route("/api/v1/apps/:appId/patches", patches);
app.route("/api/v1/apps/:appId/updates", updates);
app.route("/download", download);

export default app;
