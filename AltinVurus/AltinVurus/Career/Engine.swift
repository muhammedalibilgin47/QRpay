import Foundation

struct MatchEvent: Identifiable {
    enum Kind {
        case chance(ChanceKind)
        case opponentGoal
        case opponentChance
        case card(String)
        case halfTime
    }

    let id = UUID()
    let minute: Int
    let kind: Kind
}

struct MatchPlan: Identifiable {
    let id = UUID()
    let opponentID: Int
    let userIsHome: Bool
    let events: [MatchEvent]
}

struct WeekResult {
    enum Outcome { case win, draw, loss }

    let outcome: Outcome
    let confidenceDelta: Double
    let income: Double
}

enum Engine {
    // MARK: - Kurulum

    static func newCareer(manager: String, teamID: Int) -> Career {
        var teams = GameData.teams
        let squad = GameData.makeSquad(rating: teams[teamID].rating)
        teams[teamID].rating = overall(squadStrength(squad))
        var c = Career(
            managerName: manager, teamID: teamID, teams: teams, squad: squad,
            market: GameData.makeMarket(), fixtures: makeFixtures(count: teams.count),
            standings: teams.map { Standing(teamID: $0.id) }, money: teams[teamID].budget
        )
        c.seasonTarget = expectedPosition(c)
        c.news = ["\(c.team.name) ile sözleşme imzaladın! Yönetimin hedefi: \(targetText(c.seasonTarget))."]
        return c
    }

    static func makeFixtures(count n: Int) -> [Fixture] {
        var ids = Array(0..<n).shuffled()
        var result: [Fixture] = []
        for round in 0..<(n - 1) {
            for i in 0..<(n / 2) {
                let a = ids[i], b = ids[n - 1 - i]
                let aHome = (round + i) % 2 == 0
                result.append(Fixture(week: round + 1, home: aHome ? a : b, away: aHome ? b : a))
                result.append(Fixture(week: round + n, home: aHome ? b : a, away: aHome ? a : b))
            }
            let last = ids.removeLast()
            ids.insert(last, at: 1)
        }
        return result
    }

    static func totalWeeks(_ c: Career) -> Int { (c.teams.count - 1) * 2 }

    // MARK: - Güç hesapları

    static func squadStrength(_ squad: [Player]) -> (attack: Double, defense: Double) {
        func top(_ p: Position, _ n: Int) -> Double {
            let ratings = squad.filter { $0.position == p }.map(\.rating).sorted(by: >).prefix(n)
            let sum = ratings.reduce(0, +) + (n - ratings.count) * 40
            return Double(sum) / Double(n)
        }
        let attack = top(.mid, 3) * 0.4 + top(.fwd, 3) * 0.6
        let defense = top(.gk, 1) * 0.35 + top(.def, 4) * 0.65
        return (attack, defense)
    }

    static func overall(_ s: (attack: Double, defense: Double)) -> Int {
        Int(((s.attack + s.defense) / 2).rounded())
    }

    static func strength(_ c: Career, team id: Int) -> (attack: Double, defense: Double) {
        if id == c.teamID { return squadStrength(c.squad) }
        let r = Double(c.teams[id].rating)
        return (r, r)
    }

    static func refreshUserRating(_ c: inout Career) {
        c.teams[c.teamID].rating = overall(squadStrength(c.squad))
    }

    static func expectedPosition(_ c: Career) -> Int {
        let rank = (c.teams.sorted { $0.rating > $1.rating }.firstIndex { $0.id == c.teamID } ?? 9) + 1
        switch rank {
        case 1: return 1
        case 2...3: return 3
        case 4...6: return 6
        default: return 8
        }
    }

    static func targetText(_ pos: Int) -> String {
        switch pos {
        case 1: "Şampiyonluk"
        case 3: "İlk 3"
        case 6: "İlk 6"
        default: "Ligde kalmak (ilk 8)"
        }
    }

    // MARK: - Lig

