import AppKit
import SwiftTerm

struct TerminalTheme {

  let background: NSColor
  let foreground: NSColor
  let cursor: NSColor
  let ansi: [SwiftTerm.Color]

  static var tokyoNight: TerminalTheme {
    TerminalTheme(
      background: NSColor(hex: 0x1A1B26),
      foreground: NSColor(hex: 0xC0CAF5),
      cursor: NSColor(hex: 0xC0CAF5),
      ansi: [
        SwiftTerm.Color(hex: 0x15161E),
        SwiftTerm.Color(hex: 0xF7768E),
        SwiftTerm.Color(hex: 0x9ECE6A),
        SwiftTerm.Color(hex: 0xE0AF68),
        SwiftTerm.Color(hex: 0x7AA2F7),
        SwiftTerm.Color(hex: 0xBB9AF7),
        SwiftTerm.Color(hex: 0x7DCFFF),
        SwiftTerm.Color(hex: 0xA9B1D6),
        SwiftTerm.Color(hex: 0x414868),
        SwiftTerm.Color(hex: 0xF7768E),
        SwiftTerm.Color(hex: 0x9ECE6A),
        SwiftTerm.Color(hex: 0xE0AF68),
        SwiftTerm.Color(hex: 0x7AA2F7),
        SwiftTerm.Color(hex: 0xBB9AF7),
        SwiftTerm.Color(hex: 0x7DCFFF),
        SwiftTerm.Color(hex: 0xC0CAF5)
      ]
    )
  }
}

extension NSColor {
  convenience init(hex: Int) {
    self.init(
      srgbRed: CGFloat((hex >> 16) & 0xFF) / 255.0,
      green: CGFloat((hex >> 8) & 0xFF) / 255.0,
      blue: CGFloat(hex & 0xFF) / 255.0,
      alpha: 1.0
    )
  }
}

extension SwiftTerm.Color {
  convenience init(hex: Int) {
    self.init(
      red: UInt16((hex >> 16) & 0xFF) * 257,
      green: UInt16((hex >> 8) & 0xFF) * 257,
      blue: UInt16(hex & 0xFF) * 257
    )
  }
}
