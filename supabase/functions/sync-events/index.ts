import { authenticatedUser, serviceClient } from "../_shared/client.ts";
import { handleSyncRequest } from "../_shared/sync-handler.ts";

Deno.serve((request) => handleSyncRequest(request, { authenticatedUser, serviceClient }));