    static func table(_ c: Career) -> [Standing] {
        c.standings.sorted {
            if $0.points != $1.points { return $0.points > $1.points }
            if $0.goalDiff != $1.goalDiff { return $0.goalDiff > $1.goalDiff }
            if $0.goalsFor != $1.goalsFor { return $0.goalsFor > $1.goalsFor }
            return c.teams[$0.teamID].name < c.teams[$1.teamID].name
        }
    }

    static func position(_ c: Career) -> Int {
        (table(c).firstIndex { $0.teamID == c.teamID } ?? 0) + 1
    }

    static func nextFixture(_ c: Career) -> Fixture? {
        c.fixtures.first { $0.week == c.week && ($0.home == c.teamID || $0.away == c.teamID) }
    }

    // MARK: - Maç

    static func plan(_ c: Career) -> MatchPlan? {
        guard let f = nextFixture(c) else { return nil }
        let home = f.home == c.teamID
        let opp = home ? f.away : f.home
        let me = strength(c, team: c.teamID), them = strength(c, team: opp)

        var chances = 3 + Int(((me.attack - them.defense) / 6).rounded()) + c.tactic.chanceBonus + (home ? 1 : 0)
        chances = min(6, max(2, chances))
        let lambda = max(0.15, 1.1 + (them.attack - me.defense) / 12 + c.tactic.concedeBonus + (home ? -0.15 : 0.15))
        let oppGoals = min(5, poisson(lambda))

        var used: Set<Int> = [45]
        func freeMinute() -> Int {
            var m: Int
            repeat { m = Int.random(in: 2...89) } while used.contains(m)
            used.insert(m)
            return m
        }

        var events: [MatchEvent] = []
        for _ in 0..<chances { events.append(MatchEvent(minute: freeMinute(), kind: .chance(randomChanceKind()))) }
        for _ in 0..<oppGoals { events.append(MatchEvent(minute: freeMinute(), kind: .opponentGoal)) }
        for _ in 0..<Int.random(in: 1...3) { events.append(MatchEvent(minute: freeMinute(), kind: .opponentChance)) }
        if Bool.random(), let p = c.squad.randomElement() {
            events.append(MatchEvent(minute: freeMinute(), kind: .card("Sarı kart: \(p.name)")))
        }
        events.append(MatchEvent(minute: 45, kind: .halfTime))
        events.sort { $0.minute < $1.minute }
        return MatchPlan(opponentID: opp, userIsHome: home, events: events)
    }

    static func randomChanceKind() -> ChanceKind {
        let r = Double.random(in: 0..<1)
        if r < 0.45 { return .inside }
        if r < 0.7 { return .longShot }
        if r < 0.9 { return .freeKick }
        return .penalty
    }

    static func poisson(_ lambda: Double) -> Int {
        let l = exp(-lambda)
        var k = 0
        var p = 1.0
        repeat {
            k += 1
            p *= Double.random(in: 0..<1)
        } while p > l
        return k - 1
    }

