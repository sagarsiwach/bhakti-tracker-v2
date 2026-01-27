import SwiftUI
import SwiftData

@main
struct BhaktiTrackerApp: App {
    @StateObject private var mantraStore = MantraStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(mantraStore)
        }
    }
}
