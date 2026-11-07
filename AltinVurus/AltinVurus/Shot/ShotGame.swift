import Observation
import QuartzCore
import SwiftUI

struct Vec3 {
    var x: Double
    var y: Double
    var z: Double
}

enum ShotOutcome: Equatable {
    case goal, saved, post, wide, blocked

    var title: String {
        switch self {
        case .goal: "GOOOL!"
        case .saved: "KURTARDI!"
        case .post: "DİREK!"
        case .wide: "AUT"
        case .blocked: "BARAJA TAKILDI"
        }
    }

    var feedText: String {
        switch self {
        case .goal: "GOL! Harika vuruş ⚽"
        case .saved: "Kaleci kurtardı"
        case .post: "Top direkten döndü"
        case .wide: "Top dışarı gitti"
        case .blocked: "Top baraja çarptı"
        }
    }

    var isGoal: Bool { self == .goal }
}

struct Kit {
    var primary: Color
    var secondary: Color
}

struct ShotConfig {
    var kind: ChanceKind
    var keeperSkill: Double
    var shooterSkill: Double
    var opponentKit: Kit
    var caption: String

    static func practice() -> ShotConfig {
        let team = GameData.teams.randomElement()!
        return ShotConfig(
            kind: [.inside, .inside, .longShot, .freeKick, .freeKick, .penalty].randomElement()!,
            keeperSkill: .random(in: 0.35...0.8),
            shooterSkill: 0.6,
            opponentKit: Kit(primary: team.primaryColor, secondary: team.secondaryColor),
            caption: ""
        )
    }
}

struct Particle {
    var x: Double
    var y: Double
    var vx: Double
    var vy: Double
    var rot: Double
    var life: Double
    var color: Color
}

/// Şut mini oyunu: 3B top fiziği, falso, kaleci, baraj.
/// Birimler metre ve saniye. Kale çizgisi z = 0, kale merkezi x = 0.
@Observable
final class ShotGame {
    enum Phase: Equatable { case aiming, flying, finished(ShotOutcome) }

    var phase: Phase = .aiming
    var outcome: ShotOutcome?

    @ObservationIgnored let config: ShotConfig
    @ObservationIgnored var size: CGSize = .zero
    @ObservationIgnored var time: Double = 0
    @ObservationIgnored private var lastDate: Date?

    @ObservationIgnored var start = Vec3(x: 0, y: ShotGame.ballRadius, z: 11)
    @ObservationIgnored var ball = Vec3(x: 0, y: ShotGame.ballRadius, z: 11)
    @ObservationIgnored var vel = Vec3(x: 0, y: 0, z: 0)
    @ObservationIgnored private var curve: Double = 0
    @ObservationIgnored var spin: Double = 0
    @ObservationIgnored private var spinRate: Double = 0

    // Kamera
    @ObservationIgnored var cam = Vec3(x: 0, y: 2.1, z: 13.6)
    @ObservationIgnored var forwardX: Double = 0
    @ObservationIgnored var forwardZ: Double = -1
    @ObservationIgnored var focal: Double = 400
    @ObservationIgnored var horizonY: Double = 250

    // Kaleci
    @ObservationIgnored var keeperX: Double = 0
    @ObservationIgnored var keeperLift: Double = 0
    @ObservationIgnored var keeperDiving = false
    @ObservationIgnored var keeperDiveStartX: Double = 0
    @ObservationIgnored private var keeperBaseX: Double = 0
    @ObservationIgnored private var keeperTargetX: Double = 0
    @ObservationIgnored private var keeperTargetLift: Double = 0
    @ObservationIgnored private var keeperReactAt: Double = .infinity

    // Baraj
    @ObservationIgnored var wallXs: [Double] = []
    @ObservationIgnored var wallZ: Double = 0
    @ObservationIgnored var wallJump: Double = 0
    @ObservationIgnored private var wallJumpAt: Double = .infinity

    @ObservationIgnored private var checkedWall = false
    @ObservationIgnored private var checkedKeeper = false
    @ObservationIgnored private var checkedGoal = false
    @ObservationIgnored private var shotTime: Double = 0
    @ObservationIgnored private var result: ShotOutcome?
    @ObservationIgnored private var resolvedAt: Double?
    @ObservationIgnored private var finishedSent = false
    @ObservationIgnored var inNet = false
    @ObservationIgnored var netShake: Double = 0
    @ObservationIgnored var celebrating = false

    @ObservationIgnored var drag: [(point: CGPoint, time: Double)] = []
    @ObservationIgnored var particles: [Particle] = []

    static let goalHalfWidth = 3.66
    static let goalHeight = 2.44
    static let ballRadius = 0.11
    static let gravity = 9.81

