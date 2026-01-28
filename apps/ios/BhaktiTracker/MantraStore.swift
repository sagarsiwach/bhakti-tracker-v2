import Foundation
import SwiftData
import UIKit
import AudioToolbox

// MARK: - Notification for external updates
extension Notification.Name {
    static let mantraDidUpdate = Notification.Name("mantraDidUpdate")
}

@Model
class LocalMantra {
    var name: String
    var date: String
    var count: Int
    var target: Int
    var pendingSync: Bool
    var lastModified: Date

    init(name: String, date: String, count: Int, target: Int, pendingSync: Bool = false) {
        self.name = name
        self.date = date
        self.count = count
        self.target = target
        self.pendingSync = pendingSync
        self.lastModified = Date()
    }

    var progress: Double {
        min(Double(count) / Double(target), 1.0)
    }

    var isComplete: Bool {
        count >= target
    }

    var displayName: String {
        name.capitalized
    }
}

struct MantraDTO: Codable {
    let name: String
    var count: Int
    let target: Int
}

struct MantrasResponse: Codable {
    let date: String
    let mantras: [MantraDTO]
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
    private var retryQueue: [(LocalMantra, Int)] = [] // (mantra, attemptCount)
    private var isProcessingRetryQueue = false

    @Published var mantras: [LocalMantra] = []
    @Published var isLoading = false
    @Published var isOnline = true
    @Published var hasPendingSync = false
    @Published var currentStreak: Int = 0
    @Published var showCelebration = false
    @Published var celebratingMantra: String?

    // Default mantras when offline and no data exists
    private let defaultMantras = [
        ("first", 108),
        ("third", 1000)
    ]

