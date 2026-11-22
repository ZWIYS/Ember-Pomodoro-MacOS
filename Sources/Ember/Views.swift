import SwiftUI
import AppKit

// MARK: - Root

struct RootView: View {
    static let size = CGSize(width: 300, height: 410)

    @ObservedObject var model: TimerModel
    var onQuit: () -> Void

    var body: some View {
        let p = Palette(dark: model.theme == .dark)

        VStack(spacing: 0) {
            HeaderView(model: model, p: p, onQuit: onQuit)
                .padding(.bottom, 12)

            if model.state == .idle {
                SetupView(model: model, p: p)
                    .transition(.opacity)
            } else {
                RunningView(model: model, p: p)
                    .transition(.opacity)
            }
        }
        .padding(16)
        .frame(width: Self.size.width, height: Self.size.height)
        .background(p.tint)
        .environment(\.colorScheme, model.theme.colorScheme)
        .animation(.easeInOut(duration: 0.2), value: model.state == .idle)
    }
}

struct HeaderView: View {
    @ObservedObject var model: TimerModel
    let p: Palette
    var onQuit: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(Brand.orange).frame(width: 8, height: 8)
            Text("Ember")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(p.text)
            Spacer()
            IconButton(systemName: model.theme == .dark ? "sun.max" : "moon", p: p) {
                model.theme = model.theme.toggled
            }
            .help("Switch theme")
            IconButton(systemName: "power", p: p, action: onQuit)
                .help("Quit Ember")
        }
        .frame(height: 26)
    }
}

struct IconButton: View {
    let systemName: String
    let p: Palette
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(hovering ? p.text : p.secondary)
                .frame(width: 26, height: 26)
                .background(Circle().fill(hovering ? p.card : Color.clear))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

// MARK: - Setup

struct SetupView: View {
    @ObservedObject var model: TimerModel
    let p: Palette

    var body: some View {
        VStack(spacing: 10) {
            BigTile(label: "SESSION", unit: "min", value: $model.sessionMinutes,
                    range: TimerModel.sessionRange, p: p)
            BigTile(label: "BREAK", unit: "min", value: $model.breakMinutes,
                    range: TimerModel.breakRange, p: p)

            HStack(spacing: 10) {
                CompactTile(label: "CYCLE", unit: "short breaks", prefix: nil,
                            value: $model.cycleLength, range: TimerModel.cycleRange, p: p)
                CompactTile(label: "LONG BREAK", unit: "min longer", prefix: "+",
                            value: $model.longBreakExtra, range: TimerModel.extraRange, p: p)
            }

            Text("Long break \(model.longBreakMinutes) min \u{00B7} \(model.sessionsPerCycle) \(model.sessionsPerCycle == 1 ? "session" : "sessions") per cycle")
                .font(.system(size: 11))
                .foregroundColor(p.secondary)
                .padding(.top, 2)

            Spacer(minLength: 0)

            Button("Start") { model.start() }
                .buttonStyle(PillButtonStyle(fill: Brand.orange, foreground: p.onAccent, height: 44, size: 15))
        }
    }
}

struct BigTile: View {
    let label: String
    let unit: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let p: Palette

    var body: some View {
        HStack(spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.2)
                    .foregroundColor(p.secondary)
                Text(unit)
                    .font(.system(size: 11))
                    .foregroundColor(p.secondary.opacity(0.8))
            }
            Spacer()
            StepButton(systemName: "chevron.down", p: p) { value = clamp(value - 1) }
            NumberField(value: $value, range: range, size: 40, p: p)
                .frame(width: 72)
            StepButton(systemName: "chevron.up", p: p) { value = clamp(value + 1) }
        }
        .padding(.horizontal, 14)
        .frame(height: 66)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(p.card))
        .overlay(ScrollCatcher { value = clamp(value + $0) })
    }

    private func clamp(_ v: Int) -> Int { min(max(v, range.lowerBound), range.upperBound) }
}

struct CompactTile: View {
    let label: String
    let unit: String
    let prefix: String?
    @Binding var value: Int
    let range: ClosedRange<Int>
    let p: Palette

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.0)
                .foregroundColor(p.secondary)

            HStack(spacing: 2) {
                StepButton(systemName: "chevron.down", p: p) { value = clamp(value - 1) }
                HStack(spacing: 1) {
                    if let prefix {
                        Text(prefix)
                            .font(.system(size: 22, weight: .semibold, design: .rounded))
                            .foregroundColor(Brand.orange)
                    }
                    NumberField(value: $value, range: range, size: 26, p: p)
                        .frame(width: prefix == nil ? 44 : 34)
                }
                StepButton(systemName: "chevron.up", p: p) { value = clamp(value + 1) }
            }

            Text(unit)
                .font(.system(size: 10))
                .foregroundColor(p.secondary.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 86)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(p.card))
        .overlay(ScrollCatcher { value = clamp(value + $0) })
    }

    private func clamp(_ v: Int) -> Int { min(max(v, range.lowerBound), range.upperBound) }
}

