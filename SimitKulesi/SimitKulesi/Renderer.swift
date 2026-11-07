import SwiftUI

enum Renderer {
    static func draw(_ g: Game, in ctx: inout GraphicsContext, size: CGSize) {
        let W = size.width, H = size.height
        let level = CGFloat(g.layers.count)

        // Gökyüzü: sabah → gün batımı → gece
        let sky = skyColors(level)
        ctx.fill(Path(CGRect(origin: .zero, size: size)),
                 with: .linearGradient(Gradient(colors: [sky.top, sky.bottom]),
                                       startPoint: .zero, endPoint: CGPoint(x: 0, y: H)))

        let starAlpha = min(1, max(0, (level - 35) / 20))
        if starAlpha > 0 {
            for s in g.stars {
                let y = (s.y * H + g.camera * 0.15).truncatingRemainder(dividingBy: H)
                ctx.fill(Path(ellipseIn: CGRect(x: s.x * W, y: y, width: s.r, height: s.r)),
                         with: .color(.white.opacity(Double(starAlpha) * 0.85)))
            }
        }

        let groundY = H * 0.82
        let z = g.zoom
        func sx(_ x: CGFloat) -> CGFloat { W / 2 + (x - W / 2) * z }
        func sy(_ y: CGFloat) -> CGFloat { groundY - (y - g.camera) * z }
        let h = Game.layerHeight * z

        // Masa ve tepsi
        let trayTop = sy(0)
        let tableTop = trayTop + 10 * z
        if tableTop < H {
            ctx.fill(Path(CGRect(x: 0, y: tableTop, width: W, height: H - tableTop + 20)),
                     with: .linearGradient(Gradient(colors: [Color(red: 0.55, green: 0.33, blue: 0.18),
                                                             Color(red: 0.36, green: 0.2, blue: 0.1)]),
                                           startPoint: CGPoint(x: 0, y: tableTop),
                                           endPoint: CGPoint(x: 0, y: H)))
        }
        let trayW = (g.baseWidth + 70) * z
        ctx.fill(Path(roundedRect: CGRect(x: W / 2 - trayW / 2, y: trayTop, width: trayW, height: 12 * z),
                      cornerRadius: 6 * z),
                 with: .linearGradient(Gradient(colors: [Color(white: 0.92), Color(white: 0.62)]),
                                       startPoint: CGPoint(x: 0, y: trayTop),
                                       endPoint: CGPoint(x: 0, y: trayTop + 12 * z)))

        // Kule
        for (i, l) in g.layers.enumerated() {
            let rect = CGRect(x: sx(l.center - l.width / 2), y: sy(CGFloat(i + 1) * Game.layerHeight),
                              width: l.width * z, height: h)
            if rect.minY > H || rect.maxY < -60 { continue }
            drawSimit(&ctx, rect: rect.insetBy(dx: 0, dy: 1), golden: l.golden, seed: i)
        }

        if g.flash > 0, let last = g.layers.last {
            let i = g.layers.count - 1
            let rect = CGRect(x: sx(last.center - last.width / 2), y: sy(CGFloat(i + 1) * Game.layerHeight),
                              width: last.width * z, height: h).insetBy(dx: -4, dy: -3)
            ctx.stroke(Path(roundedRect: rect, cornerRadius: rect.height / 2),
                       with: .color(.white.opacity(Double(g.flash))), lineWidth: 3)
        }

        // Kayan simit
        if g.phase != .over {
            let i = g.layers.count
            let rect = CGRect(x: sx(g.moving.center - g.moving.width / 2), y: sy(CGFloat(i + 1) * Game.layerHeight),
                              width: g.moving.width * z, height: h)
            drawSimit(&ctx, rect: rect.insetBy(dx: 0, dy: 1), golden: g.moving.golden, seed: i)
        }

        // Kesilip düşen parçalar
        for d in g.debris {
            var c = ctx
            c.translateBy(x: sx(d.center), y: sy(d.y + Game.layerHeight / 2))
            c.rotate(by: .radians(Double(d.angle)))
            drawSimit(&c, rect: CGRect(x: -d.width * z / 2, y: -h / 2, width: d.width * z, height: h),
                      golden: d.golden, seed: d.seed)
        }

        // "Mükemmel!" yazıları
        for p in g.popups {
            let alpha = Double(max(0, 1 - p.age / 1.2))
            ctx.draw(Text(p.text)
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                        .foregroundColor(.white.opacity(alpha)),
                     at: CGPoint(x: W / 2, y: sy(p.y) - 44))
        }
    }

