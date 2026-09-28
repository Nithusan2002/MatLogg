import { jsonResponse, serviceClient } from "../_shared/client.ts";

Deno.serve(async (request) => {
  if (request.method !== "POST") return jsonResponse({ code: "METHOD_NOT_ALLOWED" }, 405);
  const expected = Deno.env.get("PURGE_CRON_SECRET");
  if (!expected || request.headers.get("X-Cron-Secret") !== expected) {
    return jsonResponse({ code: "UNAUTHORIZED" }, 401);
  }

  const admin = serviceClient();
  const { data: due, error } = await admin.rpc("due_account_purges_v1");
  if (error) return jsonResponse({ code: "SERVER_ERROR" }, 500);

  let purged = 0;
  let failed = 0;
  for (const row of due ?? []) {
    const ownerId = row.owner_id as string;
    const { error: dataError } = await admin.rpc("purge_account_data_admin_v1", { p_owner_id: ownerId });
    if (dataError) {
      failed += 1;
      continue;
    }
    const { error: authError } = await admin.auth.admin.deleteUser(ownerId, false);
    if (authError) failed += 1;
    else purged += 1;
  }

  console.log("account purge complete", { purged, failed });
  return jsonResponse({ purged, failed }, failed > 0 ? 207 : 200);
});
