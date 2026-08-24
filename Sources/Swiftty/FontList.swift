import AppKit

enum FontList {

  static func families() -> [String] {
    NSFontManager.shared.availableFontFamilies
      .filter { NSFont(name: $0, size: 12)?.isFixedPitch == true }
      .sorted()
  }
}