    @discardableResult
    static func finishWeek(_ c: inout Career, userGoals: Int, oppGoals: Int) -> WeekResult {
        guard let idx = c.fixtures.firstIndex(where: {
            $0.week == c.week && ($0.home == c.teamID || $0.away == c.teamID)
        }) else {
            return WeekResult(outcome: .draw, confidenceDelta: 0, income: 0)
        }
        let home = c.fixtures[idx].home == c.teamID
        c.fixtures[idx].homeGoals = home ? userGoals : oppGoals
        c.fixtures[idx].awayGoals = home ? oppGoals : userGoals
        record(&c, c.fixtures[idx])

        for i in c.fixtures.indices where c.fixtures[i].week == c.week && !c.fixtures[i].played {
            let f = c.fixtures[i]
            let h = strength(c, team: f.home), a = strength(c, team: f.away)
            c.fixtures[i].homeGoals = min(6, poisson(max(0.2, 1.35 + (h.attack - a.defense) / 14)))
            c.fixtures[i].awayGoals = min(6, poisson(max(0.2, 1.05 + (a.attack - h.defense) / 14)))
            record(&c, c.fixtures[i])
        }

        let opp = home ? c.fixtures[idx].away : c.fixtures[idx].home
        let diff = Double(c.teams[c.teamID].rating - c.teams[opp].rating)
        let outcome: WeekResult.Outcome
        var delta: Double
        var income: Double
        if userGoals > oppGoals {
            outcome = .win
            delta = 4 + (diff < 0 ? 3 : 0) + (userGoals - oppGoals >= 3 ? 2 : 0)
            income = 1.2
            c.wins += 1
        } else if userGoals == oppGoals {
            outcome = .draw
            delta = diff > 3 ? -3 : 1
            income = 0.6
            c.draws += 1
        } else {
            outcome = .loss
            delta = -(5 + (diff > 0 ? 3 : 0) + (oppGoals - userGoals >= 3 ? 2 : 0))
            income = 0.3
            c.losses += 1
        }
        if home { income += 0.3 }
        c.goalsScored += userGoals
        c.confidence = min(100, max(0, c.confidence + delta))
        c.money = Economy.round1(c.money + income)

        let oppName = c.teams[opp].name
        let line: String
        switch outcome {
        case .win: line = "\(c.week). hafta: \(oppName)'ı \(userGoals)-\(oppGoals) yendin."
        case .draw: line = "\(c.week). hafta: \(oppName) ile \(userGoals)-\(oppGoals) berabere."
        case .loss: line = "\(c.week). hafta: \(oppName)'a \(oppGoals)-\(userGoals) yenildin."
        }
        c.news.insert(line, at: 0)
        if c.confidence < 25, delta < 0, c.confidence > 0 {
            c.news.insert("⚠️ Yönetim sonuçlardan memnun değil. Koltuğun sallanıyor!", at: 0)
        }
        c.news = Array(c.news.prefix(8))

        c.week += 1
        if c.confidence <= 0 {
            c.status = .fired
            c.offers = offers(c, better: false)
            c.news.insert("❌ Yönetim seninle yolları ayırdı.", at: 0)
        } else if c.week > totalWeeks(c) {
            endSeason(&c)
        }
        return WeekResult(outcome: outcome, confidenceDelta: delta, income: income)
    }

    private static func record(_ c: inout Career, _ f: Fixture) {
        guard let hg = f.homeGoals, let ag = f.awayGoals,
              let hi = c.standings.firstIndex(where: { $0.teamID == f.home }),
              let ai = c.standings.firstIndex(where: { $0.teamID == f.away }) else { return }
        c.standings[hi].played += 1
        c.standings[ai].played += 1
        c.standings[hi].goalsFor += hg
        c.standings[hi].goalsAgainst += ag
        c.standings[ai].goalsFor += ag
        c.standings[ai].goalsAgainst += hg
        if hg > ag {
            c.standings[hi].won += 1
            c.standings[ai].lost += 1
        } else if hg < ag {
            c.standings[ai].won += 1
            c.standings[hi].lost += 1
        } else {
            c.standings[hi].drawn += 1
            c.standings[ai].drawn += 1
        }
    }

    // MARK: - Sezon sonu

    static func endSeason(_ c: inout Career) {
        let t = table(c)
        let pos = position(c)
        let champion = pos == 1
        if champion { c.trophies += 1 }
        c.history.insert(SeasonRecord(season: c.season, teamName: c.team.name, position: pos,
                                      points: t[pos - 1].points, champion: champion), at: 0)
        c.money = Economy.round1(c.money + Double(c.teams.count + 1 - pos) * 1.5)

        if pos > c.seasonTarget + 2 {
            c.status = .fired
            c.offers = offers(c, better: false)
            c.news.insert("❌ Sezonu \(pos). bitirdin. Hedef tutmadı, yönetim seni gönderdi.", at: 0)
        } else {
            c.status = .seasonOver
            let met = pos <= c.seasonTarget
            c.confidence = min(100, max(10, c.confidence + (met ? 15 : -10)))
            c.offers = met ? offers(c, better: true) : []
            c.news.insert(champion ? "🏆 ŞAMPİYON OLDUN!" : "Sezonu \(pos). sırada bitirdin.", at: 0)
        }
    }

