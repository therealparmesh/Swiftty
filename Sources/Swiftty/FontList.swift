import AppKit

enum FontList {

  static func families() -> [String] {
    NSFontManager.shared.availableFontFamilies.sorted()
  }
}
