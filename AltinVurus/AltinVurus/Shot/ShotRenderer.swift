import SwiftUI

typealias CamPoint = (lat: Double, up: Double, depth: Double)

enum ShotRenderer {
    private static let near = 0.25
    private static let grassA = Color(red: 0.13, green: 0.45, blue: 0.17)
    private static let grassB = Color(red: 0.16, green: 0.52, blue: 0.2)
    private static let skin = Color(red: 0.86, green: 0.65, blue: 0.48)
    private static let keeperKit = Kit(primary: Color(red: 0.95, green: 0.3, blue: 0.62),
                                       secondary: Color(red: 0.2, green: 0.1, blue: 0.3))

    static func draw(_ g: ShotGame, ctx: inout GraphicsContext, size: CGSize) {
        drawBackground(g, &ctx, size)
        drawPitch(g, &ctx)
        drawBoards(g, &ctx)

        // Derinliğe göre sıralı nesneler (uzaktan yakına)
        var items: [(depth: Double, draw: (inout GraphicsContext) -> Void)] = []
        items.append((g.toCamera(Vec3(x: 0, y: 1, z: -0.4)).depth, { drawGoal(g, &$0) }))

        let keeperFoot = Vec3(x: g.keeperX, y: 0, z: 0.3)
        let lean = g.keeperDiving ? max(-1, min(1, (g.keeperX - g.keeperDiveStartX) / 2.0)) * 1.25 : 0
        items.append((g.toCamera(keeperFoot).depth, {
            drawFigure(g, &$0, foot: keeperFoot, kit: keeperKit, shorts: Color(white: 0.12), keeper: true,
                       lean: lean, lift: g.keeperLift + abs(lean) * 0.2, armsUp: g.keeperDiving ? 1 : 0.35)
        }))

        for (i, x) in g.wallXs.enumerated() {
            let foot = Vec3(x: x, y: 0, z: g.wallZ)
            items.append((g.toCamera(foot).depth, {
                drawFigure(g, &$0, foot: foot, kit: g.config.opponentKit, shorts: g.config.opponentKit.secondary,
                           keeper: false, lean: sin(Double(i) * 1.7) * 0.04, lift: g.wallJump, armsUp: 0)
            }))
        }

        items.append((g.toCamera(g.ball).depth, { drawBall(g, &$0) }))

        for item in items.sorted(by: { $0.depth > $1.depth }) {
            item.draw(&ctx)
        }

        drawTrail(g, &ctx)
        drawParticles(g, &ctx)
    }

    // MARK: - Arka plan

