export interface DeletionAdmin {
  rpc(name: string, args: { p_owner_id: string }): PromiseLike<{ error: unknown }>;
  auth: { admin: { deleteUser(id: string, soft: boolean): PromiseLike<{ error: unknown }> } };
}

// Domain deletion is atomic; the profile stays due until Auth deletion succeeds.
export async function purgeAccount(admin: DeletionAdmin, ownerId: string): Promise<boolean> {
  try {
    const { error } = await admin.rpc("purge_account_data_admin_v1", { p_owner_id: ownerId });
    if (error) return false;
    const { error: authError } = await admin.auth.admin.deleteUser(ownerId, false);
    return !authError;
  } catch {
    return false;
  }
}

export type DeletionAlert = "immediate_purge_failed" | "purge_batch_failed" | "purge_lookup_failed";

// Alerts carry only an operational category/count, never account IDs or payloads.
export async function notifyDeletionFailure(
  category: DeletionAlert,
  failed: number,
  environment: (name: string) => string | undefined = Deno.env.get,
  send: typeof fetch = fetch,
): Promise<boolean> {
  const key = environment("DELETION_ALERT_RESEND_KEY");
  const from = environment("DELETION_ALERT_FROM");
  const to = environment("DELETION_ALERT_TO") ?? "nithusank.2002@gmail.com";
  if (!key || !from || !to) {
    console.error("deletion alert unavailable", { category, failed });
    return false;
  }
  try {
    const response = await send("https://api.resend.com/emails", {
      method: "POST",
      headers: { Authorization: `Bearer ${key}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        from, to: [to], subject: "MatLogg: serversletting krever oppfølging",
        text: `Kategori: ${category}. Antall feil: ${failed}. Kontroller slettejobben i Supabase. Ingen kontoopplysninger er inkludert.`,
      }),
      signal: AbortSignal.timeout(5000),
    });
    if (!response.ok) console.error("deletion alert delivery failed", { status: response.status });
    await response.body?.cancel();
    return response.ok;
  } catch {
    console.error("deletion alert delivery failed");
    return false;
  }
}
