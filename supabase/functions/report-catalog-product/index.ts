import { z } from "zod";
import { createHash } from "node:crypto";
import {
  authenticatedUser,
  jsonResponse,
  serviceClient,
} from "../_shared/client.ts";
import { requestSubject, uuid } from "../_shared/catalog.ts";

const schema = z.object({
  catalogProductId: uuid,
  reason: z.string().trim().min(3).max(500),
});

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return jsonResponse({ code: "METHOD_NOT_ALLOWED" }, 405);
  }
  const parsed = schema.safeParse(await request.json().catch(() => null));
  if (!parsed.success) return jsonResponse({ code: "VALIDATION_ERROR" }, 400);
  const admin = serviceClient();
  const auth = await authenticatedUser(request.headers.get("Authorization"));
  const subject = auth?.user.id ?? requestSubject(request);
  const subjectHash = createHash("sha256").update(subject).digest("hex");
  const { data: allowed } = await admin.rpc("consume_catalog_quota_v1", {
    p_subject_hash: subjectHash,
    p_action: "report",
    p_limit: 10,
  });
  if (!allowed) return jsonResponse({ code: "RATE_LIMITED" }, 429);
  const { data: product } = await admin.from("catalog_products").select("id")
    .eq("id", parsed.data.catalogProductId)
    .in("status", ["public_unverified", "verified"]).maybeSingle();
  if (!product) return jsonResponse({ code: "NOT_FOUND" }, 404);
  const { error } = await admin.from("catalog_reports").insert({
    catalog_product_id: product.id,
    reporter_id: auth?.user.id ?? null,
    reason: parsed.data.reason,
  });
  return error
    ? jsonResponse({ code: "SERVER_ERROR" }, 500)
    : jsonResponse({ accepted: true }, 201);
});
