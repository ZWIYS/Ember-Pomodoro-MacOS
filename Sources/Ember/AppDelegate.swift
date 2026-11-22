import AppKit
import SwiftUI
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = TimerModel()
    private var statusItem: NSStatusItem!
    private var panel: EmberPanel!
    private var outsideClickMonitor: Any?
    private var cancellables = Set<AnyCancellable>()
    private var blinkTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(handleClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        panel = EmberPanel.make(
            size: RootView.size,
            content: RootView(model: model, onQuit: { NSApp.terminate(nil) })
        )
        panel.appearance = model.theme.appearance

        // Close when the user clicks anywhere outside, or switches to another app.
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.hidePanel() }
        }
        NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.hidePanel() }
        }

        model.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshTitle() }
            .store(in: &cancellables)

        model.$theme
            .receive(on: DispatchQueue.main)
            .sink { [weak self] theme in self?.panel.appearance = theme.appearance }
            .store(in: &cancellables)

        // Drives the tray blink at the end of a phase.
        blinkTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.model.isFlashing else { return }
                self.refreshTitle()
            }
        }

        refreshTitle()
    }

    // MARK: Status item

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            let menu = NSMenu()
            let quit = NSMenuItem(title: "Quit Ember", action: #selector(quit), keyEquivalent: "q")
            quit.target = self
            menu.addItem(quit)
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else {
            togglePanel()
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func togglePanel() {
        panel.isVisible ? hidePanel() : showPanel()
    }

    private func showPanel() {
        guard let buttonWindow = statusItem.button?.window else { return }
        let size = RootView.size
        let anchor = buttonWindow.frame

        var x = anchor.midX - size.width / 2
        if let visible = buttonWindow.screen?.visibleFrame {
            x = min(max(x, visible.minX + 8), visible.maxX - size.width - 8)
        }
        panel.setFrame(NSRect(x: x, y: anchor.minY - size.height - 6, width: size.width, height: size.height), display: true)

        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.12
            panel.animator().alphaValue = 1
        } completionHandler: { [weak self] in
            MainActor.assumeIsolated { self?.panel.invalidateShadow() }
        }
        panel.invalidateShadow()
    }

    private func hidePanel() {
        guard panel.isVisible else { return }
        panel.orderOut(nil)
    }

    private func refreshTitle() {
        guard let button = statusItem.button else { return }

        let font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: model.isFlashing ? .bold : .medium)
        let dotFont = NSFont.systemFont(ofSize: 9)
        let title = NSMutableAttributedString()

        func dot(_ color: NSColor) -> NSAttributedString {
            NSAttributedString(string: "\u{25CF} ", attributes: [
                .font: dotFont, .foregroundColor: color, .baselineOffset: 1.5,
            ])
        }

        switch model.state {
        case .idle:
            // Idle: just a timer icon, no text.
            break

        case .running, .paused:
            let paused = model.state == .paused
            let phaseColor = model.phase.nsColor
            title.append(dot(paused ? .tertiaryLabelColor : phaseColor))

            var digitColor: NSColor = paused ? .secondaryLabelColor : .labelColor
            if model.isFlashing {
                let on = Int(Date().timeIntervalSince1970 * 2) % 2 == 0
                digitColor = on ? phaseColor : .labelColor
            }
            title.append(NSAttributedString(string: format(model.remainingSeconds), attributes: [
                .font: font, .foregroundColor: digitColor,
            ]))
        }

        if model.state == .idle {
            let image = NSImage(systemSymbolName: "timer", accessibilityDescription: "Ember")
            image?.isTemplate = true
            button.image = image
        } else {
            button.image = nil
        }
        button.attributedTitle = title
    }

    private func format(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%02d:%02d", m, s)
    }
}