    static func offers(_ c: Career, better: Bool) -> [Int] {
        let mine = c.team.rating
        let pool = c.teams.filter { $0.id != c.teamID && (better ? $0.rating > mine : $0.rating <= mine + 2) }
        let picked = pool.shuffled().prefix(2).map(\.id)
        if picked.isEmpty && !better {
            return c.teams.filter { $0.id != c.teamID }.sorted { $0.rating < $1.rating }.prefix(2).map(\.id)
        }
        return Array(picked)
    }

    static func acceptOffer(_ c: inout Career, teamID: Int) {
        c.teamID = teamID
        c.squad = GameData.makeSquad(rating: c.teams[teamID].rating)
        c.money = c.teams[teamID].budget * 0.5
        c.confidence = 60
        c.news = ["\(c.teams[teamID].name) ile yeni sözleşme imzaladın!"]
        startNextSeason(&c)
    }

    static func startNextSeason(_ c: inout Career) {
        c.season += 1
        c.week = 1
        c.status = .active
        c.offers = []

        var retired = 0
        c.squad = c.squad.compactMap { p in
            var p = p
            p.age += 1
            if p.age > 35 { retired += 1; return nil }
            let change: Int
            switch p.age {
            case ..<24: change = Int.random(in: 0...4)
            case 24...29: change = Int.random(in: -1...2)
            default: change = Int.random(in: -4...0)
            }
            p.rating = min(92, max(45, p.rating + change))
            return p
        }
        for pos in Position.allCases {
            while c.squad.filter({ $0.position == pos }).count < pos.minimum + 1 {
                c.squad.append(GameData.makePlayer(pos, around: c.team.rating - 8, age: 17...20))
            }
        }

        for i in c.teams.indices where i != c.teamID {
            c.teams[i].rating = min(88, max(56, c.teams[i].rating + Int.random(in: -2...2)))
        }
        refreshUserRating(&c)

        c.fixtures = makeFixtures(count: c.teams.count)
        c.standings = c.teams.map { Standing(teamID: $0.id) }
        c.market = GameData.makeMarket()
        c.money = Economy.round1(c.money + c.team.budget * 0.5)
        c.seasonTarget = expectedPosition(c)
        c.news.insert("\(c.season). sezon başladı! Hedef: \(targetText(c.seasonTarget)).", at: 0)
        if retired > 0 { c.news.insert("\(retired) oyuncun futbolu bıraktı, altyapıdan gençler geldi.", at: 1) }
        c.news = Array(c.news.prefix(8))
    }

    // MARK: - Transfer

    static func buy(_ c: inout Career, _ p: Player) -> String? {
        guard c.squad.count < 26 else { return "Kadro dolu (en fazla 26 oyuncu)." }
        guard c.money >= p.buyPrice else { return "Bütçe yetmiyor." }
        c.money = Economy.round1(c.money - p.buyPrice)
        c.squad.append(p)
        c.market.removeAll { $0.id == p.id }
        refreshUserRating(&c)
        c.news.insert("✍️ \(p.name) (\(p.rating)) transfer edildi.", at: 0)
        c.news = Array(c.news.prefix(8))
        return nil
    }

    static func canSell(_ c: Career, _ p: Player) -> Bool {
        c.squad.count > 14 && c.squad.filter { $0.position == p.position }.count > p.position.minimum
    }

    static func sell(_ c: inout Career, _ p: Player) {
        guard canSell(c, p) else { return }
        c.money = Economy.round1(c.money + p.sellPrice)
        c.squad.removeAll { $0.id == p.id }
        refreshUserRating(&c)
        c.news.insert("👋 \(p.name) satıldı.", at: 0)
        c.news = Array(c.news.prefix(8))
    }
}
