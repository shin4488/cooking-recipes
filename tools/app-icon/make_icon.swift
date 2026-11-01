// アプリのアイコン（1024 × 1024 の3枚）を描く。リポジトリの直下で次のように実行する
// swift tools/app-icon/make_icon.swift RecipePocket/Resources/Assets.xcassets/AppIcon.appiconset
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let size = 1024
let space = CGColorSpace(name: CGColorSpace.sRGB)!

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        colorSpace: space,
        components: [CGFloat((hex >> 16) & 0xff) / 255, CGFloat((hex >> 8) & 0xff) / 255, CGFloat(hex & 0xff) / 255, alpha]
    )!
}

struct Palette {
    var backgroundTop: CGColor?
    var backgroundBottom: CGColor?
    var pocket: CGColor
    var hem: CGColor
    var gingham: CGColor
    var stitch: CGColor
    var petal: CGColor
    var flowerCenter: CGColor
    var leaf: CGColor
    var card: CGColor
    var cardLine: CGColor
    var spoonBowl: CGColor
    var spoonHandle: CGColor
    var shadow: CGColor
}

/// 書き出すファイル名と色。明るい表示・ダーク表示・色付き（ホーム画面の色合いに合わせて iOS が色を付ける）の3枚
let icons: [(file: String, palette: Palette)] = [
    // くすみピンクの背景に、クリーム色のポケット。中身が背景に埋もれないよう、背景と中身の色に差を付ける
    ("AppIcon.png", Palette(backgroundTop: color(0xEFCFC6), backgroundBottom: color(0xD9A096), pocket: color(0xFFFAF5), hem: color(0xF6DED6),
                            gingham: color(0xD99C92, 0.6), stitch: color(0xC58178), petal: color(0xDB8E84), flowerCenter: color(0xEEC57F),
                            leaf: color(0x92AC86), card: color(0xFFFFFF), cardLine: color(0xDDA59C), spoonBowl: color(0xDDB78F),
                            spoonHandle: color(0xC69B70), shadow: color(0x8A4F45, 0.30))),
    ("AppIcon-Dark.png", Palette(backgroundTop: color(0x3D302E), backgroundBottom: color(0x1F1817), pocket: color(0xF8EAE3), hem: color(0xEDD0C7),
                                 gingham: color(0xCF9389, 0.6), stitch: color(0xCB8378), petal: color(0xDD8D83), flowerCenter: color(0xEEC57F),
                                 leaf: color(0x8FAA85), card: color(0xFFF7F2), cardLine: color(0xD9A097), spoonBowl: color(0xD7B08A),
                                 spoonHandle: color(0xC0966E), shadow: color(0x000000, 0.45))),
    // 色付きは灰色の濃淡だけで描き、背景は黒にする
    ("AppIcon-Tinted.png", Palette(backgroundTop: nil, backgroundBottom: nil, pocket: color(0xFFFFFF), hem: color(0xDCDCDC),
                                   gingham: color(0x9A9A9A, 0.5), stitch: color(0x8C8C8C), petal: color(0x7C7C7C), flowerCenter: color(0xC4C4C4),
                                   leaf: color(0xA4A4A4), card: color(0xF2F2F2), cardLine: color(0xABABAB), spoonBowl: color(0xBDBDBD),
                                   spoonHandle: color(0x9E9E9E), shadow: color(0x000000, 0.35))),
]

func roundedRect(_ rect: CGRect, radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

/// 上辺がまっすぐで、下が丸くわずかにとがったポケットの形。closed が false なら上辺を除いた線にする
func pocketPath(_ rect: CGRect, bottomRadius: CGFloat, topRadius: CGFloat, dip: CGFloat, closed: Bool = true) -> CGPath {
    let path = CGMutablePath()
    let tip = CGPoint(x: rect.midX, y: rect.maxY + dip)
    if closed {
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + topRadius))
        path.addQuadCurve(to: CGPoint(x: rect.minX + topRadius, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - topRadius, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + topRadius), control: CGPoint(x: rect.maxX, y: rect.minY))
    } else {
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
    }
    path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.maxY), tangent2End: tip, radius: bottomRadius)
    path.addArc(tangent1End: tip, tangent2End: CGPoint(x: rect.minX, y: rect.maxY), radius: bottomRadius * 1.6)
    path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.maxY), tangent2End: CGPoint(x: rect.minX, y: rect.minY), radius: bottomRadius)
    path.addLine(to: CGPoint(x: rect.minX, y: closed ? rect.minY + topRadius : rect.minY))
    if closed { path.closeSubpath() }
    return path
}

/// 葉。中心から angle の向きに伸びる、両端のとがった形
func leafPath(base: CGPoint, length: CGFloat, width: CGFloat, angle: CGFloat) -> CGPath {
    let path = CGMutablePath()
    path.move(to: .zero)
    path.addQuadCurve(to: CGPoint(x: length, y: 0), control: CGPoint(x: length * 0.5, y: -width))
    path.addQuadCurve(to: .zero, control: CGPoint(x: length * 0.5, y: width))
    path.closeSubpath()
    var transform = CGAffineTransform(translationX: base.x, y: base.y).rotated(by: angle)
    return path.copy(using: &transform)!
}

