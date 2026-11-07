import Foundation
import Observation
import SwiftUI

struct Layer {
    var center: CGFloat
    var width: CGFloat
    var golden: Bool
}

struct Debris {
    var center: CGFloat
    var width: CGFloat
    var y: CGFloat
    var vy: CGFloat = 0
    var angle: CGFloat = 0
    var spin: CGFloat
    var golden: Bool
    var seed: Int
}

struct Popup {
    var text: String
    var y: CGFloat
    var age: CGFloat = 0
}

struct Star {
    let x: CGFloat
    let y: CGFloat
    let r: CGFloat
}

/// Oyun mantığı. Fizik/çizim durumu her karede değiştiği için gözlem dışı tutulur;
/// sadece arayüzü ilgilendiren skor ve aşama gözlemlenir.
@Observable
final class Game {
    enum Phase { case ready, playing, over }

    var phase: Phase = .ready
    var score = 0
    var best = UserDefaults.standard.integer(forKey: "best")
    var isNewBest = false

    @ObservationIgnored var combo = 0
    @ObservationIgnored var size: CGSize = .zero
    @ObservationIgnored var layers: [Layer] = []
    @ObservationIgnored var moving = Layer(center: 0, width: 0, golden: false)
    @ObservationIgnored var direction: CGFloat = 1
    @ObservationIgnored var debris: [Debris] = []
    @ObservationIgnored var popups: [Popup] = []
    @ObservationIgnored var camera: CGFloat = 0
    @ObservationIgnored var zoom: CGFloat = 1
    @ObservationIgnored var flash: CGFloat = 0
    @ObservationIgnored var lastTime: Date?
    @ObservationIgnored let stars: [Star] = (0..<70).map {
        Star(x: hash01($0, 1), y: hash01($0, 2), r: 1 + hash01($0, 3) * 2)
    }

    static let layerHeight: CGFloat = 30
    private let perfectTolerance: CGFloat = 6

    var baseWidth: CGFloat { min(size.width * 0.62, 300) }
    private var speed: CGFloat { min(170 + CGFloat(score) * 7, 560) }
    private var slideRange: CGFloat { size.width * 0.6 }

    // MARK: - Yaşam döngüsü

    func setup(size: CGSize) {
        guard size != self.size, size.width > 0 else { return }
        self.size = size
        if layers.isEmpty { resetWorld() }
    }

    func tap() {
        switch phase {
        case .ready: phase = .playing
        case .playing: place()
        case .over: break
        }
    }

    func restart() {
        score = 0
        combo = 0
        isNewBest = false
        resetWorld()
        phase = .playing
    }

    private func resetWorld() {
        layers = [Layer(center: size.width / 2, width: baseWidth, golden: false)]
        debris = []
        popups = []
        spawnMoving()
    }

    private func spawnMoving() {
        guard let top = layers.last else { return }
        direction = layers.count % 2 == 0 ? -1 : 1
        moving = Layer(
            center: top.center - direction * slideRange,
            width: top.width,
            golden: layers.count % 10 == 0
        )
    }

    // MARK: - Simidi bırak

    private func place() {
        guard let top = layers.last else { return }
        let delta = moving.center - top.center
        let y = CGFloat(layers.count) * Self.layerHeight

        if abs(delta) <= perfectTolerance {
            combo += 1
            var width = top.width
            if combo >= 3 { width = min(width + 6, baseWidth) }
            layers.append(Layer(center: top.center, width: width, golden: moving.golden))
            flash = 1
            popups.append(Popup(text: combo >= 2 ? "Mükemmel! x\(combo)" : "Mükemmel!", y: y))
            Feedback.perfect(combo: combo)
        } else {
            combo = 0
            let overlap = top.width - abs(delta)
            if overlap <= 0 {
                debris.append(Debris(center: moving.center, width: moving.width, y: y,
                                     spin: direction * 2, golden: moving.golden, seed: layers.count))
                gameOver()
                return
            }
            let cut = abs(delta)
            let cutCenter = delta > 0
                ? top.center + top.width / 2 + cut / 2
                : top.center - top.width / 2 - cut / 2
            layers.append(Layer(center: top.center + delta / 2, width: overlap, golden: moving.golden))
            debris.append(Debris(center: cutCenter, width: cut, y: y,
                                 spin: delta > 0 ? 2.5 : -2.5, golden: moving.golden, seed: layers.count))
            Feedback.place()
        }

        score += 1
        if score % 10 == 0 {
            popups.append(Popup(text: "\(score) simit! 🔥", y: y + 45))
        }
        spawnMoving()
    }

    private func gameOver() {
        phase = .over
        if score > best {
            best = score
            isNewBest = true
            UserDefaults.standard.set(best, forKey: "best")
        }
        Feedback.fail()
    }

    // MARK: - Kare güncelleme

    func update(_ now: Date) {
        let dt = CGFloat(min(now.timeIntervalSince(lastTime ?? now), 1.0 / 30))
        lastTime = now
        guard size.width > 0 else { return }

        if phase == .playing, let top = layers.last {
            moving.center += direction * speed * dt
            if moving.center > top.center + slideRange { moving.center = top.center + slideRange; direction = -1 }
            if moving.center < top.center - slideRange { moving.center = top.center - slideRange; direction = 1 }
        }

        for i in debris.indices {
            debris[i].vy -= 1800 * dt
            debris[i].y += debris[i].vy * dt
            debris[i].angle += debris[i].spin * dt
        }
        debris.removeAll { $0.y < camera - size.height * 3 }

        for i in popups.indices {
            popups[i].age += dt
            popups[i].y += 40 * dt
        }
        popups.removeAll { $0.age > 1.2 }

        flash = max(0, flash - dt * 3)

        let towerTop = CGFloat(layers.count) * Self.layerHeight
        let groundY = size.height * 0.82
        let targetCamera: CGFloat
        let targetZoom: CGFloat
        if phase == .over {
            targetCamera = 0
            targetZoom = min(1, (groundY - size.height * 0.2) / max(1, towerTop))
        } else {
            targetCamera = max(0, towerTop - size.height * 0.45)
            targetZoom = 1
        }
        let k = min(1, dt * 5)
        camera += (targetCamera - camera) * k
        zoom += (targetZoom - zoom) * k
    }
}

/// Sabit tohumlu sözde rastgele sayı (0...1). Susam ve yıldızlar her karede aynı yerde dursun diye.
func hash01(_ a: Int, _ b: Int) -> CGFloat {
    var x = UInt64(bitPattern: Int64(a &* 73_856_093 ^ b &* 19_349_663))
    x ^= x >> 33
    x &*= 0xff51_afd7_ed55_8ccd
    x ^= x >> 33
    x &*= 0xc4ce_b9fe_1a85_ec53
    x ^= x >> 33
    return CGFloat(x % 10_000) / 10_000
}