    init(config: ShotConfig) {
        self.config = config
        setupPosition()
    }

    // MARK: - Kurulum

    private func setupPosition() {
        let side: Double = Bool.random() ? 1 : -1
        let r = Self.ballRadius
        switch config.kind {
        case .penalty: start = Vec3(x: 0, y: r, z: 11)
        case .inside: start = Vec3(x: side * .random(in: 0...9), y: r, z: .random(in: 11...16))
        case .longShot: start = Vec3(x: side * .random(in: 0...11), y: r, z: .random(in: 19...26))
        case .freeKick: start = Vec3(x: side * .random(in: 1...12), y: r, z: .random(in: 19...27))
        }
        ball = start

        // Kamera topun arkasında, kale merkezine bakıyor
        let len = hypot(start.x, start.z)
        let dx = start.x / len, dz = start.z / len
        cam = Vec3(x: start.x + dx * 2.6, y: 2.1, z: start.z + dz * 2.6)
        forwardX = -dx
        forwardZ = -dz

        if config.kind == .freeKick {
            let nearPost = start.x >= 0 ? 1.4 : -1.4
            let ox = nearPost - start.x, oz = -start.z
            let l = hypot(ox, oz)
            let cx = start.x + ox / l * 9.15
            wallZ = start.z + oz / l * 9.15
            let count = start.z > 23 ? 5 : 4
            wallXs = (0..<count).map { cx + (Double($0) - Double(count - 1) / 2) * 0.62 }
        }

        keeperBaseX = config.kind == .penalty ? 0 : max(-1.2, min(1.2, start.x * 0.15))
        keeperX = keeperBaseX
    }

    func setup(size: CGSize) {
        guard size != self.size, size.width > 0 else { return }
        self.size = size
        focal = size.width * 1.15
        horizonY = size.height * 0.3
    }

    // MARK: - Projeksiyon

    func toCamera(_ p: Vec3) -> (lat: Double, up: Double, depth: Double) {
        let dx = p.x - cam.x, dz = p.z - cam.z
        let depth = dx * forwardX + dz * forwardZ
        let lat = dx * (-forwardZ) + dz * forwardX
        return (lat, p.y - cam.y, depth)
    }

    func screen(_ c: (lat: Double, up: Double, depth: Double)) -> CGPoint {
        CGPoint(x: size.width / 2 + c.lat * focal / c.depth, y: horizonY - c.up * focal / c.depth)
    }

    func project(_ p: Vec3) -> CGPoint? {
        let c = toCamera(p)
        guard c.depth > 0.2 else { return nil }
        return screen(c)
    }

    func scale(at p: Vec3) -> Double { focal / max(0.2, toCamera(p).depth) }

    /// Ekrandaki bir noktanın kale düzlemindeki (z = 0) karşılığı
    func goalPlanePoint(_ s: CGPoint) -> (x: Double, y: Double)? {
        let lat = (Double(s.x) - size.width / 2) / focal
        let up = (horizonY - Double(s.y)) / focal
        let dx = lat * (-forwardZ) + forwardX
        let dz = lat * forwardX + forwardZ
        guard dz < -0.01 else { return nil }
        let t = -cam.z / dz
        return (cam.x + t * dx, cam.y + t * up)
    }

    // MARK: - Dokunma

    func dragChanged(_ p: CGPoint) {
        guard phase == .aiming else { return }
        if drag.isEmpty, Double(p.y) < size.height * 0.45 { return }
        drag.append((p, CACurrentMediaTime()))
    }

