import { jsonResponse, serviceClient } from "../_shared/client.ts";

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return jsonResponse({ code: "METHOD_NOT_ALLOWED" }, 405);
  }
  const expected = Deno.env.get("PURGE_CRON_SECRET");
  if (!expected || request.headers.get("X-Cron-Secret") !== expected) {
    return jsonResponse({ code: "UNAUTHORIZED" }, 401);
  }
  const admin = serviceClient();
  await admin.from("product_submissions").update({
    status: "expired",
    decided_at: new Date().toISOString(),
  })
    .in("status", ["pending_processing", "needs_review"]).lte(
      "expires_at",
      new Date().toISOString(),
    );
  const { data: due, error } = await admin.from("submission_images").select(
    "id,storage_path",
  )
    .lte("delete_after", new Date().toISOString()).limit(500);
  if (error) return jsonResponse({ code: "SERVER_ERROR" }, 500);
  let purged = 0;
  for (const image of due ?? []) {
    const { error: storageError } = await admin.storage.from(
      "product-submissions",
    ).remove([image.storage_path]);
    if (storageError) continue;
    const { error: rowError } = await admin.from("submission_images").delete()
      .eq("id", image.id);
    if (!rowError) purged += 1;
  }
  return jsonResponse({ purged });
});
