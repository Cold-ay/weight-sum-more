import SwiftUI
import SwiftData

struct ContentView: View {
    @Query(sort: \UserProfile.updatedAt, order: .reverse) private var profiles: [UserProfile]

    var body: some View {
        if let profile = profiles.first {
            MainTabView(profile: profile)
        } else {
            OnboardingView()
        }
    }
}