    init() {
        let schema = Schema([LocalMantra.self])
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

    // MARK: - Refresh from database (for Action Button updates)
    func refreshFromDatabase() {
        guard !mantras.isEmpty else { return }
        let dateString = mantras.first?.date ?? formatDate(Date())
        loadLocalMantras(for: dateString)
    }

    func loadMantras(for date: Date) async {
        isLoading = true
        let dateString = formatDate(date)

        // First, load from local storage
        loadLocalMantras(for: dateString)

        // Calculate streak
        await calculateStreak()

        // Then try to sync with server
        await syncWithServer(for: date)

        isLoading = false
    }

    private func loadLocalMantras(for dateString: String) {
        let descriptor = FetchDescriptor<LocalMantra>(
            predicate: #Predicate { $0.date == dateString }
        )

        if let localMantras = try? modelContext.fetch(descriptor), !localMantras.isEmpty {
            mantras = localMantras.sorted { $0.name < $1.name }
        } else {
            // Create default mantras for this date
            createDefaultMantras(for: dateString)
        }

        updatePendingSyncStatus()
    }

    private func createDefaultMantras(for dateString: String) {
        var newMantras: [LocalMantra] = []
        for (name, target) in defaultMantras {
            let mantra = LocalMantra(name: name, date: dateString, count: 0, target: target, pendingSync: true)
            modelContext.insert(mantra)
            newMantras.append(mantra)
        }
        try? modelContext.save()
        mantras = newMantras.sorted { $0.name < $1.name }
    }

    private func syncWithServer(for date: Date) async {
        let dateString = formatDate(date)

        // Try to fetch from server
        do {
            let serverMantras = try await fetchFromServer(date: date)
            isOnline = true

            // Conflict resolution: compare timestamps and counts
            for serverMantra in serverMantras {
                if let local = mantras.first(where: { $0.name == serverMantra.name }) {
                    if local.pendingSync {
                        // Local has pending changes
                        if local.count > serverMantra.count {
                            // Local is ahead, push to server
                            await pushToServer(mantra: local)
                        } else if local.count < serverMantra.count {
                            // Server is ahead, update local
                            local.count = serverMantra.count
                            local.pendingSync = false
                        }
                        // If equal, just mark as synced
                        else {
                            local.pendingSync = false
                        }
                    } else {
                        // No local changes, accept server data
                        local.count = serverMantra.count
                    }
                } else {
                    // New mantra from server
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
            mantras = mantras.sorted { $0.name < $1.name }

            // Push any remaining pending syncs
            await pushPendingSyncs()

            // Process retry queue
            await processRetryQueue()
        } catch {
            isOnline = false
            // Continue with local data
        }

        updatePendingSyncStatus()
    }

    private func fetchFromServer(date: Date) async throws -> [MantraDTO] {
        let dateString = formatDate(date)
        guard let url = URL(string: "\(baseURL)/api/mantras/\(dateString)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 5 // Short timeout for offline detection

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(MantrasResponse.self, from: data)
        return response.mantras
    }

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
            AudioServicesPlaySystemSound(1104) // Subtle tick sound
        }

        // Check for completion celebration
        if mantra.isComplete && !wasComplete {
            celebratingMantra = mantra.name
            showCelebration = true

            // Success haptic
            let notificationFeedback = UINotificationFeedbackGenerator()
            notificationFeedback.notificationOccurred(.success)

            // Celebration sound
            if UserPreferences.shared.soundEnabled {
                AudioServicesPlaySystemSound(1025) // Success sound
            }

            // Auto-hide celebration after 3 seconds
            Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                await MainActor.run {
                    showCelebration = false
                    celebratingMantra = nil
                }
            }
        }

        // Try to sync immediately
        Task {
            await pushToServer(mantra: mantra)
            updatePendingSyncStatus()
        }
    }

    // MARK: - Streak Calculation
    func calculateStreak() async {
        var streak = 0
        var checkDate = Date()
        let calendar = Calendar.current

        while true {
            let dateString = formatDate(checkDate)
            let descriptor = FetchDescriptor<LocalMantra>(
                predicate: #Predicate { $0.date == dateString }
            )

            guard let dayMantras = try? modelContext.fetch(descriptor),
                  !dayMantras.isEmpty else {
                break
            }

            // Check if all mantras are complete for this day
            let allComplete = dayMantras.allSatisfy { $0.isComplete }

            if allComplete {
                streak += 1
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
            } else if dateString == formatDate(Date()) {
                // Today isn't complete yet, but check yesterday
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
            } else {
                break
            }
        }

        currentStreak = streak
    }

    private func pushToServer(mantra: LocalMantra) async {
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
                // Add to retry queue with exponential backoff
                addToRetryQueue(mantra: mantra)
            }
        }
    }

    // MARK: - Retry Queue with Exponential Backoff
    private func addToRetryQueue(mantra: LocalMantra) {
        // Check if already in queue
        if !retryQueue.contains(where: { $0.0.name == mantra.name && $0.0.date == mantra.date }) {
            retryQueue.append((mantra, 0))
        }

        // Start processing if not already
        if !isProcessingRetryQueue {
            Task {
                await processRetryQueue()
            }
        }
    }

    private func processRetryQueue() async {
        guard !isProcessingRetryQueue, !retryQueue.isEmpty else { return }
        isProcessingRetryQueue = true

        var failedItems: [(LocalMantra, Int)] = []

        for (mantra, attempts) in retryQueue {
            // Exponential backoff: 1s, 2s, 4s, 8s, 16s...
            let delay = UInt64(pow(2.0, Double(attempts))) * 1_000_000_000
            try? await Task.sleep(nanoseconds: min(delay, 30_000_000_000)) // Max 30s

            await pushToServer(mantra: mantra)

            if mantra.pendingSync && attempts < 5 {
                // Still pending, re-add with incremented attempts
                failedItems.append((mantra, attempts + 1))
            }
        }

        retryQueue = failedItems
        isProcessingRetryQueue = false
    }

    private func pushPendingSyncs() async {
        let descriptor = FetchDescriptor<LocalMantra>(
            predicate: #Predicate { $0.pendingSync == true }
        )

        guard let pending = try? modelContext.fetch(descriptor) else { return }

        for mantra in pending {
            await pushToServer(mantra: mantra)
        }
    }

    func syncNow() async {
        guard !mantras.isEmpty else { return }
        let date = dateFromString(mantras.first?.date ?? formatDate(Date()))
        await loadMantras(for: date)
    }

    private func updatePendingSyncStatus() {
        let descriptor = FetchDescriptor<LocalMantra>(
            predicate: #Predicate { $0.pendingSync == true }
        )
        hasPendingSync = (try? modelContext.fetchCount(descriptor)) ?? 0 > 0
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
    func getWeeklyStats() async -> [(date: String, first: Int, third: Int)] {
        var stats: [(date: String, first: Int, third: Int)] = []
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
                stats.append((dateString, first, third))
            } else {
                stats.append((dateString, 0, 0))
            }
        }

        return stats
    }
}

enum APIError: Error {
    case invalidURL
    case networkError
}
