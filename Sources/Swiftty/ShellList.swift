import Foundation

enum ShellList {

  static func available() -> [String] {
    let contents = (try? String(contentsOfFile: "/etc/shells", encoding: .utf8)) ?? ""
    var seen = Set<String>()
    var shells: [String] = []
    for line in contents.split(separator: "\n") {
      let path = line.trimmingCharacters(in: .whitespaces)
      guard path.hasPrefix("/"),
        FileManager.default.isExecutableFile(atPath: path),
        seen.insert(path).inserted
      else { continue }
      shells.append(path)
    }
    return shells.sorted()
  }
}
