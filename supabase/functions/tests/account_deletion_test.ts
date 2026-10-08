import { assertEquals } from "@std/assert";
import { DeletionAdmin, notifyDeletionFailure, purgeAccount } from "../_shared/account-deletion.ts";

Deno.test("purge retains retry state when domain deletion fails and never deletes Auth first", async () => {
  let authCalls = 0;
  const admin: DeletionAdmin = {
    rpc: () => Promise.resolve({ error: { code: "DATABASE_FAILURE" } }),
    auth: { admin: { deleteUser: () => { authCalls++; return Promise.resolve({ error: null }); } } },
  };
  assertEquals(await purgeAccount(admin, "synthetic-owner"), false);
  assertEquals(authCalls, 0);
});

Deno.test("Auth failure can be retried after atomic domain purge", async () => {
  const calls: string[] = [];
  let failAuth = true;
  const admin: DeletionAdmin = {
    rpc: (name, args) => {
      assertEquals(args.p_owner_id, "synthetic-owner");
      calls.push(name); return Promise.resolve({ error: null });
    },
    auth: { admin: { deleteUser: (id, soft) => {
      assertEquals(id, "synthetic-owner"); assertEquals(soft, false);
      calls.push("auth"); return Promise.resolve({ error: failAuth ? {} : null });
    } } },
  };
  assertEquals(await purgeAccount(admin, "synthetic-owner"), false);
  failAuth = false;
  assertEquals(await purgeAccount(admin, "synthetic-owner"), true);
  assertEquals(calls, ["purge_account_data_admin_v1", "auth", "purge_account_data_admin_v1", "auth"]);
});

Deno.test("network exceptions leave purge eligible for retry", async () => {
  const admin: DeletionAdmin = {
    rpc: () => { throw new Error("synthetic network error"); },
    auth: { admin: { deleteUser: () => Promise.resolve({ error: null }) } },
  };
  assertEquals(await purgeAccount(admin, "synthetic-owner"), false);
});

Deno.test("alerts contain only operational counts and use the configured recipient", async () => {
  const config: Record<string, string> = {
    DELETION_ALERT_RESEND_KEY: "synthetic-key", DELETION_ALERT_FROM: "ops@example.test",
    DELETION_ALERT_TO: "recipient@example.test",
  };
  const send: typeof fetch = (_url, init) => {
    const body = JSON.parse(String(init?.body));
    assertEquals(body.to, ["recipient@example.test"]);
    assertEquals(body.text.includes("purge_batch_failed"), true);
    assertEquals(body.text.includes("synthetic-owner"), false);
    return Promise.resolve(new Response(null, { status: 200 }));
  };
  assertEquals(await notifyDeletionFailure("purge_batch_failed", 2, (name) => config[name], send), true);
  assertEquals(await notifyDeletionFailure("purge_batch_failed", 2, () => undefined, send), false);
  assertEquals(await notifyDeletionFailure("purge_batch_failed", 2, (name) => config[name],
    () => Promise.resolve(new Response(null, { status: 503 }))), false);
});
