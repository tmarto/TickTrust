import SwiftUI

@main
struct iOSApp: App {
    @StateObject private var supabase = SupabaseService.shared

    var body: some Scene {
        WindowGroup {
            if supabase.isAuthenticated {
                ContentView()
                    .environmentObject(supabase)
            } else {
                LoginView()
                    .environmentObject(supabase)
            }
        }
    }
}
