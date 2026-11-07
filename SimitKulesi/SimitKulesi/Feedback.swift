import AVFoundation
import UIKit

/// Titreşim ve ses. Sesler kod içinde üretilir, dosya gerekmez.
/// Telefon sessize alınmışsa ses çıkmaz (ambient).
enum Feedback {
    static var muted: Bool {
        get { UserDefaults.standard.bool(forKey: "muted") }
        set { UserDefaults.standard.set(newValue, forKey: "muted") }
    }

    static func place() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        Synth.shared.play(note: -2)
    }

    /// Art arda mükemmel koydukça ses inceliyor.
    static func perfect(combo: Int) {
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: min(1, 0.6 + CGFloat(combo) * 0.1))
        Synth.shared.play(note: min(3 + combo * 2, 27))
    }

    static func fail() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        Synth.shared.play(note: -14, duration: 0.45)
    }
}

final class Synth {
    static let shared = Synth()

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    private var cache: [String: AVAudioPCMBuffer] = [:]

    private init() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient)
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        try? engine.start()
        player.play()
    }

    func play(note: Int, duration: Double = 0.18) {
        guard !Feedback.muted else { return }
        let key = "\(note)-\(duration)"
        let buffer = cache[key] ?? makeTone(note: note, duration: duration)
        cache[key] = buffer
        if !engine.isRunning {
            try? engine.start()
            player.play()
        }
        player.scheduleBuffer(buffer, at: nil, options: .interrupts)
    }

    private func makeTone(note: Int, duration: Double) -> AVAudioPCMBuffer {
        let rate = 44_100.0
        let freq = 440 * pow(2, Double(note) / 12)
        let frames = AVAudioFrameCount(rate * duration)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames
        let data = buffer.floatChannelData![0]
        for i in 0..<Int(frames) {
            let t = Double(i) / rate
            let env = exp(-t * 16) * min(1, t * 400)
            let v = sin(2 * .pi * freq * t) * 0.32 + sin(4 * .pi * freq * t) * 0.08
            data[i] = Float(v * env)
        }
        return buffer
    }
}
