import AppKit

/// The fonts offered in Settings.
///
/// A terminal needs every character to have the same width, so only fixed-width
/// families are listed.
enum FontList {

  static func families() -> [String] {
    NSFontManager.shared.availableFontFamilies
      .filter { NSFont(name: $0, size: 12)?.isFixedPitch == true }
      .sorted()
  }
}
