import SwiftUI
import Combine

struct MainTabView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var currentDate = Date()
    let profile: UserProfile

    var body: some View {
        TabView {
            DashboardView(profile: profile)
                .tabItem { Label("Today", systemImage: "gauge.with.dots.needle.50percent") }

            ExerciseLogView(profile: profile)
                .tabItem { Label("Training", systemImage: "figure.run") }

            CaloriesLogView(profile: profile)
                .tabItem { Label("Nutrition", systemImage: "fork.knife") }

            WeightTrackingView(profile: profile)
                .tabItem { Label("Weight", systemImage: "scalemass") }

            MoreView(profile: profile)
                .tabItem { Label("More", systemImage: "ellipsis.circle") }
        }
        .environment(\.trackingDate, currentDate)
        .onAppear { currentDate = Date() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { currentDate = Date() }
        }
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { currentDate = $0 }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            currentDate = Date()
        }
        .tint(VitalityTheme.primary)
        .toolbarColorScheme(.dark, for: .tabBar)
        .toolbarBackground(VitalityTheme.background, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .preferredColorScheme(.dark)
    }
}
