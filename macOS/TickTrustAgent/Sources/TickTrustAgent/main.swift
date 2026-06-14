import AppKit
import Foundation

// ── Bootstrap ────────────────────────────────────────────────────────────────

let config   = Config.load()
let supabase = SupabaseClient(config: config)

// Overlay must live on main actor
let overlay  = CountdownOverlay()
let engine   = KillEngine(supabase: supabase, overlay: overlay, config: config)
let monitor  = AppMonitor()

monitor.delegate = engine

// ── Fetch managed apps, then start monitoring ─────────────────────────────────

Task {
    do {
        let apps = try await supabase.fetchManagedApps()
        monitor.updateManagedApps(apps)
        print("[TickTrust] Monitoring \(apps.count) managed app(s): \(apps.map(\.bundleId).joined(separator: ", "))")
    } catch {
        print("[TickTrust] WARNING: Could not fetch managed apps: \(error). Retrying in 60s.")
    }
    monitor.start()

    // Refresh managed app list every 5 minutes (parent may add/remove apps)
    while true {
        try? await Task.sleep(for: .seconds(300))
        if let apps = try? await supabase.fetchManagedApps() {
            monitor.updateManagedApps(apps)
        }
    }
}

// ── Run loop (required for NSWorkspace notifications + NSPanel) ───────────────

// Hide from Dock and app switcher — daemon runs invisibly
NSApp.setActivationPolicy(.accessory)
NSApp.run()
