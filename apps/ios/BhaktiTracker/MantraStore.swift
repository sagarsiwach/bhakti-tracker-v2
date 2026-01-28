import Foundation
import SwiftData
import UIKit
import AudioToolbox

// MARK: - Notification for external updates
extension Notification.Name {
    static let mantraDidUpdate = Notification.Name("mantraDidUpdate")
}

// MARK: - Local Mantra Model
@Model
class LocalMantra {
    var name: String
    var date: String
    var count: Int
    var target: Int?  // Optional - nil means no target (like Dandavat)
    var pendingSync: Bool
    var lastModified: Date

    init(name: String, date: String, count: Int, target: Int?, pendingSync: Bool = false) {
        self.name = name
        self.date = date
        self.count = count
        self.target = target
        self.pendingSync = pendingSync
        self.lastModified = Date()
    }

    var progress: Double {
        guard let target = target, target > 0 else { return 0 }
        return min(Double(count) / Double(target), 1.0)
    }

    var isComplete: Bool {
        guard let target = target else { return false }
        return count >= target
    }

    var hasTarget: Bool {
        target != nil
    }

    var displayName: String {
        switch name {
        case "first": return "First"
        case "third": return "Third"
        case "dandavat": return "Dandavat"
        default: return name.capitalized
        }
    }

    var icon: String {
        switch name {
        case "first": return "leaf.fill"
        case "third": return "leaf.circle.fill"
        case "dandavat": return "figure.stand"
        default: return "circle.fill"
        }
    }
}

// MARK: - Local Activity Model
@Model
class LocalActivity {
    var name: String
    var displayName: String
    var category: String
    var date: String
    var completed: Bool
    var completedAt: Date?
    var pendingSync: Bool

    init(name: String, displayName: String, category: String, date: String, completed: Bool = false, pendingSync: Bool = false) {
        self.name = name
        self.displayName = displayName
        self.category = category
        self.date = date
        self.completed = completed
        self.pendingSync = pendingSync
    }

    var icon: String {
        switch name {
        case "morning_aarti": return "sunrise.fill"
        case "afternoon_aarti": return "sun.max.fill"
        case "evening_aarti": return "sunset.fill"
        case "before_food_aarti": return "fork.knife"
        case "after_food_aarti": return "fork.knife.circle.fill"
        case "mangalacharan": return "book.fill"
        default: return "checkmark.circle"
        }
    }
}

// MARK: - API Response Models
struct MantraDTO: Codable {
    let name: String
    var count: Int
    let target: Int?
}

struct MantrasResponse: Codable {
    let date: String
    let mantras: [MantraDTO]
}

struct ActivityDTO: Codable {
    let name: String
    let displayName: String
    let category: String
    let completed: Bool
    let completedAt: String?
}

struct ActivitiesResponse: Codable {
    let date: String
    let activities: [ActivityDTO]
}

// MARK: - User Preferences
class UserPreferences: ObservableObject {
    static let shared = UserPreferences()

    @Published var soundEnabled: Bool {
        didSet { UserDefaults.standard.set(soundEnabled, forKey: "soundEnabled") }
    }

    init() {
        self.soundEnabled = UserDefaults.standard.bool(forKey: "soundEnabled")
    }
}

// MARK: - Mantra Store
@MainActor
class MantraStore: ObservableObject {
    private let modelContainer: ModelContainer
    private let modelContext: ModelContext
    private let baseURL = "https://bhakti.classicgroup.asia"

    // Retry queue
    private var retryQueue: [(LocalMantra, Int)] = []
    private var isProcessingRetryQueue = false

    @Published var mantras: [LocalMantra] = []
    @Published var activities: [LocalActivity] = []
    @Published var isLoading = false
    @Published var isOnline = true
    @Published var hasPendingSync = false
    @Published var currentStreak: Int = 0
    @Published var showCelebration = false
    @Published var celebratingMantra: String?

