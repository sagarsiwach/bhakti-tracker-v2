import SwiftUI

// MARK: - Color Theme
struct AppTheme {
    // Light mode - warm earth tones
    static let lightBackground = Color(red: 0.98, green: 0.96, blue: 0.93)
    static let lightSecondary = Color(red: 0.95, green: 0.92, blue: 0.88)
    static let lightCard = Color.white

    // Dark mode - rich brownish tones
    static let darkBackground = Color(red: 0.08, green: 0.07, blue: 0.06)
    static let darkSecondary = Color(red: 0.12, green: 0.10, blue: 0.09)
    static let darkCard = Color(red: 0.16, green: 0.14, blue: 0.12)

    // Accent - saffron/orange
    static let accent = Color(red: 0.95, green: 0.55, blue: 0.20)
    static let accentLight = Color(red: 0.98, green: 0.75, blue: 0.45)
    static let accentDark = Color(red: 0.85, green: 0.45, blue: 0.15)

    // Additional colors
    static let success = Color(red: 0.30, green: 0.70, blue: 0.45)
    static let warning = Color(red: 0.95, green: 0.75, blue: 0.25)

    static func background(for scheme: ColorScheme) -> Color {
        scheme == .dark ? darkBackground : lightBackground
    }

    static func secondary(for scheme: ColorScheme) -> Color {
        scheme == .dark ? darkSecondary : lightSecondary
    }

    static func card(for scheme: ColorScheme) -> Color {
        scheme == .dark ? darkCard : lightCard
    }

    static func text(for scheme: ColorScheme) -> Color {
        scheme == .dark ? .white : Color(red: 0.15, green: 0.12, blue: 0.10)
    }
}

// MARK: - Main Content View
struct ContentView: View {
    @EnvironmentObject var store: MantraStore
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.scenePhase) var scenePhase
    @State private var selectedDate = Date()
    @State private var selectedTab = 0
    @State private var showStats = false

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                // Counters Tab
                CountersView(selectedDate: $selectedDate, showStats: $showStats, store: store)
                    .tabItem {
                        Label("Practice", systemImage: "hands.clap.fill")
                    }
                    .tag(0)

                // Daily Tab (Aarti & Satsang)
                DailyView(selectedDate: $selectedDate, store: store)
                    .tabItem {
                        Label("Daily", systemImage: "checklist")
                    }
                    .tag(1)
            }
            .tint(AppTheme.accent)
            .onAppear {
                configureTabBarAppearance()
                loadData()
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                if newPhase == .active {
                    store.refreshFromDatabase()
                }
            }
            .sheet(isPresented: $showStats) {
                StatisticsView(store: store)
            }

            // Celebration overlay
            if store.showCelebration, let mantraName = store.celebratingMantra {
                CelebrationOverlay(mantraName: mantraName, isShowing: $store.showCelebration)
                    .transition(.opacity)
                    .zIndex(100)
            }
        }
        .animation(.easeInOut, value: store.showCelebration)
    }

    private func loadData() {
        Task {
            await store.loadData(for: selectedDate)
        }
    }

    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        if colorScheme == .dark {
            appearance.backgroundColor = UIColor(AppTheme.darkSecondary)
        } else {
            appearance.backgroundColor = UIColor(AppTheme.lightCard)
        }
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}

// MARK: - Counters View (Mantras + Dandavat)
struct CountersView: View {
    @Binding var selectedDate: Date
    @Binding var showStats: Bool
    @ObservedObject var store: MantraStore
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background(for: colorScheme)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Date & Streak Header
                        headerSection

                        // Offline banner
                        if !store.isOnline {
                            offlineBanner
                        }

