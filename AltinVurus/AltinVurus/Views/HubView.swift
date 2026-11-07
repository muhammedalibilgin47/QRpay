import SwiftUI

struct HubView: View {
    @Environment(CareerStore.self) private var store
    let onExit: () -> Void

    var body: some View {
        if store.career != nil {
            TabView {
                MatchTab()
                    .tabItem { Label("Maç", systemImage: "soccerball") }
                TableTab()
                    .tabItem { Label("Lig", systemImage: "list.number") }
                SquadTab()
                    .tabItem { Label("Kadro", systemImage: "person.3.fill") }
                TransferTab()
                    .tabItem { Label("Transfer", systemImage: "arrow.left.arrow.right") }
                ClubTab(onExit: onExit)
                    .tabItem { Label("Kulüp", systemImage: "building.columns.fill") }
            }
        } else {
            Color.clear.onAppear(perform: onExit)
        }
    }
}

// MARK: - Maç sekmesi

struct MatchTab: View {
    @Environment(CareerStore.self) private var store
    @State private var plan: MatchPlan?

    var body: some View {
        NavigationStack {
            ScrollView {
                if let c = store.career {
                    VStack(spacing: 16) {
                        header(c)
                        switch c.status {
                        case .active: nextMatch(c)
                        case .seasonOver: seasonOver(c)
                        case .fired: fired(c)
                        }
                        news(c)
                    }
                    .padding(16)
                }
            }
            .background(PitchBackground())
            .navigationTitle("Maç Merkezi")
            .navigationBarTitleDisplayMode(.inline)
        }
        .fullScreenCover(item: $plan) { MatchView(plan: $0) }
    }