    // Default mantras
    private let defaultMantras: [(name: String, target: Int?)] = [
        ("first", 108),
        ("third", 1000),
        ("dandavat", nil)  // No target
    ]

    // Default activities
    private let defaultActivities: [(name: String, displayName: String, category: String)] = [
        ("morning_aarti", "Morning Aarti", "aarti"),
        ("afternoon_aarti", "Afternoon Aarti", "aarti"),
        ("evening_aarti", "Evening Aarti", "aarti"),
        ("before_food_aarti", "Before Food Aarti", "satsang"),
        ("after_food_aarti", "After Food Aarti", "satsang"),
        ("mangalacharan", "Mangalacharan", "satsang")
    ]

    init() {
        let schema = Schema([LocalMantra.self, LocalActivity.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: false)
        self.modelContainer = try! ModelContainer(for: schema, configurations: config)
        self.modelContext = modelContainer.mainContext

        // Listen for external updates (from Action Button)
        NotificationCenter.default.addObserver(
            forName: .mantraDidUpdate,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refreshFromDatabase()
            }
        }
    }

    // MARK: - Computed Properties
    var aartiActivities: [LocalActivity] {
        activities.filter { $0.category == "aarti" }
    }

    var satsangActivities: [LocalActivity] {
        activities.filter { $0.category == "satsang" }
    }

    var countMantras: [LocalMantra] {
        mantras.filter { $0.hasTarget }
    }

    var trendMantras: [LocalMantra] {
        mantras.filter { !$0.hasTarget }
    }

    // MARK: - Refresh from database
    func refreshFromDatabase() {
        guard !mantras.isEmpty else { return }
        let dateString = mantras.first?.date ?? formatDate(Date())
        loadLocalData(for: dateString)
    }

    func loadData(for date: Date) async {
        isLoading = true
        let dateString = formatDate(date)

        // Load from local storage first
        loadLocalData(for: dateString)

        // Calculate streak
        await calculateStreak()

        // Sync with server
        await syncWithServer(for: date)

        isLoading = false
    }

    private func loadLocalData(for dateString: String) {
        loadLocalMantras(for: dateString)
        loadLocalActivities(for: dateString)
        updatePendingSyncStatus()
    }

    private func loadLocalMantras(for dateString: String) {
        let descriptor = FetchDescriptor<LocalMantra>(
            predicate: #Predicate { $0.date == dateString }
        )

        if let localMantras = try? modelContext.fetch(descriptor), !localMantras.isEmpty {
            mantras = localMantras.sorted {
                let order = ["first": 0, "third": 1, "dandavat": 2]
                return (order[$0.name] ?? 99) < (order[$1.name] ?? 99)
            }
        } else {
            createDefaultMantras(for: dateString)
        }
    }

    private func loadLocalActivities(for dateString: String) {
        let descriptor = FetchDescriptor<LocalActivity>(
            predicate: #Predicate { $0.date == dateString }
        )

        if let localActivities = try? modelContext.fetch(descriptor), !localActivities.isEmpty {
            activities = localActivities.sorted {
                let order = ["morning_aarti": 0, "afternoon_aarti": 1, "evening_aarti": 2,
                            "before_food_aarti": 3, "after_food_aarti": 4, "mangalacharan": 5]
                return (order[$0.name] ?? 99) < (order[$1.name] ?? 99)
            }
        } else {
            createDefaultActivities(for: dateString)
        }
    }

    private func createDefaultMantras(for dateString: String) {
        var newMantras: [LocalMantra] = []
        for (name, target) in defaultMantras {
            let mantra = LocalMantra(name: name, date: dateString, count: 0, target: target, pendingSync: true)
            modelContext.insert(mantra)
            newMantras.append(mantra)
        }
        try? modelContext.save()
        mantras = newMantras.sorted {
            let order = ["first": 0, "third": 1, "dandavat": 2]
            return (order[$0.name] ?? 99) < (order[$1.name] ?? 99)
        }
    }

