import Foundation

/// Gerçek para hareketi için lisanslı bir ödeme kuruluşunun / bankanın SDK'sı bu protokolü uygular.
/// Kart numarası yalnızca tokenize() çağrısında, doğrudan kuruluşa gider.
protocol PaymentProvider {
    func tokenize(pan: String, expMonth: Int, expYear: Int, cvv: String, holder: String) async throws -> String
    func pay(cardToken: String, karekod: KarekodPayload, amount: Decimal) async throws -> PaymentReceipt
}

struct PaymentReceipt {
    let reference: String
    let amount: Decimal
    let currency: String
    let merchant: String
    let date: Date
}

enum Payments {
    /// Gerçek sağlayıcıya geçerken yalnızca bu satırı değiştirin.
    static let provider: PaymentProvider = DemoPaymentProvider()
}

/// DEMO: Para çekmez. Arayüzü ve akışı denemek içindir.
struct DemoPaymentProvider: PaymentProvider {
    func tokenize(pan: String, expMonth: Int, expYear: Int, cvv: String, holder: String) async throws -> String {
        try await Task.sleep(for: .milliseconds(600))
        return "demo_tok_" + UUID().uuidString
    }

    func pay(cardToken: String, karekod: KarekodPayload, amount: Decimal) async throws -> PaymentReceipt {
        try await Task.sleep(for: .seconds(1))
        return PaymentReceipt(
            reference: String(UUID().uuidString.prefix(8)),
            amount: amount,
            currency: karekod.currencyCode,
            merchant: karekod.merchantName,
            date: .now
        )
    }
}
