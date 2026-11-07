import Foundation
import Observation
import Security

@Observable
final class CardStore {
    private(set) var cards: [Card] = []

    var defaultCardID: UUID? {
        didSet { UserDefaults.standard.set(defaultCardID?.uuidString, forKey: "defaultCardID") }
    }

    var defaultCard: Card? {
        cards.first { $0.id == defaultCardID } ?? cards.first
    }

    init() {
        cards = Keychain.loadCards()
        defaultCardID = UserDefaults.standard.string(forKey: "defaultCardID").flatMap(UUID.init)
    }

    func add(_ card: Card) {
        cards.append(card)
        if defaultCardID == nil { defaultCardID = card.id }
        Keychain.save(cards)
    }

    func delete(at offsets: IndexSet) {
        cards.remove(atOffsets: offsets)
        if !cards.contains(where: { $0.id == defaultCardID }) { defaultCardID = cards.first?.id }
        Keychain.save(cards)
    }
}

/// Kart listesi şifreli Anahtar Zinciri'nde, yalnızca bu cihazda ve kilit açıkken okunabilir.
private enum Keychain {
    static let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "com.tiyzi.qrpay",
        kSecAttrAccount as String: "cards",
    ]

    static func loadCards() -> [Card] {
        var q = query
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let cards = try? JSONDecoder().decode([Card].self, from: data)
        else { return [] }
        return cards
    }

    static func save(_ cards: [Card]) {
        guard let data = try? JSONEncoder().encode(cards) else { return }
        SecItemDelete(query as CFDictionary)
        var q = query
        q[kSecValueData as String] = data
        q[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        SecItemAdd(q as CFDictionary, nil)
    }
}