    private func createDefaultActivities(for dateString: String) {
        var newActivities: [LocalActivity] = []
        for (name, displayName, category) in defaultActivities {
            let activity = LocalActivity(name: name, displayName: displayName, category: category, date: dateString, pendingSync: true)
            modelContext.insert(activity)
            newActivities.append(activity)
        }
        try? modelContext.save()
        activities = newActivities.sorted {
            let order = ["morning_aarti": 0, "afternoon_aarti": 1, "evening_aarti": 2,
                        "before_food_aarti": 3, "after_food_aarti": 4, "mangalacharan": 5]
            return (order[$0.name] ?? 99) < (order[$1.name] ?? 99)
        }
    }

    // MARK: - Server Sync
    private func syncWithServer(for date: Date) async {
        let dateString = formatDate(date)

        // Sync mantras
        do {
            let serverMantras = try await fetchMantrasFromServer(date: date)
            isOnline = true

            for serverMantra in serverMantras {
                if let local = mantras.first(where: { $0.name == serverMantra.name }) {
                    if local.pendingSync {
                        if local.count > serverMantra.count {
                            await pushMantraToServer(mantra: local)
                        } else if local.count < serverMantra.count {
                            local.count = serverMantra.count
                            local.pendingSync = false
                        } else {
                            local.pendingSync = false
                        }
                    } else {
                        local.count = serverMantra.count
                    }
                } else {
                    let newMantra = LocalMantra(
                        name: serverMantra.name,
                        date: dateString,
                        count: serverMantra.count,
                        target: serverMantra.target
                    )
                    modelContext.insert(newMantra)
                    mantras.append(newMantra)
                }
            }
            try? modelContext.save()
        } catch {
            isOnline = false
        }

        // Sync activities
        do {
            let serverActivities = try await fetchActivitiesFromServer(date: date)

            for serverActivity in serverActivities {
                if let local = activities.first(where: { $0.name == serverActivity.name }) {
                    if local.pendingSync && local.completed != serverActivity.completed {
                        await pushActivityToServer(activity: local)
                    } else {
                        local.completed = serverActivity.completed
                        local.pendingSync = false
                    }
                }
            }
            try? modelContext.save()
        } catch {
            // Continue with local data
        }

        updatePendingSyncStatus()
    }

