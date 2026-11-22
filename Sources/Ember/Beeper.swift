import AppKit
import AVFoundation

/// Plays the alert at the end of a phase: the system "Hillside" tone twice with a short pause.
/// The file is read from macOS at runtime (not bundled); if it is missing, a soft
/// triple beep synthesized in code is used instead.
@MainActor
enum Beeper {
    private static let hillside = URL(fileURLWithPath:
        "/System/Library/PrivateFrameworks/ToneLibrary.framework/Versions/A/Resources/Ringtones/Hillside.m4r")

    /// The audible part of Hillside is ~0.7 s, followed by silence in the file.
    private static let audibleLength = 0.7
    /// Pause between the two plays.
    private static let gap = 0.5

    private static var players: [AVAudioPlayer] = []
    private static var sound: NSSound?

    static func play() {
        players.forEach { $0.stop() }
        players = []
        sound?.stop()

        guard let first = try? AVAudioPlayer(contentsOf: hillside),
              let second = try? AVAudioPlayer(contentsOf: hillside) else {
            playFallbackBeeps()
            return
        }
        for p in [first, second] {
            p.volume = 0.8
            p.prepareToPlay()
        }
        // Schedule both on the same clock so the gap is exact.
        let start = first.deviceCurrentTime + 0.05
        first.play(atTime: start)
        second.play(atTime: start + audibleLength + gap)
        players = [first, second]
    }

    private static func playFallbackBeeps() {
        guard let data = makeWAV() else { return }
        sound = NSSound(data: data)
        sound?.play()
    }

    private static func makeWAV() -> Data? {
        let sampleRate = 44_100.0
        let frequency = 740.0       // gentle mid-range tone
        let beepLength = 0.13       // seconds per beep
        let gapLength = 0.11
        let fade = 0.025            // soft attack/release, avoids clicks
        let amplitude = 0.30
        let beeps = 3

        var samples = [Int16]()
        let beepSamples = Int(beepLength * sampleRate)
        let gapSamples = Int(gapLength * sampleRate)

        for index in 0..<beeps {
            for n in 0..<beepSamples {
                let t = Double(n) / sampleRate
                let attack = min(1, t / fade)
                let release = min(1, (beepLength - t) / fade)
                let envelope = max(0, min(attack, release))
                // Sine plus a quiet octave for a warmer, rounder tone.
                let wave = sin(2 * .pi * frequency * t) + 0.25 * sin(2 * .pi * frequency * 2 * t)
                let value = wave / 1.25 * envelope * amplitude
                samples.append(Int16(value * Double(Int16.max)))
            }
            if index < beeps - 1 {
                samples.append(contentsOf: [Int16](repeating: 0, count: gapSamples))
            }
        }

        let byteCount = samples.count * 2
        var data = Data()
        func append<T: FixedWidthInteger>(_ value: T) {
            var v = value.littleEndian
            withUnsafeBytes(of: &v) { data.append(contentsOf: $0) }
        }

        data.append(contentsOf: Array("RIFF".utf8)); append(UInt32(36 + byteCount))
        data.append(contentsOf: Array("WAVE".utf8))
        data.append(contentsOf: Array("fmt ".utf8)); append(UInt32(16))
        append(UInt16(1))                       // PCM
        append(UInt16(1))                       // mono
        append(UInt32(sampleRate))
        append(UInt32(sampleRate) * 2)          // byte rate
        append(UInt16(2))                       // block align
        append(UInt16(16))                      // bits per sample
        data.append(contentsOf: Array("data".utf8)); append(UInt32(byteCount))
        for s in samples { append(s) }
        return data
    }
}
