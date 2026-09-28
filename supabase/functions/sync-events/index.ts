import { authenticatedUser, jsonResponse, serviceClient } from "../_shared/client.ts";
import { MAX_SYNC_EVENTS, syncRequestSchema, validateEvent } from "../_shared/sync-contract.ts";

type Rejection = { eventId: string; code: string; message: string };

Deno.serve(async (request) => {
  if (request.method !== "POST") return jsonResponse({ code: "METHOD_NOT_ALLOWED" }, 405);

  const authorization = request.headers.get("Authorization");
  const authenticated = await authenticatedUser(authorization);
  if (!authenticated) return jsonResponse({ code: "UNAUTHORIZED", message: "Ugyldig eller utløpt økt" }, 401);

  const admin = serviceClient();
  const { data: syncEnabled, error: configError } = await admin.rpc("is_sync_enabled");
  if (configError) return jsonResponse({ code: "SERVER_ERROR", message: "Kunne ikke lese synkstatus" }, 500);
  if (!syncEnabled) {
    return jsonResponse(
      { code: "SYNC_DISABLED", message: "Synkronisering er midlertidig deaktivert" },
      503,
      { "Retry-After": "300" },
    );
  }

  const { data: quotaAllowed, error: quotaError } = await admin.rpc("consume_sync_quota_v1", {
    p_owner_id: authenticated.user.id,
  });
  if (quotaError) return jsonResponse({ code: "SERVER_ERROR", message: "Kunne ikke kontrollere trafikkgrensen" }, 500);
  if (!quotaAllowed) return jsonResponse({ code: "RATE_LIMITED", message: "For mange synkforsøk" }, 429, { "Retry-After": "60" });

  let json: unknown;
  try {
    json = await request.json();
  } catch {
    return jsonResponse({ code: "VALIDATION_ERROR", message: "Ugyldig JSON" }, 400);
  }
  const parsedRequest = syncRequestSchema.safeParse(json);
  if (!parsedRequest.success) return jsonResponse({ code: "VALIDATION_ERROR", message: "Ugyldig synkforespørsel" }, 400);

  if (parsedRequest.data.events.length > MAX_SYNC_EVENTS) {
    const rejected = parsedRequest.data.events.map((event) => ({
      eventId: typeof event === "object" && event !== null && "eventId" in event
        ? String((event as { eventId: unknown }).eventId)
        : "00000000-0000-0000-0000-000000000000",
      code: "VALIDATION_ERROR",
      message: `Maks ${MAX_SYNC_EVENTS} events per batch`,
    }));
    return jsonResponse({ ackedEventIds: [], rejected, serverTime: new Date().toISOString() }, 201);
  }

  const ackedEventIds: string[] = [];
  const rejected: Rejection[] = [];
  for (const rawEvent of parsedRequest.data.events) {
    const validation = validateEvent(rawEvent);
    if (!validation.success) {
      rejected.push(validation);
      continue;
    }
    const event = validation.event;
    const { data, error } = await authenticated.client.rpc("apply_sync_event_v1", {
      p_device_id: parsedRequest.data.deviceId,
      p_event_id: event.eventId,
      p_type: event.type,
      p_created_at: event.createdAt,
      p_entity_id: event.entityId ?? null,
      p_schema_version: event.schemaVersion,
      p_payload: event.payloadJson,
    });
    if (error) {
      console.error("sync event failed", { code: error.code });
      rejected.push({ eventId: event.eventId, code: "SERVER_ERROR", message: "Midlertidig serverfeil" });
    } else if (data?.status === "acked") {
      ackedEventIds.push(event.eventId);
    } else {
      rejected.push({
        eventId: event.eventId,
        code: data?.code ?? "SERVER_ERROR",
        message: data?.message ?? "Midlertidig serverfeil",
      });
    }
  }

  return jsonResponse({ ackedEventIds, rejected, serverTime: new Date().toISOString() }, 201);
});
