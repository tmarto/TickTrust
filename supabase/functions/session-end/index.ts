import { createClient } from "jsr:@supabase/supabase-js@2";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("Method not allowed", { status: 405 });

  const { device_id, bundle_id, session_started_at, ended_at, duration_minutes } = await req.json();
  if (!device_id || !bundle_id || !session_started_at) {
    return Response.json({ error: "device_id, bundle_id, session_started_at required" }, { status: 400 });
  }

  const { data: device } = await supabase
    .from("devices")
    .select("child_id")
    .eq("id", device_id)
    .single();

  if (!device) return Response.json({ error: "device not found" }, { status: 404 });

  const { data: app } = await supabase
    .from("managed_apps")
    .select("id, daily_minutes")
    .eq("device_id", device_id)
    .eq("bundle_id", bundle_id)
    .single();

  if (!app) return new Response(null, { status: 204 });

  const startedAt  = new Date(session_started_at);
  const endedAt    = ended_at ? new Date(ended_at) : new Date();
  const durMinutes = duration_minutes
    ? Number(duration_minutes)
    : Math.round((endedAt.getTime() - startedAt.getTime()) / 60000);

  // Write time_entries row
  await supabase.from("time_entries").insert({
    device_id,
    managed_app_id:  app.id,
    started_at:      startedAt.toISOString(),
    ended_at:        endedAt.toISOString(),
    duration_minutes: durMinutes,
  });

  // Commit final used_minutes to time_accounts
  const today = endedAt.toISOString().split("T")[0];
  const { data: account } = await supabase
    .from("time_accounts")
    .select("id, used_minutes")
    .eq("child_id", device.child_id)
    .eq("managed_app_id", app.id)
    .eq("date", today)
    .single();

  if (account) {
    await supabase
      .from("time_accounts")
      .update({ used_minutes: account.used_minutes })  // already written by heartbeat
      .eq("id", account.id);
  } else {
    await supabase.from("time_accounts").insert({
      child_id:        device.child_id,
      managed_app_id:  app.id,
      date:            today,
      used_minutes:    durMinutes,
    });
  }

  return new Response(null, { status: 204 });
});
