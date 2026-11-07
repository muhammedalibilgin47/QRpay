import SwiftUI

struct ShotView: View {
    @State private var game: ShotGame
    @State private var hintPulse = false
    private let onFinish: (ShotOutcome) -> Void

    init(config: ShotConfig, onFinish: @escaping (ShotOutcome) -> Void) {
        _game = State(initialValue: ShotGame(config: config))
        self.onFinish = onFinish
    }

    var body: some View {
        ZStack {
            TimelineView(.animation) { timeline in
                Canvas { ctx, size in
                    game.setup(size: size)
                    game.update(timeline.date)
                    ShotRenderer.draw(game, ctx: &ctx, size: size)
                }
            }
            .ignoresSafeArea()
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { game.dragChanged($0.location) }
                    .onEnded { _ in game.shoot() }
            )

            VStack {
                if !game.config.caption.isEmpty {
                    Text(game.config.caption)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(.black.opacity(0.45), in: Capsule())
                        .padding(.top, 12)
                }
                Spacer()
                if game.phase == .aiming {
                    VStack(spacing: 6) {
                        Image(systemName: "chevron.up.2")
                            .font(.title.bold())
                            .offset(y: hintPulse ? -8 : 4)
                            .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: hintPulse)
                        Text("Topu kaleye doğru kaydır")
                            .font(.headline)
                        Text("Yolu eğri çizersen top falso alır")
                            .font(.footnote)
                            .opacity(0.8)
                    }
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.6), radius: 4)
                    .padding(.bottom, 24)
                    .onAppear { hintPulse = true }
                    .allowsHitTesting(false)
                    .transition(.opacity)
                }
            }

            if let o = game.outcome {
                Text(o.title)
                    .font(.system(size: o.isGoal ? 64 : 44, weight: .black, design: .rounded))
                    .foregroundStyle(o.isGoal
                        ? AnyShapeStyle(LinearGradient(colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom))
                        : AnyShapeStyle(Color.white))
                    .shadow(color: .black.opacity(0.6), radius: 8, y: 4)
                    .transition(.scale(scale: 0.3).combined(with: .opacity))
                    .allowsHitTesting(false)
            }
        }
        .animation(.spring(duration: 0.35, bounce: 0.45), value: game.outcome)
        .animation(.easeInOut, value: game.phase)
        .onChange(of: game.phase) { _, phase in
            if case .finished(let o) = phase { onFinish(o) }
        }
        .statusBarHidden()
    }
}

/// Serbest antrenman: sınırsız şut, seri ve rekor.
struct PracticeView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var round = 0
    @State private var config = ShotConfig.practice()
    @State private var goals = 0
    @State private var shots = 0
    @State private var streak = 0
    @AppStorage("practiceBest") private var best = 0

    var body: some View {
        ZStack(alignment: .top) {
            ShotView(config: config) { outcome in
                shots += 1
                if outcome.isGoal {
                    goals += 1
                    streak += 1
                    best = max(best, streak)
                } else {
                    streak = 0
                }
                config = .practice()
                round += 1
            }
            .id(round)

            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(.black.opacity(0.45), in: Circle())
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Seri: \(streak)  ·  Rekor: \(best)")
                        .font(.headline.monospacedDigit())
                    Text("\(goals)/\(shots) gol · \(config.kind.title)")
                        .font(.caption)
                        .opacity(0.85)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
    }
}
