import AppKit

// Must be called on MainActor — floats above all windows including full-screen games
@MainActor
final class CountdownOverlay {
    private var panel: NSPanel?
    private var countLabel: NSTextField?
    private var timer: Timer?

    func showWarning(appName: String, secondsRemaining: Int) {
        let msg = "\(appName) closes in"
        present(message: msg, seconds: secondsRemaining, countdown: false, onExpire: nil)
    }

    func showCountdown(appName: String, from seconds: Int, onExpire: @escaping () -> Void) {
        let msg = "\(appName) is closing"
        present(message: msg, seconds: seconds, countdown: true, onExpire: onExpire)
    }

    func hide() {
        timer?.invalidate()
        timer = nil
        panel?.orderOut(nil)
        panel = nil
        countLabel = nil
    }

    // MARK: - Private

    private func present(message: String, seconds: Int, countdown: Bool, onExpire: (() -> Void)?) {
        timer?.invalidate()
        panel?.close()

        let size = NSRect(x: 0, y: 0, width: 420, height: 180)
        let p = NSPanel(
            contentRect: size,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        // Level above screen saver so it beats full-screen games
        p.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)) + 1)
        p.backgroundColor = NSColor(red: 0.08, green: 0.08, blue: 0.08, alpha: 0.93)
        p.isOpaque = false
        p.hasShadow = true
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        p.ignoresMouseEvents = true   // kids can't click it away

        let root = NSView(frame: size)

        let msgField = NSTextField(labelWithString: message)
        msgField.font = .systemFont(ofSize: 20, weight: .semibold)
        msgField.textColor = .white
        msgField.alignment = .center
        msgField.frame = NSRect(x: 20, y: 110, width: 380, height: 30)
        root.addSubview(msgField)

        let num = NSTextField(labelWithString: formatTime(seconds))
        num.font = .monospacedDigitSystemFont(ofSize: 56, weight: .bold)
        num.textColor = seconds <= 60 ? .systemRed : .systemOrange
        num.alignment = .center
        num.frame = NSRect(x: 20, y: 24, width: 380, height: 72)
        root.addSubview(num)

        p.contentView = root
        centreOnScreen(p)
        p.orderFrontRegardless()

        panel = p
        countLabel = num

        if countdown {
            var remaining = seconds
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] t in
                remaining -= 1
                DispatchQueue.main.async {
                    guard let self else { t.invalidate(); return }
                    self.countLabel?.stringValue = self.formatTime(remaining)
                    self.countLabel?.textColor = remaining <= 5 ? .systemRed : .systemOrange
                    if remaining <= 0 {
                        t.invalidate()
                        self.hide()
                        onExpire?()
                    }
                }
            }
            RunLoop.main.add(timer!, forMode: .common)
        }
    }

    private func formatTime(_ seconds: Int) -> String {
        if seconds >= 60 {
            let m = seconds / 60
            let s = seconds % 60
            return s == 0 ? "\(m)m" : "\(m)m \(s)s"
        }
        return "\(seconds)s"
    }

    private func centreOnScreen(_ panel: NSPanel) {
        guard let screen = NSScreen.main else { return }
        let x = screen.frame.midX - panel.frame.width / 2
        let y = screen.frame.midY - panel.frame.height / 2 + 60
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
