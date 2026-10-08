import { authenticatedUser, jsonResponse, serviceClient } from "../_shared/client.ts";
import { notifyDeletionFailure, purgeAccount } from "../_shared/account-deletion.ts";

Deno.serve(async (request) => {
  if (request.method !== "DELETE" && request.method !== "POST") {
    return jsonResponse({ code: "METHOD_NOT_ALLOWED" }, 405);
  }
  const authenticated = await authenticatedUser(request.headers.get("Authorization"));
  if (!authenticated) return jsonResponse({ code: "UNAUTHORIZED", message: "Ugyldig eller utløpt økt" }, 401);

  const admin = serviceClient();
  const { data: purgeAt, error: requestError } = await admin.rpc("request_account_deletion_admin_v1", {
    p_owner_id: authenticated.user.id,
  });
  if (requestError || !purgeAt) {
    console.error("account deletion request failed", { code: requestError?.code });
    return jsonResponse({ code: "SERVER_ERROR", message: "Kontoen kunne ikke markeres for sletting" }, 500);
  }

  const { error: deleteError } = await admin.auth.admin.deleteUser(authenticated.user.id, true);
  if (deleteError) {
    console.error("auth soft delete failed", { status: deleteError.status });
  }

  // The persisted request and RLS block survive failures; cron retries the purge.
  const deletionCompleted = await purgeAccount(admin, authenticated.user.id);
  if (!deletionCompleted) await notifyDeletionFailure("immediate_purge_failed", 1);
  if (deleteError && !deletionCompleted) {
    return jsonResponse({
      code: "SERVER_ERROR",
      message: "Sletteforespørselen er lagret, men deaktivering kunne ikke bekreftes. Serveren prøver igjen.",
    }, 500);
  }

  return jsonResponse({
    code: "ACCOUNT_PENDING_DELETION",
    message: deletionCompleted ? "Kontoen er slettet" : "Sletteforespørselen er lagret og blir forsøkt igjen",
    permanentDeletionAt: new Date(String(purgeAt)).toISOString(),
    deletionCompleted,
  });
});
