import { assertEquals } from "@std/assert";
import { handleSyncRequest, SyncHandlerDependencies } from "../_shared/sync-handler.ts";

const owner = "10000000-0000-4000-8000-000000000001";
const first = "20000000-0000-4000-8000-000000000001";
const second = "20000000-0000-4000-8000-000000000002";
function event(id: string) {
  return { eventId: id, type: "log.delete", entityId: id, schemaVersion: 1,
    createdAt: "2026-10-12T00:00:00Z", payload: btoa(JSON.stringify({ id })) };
}
function request() {
  return new Request("http://localhost/sync-events", { method: "POST", headers: { Authorization: "Bearer synthetic" },
    body: JSON.stringify({ deviceId: owner, clientTime: "2026-10-12T00:00:00Z", events: [event(first), event(second)] }) });
}

for (const failure of ["is_sync_enabled", "consume_sync_quota_v1", "apply_sync_event_v1"]) {
  Deno.test(`temporary ${failure} failure recovers with the original event IDs`, async () => {
    let failing = true;
    const calls: { name: string; args?: Record<string, unknown> }[] = [];
    const rpc = {
      rpc(name: string, args?: Record<string, unknown>) {
        calls.push({ name, args });
        if (failing && name === failure && (name !== "apply_sync_event_v1" || args?.p_event_id === second)) {
          return Promise.resolve({ data: null, error: { code: "TEST_TRANSIENT" } });
        }
        return Promise.resolve({ data: name === "apply_sync_event_v1" ? { status: "acked" } : true, error: null });
      },
    };
    const dependencies: SyncHandlerDependencies = {
      authenticatedUser: () => Promise.resolve({ user: { id: owner }, client: rpc }), serviceClient: () => rpc,
    };
    const failed = await handleSyncRequest(request(), dependencies);
    const body = await failed.json();
    if (failure === "apply_sync_event_v1") {
      assertEquals(failed.status, 201);
      assertEquals(body.ackedEventIds, [first]);
      assertEquals(body.rejected, [{ eventId: second, code: "SERVER_ERROR", message: "Midlertidig serverfeil" }]);
      assertEquals(calls.filter((call) => call.name === failure).map((call) => call.args?.p_event_id), [first, second]);
    } else {
      assertEquals(failed.status, 500);
      assertEquals(body.code, "SERVER_ERROR");
      assertEquals(calls.some((call) => call.name === "apply_sync_event_v1"), false);
      if (failure === "is_sync_enabled") assertEquals(calls.length, 1);
      else assertEquals(calls.find((call) => call.name === failure)?.args, { p_owner_id: owner });
    }
    failing = false;
    const recovered = await handleSyncRequest(request(), dependencies);
    assertEquals(recovered.status, 201);
    const replay = await recovered.json();
    assertEquals(replay.ackedEventIds, [first, second]);
    assertEquals(replay.rejected, []);
    assertEquals(calls.filter((call) => call.name === "apply_sync_event_v1").slice(-2).map((call) => call.args?.p_event_id), [first, second]);
  });
}
