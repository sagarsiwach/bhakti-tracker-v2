import SwiftUI
import Charts

struct StatisticsView: View {
    @ObservedObject var store: MantraStore
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @State private var weeklyStats: [(date: String, first: Int, third: Int, dandavat: Int)] = []
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background(for: colorScheme)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Streak Card
                        streakCard

                        // Weekly Chart
                        weeklyChartCard

                        // Settings
                        settingsCard
                    }
                    .padding()
                }
            }
            .navigationTitle("Statistics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(AppTheme.accent)
                }
            }
            .task {
                weeklyStats = await store.getWeeklyStats()
                isLoading = false
            }
        }
    }

    private var streakCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundStyle(.orange)
                Text("Current Streak")
                    .fontWeight(.semibold)
                Spacer()
            }

            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text("\(store.currentStreak)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.accent)
                Text("days")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            Text(streakMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(AppTheme.card(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var streakMessage: String {
        switch store.currentStreak {
        case 0:
            return "Complete all mantras today to start a streak!"
        case 1...6:
            return "Keep going! You're building momentum."
        case 7...29:
            return "Amazing consistency! You're on fire!"
        case 30...99:
            return "Incredible dedication! A true practitioner."
        default:
            return "Legendary! Your practice is unshakeable."
        }
    }

    private var weeklyChartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(AppTheme.accent)
                Text("Last 7 Days")
                    .fontWeight(.semibold)
                Spacer()
            }

            if isLoading {
                ProgressView()
                    .frame(height: 200)
            } else {
                Chart {
                    ForEach(weeklyStats, id: \.date) { stat in
                        BarMark(
                            x: .value("Date", formatShortDate(stat.date)),
                            y: .value("Count", stat.first)
                        )
                        .foregroundStyle(AppTheme.accent)
                        .position(by: .value("Type", "First"))

                        BarMark(
                            x: .value("Date", formatShortDate(stat.date)),
                            y: .value("Count", stat.third)
                        )
                        .foregroundStyle(AppTheme.accentLight)
                        .position(by: .value("Type", "Third"))

                        BarMark(
                            x: .value("Date", formatShortDate(stat.date)),
                            y: .value("Count", stat.dandavat)
                        )
                        .foregroundStyle(AppTheme.success)
                        .position(by: .value("Type", "Dandavat"))
                    }
                }
                .chartForegroundStyleScale([
                    "First": AppTheme.accent,
                    "Third": AppTheme.accentLight,
                    "Dandavat": AppTheme.success
                ])
                .frame(height: 200)
            }

            HStack(spacing: 16) {
                Label("First", systemImage: "circle.fill")
                    .font(.caption)
                    .foregroundStyle(AppTheme.accent)
                Label("Third", systemImage: "circle.fill")
                    .font(.caption)
                    .foregroundStyle(AppTheme.accentLight)
                Label("Dandavat", systemImage: "circle.fill")
                    .font(.caption)
                    .foregroundStyle(AppTheme.success)
            }
        }
        .padding()
        .background(AppTheme.card(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var settingsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "gearshape.fill")
                    .foregroundStyle(.gray)
                Text("Settings")
                    .fontWeight(.semibold)
                Spacer()
            }

            Toggle(isOn: Binding(
                get: { UserPreferences.shared.soundEnabled },
                set: { UserPreferences.shared.soundEnabled = $0 }
            )) {
                HStack {
                    Image(systemName: "speaker.wave.2.fill")
                        .foregroundStyle(AppTheme.accent)
                    Text("Sound Effects")
                }
            }
            .tint(AppTheme.accent)
        }
        .padding()
        .background(AppTheme.card(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func formatShortDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateString) else { return dateString }

        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEE"
        return dayFormatter.string(from: date)
    }
}

#Preview {
    StatisticsView(store: MantraStore())
        .preferredColorScheme(.dark)
}