    private static func drawBackground(_ g: ShotGame, _ ctx: inout GraphicsContext, _ size: CGSize) {
        let W = size.width
        ctx.fill(Path(CGRect(origin: .zero, size: size)),
                 with: .linearGradient(Gradient(colors: [Color(red: 0.02, green: 0.03, blue: 0.08),
                                                         Color(red: 0.09, green: 0.13, blue: 0.26)]),
                                       startPoint: .zero, endPoint: CGPoint(x: 0, y: g.horizonY)))

        for fx in [0.1, 0.9] {
            let c = CGPoint(x: W * fx, y: g.horizonY * 0.22)
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - 140, y: c.y - 140, width: 280, height: 280)),
                     with: .radialGradient(Gradient(colors: [.white.opacity(0.32), .clear]),
                                           center: c, startRadius: 0, endRadius: 140))
            for k in 0..<3 {
                ctx.fill(Path(roundedRect: CGRect(x: c.x - 22, y: c.y - 10 + CGFloat(k) * 7, width: 44, height: 5),
                              cornerRadius: 2),
                         with: .color(.white.opacity(0.9)))
            }
        }

        let stand = [Vec3(x: -80, y: 0.9, z: -6.5), Vec3(x: 80, y: 0.9, z: -6.5),
                     Vec3(x: 80, y: 14, z: -22), Vec3(x: -80, y: 14, z: -22)]
        if let p = polygon(g, stand) {
            ctx.fill(p, with: .color(Color(red: 0.09, green: 0.09, blue: 0.13)))
        }

        let kit = g.config.opponentKit
        let palette: [Color] = [kit.primary, kit.primary, kit.secondary, .white.opacity(0.8),
                                Color(white: 0.45), Color(red: 0.9, green: 0.75, blue: 0.2), Color(white: 0.25)]
        for i in 0..<560 {
            let u = hash01(i, 11), v = hash01(i, 12)
            var pos = Vec3(x: -80 + 160 * u, y: 1.2 + 12.4 * v, z: -6.8 - 15 * v)
            if g.celebrating { pos.y += abs(sin(g.time * 14 + Double(i))) * 0.35 }
            guard let s = g.project(pos) else { continue }
            let r = max(1.3, 0.34 * g.scale(at: pos))
            ctx.fill(Path(ellipseIn: CGRect(x: s.x - r / 2, y: s.y - r / 2, width: r, height: r)),
                     with: .color(palette[Int(hash01(i, 13) * Double(palette.count)) % palette.count]))
        }
    }

    // MARK: - Saha

    private static func drawPitch(_ g: ShotGame, _ ctx: inout GraphicsContext) {
        if let p = polygon(g, [Vec3(x: -80, y: 0, z: -6.5), Vec3(x: 80, y: 0, z: -6.5),
                               Vec3(x: 80, y: 0, z: 80), Vec3(x: -80, y: 0, z: 80)]) {
            ctx.fill(p, with: .color(grassA))
        }
        var z = -6.5
        var k = 0
        while z < 70 {
            if k % 2 == 0, let p = polygon(g, [Vec3(x: -80, y: 0, z: z), Vec3(x: 80, y: 0, z: z),
                                               Vec3(x: 80, y: 0, z: z + 5.5), Vec3(x: -80, y: 0, z: z + 5.5)]) {
                ctx.fill(p, with: .color(grassB))
            }
            z += 5.5
            k += 1
        }

        let white = Color.white.opacity(0.85)
        func line(_ pts: [(Double, Double)]) {
            for i in 0..<(pts.count - 1) {
                if let s = segment(g, Vec3(x: pts[i].0, y: 0, z: pts[i].1),
                                   Vec3(x: pts[i + 1].0, y: 0, z: pts[i + 1].1), width: 0.1) {
                    ctx.stroke(s.path, with: .color(white), lineWidth: s.width)
                }
            }
        }
        line([(-40, 0), (40, 0)])
        line([(-9.16, 0), (-9.16, 5.5), (9.16, 5.5), (9.16, 0)])
        line([(-20.16, 0), (-20.16, 16.5), (20.16, 16.5), (20.16, 0)])
        let arc: [(Double, Double)] = (0...16).map { i in
            let a = -0.927 + 1.854 * Double(i) / 16
            return (9.15 * sin(a), 11 + 9.15 * cos(a))
        }
        line(arc)
        let spot: [Vec3] = (0..<10).map { i in
            let a = Double(i) / 10 * 2 * .pi
            return Vec3(x: cos(a) * 0.15, y: 0, z: 11 + sin(a) * 0.15)
        }
        if let p = polygon(g, spot) { ctx.fill(p, with: .color(white)) }
    }

    private static func drawBoards(_ g: ShotGame, _ ctx: inout GraphicsContext) {
        let board = [Vec3(x: -45, y: 0, z: -6), Vec3(x: 45, y: 0, z: -6),
                     Vec3(x: 45, y: 0.9, z: -6), Vec3(x: -45, y: 0.9, z: -6)]
        guard let p = polygon(g, board) else { return }
        ctx.fill(p, with: .color(Color(red: 0.05, green: 0.15, blue: 0.45)))
        let stripe = [Vec3(x: -45, y: 0.72, z: -6), Vec3(x: 45, y: 0.72, z: -6),
                      Vec3(x: 45, y: 0.82, z: -6), Vec3(x: -45, y: 0.82, z: -6)]
        if let s = polygon(g, stripe) { ctx.fill(s, with: .color(Color(red: 1, green: 0.78, blue: 0.2))) }
        var x = -36.0
        while x <= 36 {
            let pos = Vec3(x: x, y: 0.36, z: -6)
            if let s = g.project(pos) {
                let fs = max(5, 0.42 * g.scale(at: pos))
                ctx.draw(Text("ALTIN VURUŞ").font(.system(size: fs, weight: .black, design: .rounded))
                            .foregroundColor(.white.opacity(0.9)), at: s)
            }
            x += 12
        }
    }

    // MARK: - Kale

    private static func drawGoal(_ g: ShotGame, _ ctx: inout GraphicsContext) {
        let hw = ShotGame.goalHalfWidth, gh = ShotGame.goalHeight
        let wobble = g.netShake * sin(g.time * 38) * 0.25
        let backZ = -2.0 - g.netShake * 0.45 + wobble
        let backTop = 2.1
        let net = Color.white.opacity(0.32)

        func seg(_ a: Vec3, _ b: Vec3) {
            if let s = segment(g, a, b, width: 0.02) {
                ctx.stroke(s.path, with: .color(net), lineWidth: 1)
            }
        }

        var x = -hw
        while x <= hw + 0.01 {
            seg(Vec3(x: x, y: 0, z: backZ), Vec3(x: x, y: backTop, z: backZ))
            seg(Vec3(x: x, y: gh, z: 0), Vec3(x: x, y: backTop, z: backZ))
            x += 0.42
        }
        var y = 0.0
        while y <= backTop + 0.01 {
            seg(Vec3(x: -hw, y: y, z: backZ), Vec3(x: hw, y: y, z: backZ))
            y += 0.35
        }
        for sx in [-hw, hw] {
            var zz = 0.0
            while zz >= backZ {
                let top = gh + (backTop - gh) * (zz / backZ)
                seg(Vec3(x: sx, y: 0, z: zz), Vec3(x: sx, y: top, z: zz))
                zz -= 0.42
            }
            var yy = 0.0
            while yy <= gh {
                seg(Vec3(x: sx, y: yy, z: 0), Vec3(x: sx, y: min(yy, backTop), z: backZ))
                yy += 0.35
            }
            seg(Vec3(x: sx, y: gh, z: 0), Vec3(x: sx, y: backTop, z: backZ))
            seg(Vec3(x: sx, y: 0, z: backZ), Vec3(x: sx, y: backTop, z: backZ))
        }

        let frame = [Vec3(x: -hw, y: 0, z: 0), Vec3(x: -hw, y: gh, z: 0),
                     Vec3(x: hw, y: gh, z: 0), Vec3(x: hw, y: 0, z: 0)]
        for i in 0..<3 {
            if let s = segment(g, frame[i], frame[i + 1], width: 0.12) {
                ctx.stroke(s.path, with: .color(.white), style: StrokeStyle(lineWidth: s.width, lineCap: .round))
            }
        }
    }

    // MARK: - Oyuncu

    private static func drawFigure(_ g: ShotGame, _ ctx: inout GraphicsContext, foot: Vec3, kit: Kit,
                                   shorts: Color, keeper: Bool, lean: Double, lift: Double, armsUp: Double) {
        guard let base = g.project(Vec3(x: foot.x, y: 0, z: foot.z)) else { return }
        let s = CGFloat(g.scale(at: foot))

        ctx.fill(Path(ellipseIn: CGRect(x: base.x - 0.35 * s, y: base.y - 0.07 * s, width: 0.7 * s, height: 0.14 * s)),
                 with: .color(.black.opacity(0.35)))

        var c = ctx
        c.translateBy(x: base.x, y: base.y - CGFloat(1.0 + lift) * s)
        c.rotate(by: .radians(lean))

        let legW = 0.15 * s
        for sgn in [-1.0, 1.0] {
            let lx = CGFloat(sgn) * 0.1 * s - legW / 2
            c.fill(Path(roundedRect: CGRect(x: lx, y: 0.1 * s, width: legW, height: 0.5 * s), cornerRadius: legW / 2),
                   with: .color(skin))
            c.fill(Path(roundedRect: CGRect(x: lx, y: 0.55 * s, width: legW, height: 0.4 * s), cornerRadius: legW / 2),
                   with: .color(kit.secondary))
            c.fill(Path(roundedRect: CGRect(x: lx - 0.02 * s, y: 0.92 * s, width: legW + 0.06 * s, height: 0.09 * s),
                        cornerRadius: 0.03 * s),
                   with: .color(.black))
        }
        c.fill(Path(roundedRect: CGRect(x: -0.24 * s, y: -0.06 * s, width: 0.48 * s, height: 0.34 * s),
                    cornerRadius: 0.06 * s),
               with: .color(shorts))

        let armW = 0.12 * s
        for sgn in [-1.0, 1.0] {
            var a = c
            a.translateBy(x: CGFloat(sgn) * 0.25 * s, y: -0.62 * s)
            a.rotate(by: .radians(-sgn * (0.2 + armsUp * 2.4)))
            a.fill(Path(roundedRect: CGRect(x: -armW / 2, y: 0, width: armW, height: 0.6 * s), cornerRadius: armW / 2),
                   with: .color(kit.primary))
            let hand: Color = keeper ? .white : skin
            let hr = keeper ? 0.09 * s : 0.06 * s
            a.fill(Path(ellipseIn: CGRect(x: -hr, y: 0.58 * s, width: hr * 2, height: hr * 2)), with: .color(hand))
        }

        let torso = CGRect(x: -0.27 * s, y: -0.72 * s, width: 0.54 * s, height: 0.74 * s)
        c.fill(Path(roundedRect: torso, cornerRadius: 0.11 * s),
               with: .linearGradient(Gradient(colors: [kit.primary, kit.primary.opacity(0.78)]),
                                     startPoint: CGPoint(x: torso.minX, y: torso.minY),
                                     endPoint: CGPoint(x: torso.maxX, y: torso.maxY)))
        c.fill(Path(CGRect(x: -0.06 * s, y: -0.7 * s, width: 0.12 * s, height: 0.7 * s)),
               with: .color(kit.secondary.opacity(0.85)))

        c.fill(Path(ellipseIn: CGRect(x: -0.12 * s, y: -1.0 * s, width: 0.24 * s, height: 0.28 * s)), with: .color(skin))
        c.fill(Path(ellipseIn: CGRect(x: -0.125 * s, y: -1.02 * s, width: 0.25 * s, height: 0.13 * s)),
               with: .color(Color(red: 0.15, green: 0.1, blue: 0.07)))
    }

    // MARK: - Top

    private static func drawBall(_ g: ShotGame, _ ctx: inout GraphicsContext) {
        let b = g.ball
        let sc = g.scale(at: b)
        if let sh = g.project(Vec3(x: b.x, y: 0, z: b.z)) {
            let r = CGFloat(0.14 * sc)
            let alpha = max(0.08, 0.45 - b.y * 0.12)
            ctx.fill(Path(ellipseIn: CGRect(x: sh.x - r, y: sh.y - r * 0.3, width: r * 2, height: r * 0.6)),
                     with: .color(.black.opacity(alpha)))
        }
        guard let p = g.project(b) else { return }
        let r = CGFloat(ShotGame.ballRadius * sc)
        let rect = CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)
        let circle = Path(ellipseIn: rect)
        ctx.fill(circle, with: .radialGradient(Gradient(colors: [.white, Color(white: 0.72)]),
                                               center: CGPoint(x: p.x - r * 0.35, y: p.y - r * 0.35),
                                               startRadius: 0, endRadius: r * 1.6))
        var inner = ctx
        inner.clip(to: circle)
        for k in 0..<4 {
            let a = g.spin + Double(k) * 1.57
            let px = p.x + CGFloat(cos(a)) * r * 0.62
            let py = p.y + CGFloat(sin(a * 0.8 + Double(k))) * r * 0.5
            let pr = r * 0.34
            inner.fill(Path(ellipseIn: CGRect(x: px - pr, y: py - pr, width: pr * 2, height: pr * 2)),
                       with: .color(Color(white: 0.12)))
        }
        ctx.stroke(circle, with: .color(.black.opacity(0.3)), lineWidth: 1)
    }

    // MARK: - Efektler

    private static func drawTrail(_ g: ShotGame, _ ctx: inout GraphicsContext) {
        guard g.drag.count > 1 else { return }
        var path = Path()
        path.move(to: g.drag[0].point)
        for d in g.drag.dropFirst() { path.addLine(to: d.point) }
        ctx.stroke(path, with: .color(.white.opacity(0.55)),
                   style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round))
    }

    private static func drawParticles(_ g: ShotGame, _ ctx: inout GraphicsContext) {
        for p in g.particles {
            var c = ctx
            c.translateBy(x: p.x, y: p.y)
            c.rotate(by: .radians(p.rot))
            c.opacity = min(1, p.life)
            c.fill(Path(CGRect(x: -4, y: -2.5, width: 8, height: 5)), with: .color(p.color))
        }
    }

    // MARK: - Kırpma yardımcıları

    private static func lerp(_ a: CamPoint, _ b: CamPoint, _ t: Double) -> CamPoint {
        (a.lat + (b.lat - a.lat) * t, a.up + (b.up - a.up) * t, a.depth + (b.depth - a.depth) * t)
    }

    static func polygon(_ g: ShotGame, _ pts: [Vec3]) -> Path? {
        let cs = pts.map { g.toCamera($0) }
        var out: [CamPoint] = []
        for i in 0..<cs.count {
            let a = cs[i], b = cs[(i + 1) % cs.count]
            let aIn = a.depth >= near, bIn = b.depth >= near
            if aIn { out.append(a) }
            if aIn != bIn {
                out.append(lerp(a, b, (near - a.depth) / (b.depth - a.depth)))
            }
        }
        guard out.count >= 3 else { return nil }
        var path = Path()
        path.move(to: g.screen(out[0]))
        for c in out.dropFirst() { path.addLine(to: g.screen(c)) }
        path.closeSubpath()
        return path
    }

    static func segment(_ g: ShotGame, _ a: Vec3, _ b: Vec3, width: Double) -> (path: Path, width: CGFloat)? {
        var ca = g.toCamera(a), cb = g.toCamera(b)
        if ca.depth < near && cb.depth < near { return nil }
        if ca.depth < near { ca = lerp(ca, cb, (near - ca.depth) / (cb.depth - ca.depth)) }
        if cb.depth < near { cb = lerp(cb, ca, (near - cb.depth) / (ca.depth - cb.depth)) }
        var p = Path()
        p.move(to: g.screen(ca))
        p.addLine(to: g.screen(cb))
        let avg = (ca.depth + cb.depth) / 2
        return (p, CGFloat(max(1, min(8, width * g.focal / avg))))
    }
}
