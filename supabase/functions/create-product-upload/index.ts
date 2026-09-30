import { z } from "zod";
import {
  authenticatedUser,
  jsonResponse,
  serviceClient,
} from "../_shared/client.ts";
import { uuid } from "../_shared/catalog.ts";

const requestSchema = z.object({
  assetId: uuid,
  kind: z.enum(["nutrition_label", "front"]),
  contentType: z.enum(["image/jpeg", "image/png", "image/heic"]),
  byteSize: z.number().int().positive().max(5 * 1024 * 1024),
});

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return jsonResponse({ code: "METHOD_NOT_ALLOWED" }, 405);
  }
  const authenticated = await authenticatedUser(
    request.headers.get("Authorization"),
  );
  if (!authenticated) return jsonResponse({ code: "UNAUTHORIZED" }, 401);
  const parsed = requestSchema.safeParse(
    await request.json().catch(() => null),
  );
  if (!parsed.success) return jsonResponse({ code: "VALIDATION_ERROR" }, 400);

  const admin = serviceClient();
  const extension = parsed.data.contentType === "image/png"
    ? "png"
    : parsed.data.contentType === "image/heic"
    ? "heic"
    : "jpg";
  const path =
    `${authenticated.user.id}/${parsed.data.assetId}-${parsed.data.kind}.${extension}`;
  const { error: rowError } = await admin.from("submission_images").upsert({
    id: parsed.data.assetId,
    owner_id: authenticated.user.id,
    kind: parsed.data.kind,
    storage_path: path,
    content_type: parsed.data.contentType,
    byte_size: parsed.data.byteSize,
  }, { onConflict: "id" });
  if (rowError) return jsonResponse({ code: "SERVER_ERROR" }, 500);
  const { data, error } = await admin.storage.from("product-submissions")
    .createSignedUploadUrl(path, { upsert: true });
  if (error) return jsonResponse({ code: "SERVER_ERROR" }, 500);
  return jsonResponse({
    assetId: parsed.data.assetId,
    path,
    token: data.token,
    signedUrl: data.signedUrl,
  }, 201);
});
