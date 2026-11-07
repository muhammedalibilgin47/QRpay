import LocalAuthentication
import SwiftUI

struct PaymentView: View {
    let payload: String

    @Environment(CardStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var karekod: KarekodPayload?
    @State private var parseError: String?
    @State private var amountText = ""
    @State private var cardID: UUID?
    @State private var paying = false
    @State private var payError: String?
    @State private var receipt: PaymentReceipt?

    private var amount: Decimal? {
        if let fixed = karekod?.amount { return fixed }
        return Decimal(string: amountText.replacingOccurrences(of: ",", with: "."))
    }

    private var selectedCard: Card? {
        store.cards.first { $0.id == cardID } ?? store.defaultCard
    }

    var body: some View {
        NavigationStack {
            Group {
                if let receipt {
                    SuccessView(receipt: receipt) { dismiss() }
                } else if let parseError {
                    ContentUnavailableView("Ödenemiyor", systemImage: "exclamationmark.triangle", description: Text(parseError))
                } else if let karekod {
                    form(karekod)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Ödeme")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if receipt == nil {
                    ToolbarItem(placement: .cancellationAction) { Button("Vazgeç") { dismiss() } }
                }
            }
        }
        .interactiveDismissDisabled(paying)
        .task {
            do { karekod = try KarekodParser.parse(payload) }
            catch { parseError = error.localizedDescription }
        }
    }

    @ViewBuilder
    private func form(_ k: KarekodPayload) -> some View {
        Form {
            Section("İşyeri") {
                LabeledContent("Ad", value: k.merchantName)
                if let city = k.city { LabeledContent("Şehir", value: city) }
            }

            Section("Tutar") {
                if let fixed = k.amount {
                    Text(format(fixed, k.currencyCode)).font(.largeTitle.bold())
                } else {
                    HStack {
                        TextField("0,00", text: $amountText)
                            .keyboardType(.decimalPad)
                            .font(.largeTitle.bold())
                        Text(k.currencyCode).foregroundStyle(.secondary)
                    }
                }
            }

            Section("Kart") {
                if store.cards.isEmpty {
                    Text("Önce ana ekrandan bir kart ekleyin.").foregroundStyle(.secondary)
                } else {
                    Picker("Kart", selection: Binding(get: { selectedCard?.id }, set: { cardID = $0 })) {
                        ForEach(store.cards) { card in
                            Text("\(card.brand.shortName) •••• \(card.last4)").tag(Optional(card.id))
                        }
                    }
                }
            }

            if let payError {
                Section { Text(payError).foregroundStyle(.red) }
            }

            Section {
                Button {
                    Task { await pay(k) }
                } label: {
                    HStack {
                        Spacer()
                        if paying { ProgressView() } else {
                            Label("Öde \(amount.map { format($0, k.currencyCode) } ?? "")", systemImage: "faceid")
                                .bold()
                        }
                        Spacer()
                    }
                }
                .disabled(paying || selectedCard == nil || (amount ?? 0) <= 0)
            }
        }
    }

    private func pay(_ k: KarekodPayload) async {
        guard let card = selectedCard, let amount, amount > 0 else { return }
        payError = nil
        guard await authenticate(amount: format(amount, k.currencyCode), merchant: k.merchantName) else {
            payError = "Onay alınamadı."
            return
        }
        paying = true
        defer { paying = false }
        do {
            receipt = try await Payments.provider.pay(cardToken: card.token, karekod: k, amount: amount)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            payError = error.localizedDescription
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    private func authenticate(amount: String, merchant: String) async -> Bool {
        let context = LAContext()
        var err: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &err) else { return false }
        return (try? await context.evaluatePolicy(
            .deviceOwnerAuthentication,
            localizedReason: "\(merchant) için \(amount) ödemesini onayla"
        )) ?? false
    }
}

private func format(_ value: Decimal, _ currency: String) -> String {
    value.formatted(.number.precision(.fractionLength(2)).locale(Locale(identifier: "tr_TR"))) + " " + currency
}

private struct SuccessView: View {
    let receipt: PaymentReceipt
    let done: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 88))
                .foregroundStyle(.green)
                .symbolEffect(.bounce, value: receipt.reference)
            Text("Ödeme tamam").font(.title.bold())
            Text(format(receipt.amount, receipt.currency)).font(.largeTitle.monospacedDigit())
            Text(receipt.merchant).foregroundStyle(.secondary)
            Text("Ref: \(receipt.reference)").font(.caption.monospaced()).foregroundStyle(.secondary)
            Spacer()
            Button("Bitti", action: done)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.bottom)
        }
        .frame(maxWidth: .infinity)
    }
}
