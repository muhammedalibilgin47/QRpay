import SwiftUI

struct AddCardView: View {
    @Environment(CardStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var holder = ""
    @State private var number = ""
    @State private var expiry = ""
    @State private var cvv = ""
    @State private var saving = false
    @State private var error: String?

    private var digits: String { number.filter(\.isNumber) }
    private var brand: CardBrand { CardBrand.detect(digits) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Kart üzerindeki isim", text: $holder)
                        .textContentType(.name)
                        .textInputAutocapitalization(.characters)
                    HStack {
                        TextField("Kart numarası", text: $number)
                            .keyboardType(.numberPad)
                            .textContentType(.creditCardNumber)
                            .onChange(of: number) { _, new in number = Self.groupDigits(new) }
                        if !digits.isEmpty {
                            Text(brand.shortName).font(.caption.bold()).foregroundStyle(brand.color)
                        }
                    }
                    HStack {
                        TextField("AA/YY", text: $expiry)
                            .keyboardType(.numberPad)
                            .onChange(of: expiry) { _, new in expiry = Self.formatExpiry(new) }
                        SecureField("CVV", text: $cvv)
                            .keyboardType(.numberPad)
                            .onChange(of: cvv) { _, new in cvv = String(new.filter(\.isNumber).prefix(4)) }
                    }
                } footer: {
                    Text("Kart numarası ve CVV telefona kaydedilmez; doğrudan ödeme kuruluşuna gönderilir, telefonda yalnızca son 4 hane ve güvenli bir token kalır.")
                }

                if let error {
                    Section { Text(error).foregroundStyle(.red) }
                }
            }
            .navigationTitle("Kart Ekle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Vazgeç") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    if saving { ProgressView() } else { Button("Kaydet") { Task { await save() } } }
                }
            }
            .interactiveDismissDisabled(saving)
        }
    }

    private func save() async {
        error = nil
        let parts = expiry.split(separator: "/").compactMap { Int($0) }
        guard !holder.trimmingCharacters(in: .whitespaces).isEmpty else { error = "İsim girin."; return }
        guard Luhn.isValid(digits) else { error = "Kart numarası geçersiz."; return }
        guard parts.count == 2, (1...12).contains(parts[0]) else { error = "Son kullanma tarihi geçersiz."; return }
        let month = parts[0], year = 2000 + parts[1]
        let now = Calendar.current.dateComponents([.year, .month], from: .now)
        guard year > now.year! || (year == now.year! && month >= now.month!) else { error = "Kartın süresi dolmuş."; return }
        guard cvv.count >= 3 else { error = "CVV geçersiz."; return }

        saving = true
        defer { saving = false }
        do {
            let token = try await Payments.provider.tokenize(
                pan: digits, expMonth: month, expYear: year, cvv: cvv, holder: holder
            )
            store.add(Card(holder: holder.uppercased(), last4: String(digits.suffix(4)),
                           brand: brand, expMonth: month, expYear: year, token: token))
            number = ""; cvv = ""
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }

    static func groupDigits(_ s: String) -> String {
        let d = String(s.filter(\.isNumber).prefix(19))
        return stride(from: 0, to: d.count, by: 4).map { i in
            let start = d.index(d.startIndex, offsetBy: i)
            let end = d.index(start, offsetBy: min(4, d.count - i))
            return String(d[start..<end])
        }.joined(separator: " ")
    }

    static func formatExpiry(_ s: String) -> String {
        let d = String(s.filter(\.isNumber).prefix(4))
        return d.count > 2 ? "\(d.prefix(2))/\(d.dropFirst(2))" : d
    }
}
