import { createClient } from "jsr:@supabase/supabase-js@2";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("Method not allowed", { status: 405 });

  const { device_id, bundle_id, kill_event_id } = await req.json();
  if (!device_id || !bundle_id) {
    return Response.json({ error: "device_id and bundle_id required" }, { status: 400 });
  }

  const now = new Date().toISOString();

  if (kill_event_id) {
    // Confirm specific kill event
    await supabase
      .from("kill_events")
      .update({ confirmed_at: now })
      .eq("id", kill_event_id);
  } else {
    // Insert new kill event (agent-initiated kill, no prior event record)
    const { data: app } = await supabase
      .from("managed_apps")
      .select("id")
      .eq("device_id", device_id)
      .eq("bundle_id", bundle_id)
      .single();

    if (app) {
      await supabase.from("kill_events").insert({
        device_id,
        managed_app_id: app.id,
        killed_at:      now,
        confirmed_at:   now,
        reason:         "limit",
      });
    }
  }

  return new Response(null, { status: 204 });
});
