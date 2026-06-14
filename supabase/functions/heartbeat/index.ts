import { createClient } from "jsr:@supabase/supabase-js@2";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("Method not allowed", { status: 405 });

  const { device_id, bundle_id, session_started_at } = await req.json();
  if (!device_id || !bundle_id || !session_started_at) {
    return Response.json({ error: "device_id, bundle_id, session_started_at required" }, { status: 400 });
  }

  // Update last_seen + get child_id
  const { data: device } = await supabase
    .from("devices")
    .update({ last_seen_at: new Date().toISOString() })
    .eq("id", device_id)
    .select("child_id")
    .single();

  if (!device) return Response.json({ action: "kill", minutes_remaining: 0 });

  // Get managed app
  const { data: app } = await supabase
    .from("managed_apps")
    .select("id, daily_minutes")
    .eq("device_id", device_id)
    .eq("bundle_id", bundle_id)
    .eq("enabled", true)
    .single();

  if (!app) return Response.json({ action: "continue", minutes_remaining: -1 });

  // Calculate session duration so far
  const sessionStart     = new Date(session_started_at);
  const now              = new Date();
  const sessionMinutes   = (now.getTime() - sessionStart.getTime()) / 60000;

  // Get today's committed usage (from previous sessions today, before this one started)
  const today = now.toISOString().split("T")[0];
  const { data: account } = await supabase
    .from("time_accounts")
    .select("id, used_minutes, bonus_minutes, debt_minutes")
    .eq("child_id", device.child_id)
    .eq("managed_app_id", app.id)
    .eq("date", today)
    .single();

  const committed = account?.used_minutes  ?? 0;
  const bonus     = account?.bonus_minutes ?? 0;
  const debt      = account?.debt_minutes  ?? 0;

  // Total used = previous committed + current live session
  const totalUsed        = committed + sessionMinutes;
  const effectiveLimit   = Math.max(0, app.daily_minutes + bonus - debt);
  const minutesRemaining = Math.max(0, effectiveLimit - totalUsed);
  const secondsRemaining = minutesRemaining * 60;

  // Determine action
  let action: string;
  if (minutesRemaining <= 0)      action = "kill";
  else if (secondsRemaining <= 10) action = "warn_10s";
  else if (secondsRemaining <= 60) action = "warn_1min";
  else if (secondsRemaining <= 120) action = "warn_2min";
  else                              action = "continue";

  // Upsert time account with live session minutes
  const newUsed = Math.round(totalUsed * 10) / 10;  // round to 1dp
  if (account) {
    await supabase
      .from("time_accounts")
      .update({ used_minutes: newUsed })
      .eq("id", account.id);
  } else {
    await supabase.from("time_accounts").insert({
      child_id:       device.child_id,
      managed_app_id: app.id,
      date:           today,
      used_minutes:   newUsed,
    });
  }

  return Response.json({ action, minutes_remaining: Math.round(minutesRemaining) });
});
