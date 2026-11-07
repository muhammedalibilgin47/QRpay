import SwiftUI

struct MatchView: View {
    @Environment(CareerStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let plan: MatchPlan

    struct FeedItem: Identifiable {
        let id = UUID()
        let minute: Int
        let icon: String
        let text: String
        let color: Color
    }

    struct ActiveChance: Identifiable {
        let id = UUID()
        let kind: ChanceKind
        let minute: Int
    }

    @State private var minute = 0
    @State private var userGoals = 0
    @State private var oppGoals = 0
    @State private var feed: [FeedItem] = []
    @State private var chance: ActiveChance?
    @State private var waiting = false
    @State private var banner: String?
    @State private var result: WeekResult?
    @State private var finalScore: (Int, Int)?
    @State private var started = false

    var body: some View {
        ZStack {
            PitchBackground()
            if let c = store.career {
                let me = c.team
                let opp = c.teams[plan.opponentID]
                VStack(spacing: 16) {
                    scoreboard(home: plan.userIsHome ? me : opp, away: plan.userIsHome ? opp : me)
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(feed) { item in
                                HStack(alignment: .top, spacing: 12) {
                                    Text("\(item.minute)'")
                                        .font(.subheadline.monospacedDigit().bold())
                                        .frame(width: 36, alignment: .trailing)
                                        .foregroundStyle(.secondary)
                                    Image(systemName: item.icon).foregroundStyle(item.color).frame(width: 22)
                                    Text(item.text).font(.subheadline)
                                    Spacer()
                                }
                                .padding(.vertical, 6)
                                .transition(.move(edge: .top).combined(with: .opacity))
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.top, 8)

                if let banner {
                    Text(banner)
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.black)
                        .padding(.horizontal, 28).padding(.vertical, 18)
                        .background(gold, in: RoundedRectangle(cornerRadius: 20))
                        .shadow(radius: 20)
                        .transition(.scale(scale: 0.5).combined(with: .opacity))
                }

                if let result, let finalScore {
                    resultCard(result, score: finalScore, opp: opp)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .animation(.spring(duration: 0.4), value: feed.count)
        .animation(.spring(duration: 0.4, bounce: 0.4), value: banner)
        .animation(.spring(duration: 0.5), value: result != nil)
        .task {
            guard !started else { return }
            started = true
            await run()
        }
        .fullScreenCover(item: $chance) { ch in
            ShotView(config: shotConfig(ch)) { outcome in
                if outcome.isGoal {
                    userGoals += 1
                    add(ch.minute, "soccerball", "GOL! \(store.career?.team.name ?? "") ⚽", .green)
                } else {
                    add(ch.minute, "xmark.circle", outcome.feedText, .orange)
                }
                chance = nil
                waiting = false
            }
        }
    }

    private func scoreboard(home: Team, away: Team) -> some View {
        let homeScore = plan.userIsHome ? userGoals : oppGoals
        let awayScore = plan.userIsHome ? oppGoals : userGoals
        return VStack(spacing: 10) {
            HStack {
                VStack(spacing: 6) {
                    TeamBadge(team: home, size: 50)
                    Text(home.name).font(.caption.bold()).lineLimit(1).minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity)
                Text("\(homeScore) - \(awayScore)")
                    .font(.system(size: 48, weight: .black, design: .rounded).monospacedDigit())
                    .contentTransition(.numericText())
                    .animation(.snappy, value: homeScore + awayScore * 10)
                VStack(spacing: 6) {
                    TeamBadge(team: away, size: 50)
                    Text(away.name).font(.caption.bold()).lineLimit(1).minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity)
            }
            HStack(spacing: 6) {
                Circle().fill(minute >= 90 ? .gray : .red).frame(width: 8, height: 8)
                Text(minute >= 90 ? "MAÇ SONU" : "\(minute)'")
                    .font(.headline.monospacedDigit())
            }
            ProgressView(value: Double(minute), total: 90).tint(gold).padding(.horizontal, 24)
        }
        .padding(.vertical, 14)
        .background(Color.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 22))
        .padding(.horizontal, 16)
    }

    private func resultCard(_ r: WeekResult, score: (Int, Int), opp: Team) -> some View {
        VStack(spacing: 12) {
            Spacer()
            VStack(spacing: 10) {
                Text(r.outcome == .win ? "GALİBİYET" : (r.outcome == .draw ? "BERABERLİK" : "MAĞLUBİYET"))
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(r.outcome == .win ? .green : (r.outcome == .draw ? gold : .red))
                Text("\(score.0) - \(score.1)").font(.system(size: 40, weight: .heavy, design: .rounded))
                HStack(spacing: 18) {
                    Label("\(r.confidenceDelta >= 0 ? "+" : "")\(Int(r.confidenceDelta)) güven",
                          systemImage: r.confidenceDelta >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .foregroundStyle(r.confidenceDelta >= 0 ? .green : .red)
                    Label("+\(Economy.format(r.income))", systemImage: "banknote")
                        .foregroundStyle(gold)
                }
                .font(.subheadline.weight(.semibold))
                BigButton(title: "Devam", icon: "arrow.right") { dismiss() }
                    .padding(.top, 6)
            }
            .padding(24)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28))
            .padding(16)
        }
    }

    // MARK: - Maç akışı

    private func add(_ minute: Int, _ icon: String, _ text: String, _ color: Color) {
        feed.insert(FeedItem(minute: minute, icon: icon, text: text, color: color), at: 0)
    }

    private func pause(_ seconds: Double) async {
        try? await Task.sleep(for: .seconds(seconds))
    }

    private func run() async {
        guard let c = store.career else { return }
        let opp = c.teams[plan.opponentID]
        SFX.whistle()
        add(0, "flag.fill", "Hakem düdüğü çaldı, maç başladı!", .white)
        var events = plan.events[...]
        for m in 1...90 {
            await pause(0.09)
            minute = m
            while let e = events.first, e.minute == m {
                events = events.dropFirst()
                switch e.kind {
                case .chance(let kind):
                    SFX.tap()
                    banner = "\(m)' FIRSAT!\n\(kind.title)"
                    await pause(1.1)
                    banner = nil
                    await pause(0.25)
                    waiting = true
                    chance = ActiveChance(kind: kind, minute: m)
                    while waiting { await pause(0.1) }
                    await pause(0.4)
                case .opponentGoal:
                    oppGoals += 1
                    SFX.concede()
                    add(m, "soccerball", "Gol: \(opp.name)", .red)
                    await pause(1.0)
                case .opponentChance:
                    add(m, "hand.raised.fill", ["Kalecimiz harika kurtardı!", "Rakip top direkten döndü.", "Rakip şut auta gitti."].randomElement()!, .cyan)
                    await pause(0.5)
                case .card(let text):
                    add(m, "rectangle.portrait.fill", text, .yellow)
                    await pause(0.3)
                case .halfTime:
                    SFX.whistle()
                    add(45, "pause.circle.fill", "Devre arası", .white)
                    await pause(1.2)
                }
            }
        }
        SFX.whistle()
        add(90, "flag.checkered", "Maç sona erdi.", .white)
        await pause(0.6)
        let u = userGoals, o = oppGoals
        var outcome: WeekResult?
        store.update { career in outcome = Engine.finishWeek(&career, userGoals: u, oppGoals: o) }
        finalScore = plan.userIsHome ? (u, o) : (o, u)
        result = outcome
    }

    private func shotConfig(_ ch: ActiveChance) -> ShotConfig {
        let c = store.career!
        let opp = c.teams[plan.opponentID]
        let mine = Engine.squadStrength(c.squad)
        return ShotConfig(
            kind: ch.kind,
            keeperSkill: max(0.1, min(1, (Double(opp.rating) - 55) / 35)),
            shooterSkill: max(0.1, min(1, (mine.attack - 55) / 35)),
            opponentKit: Kit(primary: opp.primaryColor, secondary: opp.secondaryColor),
            caption: "\(ch.minute)' · \(ch.kind.title)"
        )
    }
}
