import Foundation
import Observation
import SwiftUI

@Observable
final class CareerStore {
    private static let key = "career.v1"

    var career: Career? {
        didSet { save() }
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let c = try? JSONDecoder().decode(Career.self, from: data) {
            career = c
        }
    }

    func update(_ change: (inout Career) -> Void) {
        guard var c = career else { return }
        change(&c)
        career = c
    }

    private func save() {
        if let career, let data = try? JSONEncoder().encode(career) {
            UserDefaults.standard.set(data, forKey: Self.key)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.key)
        }
    }
}

extension Color {
    init(hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let v = UInt64(s, radix: 16) ?? 0
        self.init(red: Double((v >> 16) & 0xFF) / 255,
                  green: Double((v >> 8) & 0xFF) / 255,
                  blue: Double(v & 0xFF) / 255)
    }
}

extension Team {
    var primaryColor: Color { Color(hex: primary) }
    var secondaryColor: Color { Color(hex: secondary) }
}
