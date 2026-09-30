import { z } from "zod";
import {
  authenticatedUser,
  jsonResponse,
  serviceClient,
} from "../_shared/client.ts";
import { uuid } from "../_shared/catalog.ts";

const schema = z.object({
  submissionId: uuid,
  action: z.enum(["approve", "reject", "merge"]),
  reason: z.string().max(1000).nullable().optional(),
  targetCatalogProductId: uuid.nullable().optional(),
}).refine(
  (value) => value.action !== "merge" || value.targetCatalogProductId,
  "Merge krever målprodukt",
);

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return jsonResponse({ code: "METHOD_NOT_ALLOWED" }, 405);
  }
  const authenticated = await authenticatedUser(
    request.headers.get("Authorization"),
  );
  if (!authenticated) return jsonResponse({ code: "UNAUTHORIZED" }, 401);
  if (authenticated.user.app_metadata?.role !== "catalog_moderator") {
    return jsonResponse({ code: "FORBIDDEN" }, 403);
  }
  const parsed = schema.safeParse(await request.json().catch(() => null));
  if (!parsed.success) return jsonResponse({ code: "VALIDATION_ERROR" }, 400);
  const admin = serviceClient();
  const { data: submission } = await admin.from("product_submissions").select(
    "id,status,payload,catalog_product_id",
  )
    .eq("id", parsed.data.submissionId).maybeSingle();
  if (!submission) return jsonResponse({ code: "NOT_FOUND" }, 404);
  if (["verified", "rejected", "merged"].includes(submission.status)) {
    return jsonResponse({ code: "ALREADY_DECIDED" }, 409);
  }
  const status = parsed.data.action === "approve"
    ? "verified"
    : parsed.data.action === "reject"
    ? "rejected"
    : "merged";
  const targetId = parsed.data.targetCatalogProductId ??
    submission.catalog_product_id;
  if (parsed.data.action === "approve" && !targetId) {
    return jsonResponse({ code: "CATALOG_PRODUCT_REQUIRED" }, 409);
  }
  if (parsed.data.action === "approve") {
    await admin.from("catalog_products").update({ status: "verified" }).eq(
      "id",
      targetId,
    );
  }
  const { error: actionError } = await admin.from("moderation_actions").insert({
    submission_id: submission.id,
    moderator_id: authenticated.user.id,
    action: parsed.data.action,
    reason: parsed.data.reason ?? null,
    target_catalog_product_id: parsed.data.targetCatalogProductId ?? null,
  });
  if (actionError) return jsonResponse({ code: "SERVER_ERROR" }, 500);
  const { error } = await admin.from("product_submissions").update({
    status,
    decided_at: new Date().toISOString(),
    catalog_product_id: targetId,
    updated_at: new Date().toISOString(),
  }).eq("id", submission.id);
  if (error) return jsonResponse({ code: "SERVER_ERROR" }, 500);
  await admin.from("submission_images").update({
    delete_after: new Date(Date.now() + 30 * 86400_000).toISOString(),
  })
    .eq("submission_id", submission.id).eq("kind", "nutrition_label");
  if (parsed.data.action !== "approve") {
    await admin.from("submission_images").update({
      delete_after: new Date(Date.now() + 30 * 86400_000).toISOString(),
    })
      .eq("submission_id", submission.id).eq("kind", "front");
  }
  return jsonResponse({ id: submission.id, status });
});