    static func drawSimit(_ ctx: inout GraphicsContext, rect: CGRect, golden: Bool, seed: Int) {
        guard rect.width > 0.5 else { return }
        let path = Path(roundedRect: rect, cornerRadius: min(rect.height, rect.width) / 2)
        let colors: [Color] = golden
            ? [Color(red: 1, green: 0.88, blue: 0.35), Color(red: 0.86, green: 0.6, blue: 0.08)]
            : [Color(red: 0.88, green: 0.55, blue: 0.24), Color(red: 0.58, green: 0.3, blue: 0.11)]
        ctx.fill(path, with: .linearGradient(Gradient(colors: colors),
                                             startPoint: CGPoint(x: rect.midX, y: rect.minY),
                                             endPoint: CGPoint(x: rect.midX, y: rect.maxY)))

        // Parlaklık
        let hlWidth = rect.width - rect.height
        if hlWidth > 0 {
            ctx.fill(Path(roundedRect: CGRect(x: rect.minX + rect.height / 2, y: rect.minY + rect.height * 0.16,
                                              width: hlWidth, height: rect.height * 0.16),
                          cornerRadius: rect.height * 0.08),
                     with: .color(.white.opacity(golden ? 0.45 : 0.22)))
        }

        // Susam
        let count = Int(rect.width / 8)
        let seedColor = Color(red: 1, green: 0.95, blue: 0.82)
        for k in 0..<max(0, count) {
            let rx = rect.minX + rect.height * 0.3 + hash01(seed, k * 2) * max(0, rect.width - rect.height * 0.6)
            let ry = rect.minY + rect.height * (0.3 + hash01(seed, k * 2 + 1) * 0.45)
            ctx.fill(Path(ellipseIn: CGRect(x: rx, y: ry, width: 3.4, height: 1.9)), with: .color(seedColor))
        }

        ctx.stroke(path, with: .color(.black.opacity(0.18)), lineWidth: 1)
    }

    private struct SkyStop {
        let level: CGFloat
        let top: (Double, Double, Double)
        let bottom: (Double, Double, Double)
    }

    private static let stops: [SkyStop] = [
        SkyStop(level: 0, top: (0.45, 0.76, 0.98), bottom: (0.84, 0.94, 1.0)),
        SkyStop(level: 25, top: (0.96, 0.5, 0.38), bottom: (1.0, 0.82, 0.58)),
        SkyStop(level: 50, top: (0.12, 0.1, 0.32), bottom: (0.42, 0.27, 0.52)),
        SkyStop(level: 80, top: (0.02, 0.02, 0.08), bottom: (0.1, 0.08, 0.26)),
    ]

    static func skyColors(_ level: CGFloat) -> (top: Color, bottom: Color) {
        guard let upper = stops.firstIndex(where: { $0.level > level }) else {
            let s = stops.last!
            return (rgb(s.top), rgb(s.bottom))
        }
        let a = stops[max(0, upper - 1)], b = stops[upper]
        let t = Double((level - a.level) / (b.level - a.level))
        return (mix(a.top, b.top, t), mix(a.bottom, b.bottom, t))
    }

    private static func rgb(_ c: (Double, Double, Double)) -> Color { Color(red: c.0, green: c.1, blue: c.2) }

    private static func mix(_ a: (Double, Double, Double), _ b: (Double, Double, Double), _ t: Double) -> Color {
        let t = min(1, max(0, t))
        return Color(red: a.0 + (b.0 - a.0) * t, green: a.1 + (b.1 - a.1) * t, blue: a.2 + (b.2 - a.2) * t)
    }
}
