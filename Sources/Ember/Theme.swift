import SwiftUI
import AppKit

private func rgb(_ hex: UInt32) -> (Double, Double, Double) {
    (Double((hex >> 16) & 0xFF) / 255, Double((hex >> 8) & 0xFF) / 255, Double(hex & 0xFF) / 255)
}

extension Color {
    init(hex: UInt32) {
        let (r, g, b) = rgb(hex)
        self.init(red: r, green: g, blue: b)
    }
}

extension NSColor {
    convenience init(hex: UInt32) {
        let (r, g, b) = rgb(hex)
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}

enum Brand {
    // Terracotta orange and a warm, muted yellow for breaks.
    static let orangeHex: UInt32 = 0xD97757
    static let yellowHex: UInt32 = 0xE5B94E

    static let orange = Color(hex: orangeHex)
    static let yellow = Color(hex: yellowHex)
    static let orangeNS = NSColor(hex: orangeHex)
    static let yellowNS = NSColor(hex: yellowHex)

    // Warm neutrals.
    static let darkSurface: UInt32 = 0x262624   // warm dark gray
    static let lightSurface: UInt32 = 0xFAF9F5  // warm off-white
    static let darkInk: UInt32 = 0x141413
}

enum ThemeChoice: String {
    case light, dark

    var colorScheme: ColorScheme { self == .dark ? .dark : .light }
    var appearance: NSAppearance? { NSAppearance(named: self == .dark ? .darkAqua : .aqua) }
    var toggled: ThemeChoice { self == .dark ? .light : .dark }
}

struct Palette {
    let dark: Bool

    var tint: Color {
        dark ? Color(hex: Brand.darkSurface).opacity(0.28) : Color(hex: Brand.lightSurface).opacity(0.20)
    }
    var card: Color {
        dark ? Color(hex: Brand.lightSurface).opacity(0.07) : Color(hex: Brand.darkInk).opacity(0.05)
    }
    var track: Color {
        dark ? Color(hex: Brand.lightSurface).opacity(0.10) : Color(hex: Brand.darkInk).opacity(0.08)
    }
    var text: Color {
        dark ? Color(hex: Brand.lightSurface) : Color(hex: Brand.darkInk)
    }
    var secondary: Color {
        dark ? Color(hex: Brand.lightSurface).opacity(0.55) : Color(hex: Brand.darkInk).opacity(0.55)
    }
    var onAccent: Color { Color(hex: Brand.darkInk) }
}

extension Phase {
    var color: Color { self == .work ? Brand.orange : Brand.yellow }
    var nsColor: NSColor { self == .work ? Brand.orangeNS : Brand.yellowNS }
}
