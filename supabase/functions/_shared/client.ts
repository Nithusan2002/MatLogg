import { createClient, SupabaseClient, User } from "npm:@supabase/supabase-js@2";

function requiredEnvironment(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`Missing ${name}`);
  return value;
}

export function serviceClient(): SupabaseClient {
  return createClient(
    requiredEnvironment("SUPABASE_URL"),
    requiredEnvironment("SUPABASE_SERVICE_ROLE_KEY"),
    { auth: { persistSession: false, autoRefreshToken: false } },
  );
}

export function userClient(authorization: string): SupabaseClient {
  const publishableKey = Deno.env.get("SUPABASE_PUBLISHABLE_KEY") ??
    requiredEnvironment("SUPABASE_ANON_KEY");
  return createClient(requiredEnvironment("SUPABASE_URL"), publishableKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

export async function authenticatedUser(
  authorization: string | null,
): Promise<{ client: SupabaseClient; user: User } | null> {
  if (!authorization?.startsWith("Bearer ")) return null;
  const client = userClient(authorization);
  const token = authorization.slice("Bearer ".length);
  const { data, error } = await client.auth.getUser(token);
  if (error || !data.user) return null;
  return { client, user: data.user };
}

export function jsonResponse(body: unknown, status = 200, headers?: HeadersInit): Response {
  return Response.json(body, {
    status,
    headers: { "Cache-Control": "no-store", ...headers },
  });
}