    func shoot() {
        defer { drag = [] }
        guard phase == .aiming, drag.count >= 3, let first = drag.first, let last = drag.last else { return }
        let dy = Double(first.point.y - last.point.y)
        guard dy > 40, let ballScreen = project(ball) else { return }

        let window = drag.filter { last.time - $0.time <= 0.12 }
        let r0 = window.first ?? first
        let dt = max(1.0 / 60, last.time - r0.time)
        let speedPx = hypot(Double(last.point.x - r0.point.x), Double(last.point.y - r0.point.y)) / dt
        let power = min(1, max(0, (speedPx - 500) / 2500))

        // Yön: kaydırma çizgisinin kale hizasına uzantısı.
        // Yükseklik: kaydırmanın top–kale mesafesine oranı (her mesafede aynı his).
        guard let goalBase = project(Vec3(x: 0, y: 0, z: 0)),
              let goalTop = project(Vec3(x: 0, y: Self.goalHeight, z: 0)) else { return }
        let reach = max(60, Double(ballScreen.y - goalBase.y))
        let ratio = dy / reach
        let midY = (goalBase.y + goalTop.y) / 2
        let lateral = Double(last.point.x - first.point.x) / dy * Double(ballScreen.y - midY)
        guard var target = goalPlanePoint(CGPoint(x: ballScreen.x + CGFloat(lateral), y: midY)) else { return }
        target.y = (ratio - 0.55) * 4.2

        let sigma = 0.12 + (1 - config.shooterSkill) * 0.3 + power * 0.3
        target.x += gaussian() * sigma
        target.y += gaussian() * sigma * 0.6 + power * 0.25
        target.y = max(0.15, target.y)

        curve = max(-9, min(9, -curveDeviation() / 11 * (1 - power * 0.4)))
        let speed = 15 + power * 16
        let dist = hypot(target.x - ball.x, ball.z)
        let t = dist / speed
        vel = Vec3(
            x: (target.x - ball.x - 0.5 * curve * t * t) / t,
            y: (target.y - ball.y + 0.5 * Self.gravity * t * t) / t,
            z: -ball.z / t
        )
        spinRate = 10 + power * 20 + abs(curve) * 2

        keeperReactAt = time + (config.kind == .penalty ? 0.1 : 0.3 - config.keeperSkill * 0.14 + .random(in: 0...0.06))
        wallJumpAt = time + 0.1
        shotTime = time
        phase = .flying
        SFX.kick()
    }

    /// Kaydırma yolunun düz çizgiden ne kadar saptığı (piksel, işaretli)
    private func curveDeviation() -> Double {
        guard let a = drag.first?.point, let b = drag.last?.point else { return 0 }
        let bx = Double(b.x - a.x), by = Double(b.y - a.y)
        let len = max(1, hypot(bx, by))
        var best = 0.0
        for d in drag {
            let px = Double(d.point.x - a.x), py = Double(d.point.y - a.y)
            let cross = (bx * py - by * px) / len
            if abs(cross) > abs(best) { best = cross }
        }
        return best
    }

    // MARK: - Güncelleme

    func update(_ now: Date) {
        let dt = min(now.timeIntervalSince(lastDate ?? now), 1.0 / 30)
        lastDate = now
        time += dt

        updateKeeper(dt)
        if time >= wallJumpAt {
            wallJump = 0.45 * max(0, sin(min(.pi, (time - wallJumpAt) * 5)))
        }
        updateBall(dt)
        netShake = max(0, netShake - dt * 1.4)
        updateParticles(dt)

        if let r = resolvedAt, let res = result, time - r > 1.8, !finishedSent {
            finishedSent = true
            DispatchQueue.main.async { self.phase = .finished(res) }
        }
    }

    private func updateKeeper(_ dt: Double) {
        if phase == .aiming {
            keeperX = keeperBaseX + sin(time * 2.1) * 0.22
            return
        }
        if !keeperDiving, time >= keeperReactAt, result == nil || result == .blocked {
            keeperDiving = true
            keeperDiveStartX = keeperX
            let t = max(0.05, ball.z / max(1, -vel.z))
            // Kaleci falsoyu tam okuyamaz: tahmininde eğrilik yok
            var px = ball.x + vel.x * t
            var py = ball.y + vel.y * t - 0.5 * Self.gravity * t * t
            if config.kind == .penalty, Double.random(in: 0...1) > 0.3 + config.keeperSkill * 0.35 {
                px = Bool.random() ? 2.6 : -2.6
                py = .random(in: 0.3...1.5)
            } else {
                let err = 0.25 + (1 - config.keeperSkill) * 0.8
                px += gaussian() * err
                py += gaussian() * err * 0.5
            }
            keeperTargetX = max(-3.5, min(3.5, px))
            keeperTargetLift = max(0, min(0.8, py - 1.1))
        }
        if keeperDiving {
            let speed = 4.0 + config.keeperSkill * 3.4
            let dx = keeperTargetX - keeperX
            keeperX += max(-speed * dt, min(speed * dt, dx))
            let dl = keeperTargetLift - keeperLift
            keeperLift += max(-3 * dt, min(3 * dt, dl))
        }
    }

    private func updateBall(_ dt: Double) {
        guard phase != .aiming else { return }
        let steps = 4
        let h = dt / Double(steps)
        for _ in 0..<steps {
            if inNet {
                vel.x *= 0.92
                vel.z *= 0.92
                vel.y -= Self.gravity * h
                ball.x += vel.x * h
                ball.z = max(-1.7, ball.z + vel.z * h)
                ball.y = max(Self.ballRadius, ball.y + vel.y * h)
                continue
            }
            vel.x += curve * h
            vel.y -= Self.gravity * h
            ball.x += vel.x * h
            ball.y += vel.y * h
            ball.z += vel.z * h
            if ball.y < Self.ballRadius {
                ball.y = Self.ballRadius
                vel.y = abs(vel.y) * 0.5
                vel.x *= 0.85
                vel.z *= 0.85
            }
            checkEvents()
        }
        spin += spinRate * dt
        if result == nil, time - shotTime > 3.2 { resolve(.wide) }
    }