struct NumberField: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    let size: CGFloat
    let p: Palette

    var body: some View {
        TextField("", value: $value, format: .number)
            .textFieldStyle(.plain)
            .multilineTextAlignment(.center)
            .font(.system(size: size, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .foregroundColor(p.text)
    }
}

struct StepButton: View {
    let systemName: String
    let p: Palette
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(hovering ? Brand.orange : p.secondary)
                .frame(width: 22, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

// MARK: - Running

struct RunningView: View {
    @ObservedObject var model: TimerModel
    let p: Palette

    private var color: Color { model.phase.color }
    private var paused: Bool { model.state == .paused }

    private var phaseLabel: String {
        if paused { return "PAUSED" }
        switch model.phase {
        case .work: return "FOCUS"
        case .shortBreak: return "BREAK"
        case .longBreak: return "LONG BREAK"
        }
    }

    var body: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 0)

            ZStack {
                Circle().stroke(p.track, lineWidth: 12)
                Circle()
                    .trim(from: 0, to: model.progress)
                    .stroke(color.opacity(paused ? 0.5 : 1), style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(model.progress < 0.02 ? nil : .linear(duration: 1), value: model.progress)

                VStack(spacing: 4) {
                    Text(phaseLabel)
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(1.5)
                        .foregroundColor(color)
                    Text(timeString(model.remainingSeconds))
                        .font(.system(size: model.remainingSeconds >= 3600 ? 36 : 46, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(p.text)
                    Text("Session \(model.sessionNumber) of \(model.sessionsPerCycle)")
                        .font(.system(size: 12))
                        .foregroundColor(p.secondary)
                }
            }
            .frame(width: 200, height: 200)

            if model.phase == .work {
                Button("+\(TimerModel.extendStep) min") { model.extend() }
                    .buttonStyle(PillButtonStyle(fill: p.card, foreground: p.secondary, height: 26, size: 12, horizontalPadding: 12))
            } else {
                Color.clear.frame(height: 26)
            }

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                Button(paused ? "Resume" : "Pause") { model.togglePause() }
                    .buttonStyle(PillButtonStyle(fill: p.card, foreground: p.text, height: 40, size: 14))
                Button("Stop") { model.stop() }
                    .buttonStyle(PillButtonStyle(fill: Brand.orange, foreground: p.onAccent, height: 40, size: 14))
            }
        }
    }

    private func timeString(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%02d:%02d", m, s)
    }
}

// MARK: - Styles & helpers

struct PillButtonStyle: ButtonStyle {
    let fill: Color
    let foreground: Color
    var height: CGFloat = 40
    var size: CGFloat = 14
    var horizontalPadding: CGFloat? = nil

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: size, weight: .semibold, design: .rounded))
            .foregroundColor(foreground)
            .frame(maxWidth: horizontalPadding == nil ? .infinity : nil)
            .padding(.horizontal, horizontalPadding ?? 0)
            .frame(height: height)
            .background(Capsule().fill(fill))
            .opacity(configuration.isPressed ? 0.75 : 1)
            .contentShape(Capsule())
    }
}

/// Transparent overlay that turns mouse-wheel scrolling into +1 / -1 steps
/// without swallowing clicks meant for the controls underneath.
struct ScrollCatcher: NSViewRepresentable {
    var onStep: (Int) -> Void

    func makeNSView(context: Context) -> CatcherView {
        let v = CatcherView()
        v.onStep = onStep
        return v
    }

    func updateNSView(_ nsView: CatcherView, context: Context) {
        nsView.onStep = onStep
    }

    final class CatcherView: NSView {
        var onStep: ((Int) -> Void)?
        private var accumulated: CGFloat = 0

        override func hitTest(_ point: NSPoint) -> NSView? {
            NSApp.currentEvent?.type == .scrollWheel ? super.hitTest(point) : nil
        }

        override func scrollWheel(with event: NSEvent) {
            let threshold: CGFloat = event.hasPreciseScrollingDeltas ? 10 : 1
            accumulated += event.scrollingDeltaY
            while accumulated >= threshold { onStep?(1); accumulated -= threshold }
            while accumulated <= -threshold { onStep?(-1); accumulated += threshold }
        }
    }
}