    private func fetchMantrasFromServer(date: Date) async throws -> [MantraDTO] {
        let dateString = formatDate(date)
        guard let url = URL(string: "\(baseURL)/api/mantras/\(dateString)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 5

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(MantrasResponse.self, from: data)
        return response.mantras
    }

    private func fetchActivitiesFromServer(date: Date) async throws -> [ActivityDTO] {
        let dateString = formatDate(date)
        guard let url = URL(string: "\(baseURL)/api/activities/\(dateString)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 5

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(ActivitiesResponse.self, from: data)
        return response.activities
    }

    // MARK: - Increment Mantra
    func increment(mantra: LocalMantra) {
        let wasComplete = mantra.isComplete

        mantra.count += 1
        mantra.pendingSync = true
        mantra.lastModified = Date()
        try? modelContext.save()

        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()

        // Sound feedback if enabled
        if UserPreferences.shared.soundEnabled {
            AudioServicesPlaySystemSound(1104)
        }

        // Check for completion celebration
        if mantra.hasTarget && mantra.isComplete && !wasComplete {
            celebratingMantra = mantra.name
            showCelebration = true

            let notificationFeedback = UINotificationFeedbackGenerator()
            notificationFeedback.notificationOccurred(.success)

            if UserPreferences.shared.soundEnabled {
                AudioServicesPlaySystemSound(1025)
            }

            Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                await MainActor.run {
                    showCelebration = false
                    celebratingMantra = nil
                }
            }
        }

        Task {
            await pushMantraToServer(mantra: mantra)
            updatePendingSyncStatus()
        }
    }

    // MARK: - Toggle Activity
    func toggle(activity: LocalActivity) {
        activity.completed.toggle()
        activity.completedAt = activity.completed ? Date() : nil
        activity.pendingSync = true
        try? modelContext.save()

        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()

        // Sound feedback if enabled
        if UserPreferences.shared.soundEnabled {
            AudioServicesPlaySystemSound(activity.completed ? 1104 : 1105)
        }

        Task {
            await pushActivityToServer(activity: activity)
            updatePendingSyncStatus()
        }
    }

    // MARK: - Push to Server
    private func pushMantraToServer(mantra: LocalMantra) async {
        guard let url = URL(string: "\(baseURL)/api/mantras") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 5

        let body: [String: Any] = [
            "name": mantra.name,
            "date": mantra.date,
            "count": mantra.count
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (_, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                await MainActor.run {
                    mantra.pendingSync = false
                    try? modelContext.save()
                    isOnline = true
                }
            }
        } catch {
            await MainActor.run {
                isOnline = false
            }
        }
    }

    private func pushActivityToServer(activity: LocalActivity) async {
        guard let url = URL(string: "\(baseURL)/api/activities") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 5

        let body: [String: Any] = [
            "name": activity.name,
            "date": activity.date,
            "completed": activity.completed
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (_, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                await MainActor.run {
                    activity.pendingSync = false
                    try? modelContext.save()
                    isOnline = true
                }
            }
        } catch {
            await MainActor.run {
                isOnline = false
            }
        }
    }

    // MARK: - Streak Calculation
    func calculateStreak() async {
        var streak = 0
        var checkDate = Date()
        let calendar = Calendar.current

        while true {
            let dateString = formatDate(checkDate)
            let mantraDescriptor = FetchDescriptor<LocalMantra>(
                predicate: #Predicate { $0.date == dateString }
            )

            guard let dayMantras = try? modelContext.fetch(mantraDescriptor),
                  !dayMantras.isEmpty else {
                break
            }

            let mantrasWithTargets = dayMantras.filter { $0.target != nil }
            let allMantrasComplete = mantrasWithTargets.allSatisfy { $0.isComplete }

            if allMantrasComplete && !mantrasWithTargets.isEmpty {
                streak += 1
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
            } else if dateString == formatDate(Date()) {
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
            } else {
                break
            }
        }

        currentStreak = streak
    }

    func syncNow() async {
        guard !mantras.isEmpty else { return }
        let date = dateFromString(mantras.first?.date ?? formatDate(Date()))
        await loadData(for: date)
    }

    private func updatePendingSyncStatus() {
        let mantraDescriptor = FetchDescriptor<LocalMantra>(
            predicate: #Predicate { $0.pendingSync == true }
        )
        let activityDescriptor = FetchDescriptor<LocalActivity>(
            predicate: #Predicate { $0.pendingSync == true }
        )

        let mantraPending = (try? modelContext.fetchCount(mantraDescriptor)) ?? 0
        let activityPending = (try? modelContext.fetchCount(activityDescriptor)) ?? 0
        hasPendingSync = (mantraPending + activityPending) > 0
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func dateFromString(_ string: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: string) ?? Date()
    }

    // MARK: - Statistics
    func getWeeklyStats() async -> [(date: String, first: Int, third: Int, dandavat: Int)] {
        var stats: [(date: String, first: Int, third: Int, dandavat: Int)] = []
        let calendar = Calendar.current

        for dayOffset in (0..<7).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) else { continue }
            let dateString = formatDate(date)

            let descriptor = FetchDescriptor<LocalMantra>(
                predicate: #Predicate { $0.date == dateString }
            )

            if let dayMantras = try? modelContext.fetch(descriptor) {
                let first = dayMantras.first { $0.name == "first" }?.count ?? 0
                let third = dayMantras.first { $0.name == "third" }?.count ?? 0
                let dandavat = dayMantras.first { $0.name == "dandavat" }?.count ?? 0
                stats.append((dateString, first, third, dandavat))
            } else {
                stats.append((dateString, 0, 0, 0))
            }
        }

        return stats
    }
}

enum APIError: Error {
    case invalidURL
    case networkError
}
