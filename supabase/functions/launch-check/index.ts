import { createClient } from "jsr:@supabase/supabase-js@2";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("Method not allowed", { status: 405 });

  const { device_id, bundle_id } = await req.json();
  if (!device_id || !bundle_id) {
    return Response.json({ error: "device_id and bundle_id required" }, { status: 400 });
  }

  // Update device last_seen + get child_id
  const { data: device } = await supabase
    .from("devices")
    .update({ last_seen_at: new Date().toISOString() })
    .eq("id", device_id)
    .select("child_id")
    .single();

  if (!device) {
    return Response.json({ allowed: false, reason: "device_not_found", minutes_remaining: 0 });
  }

  // Check if app is managed + enabled
  const { data: app } = await supabase
    .from("managed_apps")
    .select("id, daily_minutes")
    .eq("device_id", device_id)
    .eq("bundle_id", bundle_id)
    .eq("enabled", true)
    .single();

  if (!app) {
    // Not managed — allow silently, no log
    return Response.json({ allowed: true, reason: "unmanaged", minutes_remaining: -1 });
  }

  // Get today's time account
  const today = new Date().toISOString().split("T")[0];
  const { data: account } = await supabase
    .from("time_accounts")
    .select("used_minutes, bonus_minutes, debt_minutes")
    .eq("child_id", device.child_id)
    .eq("managed_app_id", app.id)
    .eq("date", today)
    .single();

  const used  = account?.used_minutes  ?? 0;
  const bonus = account?.bonus_minutes ?? 0;
  const debt  = account?.debt_minutes  ?? 0;
  const effectiveLimit   = Math.max(0, app.daily_minutes + bonus - debt);
  const minutesRemaining = Math.max(0, effectiveLimit - used);
  const allowed          = minutesRemaining > 0;
  const result           = allowed ? "allowed" : "blocked";

  // Audit log
  await supabase.from("launch_checks").insert({
    device_id,
    managed_app_id: app.id,
    result,
    minutes_remaining: minutesRemaining,
  });

  return Response.json({ allowed, reason: result, minutes_remaining: minutesRemaining });
});
