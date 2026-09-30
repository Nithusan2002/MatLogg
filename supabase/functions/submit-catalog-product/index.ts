import { z } from "zod";
import {
  authenticatedUser,
  jsonResponse,
  serviceClient,
} from "../_shared/client.ts";
import {
  isValidGTIN,
  normalizeCatalogText,
  nutrients,
  nutritionBasis,
  uuid,
} from "../_shared/catalog.ts";

const schema = z.object({
  submissionId: uuid,
  productId: uuid,
  name: z.string().trim().min(1).max(200),
  brand: z.string().trim().min(1).max(160),
  barcode: z.string().trim().nullable(),
  nutritionBasis,
  nutrients,
  labelAssetId: uuid,
  frontAssetId: uuid,
  explicitConsent: z.literal(true),
  aiFieldsConfirmed: z.boolean(),
});

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return jsonResponse({ code: "METHOD_NOT_ALLOWED" }, 405);
  }
  const authenticated = await authenticatedUser(
    request.headers.get("Authorization"),
  );
  if (!authenticated) return jsonResponse({ code: "UNAUTHORIZED" }, 401);
  const parsed = schema.safeParse(await request.json().catch(() => null));
  if (!parsed.success) return jsonResponse({ code: "VALIDATION_ERROR" }, 400);
  const input = parsed.data;
  const admin = serviceClient();
  const { data: enabled } = await admin.rpc("feature_enabled_v1", {
    p_key: "catalog_contributions_enabled",
  });
  if (!enabled) return jsonResponse({ code: "FEATURE_DISABLED" }, 503);
  const { data: existing } = await admin.from("product_submissions").select(
    "id,status,catalog_product_id",
  )
    .eq("id", input.submissionId).eq("owner_id", authenticated.user.id)
    .maybeSingle();
  if (existing) return jsonResponse(existing);
  const { data: images } = await admin.from("submission_images").select(
    "id,kind,storage_path,perceptual_hash",
  )
    .eq("owner_id", authenticated.user.id).in("id", [
      input.labelAssetId,
      input.frontAssetId,
    ]);
  if (
    !images || images.length !== 2 || !images.some((image) =>
      image.kind === "nutrition_label"
    ) || !images.some((image) => image.kind === "front")
  ) {
    return jsonResponse({ code: "IMAGES_REQUIRED" }, 400);
  }
  const flags: string[] = [];
  const frontImage = images.find((image) => image.kind === "front")!;
  const frontHash = frontImage.perceptual_hash;
  if (!input.aiFieldsConfirmed) flags.push("AI_FIELDS_NOT_CONFIRMED");
  if (input.barcode && !isValidGTIN(input.barcode)) flags.push("INVALID_GTIN");
  if (input.barcode) {
    const { data: barcodeMatch } = await admin.from("catalog_products").select(
      "id",
    ).eq("barcode", input.barcode).maybeSingle();
    if (barcodeMatch) flags.push("EXISTING_BARCODE_CORRECTION");
  } else {
    const normalizedName = normalizeCatalogText(input.name),
      normalizedBrand = normalizeCatalogText(input.brand);
    const { data: exact } = await admin.from("catalog_products").select("id")
      .eq("normalized_name", normalizedName).eq(
        "normalized_brand",
        normalizedBrand,
      ).limit(1);
    const { data: fuzzy } = await admin.rpc("catalog_duplicate_candidates_v1", {
      p_name: input.name,
      p_brand: input.brand,
      p_threshold: 0.70,
    });
    const { data: hashMatch } = frontHash
      ? await admin.from("catalog_products").select("id").eq(
        "front_image_phash",
        frontHash,
      ).limit(1)
      : { data: [] };
    if (exact?.length) flags.push("EXACT_DUPLICATE");
    if (fuzzy?.length) flags.push("FUZZY_DUPLICATE");
    if (hashMatch?.length) flags.push("IMAGE_DUPLICATE");
    if (!frontHash) flags.push("IMAGE_HASH_PENDING");
  }
  const { data: autoPublishEnabled } = await admin.rpc("feature_enabled_v1", {
    p_key: "catalog_auto_publish_enabled",
  });
  const mayPublish = autoPublishEnabled && flags.length === 0 &&
    Boolean(frontHash);
  const status = mayPublish
    ? "public_unverified"
    : flags.length
    ? "needs_review"
    : "pending_processing";
  const payload = {
    name: input.name,
    brand: input.brand,
    barcode: input.barcode,
    nutritionBasis: input.nutritionBasis,
    nutrients: input.nutrients,
  };
  const { error } = await admin.from("product_submissions").insert({
    id: input.submissionId,
    owner_id: authenticated.user.id,
    product_id: input.productId,
    status,
    payload,
    explicit_consent: true,
    ai_fields_confirmed: input.aiFieldsConfirmed,
    validation_flags: flags,
  });
  if (error) {
    return jsonResponse({
      code: error.code === "23505" ? "DUPLICATE" : "SERVER_ERROR",
    }, error.code === "23505" ? 409 : 500);
  }
  await admin.from("submission_images").update({
    submission_id: input.submissionId,
  }).in("id", [input.labelAssetId, input.frontAssetId]).eq(
    "owner_id",
    authenticated.user.id,
  );
  let catalogProductId: string | null = null;
  if (mayPublish && frontHash) {
    const { data: bytes, error: downloadError } = await admin.storage.from(
      "product-submissions",
    ).download(frontImage.storage_path);
    if (downloadError) {
      return jsonResponse({ code: "IMAGE_PROCESSING_REQUIRED" }, 202);
    }
    const publicPath = `${input.submissionId}/front`;
    const { error: uploadError } = await admin.storage.from(
      "catalog-product-images",
    ).upload(publicPath, bytes, { upsert: false });
    if (uploadError) {
      return jsonResponse({ code: "IMAGE_PROCESSING_REQUIRED" }, 202);
    }
    const { data: created, error: catalogError } = await admin.from(
      "catalog_products",
    ).insert({
      name: input.name,
      normalized_name: normalizeCatalogText(input.name),
      brand: input.brand,
      normalized_brand: normalizeCatalogText(input.brand),
      barcode: input.barcode,
      nutrition_basis: input.nutritionBasis,
      nutrients: input.nutrients,
      front_image_path: publicPath,
      front_image_phash: frontHash,
      status: "public_unverified",
      source_submission_id: input.submissionId,
    }).select("id").single();
    if (catalogError) {
      return jsonResponse({ code: "CATALOG_WRITE_FAILED" }, 500);
    }
    catalogProductId = created.id;
    await admin.from("product_submissions").update({
      catalog_product_id: catalogProductId,
      decided_at: new Date().toISOString(),
    }).eq("id", input.submissionId);
    await admin.from("submission_images").update({
      delete_after: new Date(Date.now() + 30 * 86400_000).toISOString(),
    }).eq("submission_id", input.submissionId).eq("kind", "nutrition_label");
  }
  return jsonResponse({
    id: input.submissionId,
    status,
    catalogProductId,
    validationFlags: flags,
  }, 201);
});
