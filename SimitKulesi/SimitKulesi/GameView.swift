import SwiftUI

struct GameView: View {
    @State private var game = Game()
    @State private var pulse = false
    @State private var muted = Feedback.muted

    var body: some View {
        ZStack {
            TimelineView(.animation) { timeline in
                Canvas { ctx, size in
                    game.setup(size: size)
                    game.update(timeline.date)
                    Renderer.draw(game, in: &ctx, size: size)
                }
            }
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture { game.tap() }

            switch game.phase {
            case .ready: readyOverlay
            case .playing: scoreOverlay
            case .over: gameOverCard
            }
        }
        .animation(.spring(duration: 0.45), value: game.phase)
    }

    private var readyOverlay: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 14) {
                Spacer().frame(height: 80)
                Text("Simit\nKulesi")
                    .font(.system(size: 60, weight: .black, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
                if game.best > 0 {
                    Label("Rekor: \(game.best)", systemImage: "trophy.fill")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14).padding(.vertical, 6)
                        .background(.black.opacity(0.2), in: Capsule())
                }
                Spacer()
                Text("Başlamak için dokun")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
                    .opacity(pulse ? 1 : 0.35)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulse)
                    .onAppear { pulse = true }
                Spacer().frame(height: 170)
            }
            .frame(maxWidth: .infinity)
            .allowsHitTesting(false)

            Button {
                muted.toggle()
                Feedback.muted = muted
            } label: {
                Image(systemName: muted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(.black.opacity(0.2), in: Circle())
            }
            .padding(.trailing, 20)
            .padding(.top, 8)
            .accessibilityLabel(muted ? "Sesi aç" : "Sesi kapat")
        }
        .transition(.opacity)
    }

    private var scoreOverlay: some View {
        VStack {
            Text("\(game.score)")
                .font(.system(size: 72, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
                .contentTransition(.numericText())
                .animation(.snappy, value: game.score)
                .padding(.top, 50)
            Spacer()
        }
        .allowsHitTesting(false)
        .transition(.opacity)
    }

    private var gameOverCard: some View {
        VStack(spacing: 10) {
            Text(game.isNewBest ? "Yeni rekor! 🎉" : "Kule yıkıldı!")
                .font(.title2.bold())
            Text("\(game.score)")
                .font(.system(size: 80, weight: .black, design: .rounded))
                .foregroundStyle(.orange)
            Text("simit dizdin").foregroundStyle(.secondary)
            Label("Rekor: \(game.best)", systemImage: "trophy.fill")
                .font(.headline)
                .padding(.bottom, 8)
            Button {
                game.restart()
            } label: {
                Label("Tekrar oyna", systemImage: "arrow.clockwise")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.orange)
            ShareLink(item: "Simit Kulesi'nde \(game.score) simit dizdim! 🥯 Geçebilir misin?") {
                Label("Skorunu paylaş", systemImage: "square.and.arrow.up")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .tint(.orange)
        }
        .padding(28)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 32))
        .padding(.horizontal, 32)
        .transition(.scale(scale: 0.8).combined(with: .opacity))
    }
}
