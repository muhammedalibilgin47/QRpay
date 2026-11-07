import SwiftUI

struct MenuView: View {
    @Environment(CareerStore.self) private var store
    let onContinue: () -> Void
    let onNew: () -> Void
    let onPractice: () -> Void

    @State private var appear = false
    @State private var muted = SFX.muted

    var body: some View {
        ZStack {
            PitchBackground()
            VStack(spacing: 14) {
                HStack {
                    Spacer()
                    Button {
                        muted.toggle()
                        SFX.muted = muted
                    } label: {
                        Image(systemName: muted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .foregroundStyle(.white)
                            .padding(12)
                            .background(.white.opacity(0.1), in: Circle())
                    }
                    .accessibilityLabel(muted ? "Sesi aç" : "Sesi kapat")
                }
                Spacer()
                Image(systemName: "soccerball")
                    .font(.system(size: 70))
                    .foregroundStyle(.white)
                    .rotationEffect(.degrees(appear ? 360 : 0))
                    .animation(.easeOut(duration: 1.2), value: appear)
                Text("ALTIN VURUŞ")
                    .font(.system(size: 44, weight: .black, design: .rounded))
                    .foregroundStyle(LinearGradient(colors: [.yellow, gold, .orange], startPoint: .top, endPoint: .bottom))
                    .shadow(color: .black.opacity(0.5), radius: 6, y: 3)
                Text("Teknik Direktör Kariyeri")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
                Spacer()

                if let c = store.career {
                    Button { SFX.tap(); onContinue() } label: {
                        HStack(spacing: 14) {
                            TeamBadge(team: c.team, size: 40)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Kariyere devam et").font(.headline)
                                Text("\(c.team.name) · \(c.season). sezon · \(min(c.week, Engine.totalWeeks(c))). hafta")
                                    .font(.caption)
                                    .opacity(0.75)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .foregroundStyle(.black)
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity, minHeight: 64)
                        .background(gold, in: RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                    BigButton(title: "Yeni kariyer", icon: "plus", prominent: false, action: onNew)
                } else {
                    BigButton(title: "Kariyere başla", icon: "briefcase.fill", action: onNew)
                }
                BigButton(title: "Serbest antrenman", icon: "figure.soccer", prominent: false, action: onPractice)
                    .padding(.bottom, 24)
            }
            .padding(.horizontal, 24)
        }
        .onAppear { appear = true }
    }
}

struct NewCareerView: View {
    @Environment(CareerStore.self) private var store
    let onBack: () -> Void
    let onStart: () -> Void

    @AppStorage("managerName") private var name = "Tiyzi"
    @State private var selected: Int?
    @State private var confirmOverwrite = false

    private var teams: [Team] { GameData.teams.sorted { $0.rating < $1.rating } }

    var body: some View {
        NavigationStack {
            List {
                Section("Teknik direktör") {
                    TextField("Adın", text: $name)
                        .textInputAutocapitalization(.words)
                }
                Section {
                    ForEach(teams) { team in
                        Button {
                            SFX.tap()
                            selected = team.id
                        } label: {
                            HStack(spacing: 14) {
                                TeamBadge(team: team, size: 38)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(team.name).font(.headline).foregroundStyle(.primary)
                                    Text("Bütçe \(Economy.format(team.budget)) · \(difficulty(team))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                RatingBadge(rating: team.rating)
                                Image(systemName: selected == team.id ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selected == team.id ? gold : .secondary)
                            }
                        }
                    }
                } header: {
                    Text("Takımını seç")
                } footer: {
                    Text("Zayıf takımla başlamak zor ama şampiyonluk daha tatlı olur. Tüm takım ve oyuncular kurgusaldır.")
                }
            }
            .navigationTitle("Yeni kariyer")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Geri", action: onBack) }
            }
            .safeAreaInset(edge: .bottom) {
                BigButton(title: "Sözleşmeyi imzala", icon: "signature") {
                    if store.career != nil { confirmOverwrite = true } else { start() }
                }
                .disabled(selected == nil || name.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(selected == nil ? 0.5 : 1)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(.bar)
            }
            .alert("Mevcut kariyer silinsin mi?", isPresented: $confirmOverwrite) {
                Button("Sil ve başla", role: .destructive) { start() }
                Button("Vazgeç", role: .cancel) {}
            } message: {
                Text("Kayıtlı kariyerin kaybolacak.")
            }
        }
    }

    private func difficulty(_ team: Team) -> String {
        switch team.rating {
        case 78...: "Kolay"
        case 70..<78: "Orta"
        case 65..<70: "Zor"
        default: "Çok zor"
        }
    }

    private func start() {
        guard let id = selected else { return }
        store.career = Engine.newCareer(manager: name.trimmingCharacters(in: .whitespaces), teamID: id)
        onStart()
    }
}
