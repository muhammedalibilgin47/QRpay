import Foundation

/// Tüm takım ve oyuncu adları uydurmadır.
enum GameData {
    static let teams: [Team] = [
        Team(id: 0, name: "Boğaziçi FK", short: "BOĞ", primary: "#B71C1C", secondary: "#FFFFFF", rating: 82, budget: 30),
        Team(id: 1, name: "Başkent Kartalları", short: "BKA", primary: "#212121", secondary: "#E0E0E0", rating: 80, budget: 27),
        Team(id: 2, name: "Ege Yıldızı", short: "EGE", primary: "#0D47A1", secondary: "#FFD54F", rating: 78, budget: 24),
        Team(id: 3, name: "Anadolu Gücü", short: "AND", primary: "#4A148C", secondary: "#FFB300", rating: 75, budget: 20),
        Team(id: 4, name: "Karadeniz Fırtınası", short: "KAR", primary: "#006064", secondary: "#FFFFFF", rating: 73, budget: 17),
        Team(id: 5, name: "Akdeniz Rüzgarı", short: "AKD", primary: "#E65100", secondary: "#0D47A1", rating: 70, budget: 14),
        Team(id: 6, name: "Marmara Demirspor", short: "MAR", primary: "#1B5E20", secondary: "#FFFFFF", rating: 68, budget: 12),
        Team(id: 7, name: "Kapadokya SK", short: "KAP", primary: "#5D4037", secondary: "#FFE0B2", rating: 66, budget: 10),
        Team(id: 8, name: "Trakya Birlik", short: "TRA", primary: "#F9A825", secondary: "#1A237E", rating: 64, budget: 8),
        Team(id: 9, name: "Doğu Kalesi", short: "DOĞ", primary: "#00897B", secondary: "#212121", rating: 62, budget: 7),
    ]

    static let firstNames = [
        "Emre", "Burak", "Mert", "Kaan", "Arda", "Cengiz", "Yusuf", "Ozan", "Kerem", "Barış",
        "Hakan", "Serdar", "Onur", "Tolga", "Umut", "Efe", "Can", "Deniz", "Furkan", "Oğuz",
        "Selim", "Batuhan", "Eren", "Volkan", "Sinan", "Alper", "Mehmet", "Ahmet", "Ali", "Okan",
        "Doruk", "Berk", "Taylan", "Koray", "Rıza", "Halil",
    ]

    static let lastNames = [
        "Yılmaz", "Kaya", "Demir", "Şahin", "Çelik", "Aydın", "Öztürk", "Arslan", "Doğan", "Kılıç",
        "Aslan", "Koç", "Kurt", "Özkan", "Şimşek", "Polat", "Erdem", "Güneş", "Aksoy", "Tekin",
        "Karaca", "Bulut", "Uçar", "Yavuz", "Ateş", "Korkmaz", "Bozkurt", "Tunç", "Sezer", "Duman",
        "Kalkan", "Ergin", "Sarı", "Tok",
    ]

    static func randomName() -> String {
        "\(firstNames.randomElement()!) \(lastNames.randomElement()!)"
    }

    static func makePlayer(_ position: Position, around rating: Int, spread: ClosedRange<Int> = -6...4,
                           age: ClosedRange<Int> = 18...33) -> Player {
        Player(name: randomName(), position: position,
               rating: min(92, max(45, rating + Int.random(in: spread))),
               age: Int.random(in: age))
    }

    static func makeSquad(rating: Int) -> [Player] {
        var squad: [Player] = []
        let plan: [(Position, Int)] = [(.gk, 2), (.def, 6), (.mid, 6), (.fwd, 4)]
        for (pos, count) in plan {
            for i in 0..<count {
                // İlk oyuncular as kadro, gerisi yedek
                let starter = i < (pos == .gk ? 1 : count - 2)
                squad.append(makePlayer(pos, around: rating, spread: starter ? -3...4 : -9...0))
            }
        }
        return squad
    }

    static func makeMarket(count: Int = 24) -> [Player] {
        (0..<count).map { _ in
            let pos = [Position.gk, .def, .def, .mid, .mid, .fwd, .fwd].randomElement()!
            return makePlayer(pos, around: Int.random(in: 60...84), spread: -2...3, age: 18...32)
        }
        .sorted { $0.rating > $1.rating }
    }
}
