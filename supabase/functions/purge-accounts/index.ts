import { jsonResponse, serviceClient } from "../_shared/client.ts";
import { notifyDeletionFailure, purgeAccount } from "../_shared/account-deletion.ts";

Deno.serve(async (request) => {
  if (request.method !== "POST") return jsonResponse({ code: "METHOD_NOT_ALLOWED" }, 405);
  const expected = Deno.env.get("PURGE_CRON_SECRET");
  if (!expected || request.headers.get("X-Cron-Secret") !== expected) {
    return jsonResponse({ code: "UNAUTHORIZED" }, 401);
  }

  const admin = serviceClient();
  const { data: due, error } = await admin.rpc("due_account_purges_v1");
  if (error) {
    await notifyDeletionFailure("purge_lookup_failed", 1);
    return jsonResponse({ code: "SERVER_ERROR" }, 500);
  }

  let purged = 0;
  let failed = 0;
  for (const row of due ?? []) {
    const ownerId = row.owner_id as string;
    if (await purgeAccount(admin, ownerId)) purged += 1;
    else failed += 1;
  }

  if (failed > 0) await notifyDeletionFailure("purge_batch_failed", failed);

  console.log("account purge complete", { purged, failed });
  return jsonResponse({ purged, failed }, failed > 0 ? 207 : 200);
});
