import Foundation
import AppKit

enum Phase {
    case work, shortBreak, longBreak

    var isBreak: Bool { self != .work }
}

enum RunState {
    case idle, running, paused
}

private extension Int {
    func clamped(_ range: ClosedRange<Int>) -> Int { Swift.min(Swift.max(self, range.lowerBound), range.upperBound) }
}

@MainActor
final class TimerModel: ObservableObject {
    // MARK: Settings (persisted)

    nonisolated static let sessionRange = 1...180
    nonisolated static let breakRange = 1...60
    nonisolated static let cycleRange = 0...12
    nonisolated static let extraRange = 0...60
    nonisolated static let extendStep = 5
    nonisolated static let maxPhaseSeconds = sessionRange.upperBound * 60

    private let defaults = UserDefaults.standard

    @Published var sessionMinutes: Int {
        didSet {
            let v = sessionMinutes.clamped(Self.sessionRange)
            if v != sessionMinutes { sessionMinutes = v }
            defaults.set(v, forKey: "sessionMinutes")
        }
    }
    @Published var breakMinutes: Int {
        didSet {
            let v = breakMinutes.clamped(Self.breakRange)
            if v != breakMinutes { breakMinutes = v }
            defaults.set(v, forKey: "breakMinutes")
        }
    }
    /// Number of short breaks before a long one.
    @Published var cycleLength: Int {
        didSet {
            let v = cycleLength.clamped(Self.cycleRange)
            if v != cycleLength { cycleLength = v }
            defaults.set(v, forKey: "cycleLength")
        }
    }
    /// Minutes added to the short break to get the long break.
    @Published var longBreakExtra: Int {
        didSet {
            let v = longBreakExtra.clamped(Self.extraRange)
            if v != longBreakExtra { longBreakExtra = v }
            defaults.set(v, forKey: "longBreakExtra")
        }
    }
    /// Start a new cycle automatically after the long break (otherwise stop).
    @Published var repeatCycles: Bool {
        didSet { defaults.set(repeatCycles, forKey: "repeatCycles") }
    }
    @Published var theme: ThemeChoice {
        didSet { defaults.set(theme.rawValue, forKey: "theme") }
    }

    // MARK: Runtime state

    @Published private(set) var state: RunState = .idle
    @Published private(set) var phase: Phase = .work
    @Published private(set) var remainingSeconds: Int = 0
    @Published private(set) var totalSeconds: Int = 1
    @Published private(set) var shortBreaksDone = 0
    @Published private(set) var flashUntil: Date?

    private var endDate: Date?
    private var pausedRemaining: TimeInterval = 0
    private var ticker: Timer?

    init() {
        let d = UserDefaults.standard
        func stored(_ key: String, _ fallback: Int, _ range: ClosedRange<Int>) -> Int {
            (d.object(forKey: key) as? Int ?? fallback).clamped(range)
        }
        sessionMinutes = stored("sessionMinutes", 25, Self.sessionRange)
        breakMinutes = stored("breakMinutes", 5, Self.breakRange)
        cycleLength = stored("cycleLength", 3, Self.cycleRange)
        longBreakExtra = stored("longBreakExtra", 10, Self.extraRange)
        repeatCycles = d.object(forKey: "repeatCycles") as? Bool ?? true
        if let raw = d.string(forKey: "theme"), let t = ThemeChoice(rawValue: raw) {
            theme = t
        } else {
            let isDark = NSApp?.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            theme = isDark ? .dark : .light
        }
    }

    // MARK: Derived

    var longBreakMinutes: Int { breakMinutes + longBreakExtra }
    var sessionsPerCycle: Int { cycleLength + 1 }

    var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return 1 - Double(remainingSeconds) / Double(totalSeconds)
    }

    /// Which session of the cycle the user is in (or just finished, during a break).
    var sessionNumber: Int {
        switch phase {
        case .work: return shortBreaksDone + 1
        case .shortBreak: return shortBreaksDone
        case .longBreak: return sessionsPerCycle
        }
    }

    var canExtend: Bool { totalSeconds < Self.maxPhaseSeconds }

    var isFlashing: Bool {
        guard let until = flashUntil else { return false }
        return until > Date()
    }

    // MARK: Actions

    func start() {
        shortBreaksDone = 0
        begin(.work)
    }

    func stop() {
        ticker?.invalidate()
        ticker = nil
        endDate = nil
        flashUntil = nil
        state = .idle
        phase = .work
        shortBreaksDone = 0
    }

    func pause() {
        guard state == .running, let end = endDate else { return }
        pausedRemaining = max(0, end.timeIntervalSinceNow)
        ticker?.invalidate()
        ticker = nil
        endDate = nil
        state = .paused
    }

    func resume() {
        guard state == .paused else { return }
        endDate = Date().addingTimeInterval(pausedRemaining)
        state = .running
        startTicker()
    }

    func togglePause() {
        state == .running ? pause() : resume()
    }

    /// Extends the current phase without stopping it.
    func extend(minutes: Int = TimerModel.extendStep) {
        // A phase can never be stretched beyond the maximum session length (3 hours).
        let delta = min(minutes * 60, max(0, Self.maxPhaseSeconds - totalSeconds))
        guard delta > 0 else { return }
        totalSeconds += delta
        remainingSeconds += delta
        if state == .running, let end = endDate {
            endDate = end.addingTimeInterval(TimeInterval(delta))
        } else if state == .paused {
            pausedRemaining += TimeInterval(delta)
        }
    }

    // MARK: Internals

    private func duration(of phase: Phase) -> Int {
        switch phase {
        case .work: return sessionMinutes * 60
        case .shortBreak: return breakMinutes * 60
        case .longBreak: return longBreakMinutes * 60
        }
    }

    private func begin(_ next: Phase) {
        phase = next
        totalSeconds = duration(of: next)
        remainingSeconds = totalSeconds
        endDate = Date().addingTimeInterval(TimeInterval(totalSeconds))
        state = .running
        startTicker()
    }

    private func startTicker() {
        ticker?.invalidate()
        let t = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        ticker = t
    }

    private func tick() {
        guard state == .running, let end = endDate else { return }
        let left = end.timeIntervalSinceNow
        if left <= 0 {
            finishPhase()
            return
        }
        let secs = Int(left.rounded(.up))
        if secs != remainingSeconds { remainingSeconds = secs }
    }

    private func finishPhase() {
        Beeper.play()
        flashUntil = Date().addingTimeInterval(5)

        switch phase {
        case .work:
            if shortBreaksDone < cycleLength {
                shortBreaksDone += 1
                begin(.shortBreak)
            } else {
                begin(.longBreak)
            }
        case .shortBreak:
            begin(.work)
        case .longBreak:
            if repeatCycles {
                shortBreaksDone = 0
                begin(.work)
            } else {
                stop()
            }
        }
    }
}
