#!/usr/bin/env bash
#
# Generate Resources/AppIcon.icns without checking a binary asset into the repo.
#
# Idempotent: skips rendering if AppIcon.icns already exists and --force is not
# given.
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RES_DIR="${REPO_ROOT}/Resources"
ICNS_PATH="${RES_DIR}/AppIcon.icns"
ICONSET_DIR="$(mktemp -d)/AppIcon.iconset"
RENDER_SWIFT="$(mktemp).swift"

cleanup() {
    rm -f "${RENDER_SWIFT}"
    rm -rf "$(dirname "${ICONSET_DIR}")"
}
trap cleanup EXIT

if [[ "${1:-}" != "--force" && -f "${ICNS_PATH}" ]]; then
    echo "OK ${ICNS_PATH} already exists (pass --force to regenerate)."
    exit 0
fi

mkdir -p "${RES_DIR}" "${ICONSET_DIR}"

cat > "${RENDER_SWIFT}" <<'SWIFT'
import AppKit

func renderIcon(size: Int, to url: URL) {
    let dim = CGFloat(size)
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false,
        colorSpaceName: .calibratedRGB,
        bytesPerRow: 0, bitsPerPixel: 0
    ) else {
        FileHandle.standardError.write(Data("failed to create bitmap rep \(size)\n".utf8))
        exit(1)
    }

    guard let gctx = NSGraphicsContext(bitmapImageRep: rep) else {
        FileHandle.standardError.write(Data("failed to create graphics context \(size)\n".utf8))
        exit(1)
    }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = gctx
    defer { NSGraphicsContext.restoreGraphicsState() }

    let inset = dim * 0.08
    let rect = CGRect(x: inset, y: inset, width: dim - inset * 2, height: dim - inset * 2)
    let radius = rect.width * 0.225
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    path.addClip()

    let top = NSColor(calibratedRed: 0.141, green: 0.157, blue: 0.231, alpha: 1.0)
    let bottom = NSColor(calibratedRed: 0.102, green: 0.106, blue: 0.149, alpha: 1.0)
    let gradient = NSGradient(starting: top, ending: bottom)!
    gradient.draw(in: rect, angle: -90)

    let highlight = NSColor.white.withAlphaComponent(0.10)
    highlight.setFill()
    let glassRect = CGRect(x: rect.minX, y: rect.midY, width: rect.width, height: rect.height / 2)
    NSBezierPath(roundedRect: glassRect, xRadius: radius, yRadius: radius).fill()

    let stroke = NSColor(calibratedRed: 0.620, green: 0.808, blue: 0.416, alpha: 1.0)
    stroke.setStroke()
    let lw = dim * 0.05
    let chevron = NSBezierPath()
    chevron.lineWidth = lw
    chevron.lineCapStyle = .round
    chevron.lineJoinStyle = .round
    let cx = rect.minX + rect.width * 0.34
    let cy = rect.midY
    let arm = rect.width * 0.14
    chevron.move(to: CGPoint(x: cx - arm, y: cy + arm))
    chevron.line(to: CGPoint(x: cx + arm, y: cy))
    chevron.line(to: CGPoint(x: cx - arm, y: cy - arm))
    chevron.stroke()

    let cursor = NSBezierPath()
    cursor.lineWidth = lw
    cursor.lineCapStyle = .round
    let ux = rect.minX + rect.width * 0.56
    let uy = cy - arm
    cursor.move(to: CGPoint(x: ux, y: uy))
    cursor.line(to: CGPoint(x: ux + rect.width * 0.20, y: uy))
    cursor.stroke()

    gctx.flushGraphics()
    guard let png = rep.representation(using: .png, properties: [:]) else {
        FileHandle.standardError.write(Data("failed to encode \(size)\n".utf8))
        exit(1)
    }
    do {
        try png.write(to: url)
    } catch {
        FileHandle.standardError.write(Data("failed to write \(url.path): \(error)\n".utf8))
        exit(1)
    }
}

let outDir = URL(fileURLWithPath: CommandLine.arguments[1])
// (point size, scale) -> filename, per Apple's iconset naming.
let specs: [(Int, Int)] = [(16,1),(16,2),(32,1),(32,2),(128,1),(128,2),(256,1),(256,2),(512,1),(512,2)]
for (pt, scale) in specs {
    let px = pt * scale
    let suffix = scale == 2 ? "@2x" : ""
    let name = "icon_\(pt)x\(pt)\(suffix).png"
    renderIcon(size: px, to: outDir.appendingPathComponent(name))
}
SWIFT

echo "> Rendering iconset..."
swift "${RENDER_SWIFT}" "${ICONSET_DIR}"

echo "> Packing ${ICNS_PATH}..."
iconutil -c icns "${ICONSET_DIR}" -o "${ICNS_PATH}"

echo "OK Generated ${ICNS_PATH}"
