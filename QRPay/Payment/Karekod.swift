import Foundation

/// TR Karekod (TCMB standardı, EMVCo QR tabanlı) çözümleyici.
struct KarekodPayload {
    let raw: String
    let fields: [String: String]

    var merchantName: String { fields["59"] ?? "Bilinmeyen işyeri" }
    var city: String? { fields["60"] }
    /// Dinamik karekodda tutar karekodun içindedir; statik karekodda kullanıcı girer.
    var amount: Decimal? { fields["54"].flatMap { Decimal(string: $0) } }
    var isDynamic: Bool { fields["01"] == "12" }
    var currencyCode: String {
        switch fields["53"] {
        case "949", nil: "TL"
        case "840": "USD"
        case "978": "EUR"
        case let other?: other
        }
    }
}

enum KarekodParser {
    enum ParseError: LocalizedError {
        case notPayment, badChecksum

        var errorDescription: String? {
            switch self {
            case .notPayment: "Bu bir ödeme karekodu değil."
            case .badChecksum: "Karekod bozuk veya değiştirilmiş görünüyor. Ödeme yapmayın."
            }
        }
    }

    static func parse(_ string: String) throws -> KarekodPayload {
        let chars = Array(string)
        var fields: [String: String] = [:]
        var i = 0
        while i < chars.count {
            guard i + 4 <= chars.count,
                  let length = Int(String(chars[i + 2..<i + 4])),
                  i + 4 + length <= chars.count
            else { throw ParseError.notPayment }
            let tag = String(chars[i..<i + 2])
            fields[tag] = String(chars[i + 4..<i + 4 + length])
            i += 4 + length
        }
        guard fields["00"] == "01" else { throw ParseError.notPayment }

        if let crc = fields["63"] {
            // CRC, "6304" dahil son 4 karakter hariç tüm metin üzerinden hesaplanır.
            let body = String(chars.dropLast(4))
            guard crc16(body) == crc.uppercased() else { throw ParseError.badChecksum }
        }
        return KarekodPayload(raw: string, fields: fields)
    }

    /// CRC-16/CCITT-FALSE (poly 0x1021, başlangıç 0xFFFF)
    static func crc16(_ s: String) -> String {
        var crc: UInt16 = 0xFFFF
        for byte in s.utf8 {
            crc ^= UInt16(byte) << 8
            for _ in 0..<8 {
                crc = (crc & 0x8000) != 0 ? (crc << 1) ^ 0x1021 : crc << 1
            }
        }
        return String(format: "%04X", crc)
    }
}
