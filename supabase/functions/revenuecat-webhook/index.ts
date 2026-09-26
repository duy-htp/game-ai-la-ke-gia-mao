import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const json = (status: number, body: Record<string, unknown>) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });

Deno.serve(async (request) => {
  if (request.method !== "POST") return json(405, { error: "method_not_allowed" });
  const expected = Deno.env.get("REVENUECAT_WEBHOOK_AUTH");
  const supplied = request.headers.get("authorization");
  if (!expected || supplied !== `Bearer ${expected}`) {
    return json(401, { error: "unauthorized" });
  }
  try {
    const payload = await request.json();
    const event = payload?.event;
    const eventId = event?.id;
    const playerId = event?.app_user_id;
    const transactionId = event?.original_transaction_id;
    const occurredAtMs = event?.event_timestamp_ms;
    const entitlementIds: string[] = event?.entitlement_ids ?? [];
    if (
      typeof eventId !== "string" ||
      typeof playerId !== "string" ||
      typeof transactionId !== "string" ||
      typeof occurredAtMs !== "number"
    ) {
      return json(400, { error: "invalid_event" });
    }
    const active = entitlementIds.includes("remove_ads");
    const client = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      { auth: { persistSession: false } },
    );
    const { error } = await client.rpc("process_verified_entitlement_event", {
      p_player_id: playerId,
      p_provider: "revenuecat",
      p_provider_event_id: eventId,
      p_source_transaction_id: transactionId,
      p_active: active,
      p_provider_occurred_at: new Date(occurredAtMs).toISOString(),
    });
    if (error) return json(400, { error: "event_rejected" });
    return json(200, { accepted: true });
  } catch (_) {
    return json(400, { error: "invalid_json" });
  }
});
