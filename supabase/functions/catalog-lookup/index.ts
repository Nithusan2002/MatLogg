import { z } from "zod";
import { createHash } from "node:crypto";
import { jsonResponse, serviceClient } from "../_shared/client.ts";
import { normalizeCatalogText, requestSubject } from "../_shared/catalog.ts";

const schema = z.object({
  query: z.string().trim().min(2).max(80).optional(),
  barcode: z.string().regex(/^\d{8,14}$/).optional(),
})
  .refine((value) => value.query || value.barcode);

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return jsonResponse({ code: "METHOD_NOT_ALLOWED" }, 405);
  }
  const admin = serviceClient();
  const { data: enabled } = await admin.rpc("feature_enabled_v1", {
    p_key: "shared_catalog_read_enabled",
  });
  if (!enabled) return jsonResponse({ code: "FEATURE_DISABLED" }, 503);
  const subjectHash = createHash("sha256").update(requestSubject(request))
    .digest("hex");
  const { data: allowed } = await admin.rpc("consume_catalog_quota_v1", {
    p_subject_hash: subjectHash,
    p_action: "lookup",
    p_limit: 60,
  });
  if (!allowed) {
    return jsonResponse({ code: "RATE_LIMITED" }, 429, { "Retry-After": "60" });
  }
  const parsed = schema.safeParse(await request.json().catch(() => null));
  if (!parsed.success) return jsonResponse({ code: "VALIDATION_ERROR" }, 400);

  let query = admin.from("catalog_products").select(
    "id,name,brand,barcode,nutrition_basis,nutrients,front_image_path,status,updated_at",
  )
    .in("status", ["public_unverified", "verified"]).limit(20);
  if (parsed.data.barcode) query = query.eq("barcode", parsed.data.barcode);
  else {query = query.textSearch(
      "normalized_name",
      normalizeCatalogText(parsed.data.query!),
      { type: "websearch", config: "simple" },
    );}
  const { data, error } = await query;
  if (error) return jsonResponse({ code: "SERVER_ERROR" }, 500);
  const products = (data ?? []).map((product) => ({
    ...product,
    front_image_url: admin.storage.from("catalog-product-images").getPublicUrl(
      product.front_image_path,
    ).data.publicUrl,
  }));
  return jsonResponse({ products });
});
