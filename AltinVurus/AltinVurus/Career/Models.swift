import Foundation

enum Position: String, Codable, CaseIterable, Identifiable {
    case gk = "KL", def = "DEF", mid = "OS", fwd = "FV"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .gk: "Kaleciler"
        case .def: "Defans"
        case .mid: "Orta saha"
        case .fwd: "Forvetler"
        }
    }

    /// Kadroda bu mevkide en az kaç oyuncu kalmalı
    var minimum: Int {
        switch self {
        case .gk: 1
        case .def: 4
        case .mid: 3
        case .fwd: 2
        }
    }
}

struct Player: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var position: Position
    var rating: Int
    var age: Int

    var value: Double { Economy.value(rating: rating, age: age) }
    var buyPrice: Double { Economy.round1(value * 1.1) }
    var sellPrice: Double { Economy.round1(value * 0.9) }
}

struct Team: Codable, Identifiable, Hashable {
    let id: Int
    var name: String
    var short: String
    var primary: String
    var secondary: String
    var rating: Int
    var budget: Double
}

struct Standing: Codable, Identifiable {
    var teamID: Int
    var played = 0
    var won = 0
    var drawn = 0
    var lost = 0
    var goalsFor = 0
    var goalsAgainst = 0

    var id: Int { teamID }
    var points: Int { won * 3 + drawn }
    var goalDiff: Int { goalsFor - goalsAgainst }
}

struct Fixture: Codable, Identifiable {
    var id = UUID()
    var week: Int
    var home: Int
    var away: Int
    var homeGoals: Int?
    var awayGoals: Int?

    var played: Bool { homeGoals != nil }
}

enum Tactic: String, Codable, CaseIterable, Identifiable {
    case defensive = "Defansif"
    case balanced = "Dengeli"
    case attacking = "Hücum"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .defensive: "shield.fill"
        case .balanced: "scalemass.fill"
        case .attacking: "flame.fill"
        }
    }

    var detail: String {
        switch self {
        case .defensive: "Az pozisyon verir, az pozisyon bulursun."
        case .balanced: "Dengeli oyun."
        case .attacking: "Daha çok fırsat, ama arkada boşluk kalır."
        }
    }

    var chanceBonus: Int {
        switch self {
        case .defensive: -1
        case .balanced: 0
        case .attacking: 1
        }
    }

    var concedeBonus: Double {
        switch self {
        case .defensive: -0.35
        case .balanced: 0
        case .attacking: 0.4
        }
    }
}

enum ChanceKind: String, Codable, CaseIterable {
    case inside, longShot, freeKick, penalty

    var title: String {
        switch self {
        case .inside: "Ceza sahası içi"
        case .longShot: "Uzaktan şut"
        case .freeKick: "Serbest vuruş"
        case .penalty: "Penaltı"
        }
    }
}

struct SeasonRecord: Codable, Identifiable {
    var id = UUID()
    var season: Int
    var teamName: String
    var position: Int
    var points: Int
    var champion: Bool
}

struct Career: Codable {
    enum Status: String, Codable { case active, seasonOver, fired }

    var managerName: String
    var teamID: Int
    var teams: [Team]
    var squad: [Player]
    var market: [Player]
    var fixtures: [Fixture]
    var standings: [Standing]
    var money: Double
    var season = 1
    var week = 1
    var confidence: Double = 60
    var seasonTarget = 8
    var tactic: Tactic = .balanced
    var history: [SeasonRecord] = []
    var trophies = 0
    var wins = 0
    var draws = 0
    var losses = 0
    var goalsScored = 0
    var status: Status = .active
    var offers: [Int] = []
    var news: [String] = []

    init(managerName: String, teamID: Int, teams: [Team], squad: [Player], market: [Player],
         fixtures: [Fixture], standings: [Standing], money: Double) {
        self.managerName = managerName
        self.teamID = teamID
        self.teams = teams
        self.squad = squad
        self.market = market
        self.fixtures = fixtures
        self.standings = standings
        self.money = money
    }

    var team: Team { teams[teamID] }
}

enum Economy {
    static func value(rating: Int, age: Int) -> Double {
        let base = 1.4 * pow(1.13, Double(rating - 60))
        let ageFactor = age <= 22 ? 1.3 : (age >= 31 ? 0.6 : 1.0)
        return round1(max(0.2, base * ageFactor))
    }

    static func round1(_ v: Double) -> Double { (v * 10).rounded() / 10 }

    static func format(_ v: Double) -> String {
        v.formatted(.number.precision(.fractionLength(1)).locale(Locale(identifier: "tr_TR"))) + " Mn ₺"
    }
}
