import SwiftUI

struct ContentView: View {
    @Environment(Router.self) private var router
    @Environment(CardStore.self) private var store
    @State private var showAddCard = false
    @State private var pendingPayload: String?
    @State private var scanned: ScannedQR?

    var body: some View {
        @Bindable var router = router
        NavigationStack {
            List {
                Section {
                    Button {
                        router.showScanner = true
                    } label: {
                        Label("QR ile Öde", systemImage: "qrcode.viewfinder")
                            .font(.title3.bold())
                            .frame(maxWidth: .infinity, minHeight: 56)
                    }
                    .buttonStyle(.borderedProminent)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                Section("Kartlarım") {
                    if store.cards.isEmpty {
                        ContentUnavailableView(
                            "Kart yok",
                            systemImage: "creditcard",
                            description: Text("Ödeme yapmak için sağ üstteki + ile kart ekle.")
                        )
                    }
                    ForEach(store.cards) { card in
                        CardRow(card: card, isDefault: card.id == store.defaultCard?.id)
                            .contentShape(Rectangle())
                            .onTapGesture { store.defaultCardID = card.id }
                    }
                    .onDelete { store.delete(at: $0) }
                }

                Section {
                    Label(
                        "Denetim Merkezi'ne eklemek için: Denetim Merkezi'ni aç → boş bir yere basılı tut → Denetim Ekle → \"QR ile Öde\".",
                        systemImage: "info.circle"
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("QR Öde")
            .toolbar {
                Button { showAddCard = true } label: { Image(systemName: "plus") }
            }
            .sheet(isPresented: $showAddCard) { AddCardView() }
            .fullScreenCover(isPresented: $router.showScanner, onDismiss: {
                if let payload = pendingPayload {
                    pendingPayload = nil
                    scanned = ScannedQR(payload: payload)
                }
            }) {
                ScannerScreen { payload in
                    pendingPayload = payload
                    router.showScanner = false
                }
            }
            .sheet(item: $scanned) { PaymentView(payload: $0.payload) }
        }
    }
}

struct ScannedQR: Identifiable {
    let id = UUID()
    let payload: String
}

struct CardRow: View {
    let card: Card
    let isDefault: Bool

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 6)
                .fill(card.brand.color.gradient)
                .frame(width: 48, height: 32)
                .overlay(Text(card.brand.shortName).font(.caption2.bold()).foregroundStyle(.white))
            VStack(alignment: .leading, spacing: 2) {
                Text("•••• \(card.last4)").font(.body.monospaced())
                Text("\(card.holder) · \(String(format: "%02d/%02d", card.expMonth, card.expYear % 100))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if isDefault {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.tint)
            }
        }
    }
}