func drawFlower(_ context: CGContext, center: CGPoint, palette p: Palette) {
    // 葉を花の下に2枚
    context.setFillColor(p.leaf)
    context.addPath(leafPath(base: CGPoint(x: center.x - 10, y: center.y + 46), length: 122, width: 32, angle: 150 * .pi / 180))
    context.addPath(leafPath(base: CGPoint(x: center.x + 10, y: center.y + 46), length: 122, width: 32, angle: 30 * .pi / 180))
    context.fillPath()
    // 丸い花びら5枚
    context.setFillColor(p.petal)
    for index in 0..<5 {
        let angle = (-90 + CGFloat(index) * 72) * .pi / 180
        let petal = CGPoint(x: center.x + cos(angle) * 40, y: center.y + sin(angle) * 40)
        context.addEllipse(in: CGRect(x: petal.x - 34, y: petal.y - 34, width: 68, height: 68))
    }
    context.fillPath()
    context.setFillColor(p.flowerCenter)
    context.addEllipse(in: CGRect(x: center.x - 24, y: center.y - 24, width: 48, height: 48))
    context.fillPath()
}

func draw(_ p: Palette, to url: URL) {
    let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    // 上を原点にする
    context.translateBy(x: 0, y: CGFloat(size))
    context.scaleBy(x: 1, y: -1)

    if let top = p.backgroundTop, let bottom = p.backgroundBottom {
        let gradient = CGGradient(colorsSpace: space, colors: [top, bottom] as CFArray, locations: [0, 1])!
        context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: CGFloat(size)), options: [])
    } else {
        context.setFillColor(color(0x000000))
        context.fill(CGRect(x: 0, y: 0, width: size, height: size))
    }

    let pocketRect = CGRect(x: 214, y: 486, width: 596, height: 356)

    // ポケットからのぞくレシピカード
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: 10), blur: 24, color: p.shadow)
    context.translateBy(x: 400, y: 470)
    context.rotate(by: -10 * .pi / 180)
    let card = CGRect(x: -150, y: -240, width: 300, height: 420)
    context.addPath(roundedRect(card, radius: 34))
    context.setFillColor(p.card)
    context.fillPath()
    context.setShadow(offset: .zero, blur: 0, color: nil)
    context.setFillColor(p.cardLine)
    context.addPath(roundedRect(CGRect(x: -100, y: -180, width: 120, height: 30), radius: 15))
    context.fillPath()
    for (index, width) in [200.0, 170.0, 190.0].enumerated() {
        context.addPath(roundedRect(CGRect(x: -100, y: -112 + Double(index) * 52, width: width, height: 20), radius: 10))
    }
    context.setFillColor(p.cardLine.copy(alpha: 0.7)!)
    context.fillPath()
    context.restoreGState()

    // 木のスプーン
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: 10), blur: 24, color: p.shadow)
    context.translateBy(x: 640, y: 520)
    context.rotate(by: 16 * .pi / 180)
    context.addPath(roundedRect(CGRect(x: -26, y: -250, width: 52, height: 330), radius: 26))
    context.setFillColor(p.spoonHandle)
    context.fillPath()
    context.addEllipse(in: CGRect(x: -84, y: -420, width: 168, height: 220))
    context.setFillColor(p.spoonBowl)
    context.fillPath()
    context.setShadow(offset: .zero, blur: 0, color: nil)
    context.addEllipse(in: CGRect(x: -54, y: -388, width: 108, height: 150))
    context.setFillColor(p.spoonHandle.copy(alpha: 0.35)!)
    context.fillPath()
    context.restoreGState()

    // ポケット本体
    let pocket = pocketPath(pocketRect, bottomRadius: 120, topRadius: 18, dip: 40)
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: 14), blur: 30, color: p.shadow)
    context.addPath(pocket)
    context.setFillColor(p.pocket)
    context.fillPath()
    context.restoreGState()

    // 上端の折り返しは、ギンガムチェックの布にする
    let hemHeight: CGFloat = 76
    context.saveGState()
    context.addPath(pocket)
    context.clip()
    let hem = CGRect(x: pocketRect.minX, y: pocketRect.minY, width: pocketRect.width, height: hemHeight)
    context.clip(to: hem)
    context.setFillColor(p.hem)
    context.fill(hem)
    context.setFillColor(p.gingham)
    let square: CGFloat = 26
    var x = hem.minX
    while x < hem.maxX {
        context.fill(CGRect(x: x, y: hem.minY, width: square, height: hem.height))
        x += square * 2
    }
    var y = hem.minY
    while y < hem.maxY {
        context.fill(CGRect(x: hem.minX, y: y, width: hem.width, height: square))
        y += square * 2
    }
    context.restoreGState()

    // ステッチ。折り返しの下の線と、そこから下を囲む線
    let hemY = pocketRect.minY + hemHeight
    context.saveGState()
    context.setStrokeColor(p.stitch)
    context.setLineWidth(11)
    context.setLineCap(.round)
    context.setLineDash(phase: 0, lengths: [26, 24])
    context.move(to: CGPoint(x: pocketRect.minX + 34, y: hemY + 2))
    context.addLine(to: CGPoint(x: pocketRect.maxX - 34, y: hemY + 2))
    context.strokePath()
    let stitchRect = CGRect(x: pocketRect.minX + 34, y: hemY + 28, width: pocketRect.width - 68, height: pocketRect.maxY - 34 - (hemY + 28))
    context.addPath(pocketPath(stitchRect, bottomRadius: 92, topRadius: 0, dip: 30, closed: false))
    context.strokePath()
    context.restoreGState()

    // 刺しゅうの花
    drawFlower(context, center: CGPoint(x: pocketRect.midX, y: pocketRect.minY + 212), palette: p)

    let image = context.makeImage()!
    let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, image, nil)
    CGImageDestinationFinalize(destination)
}

let output = URL(fileURLWithPath: CommandLine.arguments[1])
for icon in icons {
    draw(icon.palette, to: output.appending(path: icon.file))
}
print("\(output.path(percentEncoded: false)) に \(icons.count) 枚を書き出しました")
