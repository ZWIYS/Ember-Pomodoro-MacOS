import SwiftUI
import AppKit

enum Brand {
    static let orange = Color(red: 1.00, green: 0.54, blue: 0.12)
    static let yellow = Color(red: 1.00, green: 0.79, blue: 0.24)
    static let orangeNS = NSColor(red: 1.00, green: 0.54, blue: 0.12, alpha: 1)
    static let yellowNS = NSColor(red: 1.00, green: 0.79, blue: 0.24, alpha: 1)
}

enum ThemeChoice: String {
    case light, dark

    var colorScheme: ColorScheme { self == .dark ? .dark : .light }
    var appearance: NSAppearance? { NSAppearance(named: self == .dark ? .darkAqua : .aqua) }
    var toggled: ThemeChoice { self == .dark ? .light : .dark }
}

struct Palette {
    let dark: Bool

    var tint: Color { dark ? Color(white: 0.10).opacity(0.50) : Color.white.opacity(0.30) }
    var card: Color { dark ? Color.white.opacity(0.07) : Color.black.opacity(0.05) }
    var track: Color { dark ? Color.white.opacity(0.10) : Color.black.opacity(0.08) }
    var text: Color { dark ? Color.white : Color(white: 0.12) }
    var secondary: Color { dark ? Color.white.opacity(0.55) : Color.black.opacity(0.50) }
    var onAccent: Color { Color(white: 0.10) }
}

extension Phase {
    var color: Color { self == .work ? Brand.orange : Brand.yellow }
    var nsColor: NSColor { self == .work ? Brand.orangeNS : Brand.yellowNS }
}