    private func header(_ c: Career) -> some View {
        HStack(spacing: 14) {
            TeamBadge(team: c.team, size: 52)
            VStack(alignment: .leading, spacing: 4) {
                Text(c.team.name).font(.title3.bold())
                Text("TD \(c.managerName) · \(c.season). sezon").font(.subheadline).foregroundStyle(.secondary)
                HStack(spacing: 10) {
                    Label("\(Engine.position(c)).", systemImage: "list.number")
                    Label(Economy.format(c.money), systemImage: "banknote")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(gold)
            }
            Spacer()
        }
    }

    @ViewBuilder
    private func nextMatch(_ c: Career) -> some View {
        if let f = Engine.nextFixture(c) {
            let home = c.teams[f.home], away = c.teams[f.away]
            let opp = f.home == c.teamID ? away : home
            let me = Engine.squadStrength(c.squad)
            Card {
                Text("\(c.week). HAFTA / \(Engine.totalWeeks(c))")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                HStack {
                    teamColumn(home, label: "Ev sahibi")
                    Text("VS")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(gold)
                    teamColumn(away, label: "Deplasman")
                }
                compare("Hücum", mine: me.attack, theirs: Double(opp.rating))
                compare("Defans", mine: me.defense, theirs: Double(opp.rating))
            }

            Card {
                Text("Taktik").font(.headline)
                Picker("Taktik", selection: Binding(
                    get: { c.tactic },
                    set: { t in store.update { $0.tactic = t } }
                )) {
                    ForEach(Tactic.allCases) { t in
                        Label(t.rawValue, systemImage: t.icon).tag(t)
                    }
                }
                .pickerStyle(.segmented)
                Text(c.tactic.detail).font(.footnote).foregroundStyle(.secondary)
            }

            BigButton(title: "Maça çık", icon: "sportscourt.fill") {
                plan = Engine.plan(c)
            }
        }
    }

    private func teamColumn(_ t: Team, label: String) -> some View {
        VStack(spacing: 6) {
            TeamBadge(team: t, size: 56)
            Text(t.name).font(.subheadline.bold()).multilineTextAlignment(.center).lineLimit(2)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func compare(_ title: String, mine: Double, theirs: Double) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text("\(Int(mine.rounded()))").monospacedDigit()
                Spacer()
                Text(title).foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(theirs.rounded()))").monospacedDigit()
            }
            .font(.caption.weight(.semibold))
            GeometryReader { geo in
                let total = max(1, mine + theirs)
                HStack(spacing: 2) {
                    Capsule().fill(gold).frame(width: geo.size.width * mine / total)
                    Capsule().fill(Color.white.opacity(0.3))
                }
            }
            .frame(height: 6)
        }
    }

    @ViewBuilder
    private func seasonOver(_ c: Career) -> some View {
        let last = c.history.first
        Card {
            HStack {
                Image(systemName: last?.champion == true ? "trophy.fill" : "flag.checkered")
                    .font(.largeTitle)
                    .foregroundStyle(gold)
                VStack(alignment: .leading) {
                    Text(last?.champion == true ? "ŞAMPİYONSUN!" : "Sezon bitti").font(.title2.bold())
                    Text("\(last?.position ?? 0). sıra · \(last?.points ?? 0) puan · Hedef: \(Engine.targetText(c.seasonTarget))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        if !c.offers.isEmpty {
            Card {
                Text("İş teklifleri").font(.headline)
                ForEach(c.offers, id: \.self) { id in
                    offerRow(c.teams[id])
                }
            }
        }
        BigButton(title: "\(c.team.name) ile devam et", icon: "arrow.right.circle.fill") {
            store.update { Engine.startNextSeason(&$0) }
        }
    }

    @ViewBuilder
    private func fired(_ c: Career) -> some View {
        Card {
            HStack {
                Image(systemName: "xmark.octagon.fill").font(.largeTitle).foregroundStyle(.red)
                VStack(alignment: .leading) {
                    Text("Kovuldun!").font(.title2.bold())
                    Text("Yönetim güveni tükendi. Kariyerine başka kulüpte devam edebilirsin.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        Card {
            Text("Seni isteyen kulüpler").font(.headline)
            ForEach(c.offers, id: \.self) { id in
                offerRow(c.teams[id])
            }
        }
    }

    private func offerRow(_ t: Team) -> some View {
        HStack(spacing: 12) {
            TeamBadge(team: t, size: 36)
            VStack(alignment: .leading) {
                Text(t.name).font(.subheadline.bold())
                Text("Güç \(t.rating) · Bütçe \(Economy.format(t.budget))").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button("İmzala") {
                SFX.tap()
                store.update { Engine.acceptOffer(&$0, teamID: t.id) }
            }
            .buttonStyle(.borderedProminent)
            .foregroundStyle(.black)
        }
    }

    private func news(_ c: Career) -> some View {
        Card {
            Text("Haberler").font(.headline)
            ForEach(Array(c.news.enumerated()), id: \.offset) { _, line in
                Text(line).font(.subheadline)
                Divider().opacity(0.3)
            }
        }
    }
}

// MARK: - Lig sekmesi

struct TableTab: View {
    @Environment(CareerStore.self) private var store

    var body: some View {
        NavigationStack {
            List {
                if let c = store.career {
                    Section {
                        HStack(spacing: 0) {
                            Text("#").frame(width: 26, alignment: .leading)
                            Text("Takım")
                            Spacer()
                            Group {
                                Text("O")
                                Text("G")
                                Text("B")
                                Text("M")
                                Text("AV")
                            }
                            .frame(width: 28)
                            Text("P").frame(width: 34)
                        }
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)

                        ForEach(Array(Engine.table(c).enumerated()), id: \.element.teamID) { i, s in
                            row(c, i + 1, s)
                        }
                    } footer: {
                        Text("1. şampiyon · Son 2 sıra yönetimin kabusu. Hedefin: \(Engine.targetText(c.seasonTarget))")
                    }

                    let played = c.fixtures.filter { $0.week == c.week - 1 && $0.played }
                    if !played.isEmpty {
                        Section("\(c.week - 1). hafta sonuçları") {
                            ForEach(played) { f in
                                HStack {
                                    Text(c.teams[f.home].name).frame(maxWidth: .infinity, alignment: .trailing)
                                    Text("\(f.homeGoals ?? 0) - \(f.awayGoals ?? 0)")
                                        .font(.body.monospacedDigit().bold())
                                        .frame(width: 54)
                                    Text(c.teams[f.away].name).frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .font(.caption)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Puan Durumu")
        }
    }

    private func row(_ c: Career, _ pos: Int, _ s: Standing) -> some View {
        let team = c.teams[s.teamID]
        let mine = s.teamID == c.teamID
        return HStack(spacing: 0) {
            Text("\(pos)")
                .frame(width: 26, alignment: .leading)
                .foregroundStyle(pos == 1 ? gold : (pos >= c.teams.count - 1 ? .red : .primary))
            TeamBadge(team: team, size: 20).padding(.trailing, 8)
            Text(team.name).lineLimit(1).minimumScaleFactor(0.7)
            Spacer(minLength: 4)
            Group {
                Text("\(s.played)")
                Text("\(s.won)")
                Text("\(s.drawn)")
                Text("\(s.lost)")
                Text(s.goalDiff > 0 ? "+\(s.goalDiff)" : "\(s.goalDiff)")
            }
            .frame(width: 28)
            Text("\(s.points)").bold().frame(width: 34)
        }
        .font(.subheadline.monospacedDigit())
        .fontWeight(mine ? .heavy : .regular)
        .listRowBackground(mine ? gold.opacity(0.18) : nil)
    }
}

// MARK: - Kadro sekmesi

struct SquadTab: View {
    @Environment(CareerStore.self) private var store
    @State private var selling: Player?

    var body: some View {
        NavigationStack {
            List {
                if let c = store.career {
                    let s = Engine.squadStrength(c.squad)
                    Section {
                        HStack {
                            stat("Genel", Engine.overall(s))
                            stat("Hücum", Int(s.attack.rounded()))
                            stat("Defans", Int(s.defense.rounded()))
                            stat("Oyuncu", c.squad.count)
                        }
                    }
                    ForEach(Position.allCases) { pos in
                        Section(pos.title) {
                            ForEach(c.squad.filter { $0.position == pos }.sorted { $0.rating > $1.rating }) { p in
                                PlayerRow(player: p, price: nil)
                                    .swipeActions {
                                        if Engine.canSell(c, p) {
                                            Button("Sat") { selling = p }.tint(.red)
                                        }
                                    }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Kadro")
            .confirmationDialog(
                "Oyuncu satılsın mı?",
                isPresented: Binding(get: { selling != nil }, set: { if !$0 { selling = nil } }),
                titleVisibility: .visible,
                presenting: selling
            ) { p in
                Button("\(p.name) — \(Economy.format(p.sellPrice))'ye sat", role: .destructive) {
                    store.update { Engine.sell(&$0, p) }
                }
            }
        }
    }

    private func stat(_ title: String, _ value: Int) -> some View {
        VStack(spacing: 2) {
            Text("\(value)").font(.title2.bold().monospacedDigit()).foregroundStyle(gold)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct PlayerRow: View {
    let player: Player
    let price: Double?

    var body: some View {
        HStack(spacing: 12) {
            RatingBadge(rating: player.rating)
            VStack(alignment: .leading, spacing: 2) {
                Text(player.name).font(.subheadline.weight(.semibold))
                Text("\(player.position.rawValue) · \(player.age) yaş").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(Economy.format(price ?? player.value))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Transfer sekmesi

struct TransferTab: View {
    @Environment(CareerStore.self) private var store
    @State private var filter: Position?
    @State private var buying: Player?
    @State private var error: String?

    var body: some View {
        NavigationStack {
            List {
                if let c = store.career {
                    Section {
                        HStack {
                            Label(Economy.format(c.money), systemImage: "banknote.fill")
                                .font(.headline)
                                .foregroundStyle(gold)
                            Spacer()
                            Text("\(c.squad.count)/26 oyuncu").font(.caption).foregroundStyle(.secondary)
                        }
                        Picker("Mevki", selection: $filter) {
                            Text("Tümü").tag(Position?.none)
                            ForEach(Position.allCases) { Text($0.rawValue).tag(Position?.some($0)) }
                        }
                        .pickerStyle(.segmented)
                    }
                    Section {
                        ForEach(c.market.filter { filter == nil || $0.position == filter }) { p in
                            Button {
                                SFX.tap()
                                buying = p
                            } label: {
                                PlayerRow(player: p, price: p.buyPrice)
                                    .opacity(c.money >= p.buyPrice ? 1 : 0.45)
                            }
                            .foregroundStyle(.primary)
                        }
                    } header: {
                        Text("Transfer listesi")
                    } footer: {
                        Text("Oyuncu almak takım gücünü artırır. Liste her sezon yenilenir.")
                    }
                }
            }
            .navigationTitle("Transfer")
            .confirmationDialog(
                "Transfer",
                isPresented: Binding(get: { buying != nil }, set: { if !$0 { buying = nil } }),
                titleVisibility: .hidden,
                presenting: buying
            ) { p in
                Button("\(p.name) (\(p.rating)) — \(Economy.format(p.buyPrice))") {
                    store.update { c in error = Engine.buy(&c, p) }
                }
            }
            .alert("Transfer olmadı", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("Tamam", role: .cancel) {}
            } message: {
                Text(error ?? "")
            }
        }
    }
}

// MARK: - Kulüp sekmesi

struct ClubTab: View {
    @Environment(CareerStore.self) private var store
    let onExit: () -> Void

    var body: some View {
        NavigationStack {
            List {
                if let c = store.career {
                    Section("Yönetim") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Yönetim güveni")
                                Spacer()
                                Text("%\(Int(c.confidence))").bold().foregroundStyle(confColor(c.confidence))
                            }
                            ProgressView(value: c.confidence, total: 100).tint(confColor(c.confidence))
                        }
                        LabeledContent("Sezon hedefi", value: Engine.targetText(c.seasonTarget))
                        LabeledContent("Şu anki sıra", value: "\(Engine.position(c)).")
                        LabeledContent("Bütçe", value: Economy.format(c.money))
                    }
                    Section("Teknik direktör: \(c.managerName)") {
                        LabeledContent("Sezon", value: "\(c.season)")
                        LabeledContent("Galibiyet / Beraberlik / Mağlubiyet", value: "\(c.wins) / \(c.draws) / \(c.losses)")
                        LabeledContent("Atılan gol", value: "\(c.goalsScored)")
                        LabeledContent("Kupalar", value: c.trophies > 0 ? String(repeating: "🏆", count: min(c.trophies, 10)) : "—")
                    }
                    if !c.history.isEmpty {
                        Section("Geçmiş sezonlar") {
                            ForEach(c.history) { h in
                                HStack {
                                    Text("\(h.season). sezon")
                                    Text(h.teamName).foregroundStyle(.secondary)
                                    Spacer()
                                    Text(h.champion ? "🏆 1." : "\(h.position).").bold()
                                    Text("\(h.points) P").foregroundStyle(.secondary)
                                }
                                .font(.subheadline)
                            }
                        }
                    }
                    Section {
                        Button("Ana menüye dön", action: onExit)
                    }
                }
            }
            .navigationTitle("Kulüp")
        }
    }

    private func confColor(_ v: Double) -> Color {
        v >= 60 ? .green : (v >= 30 ? .orange : .red)
    }
}
