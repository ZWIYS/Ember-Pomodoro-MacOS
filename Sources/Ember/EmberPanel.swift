import AppKit
import SwiftUI

/// Borderless floating window used instead of NSPopover, so the corners can be as round as we like.
final class EmberPanel: NSPanel {
    static let cornerRadius: CGFloat = 30

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    /// Escape closes the panel.
    override func cancelOperation(_ sender: Any?) {
        orderOut(nil)
    }

    @MainActor
    static func make<Content: View>(size: CGSize, content: Content) -> EmberPanel {
        let panel = EmberPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .popUpMenu
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let blur = NSVisualEffectView(frame: NSRect(origin: .zero, size: size))
        blur.material = .popover
        blur.blendingMode = .behindWindow
        blur.state = .active
        blur.wantsLayer = true
        blur.layer?.cornerRadius = cornerRadius
        blur.layer?.cornerCurve = .continuous
        blur.layer?.masksToBounds = true

        let host = NSHostingView(rootView: content)
        host.frame = blur.bounds
        host.autoresizingMask = [.width, .height]
        blur.addSubview(host)

        panel.contentView = blur
        return panel
    }
}
