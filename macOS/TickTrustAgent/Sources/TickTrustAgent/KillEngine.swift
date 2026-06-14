import AppKit
import Foundation

final class KillEngine: AppMonitorDelegate {
    private let supabase: SupabaseClient
    private let overlay: CountdownOverlay
    private let config: Config

    private var session: AppSession?
    private var heartbeatTask: Task<Void, Never>?
    private let lock = NSLock()

    struct AppSession {
        let bundleId: String
        let appName: String
        let pid: pid_t
        let startedAt: Date
    }

    init(supabase: SupabaseClient, overlay: CountdownOverlay, config: Config) {
        self.supabase = supabase
        self.overlay  = overlay
        self.config   = config
    }

    // MARK: - AppMonitorDelegate

    func managedAppBecameActive(_ app: ActiveApp) {
        Task { await handleActivation(app) }
    }

    func managedAppBecameInactive(_ bundleId: String) {
        Task { await handleDeactivation(bundleId: bundleId, reason: .userClosed) }
    }

    // MARK: - Activation

    private func handleActivation(_ app: ActiveApp) async {
        cancelCurrentSession()

        do {
            let check = try await supabase.launchCheck(bundleId: app.bundleId)
            guard check.allowed else {
                log("Blocking \(app.bundleId) — \(check.reason) (\(check.minutesRemaining) min left)")
                forceKill(pid: app.pid, bundleId: app.bundleId, reason: "blocked_at_launch")
                return
            }
            log("Allowing \(app.bundleId) — \(check.minutesRemaining) min remaining")
            let s = AppSession(bundleId: app.bundleId, appName: app.name,
                               pid: app.pid, startedAt: Date())
            lock.lock(); session = s; lock.unlock()
            startHeartbeat(session: s)
        } catch {
            log("launch-check failed: \(error) — offline_mode=\(config.offlineMode)")
            if config.offlineMode == "strict" {
                forceKill(pid: app.pid, bundleId: app.bundleId, reason: "offline_blocked")
            } else {
                // Lenient: allow but schedule auto-kill after grace period
                let s = AppSession(bundleId: app.bundleId, appName: app.name,
                                   pid: app.pid, startedAt: Date())
                lock.lock(); session = s; lock.unlock()
                scheduleOfflineKill(session: s, graceMinutes: config.offlineGraceMinutes)
            }
        }
    }

    // MARK: - Deactivation

    private enum DeactivationReason { case userClosed, killed }

    private func handleDeactivation(bundleId: String, reason: DeactivationReason) async {
        lock.lock()
        let s = session
        if session?.bundleId == bundleId { session = nil }
        lock.unlock()

        heartbeatTask?.cancel()
        heartbeatTask = nil
        await MainActor.run { overlay.hide() }

        guard let s, reason == .userClosed else { return }
        try? await supabase.sessionEnd(bundleId: s.bundleId, startedAt: s.startedAt, endedAt: Date())
    }

    // MARK: - Heartbeat loop

    private func startHeartbeat(session s: AppSession) {
        heartbeatTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard !Task.isCancelled else { break }

                lock.lock()
                let current = self.session
                lock.unlock()
                guard current?.bundleId == s.bundleId else { break }

                do {
                    let resp = try await supabase.heartbeat(
                        bundleId: s.bundleId,
                        sessionStartedAt: s.startedAt
                    )
                    await applyAction(resp.action, session: s, minutesRemaining: resp.minutesRemaining)
                } catch {
                    log("Heartbeat error: \(error) — continuing session")
                }
            }
        }
    }

    private func applyAction(_ action: String, session s: AppSession, minutesRemaining: Int) async {
        switch action {
        case "continue":
            break

        case "warn_2min":
            await MainActor.run {
                overlay.showWarning(appName: s.appName, secondsRemaining: 120)
            }

        case "warn_1min":
            await MainActor.run {
                overlay.showWarning(appName: s.appName, secondsRemaining: 60)
            }

        case "warn_10s":
            await MainActor.run {
                overlay.showCountdown(appName: s.appName, from: 10) { [weak self] in
                    self?.executeKill(session: s, reason: "limit")
                }
            }

        case "kill":
            executeKill(session: s, reason: "limit")

        default:
            log("Unknown action: \(action)")
        }
    }

    // MARK: - Kill

    private func executeKill(session s: AppSession, reason: String) {
        log("KILL \(s.appName) pid=\(s.pid) reason=\(reason)")
        heartbeatTask?.cancel()
        lock.lock(); session = nil; lock.unlock()
        Task { await MainActor.run { overlay.hide() } }
        forceKill(pid: s.pid, bundleId: s.bundleId, reason: reason)
        Task { try? await supabase.sessionEnd(bundleId: s.bundleId, startedAt: s.startedAt, endedAt: Date()) }
        Task { try? await supabase.killConfirm(bundleId: s.bundleId, killEventId: "") }
    }

    private func forceKill(pid: pid_t, bundleId: String, reason: String) {
        // Try graceful first, then SIGKILL
        if let app = NSRunningApplication(processIdentifier: pid) {
            app.forceTerminate()
        }
        Darwin.kill(pid, SIGKILL)
    }

    private func scheduleOfflineKill(session s: AppSession, graceMinutes: Int) {
        Task {
            log("Offline lenient — grace period \(graceMinutes)m for \(s.appName)")
            try? await Task.sleep(for: .seconds(graceMinutes * 60))
            guard !Task.isCancelled else { return }
            lock.lock()
            let stillActive = session?.bundleId == s.bundleId
            lock.unlock()
            if stillActive { executeKill(session: s, reason: "offline_grace_expired") }
        }
    }

    private func cancelCurrentSession() {
        heartbeatTask?.cancel()
        heartbeatTask = nil
        lock.lock()
        let s = session
        session = nil
        lock.unlock()
        Task { await MainActor.run { overlay.hide() } }
        if let s {
            Task { try? await supabase.sessionEnd(bundleId: s.bundleId, startedAt: s.startedAt, endedAt: Date()) }
        }
    }

    private func log(_ msg: String) {
        let ts = ISO8601DateFormatter().string(from: Date())
        print("[\(ts)] TickTrust: \(msg)")
    }
}
