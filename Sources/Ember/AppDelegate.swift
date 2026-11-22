import AppKit
import SwiftUI
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = TimerModel()
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var cancellables = Set<AnyCancellable>()
    private var blinkTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(handleClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: RootView.size.width, height: RootView.size.height)
        popover.contentViewController = NSHostingController(
            rootView: RootView(model: model, onQuit: { NSApp.terminate(nil) })
        )
        popover.appearance = model.theme.appearance

        model.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshTitle() }
            .store(in: &cancellables)

        model.$theme
            .receive(on: DispatchQueue.main)
            .sink { [weak self] theme in self?.popover.appearance = theme.appearance }
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
            togglePopover()
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
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
            title.append(dot(.tertiaryLabelColor))
            title.append(NSAttributedString(string: "Ember", attributes: [
                .font: NSFont.systemFont(ofSize: 13, weight: .medium),
                .foregroundColor: NSColor.labelColor,
            ]))

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
