import SwiftUI

@main
struct GymAppApp: App {
    @StateObject private var authState = AuthState.shared
    
    init() {
        // Initialize Firebase
        FirebaseService.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if authState.isAuthenticated {
                    MainTabView()
                } else {
                    OnboardingView()
                }
            }
            .onOpenURL { url in
                // ASWebAuthenticationSession handles the callback; nothing needed here for now.
            }
        }
    }
}
