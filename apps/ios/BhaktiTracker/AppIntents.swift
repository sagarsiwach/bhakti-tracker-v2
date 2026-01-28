import AppIntents
import SwiftData
import UIKit

// MARK: - Increment First Mantra Intent
struct IncrementFirstMantraIntent: AppIntent {
    static var title: LocalizedStringResource = "Increment First Mantra"
    static var description = IntentDescription("Add one count to First mantra")

    func perform() async throws -> some IntentResult {
        await incrementMantra(name: "first")
        return .result()
    }
}

// MARK: - Increment Third Mantra Intent
struct IncrementThirdMantraIntent: AppIntent {
    static var title: LocalizedStringResource = "Increment Third Mantra"
    static var description = IntentDescription("Add one count to Third mantra")

    func perform() async throws -> some IntentResult {
        await incrementMantra(name: "third")
        return .result()
    }
}

// MARK: - Increment Dandavat Intent
struct IncrementDandavatIntent: AppIntent {
    static var title: LocalizedStringResource = "Increment Dandavat"
    static var description = IntentDescription("Add one count to Dandavat pranam")

    func perform() async throws -> some IntentResult {
        await incrementMantra(name: "dandavat")
        return .result()
    }
}

// MARK: - App Shortcuts (for Siri & Action Button)
struct BhaktiShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: IncrementFirstMantraIntent(),
            phrases: [
                "Increment First in \(.applicationName)",
                "Log First in \(.applicationName)"
            ],
            shortTitle: "First +1",
            systemImageName: "leaf.fill"
        )
        AppShortcut(
            intent: IncrementThirdMantraIntent(),
            phrases: [
                "Increment Third in \(.applicationName)",
                "Log Third in \(.applicationName)"
            ],
            shortTitle: "Third +1",
            systemImageName: "leaf.circle.fill"
        )
        AppShortcut(
            intent: IncrementDandavatIntent(),
            phrases: [
                "Increment Dandavat in \(.applicationName)",
                "Log Dandavat in \(.applicationName)"
            ],
            shortTitle: "Dandavat +1",
            systemImageName: "figure.stand"
        )
    }
}

// MARK: - Helper Function
@MainActor
private func incrementMantra(name: String) async {
    let schema = Schema([LocalMantra.self, LocalActivity.self])
    let config = ModelConfiguration(isStoredInMemoryOnly: false)

    guard let container = try? ModelContainer(for: schema, configurations: config) else {
        return
    }

    let context = container.mainContext
    let today = formatDate(Date())

    let descriptor = FetchDescriptor<LocalMantra>(
        predicate: #Predicate { $0.date == today && $0.name == name }
    )

    if let mantra = try? context.fetch(descriptor).first {
        mantra.count += 1
        mantra.pendingSync = true
        mantra.lastModified = Date()
        try? context.save()
    } else {
        // Get correct target: nil for dandavat, 108 for first, 1000 for third
        let target: Int? = name == "dandavat" ? nil : (name == "first" ? 108 : 1000)
        let mantra = LocalMantra(name: name, date: today, count: 1, target: target, pendingSync: true)
        context.insert(mantra)
        try? context.save()
    }

    // Haptic feedback
    let feedback = UIImpactFeedbackGenerator(style: .medium)
    feedback.impactOccurred()

    // Notify the app to refresh UI
    NotificationCenter.default.post(name: .mantraDidUpdate, object: nil)
}

private func formatDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: date)
}