                        // Mantra Cards
                        ForEach(store.mantras, id: \.name) { mantra in
                            MantraCard(mantra: mantra) {
                                store.increment(mantra: mantra)
                            }
                        }

                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
            }
            .navigationTitle("Practice")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showStats = true
                    } label: {
                        Image(systemName: "chart.bar.fill")
                            .foregroundStyle(AppTheme.accent)
                    }
                }

                if store.hasPendingSync {
                    ToolbarItem(placement: .topBarTrailing) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundStyle(AppTheme.accent)
                            .symbolEffect(.pulse)
                    }
                }
            }
        }
    }

    private var headerSection: some View {
        HStack {
            // Date picker
            DatePickerView(selectedDate: $selectedDate) {
                Task { await store.loadData(for: selectedDate) }
            }

            Spacer()

            // Streak badge
            if store.currentStreak > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(.orange)
                    Text("\(store.currentStreak)")
                        .fontWeight(.bold)
                    Text("days")
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(AppTheme.card(for: colorScheme))
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
            }
        }
    }

    private var offlineBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
            Text("Offline mode - changes will sync later")
        }
        .font(.caption)
        .fontWeight(.medium)
        .foregroundStyle(.white)
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .background(AppTheme.accent.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Mantra Card
struct MantraCard: View {
    let mantra: LocalMantra
    var onTap: () -> Void
    @Environment(\.colorScheme) var colorScheme
    @State private var isPressed = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Icon with progress ring
                ZStack {
                    // Background circle
                    Circle()
                        .fill(AppTheme.secondary(for: colorScheme))
                        .frame(width: 70, height: 70)

                    // Progress ring (only for mantras with targets)
                    if mantra.hasTarget {
                        Circle()
                            .trim(from: 0, to: mantra.progress)
                            .stroke(
                                LinearGradient(
                                    colors: [AppTheme.accent, AppTheme.accentLight],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 4, lineCap: .round)
                            )
                            .frame(width: 70, height: 70)
                            .rotationEffect(.degrees(-90))
                    }

                    // Icon
                    Image(systemName: mantra.icon)
                        .font(.system(size: 28))
                        .foregroundStyle(mantra.isComplete ? AppTheme.success : AppTheme.accent)
                }

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(mantra.displayName)
                        .font(.headline)
                        .foregroundStyle(AppTheme.text(for: colorScheme))

                    if let target = mantra.target {
                        Text("\(mantra.count) / \(target)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Total: \(mantra.count)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if mantra.hasTarget {
                        Text("\(Int(mantra.progress * 100))%")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(mantra.isComplete ? AppTheme.success : AppTheme.accent)
                    }
                }

                Spacer()

                // Count display
                VStack {
                    Text("\(mantra.count)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.accent)
                        .contentTransition(.numericText())

                    if mantra.isComplete {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(AppTheme.success)
                    }
                }
            }
            .padding(16)
            .background(AppTheme.card(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.08), radius: 8, y: 2)
            .scaleEffect(isPressed ? 0.98 : 1.0)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(flexibility: .soft), trigger: mantra.count)
        .onLongPressGesture(minimumDuration: 0, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// MARK: - Daily View (Aarti & Satsang)
struct DailyView: View {
    @Binding var selectedDate: Date
    @ObservedObject var store: MantraStore
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background(for: colorScheme)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Date picker
                        DatePickerView(selectedDate: $selectedDate) {
                            Task { await store.loadData(for: selectedDate) }
                        }
                        .padding(.horizontal)

                        // Aarti Section
                        if !store.aartiActivities.isEmpty {
                            ActivitySection(
                                title: "Aarti",
                                icon: "sun.max.fill",
                                activities: store.aartiActivities,
                                store: store
                            )
                        }

                        // Satsang Section
                        if !store.satsangActivities.isEmpty {
                            ActivitySection(
                                title: "Satsang",
                                icon: "book.fill",
                                activities: store.satsangActivities,
                                store: store
                            )
                        }

                        Spacer(minLength: 100)
                    }
                    .padding(.top, 8)
                }
            }
            .navigationTitle("Daily Practice")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - Activity Section
struct ActivitySection: View {
    let title: String
    let icon: String
    let activities: [LocalActivity]
    @ObservedObject var store: MantraStore
    @Environment(\.colorScheme) var colorScheme

    private var completedCount: Int {
        activities.filter { $0.completed }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section Header
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(AppTheme.accent)
                Text(title)
                    .font(.headline)
                Spacer()
                Text("\(completedCount)/\(activities.count)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            // Activity Cards
            VStack(spacing: 8) {
                ForEach(activities, id: \.name) { activity in
                    ActivityRow(activity: activity) {
                        store.toggle(activity: activity)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Activity Row
struct ActivityRow: View {
    let activity: LocalActivity
    var onToggle: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 14) {
                // Icon
                Image(systemName: activity.icon)
                    .font(.system(size: 20))
                    .foregroundStyle(activity.completed ? AppTheme.success : AppTheme.accent)
                    .frame(width: 32)

                // Name
                Text(activity.displayName)
                    .font(.body)
                    .foregroundStyle(AppTheme.text(for: colorScheme))
                    .strikethrough(activity.completed, color: .secondary)

                Spacer()

                // Checkbox
                Image(systemName: activity.completed ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundStyle(activity.completed ? AppTheme.success : .secondary.opacity(0.5))
                    .contentTransition(.symbolEffect(.replace))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(AppTheme.card(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.2 : 0.05), radius: 4, y: 1)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(flexibility: .soft), trigger: activity.completed)
    }
}

// MARK: - Date Picker
struct DatePickerView: View {
    @Binding var selectedDate: Date
    var onDateChange: () -> Void
    @Environment(\.colorScheme) var colorScheme

    private var isToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }

    var body: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
                }
                onDateChange()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 40, height: 40)
                    .background(AppTheme.card(for: colorScheme))
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
            }

            VStack(spacing: 2) {
                Text(selectedDate, format: .dateTime.weekday(.wide))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(selectedDate, format: .dateTime.day().month(.abbreviated))
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            .frame(minWidth: 100)

            Button {
                guard !isToday else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
                }
                onDateChange()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(isToday ? .gray.opacity(0.5) : AppTheme.accent)
                    .frame(width: 40, height: 40)
                    .background(AppTheme.card(for: colorScheme))
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
            }
            .disabled(isToday)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(MantraStore())
        .preferredColorScheme(.dark)
}
