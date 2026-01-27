import Foundation
import SwiftData
import UIKit

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

@MainActor
class MantraStore: ObservableObject {
    private let modelContainer: ModelContainer
    private let modelContext: ModelContext
    private let baseURL = "https://bhakti.classicgroup.asia"

    @Published var mantras: [LocalMantra] = []
    @Published var isLoading = false
    @Published var isOnline = true
    @Published var hasPendingSync = false

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
    }

    func loadMantras(for date: Date) async {
        isLoading = true
        let dateString = formatDate(date)

        // First, load from local storage
        loadLocalMantras(for: dateString)

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

            // Update local with server data (server wins for now)
            for serverMantra in serverMantras {
                if let local = mantras.first(where: { $0.name == serverMantra.name }) {
                    // If local has pending changes with higher count, push to server
                    if local.pendingSync && local.count > serverMantra.count {
                        await pushToServer(mantra: local)
                    } else {
                        // Otherwise, update local with server data
                        local.count = serverMantra.count
                        local.pendingSync = false
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
        mantra.count += 1
        mantra.pendingSync = true
        mantra.lastModified = Date()
        try? modelContext.save()

        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()

        // Try to sync immediately
        Task {
            await pushToServer(mantra: mantra)
            updatePendingSyncStatus()
        }
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
            }
        }
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
}

enum APIError: Error {
    case invalidURL
    case networkError
}