    private func checkEvents() {
        if !checkedWall, !wallXs.isEmpty, ball.z <= wallZ {
            checkedWall = true
            if ball.y < 1.85 + wallJump, wallXs.contains(where: { abs($0 - ball.x) < 0.33 }) {
                vel = Vec3(x: .random(in: -3...3), y: 3, z: abs(vel.z) * 0.25)
                curve = 0
                resolve(.blocked)
                return
            }
        }
        guard result == nil else { return }

        if !checkedKeeper, ball.z <= 0.45 {
            checkedKeeper = true
            let reachX = (keeperDiving ? 0.8 : 0.5) + config.keeperSkill * 0.25
            let reachTop = 1.85 + keeperLift * 0.7 + 0.3
            let reachBottom = max(0, keeperLift - 0.35)
            if abs(ball.x - keeperX) < reachX, ball.y < reachTop, ball.y > reachBottom {
                vel = Vec3(x: vel.x * 0.2 + .random(in: -4...4), y: .random(in: 2...5), z: abs(vel.z) * 0.3)
                curve = 0
                resolve(.saved)
                return
            }
        }

        if !checkedGoal, ball.z <= 0 {
            checkedGoal = true
            let ax = abs(ball.x)
            let hitPost = abs(ax - Self.goalHalfWidth) < 0.17 && ball.y < Self.goalHeight + 0.1
            let hitBar = abs(ball.y - Self.goalHeight) < 0.15 && ax < Self.goalHalfWidth + 0.1
            if hitPost || hitBar {
                vel = Vec3(x: hitPost ? -vel.x * 0.6 : vel.x,
                           y: hitBar ? -abs(vel.y) * 0.4 + 1 : vel.y,
                           z: abs(vel.z) * 0.45)
                curve = 0
                ball.z = 0.05
                resolve(.post)
            } else if ax < Self.goalHalfWidth - Self.ballRadius, ball.y < Self.goalHeight - Self.ballRadius {
                inNet = true
                netShake = 1
                resolve(.goal)
            } else {
                resolve(.wide)
            }
        }
    }

    private func resolve(_ o: ShotOutcome) {
        guard result == nil else { return }
        result = o
        resolvedAt = time
        switch o {
        case .goal:
            celebrating = true
            SFX.goal()
            spawnConfetti()
        case .saved, .blocked: SFX.save()
        case .post: SFX.post()
        case .wide: SFX.miss()
        }
        DispatchQueue.main.async { self.outcome = o }
    }

    // MARK: - Konfeti

    private func spawnConfetti() {
        guard let p = project(Vec3(x: 0, y: 1.6, z: 0)) else { return }
        let colors: [Color] = [.yellow, .white, .orange, .green, .pink, .cyan]
        for _ in 0..<120 {
            let a = Double.random(in: -Double.pi...0)
            let s = Double.random(in: 250...750)
            particles.append(Particle(x: Double(p.x), y: Double(p.y), vx: cos(a) * s, vy: sin(a) * s,
                                      rot: .random(in: 0...6), life: .random(in: 1.4...2.4),
                                      color: colors.randomElement()!))
        }
    }

    private func updateParticles(_ dt: Double) {
        guard !particles.isEmpty else { return }
        for i in particles.indices {
            particles[i].vy += 700 * dt
            particles[i].vx *= 0.985
            particles[i].x += particles[i].vx * dt
            particles[i].y += particles[i].vy * dt
            particles[i].rot += 6 * dt
            particles[i].life -= dt
        }
        particles.removeAll { $0.life <= 0 }
    }
}

func gaussian() -> Double {
    let u1 = Double.random(in: 0.0001...1), u2 = Double.random(in: 0...1)
    return sqrt(-2 * log(u1)) * cos(2 * .pi * u2)
}

func hash01(_ a: Int, _ b: Int) -> Double {
    var x = UInt64(bitPattern: Int64(a &* 73_856_093 ^ b &* 19_349_663))
    x ^= x >> 33
    x &*= 0xff51_afd7_ed55_8ccd
    x ^= x >> 33
    x &*= 0xc4ce_b9fe_1a85_ec53
    x ^= x >> 33
    return Double(x % 10_000) / 10_000
}
