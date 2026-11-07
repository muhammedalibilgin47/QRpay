import SwiftUI

/// Kayıtlı kart. Kart numarası ve CVV ASLA saklanmaz:
/// yalnızca son 4 hane ve ödeme kuruluşunun verdiği token tutulur.
struct Card: Identifiable, Codable, Hashable {
    var id = UUID()
    var holder: String
    var last4: String
    var brand: CardBrand
    var expMonth: Int
    var expYear: Int
    var token: String
}

enum CardBrand: String, Codable {
    case visa, mastercard, troy, amex, unknown

    static func detect(_ pan: String) -> CardBrand {
        let p2 = Int(pan.prefix(2)) ?? 0
        let p4 = Int(pan.prefix(4)) ?? 0
        if pan.hasPrefix("4") { return .visa }
        if (51...55).contains(p2) || (2221...2720).contains(p4) { return .mastercard }
        if pan.hasPrefix("9792") || pan.hasPrefix("65") { return .troy }
        if p2 == 34 || p2 == 37 { return .amex }
        return .unknown
    }

    var shortName: String {
        switch self {
        case .visa: "VISA"
        case .mastercard: "MC"
        case .troy: "TROY"
        case .amex: "AMEX"
        case .unknown: "KART"
        }
    }

    var color: Color {
        switch self {
        case .visa: .blue
        case .mastercard: .orange
        case .troy: .teal
        case .amex: .indigo
        case .unknown: .gray
        }
    }
}

enum Luhn {
    static func isValid(_ number: String) -> Bool {
        let digits = number.compactMap(\.wholeNumberValue)
        guard (13...19).contains(digits.count), digits.count == number.count else { return false }
        let sum = digits.reversed().enumerated().reduce(0) { acc, item in
            let (i, d) = item
            guard i % 2 == 1 else { return acc + d }
            let doubled = d * 2
            return acc + (doubled > 9 ? doubled - 9 : doubled)
        }
        return sum % 10 == 0
    }
}
