import SwiftUI

@main
struct AltinVurusApp: App {
    @State private var store = CareerStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .preferredColorScheme(.dark)
                .tint(Color(red: 1, green: 0.76, blue: 0.2))
        }
    }
}

struct RootView: View {
    enum Screen { case menu, newCareer, hub }

    @Environment(CareerStore.self) private var store
    @State private var screen: Screen = .menu
    @State private var practice = false

    var body: some View {
        ZStack {
            switch screen {
            case .menu:
                MenuView(
                    onContinue: { screen = .hub },
                    onNew: { screen = .newCareer },
                    onPractice: { practice = true }
                )
                .transition(.opacity)
            case .newCareer:
                NewCareerView(onBack: { screen = .menu }, onStart: { screen = .hub })
                    .transition(.move(edge: .trailing))
            case .hub:
                HubView(onExit: { screen = .menu })
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: screen)
        .fullScreenCover(isPresented: $practice) { PracticeView() }
    }
}
