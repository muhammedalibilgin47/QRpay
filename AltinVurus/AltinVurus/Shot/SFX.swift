import AVFoundation
import UIKit

/// Ses efektleri kod içinde üretilir (dosya gerekmez). Telefon sessizdeyse ses çıkmaz.
enum SFX {
    static var muted: Bool {
        get { UserDefaults.standard.bool(forKey: "muted") }
        set { UserDefaults.standard.set(newValue, forKey: "muted") }
    }

    static func kick() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        Synth.shared.play(.kick)
    }

    static func goal() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        Synth.shared.play(.crowd)
    }

    static func save() {
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        Synth.shared.play(.ooh)
    }

    static func post() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        Synth.shared.play(.clang)
        Synth.shared.play(.ooh)
    }

    static func miss() { Synth.shared.play(.ooh) }

    static func whistle() { Synth.shared.play(.whistle) }

    static func concede() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        Synth.shared.play(.ooh)
    }

    static func tap() { UISelectionFeedbackGenerator().selectionChanged() }
}

final class Synth {
    enum Sound: CaseIterable { case kick, crowd, ooh, clang, whistle }

    static let shared = Synth()

    private let engine = AVAudioEngine()
    private var players: [AVAudioPlayerNode] = []
    private var next = 0
    private let rate = 44_100.0
    private let format: AVAudioFormat
    private var buffers: [Sound: AVAudioPCMBuffer] = [:]

    private init() {
        format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1)!
        try? AVAudioSession.sharedInstance().setCategory(.ambient)
        for _ in 0..<4 {
            let p = AVAudioPlayerNode()
            engine.attach(p)
            engine.connect(p, to: engine.mainMixerNode, format: format)
            players.append(p)
        }
        try? engine.start()
        players.forEach { $0.play() }
    }

    func play(_ sound: Sound) {
        guard !SFX.muted else { return }
        let buffer = buffers[sound] ?? make(sound)
        buffers[sound] = buffer
        if !engine.isRunning {
            try? engine.start()
            players.forEach { $0.play() }
        }
        let p = players[next]
        next = (next + 1) % players.count
        p.scheduleBuffer(buffer, at: nil, options: .interrupts)
    }

    private func make(_ sound: Sound) -> AVAudioPCMBuffer {
        switch sound {
        case .kick:
            return render(0.18) { t, n in
                let f = 140 - 80 * min(1, t / 0.12)
                return sin(2 * .pi * f * t) * exp(-t * 28) * 0.8 + n * exp(-t * 90) * 0.4
            }
        case .crowd:
            var lp = 0.0
            return render(2.6) { t, n in
                lp += 0.07 * (n - lp)
                let env = min(1, t / 0.15) * exp(-max(0, t - 0.6) * 1.4)
                let swell = 0.75 + 0.25 * sin(2 * .pi * 3.1 * t)
                return lp * env * swell * 2.6
            }
        case .ooh:
            var lp = 0.0
            return render(1.0) { t, n in
                lp += 0.04 * (n - lp)
                let env = min(1, t / 0.12) * exp(-max(0, t - 0.25) * 3)
                return (lp * 3 + sin(2 * .pi * 210 * t) * 0.05) * env
            }
        case .clang:
            return render(0.7) { t, _ in
                (sin(2 * .pi * 1250 * t) + sin(2 * .pi * 1870 * t) * 0.7 + sin(2 * .pi * 2630 * t) * 0.4)
                    * exp(-t * 6) * 0.22
            }
        case .whistle:
            return render(0.55) { t, _ in
                let env = min(1, t / 0.02) * min(1, max(0, 0.55 - t) / 0.06)
                return sin(2 * .pi * 2850 * t + 3 * sin(2 * .pi * 32 * t)) * env * 0.22
            }
        }
    }

    private func render(_ duration: Double, _ sample: (Double, Double) -> Double) -> AVAudioPCMBuffer {
        let frames = AVAudioFrameCount(rate * duration)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames
        let data = buffer.floatChannelData![0]
        for i in 0..<Int(frames) {
            let v = sample(Double(i) / rate, Double.random(in: -1...1))
            data[i] = Float(max(-1, min(1, v)))
        }
        return buffer
    }
}
