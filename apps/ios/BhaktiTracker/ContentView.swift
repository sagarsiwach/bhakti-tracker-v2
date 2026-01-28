import SwiftUI

// MARK: - Color Theme
struct AppTheme {
    // Light mode - warm earth tones
    static let lightBackground = Color(red: 0.96, green: 0.91, blue: 0.84)
    static let lightSecondary = Color(red: 0.92, green: 0.86, blue: 0.78)
    static let lightCard = Color.white.opacity(0.7)

    // Dark mode - rich brownish tones
    static let darkBackground = Color(red: 0.12, green: 0.10, blue: 0.08)
    static let darkSecondary = Color(red: 0.18, green: 0.14, blue: 0.11)
    static let darkCard = Color(red: 0.22, green: 0.18, blue: 0.14)

    // Accent - saffron/orange
    static let accent = Color(red: 0.92, green: 0.55, blue: 0.20)
    static let accentLight = Color(red: 0.96, green: 0.72, blue: 0.45)

    static func background(for scheme: ColorScheme) -> Color {
        scheme == .dark ? darkBackground : lightBackground
    }

    static func secondary(for scheme: ColorScheme) -> Color {
        scheme == .dark ? darkSecondary : lightSecondary
    }

    static func card(for scheme: ColorScheme) -> Color {
        scheme == .dark ? darkCard : lightCard
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
                MantraPageView(
                    mantraIndex: 0,
                    selectedDate: $selectedDate,
                    showStats: $showStats,
                    store: store
                )
                .tabItem {
                    Label("First", systemImage: "leaf.fill")
                }
                .tag(0)

                MantraPageView(
                    mantraIndex: 1,
                    selectedDate: $selectedDate,
                    showStats: $showStats,
                    store: store
                )
                .tabItem {
                    Label("Third", systemImage: "leaf.circle.fill")
                }
                .tag(1)
            }
            .tint(AppTheme.accent)
            .onAppear {
                configureTabBarAppearance()
                loadMantras()
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                if newPhase == .active {
                    // Refresh when app becomes active (handles Action Button updates)
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

    private func loadMantras() {
        Task {
            await store.loadMantras(for: selectedDate)
        }
    }

    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        if colorScheme == .dark {
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor(AppTheme.darkSecondary)
        }
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}

// MARK: - Mantra Page View
struct MantraPageView: View {
    let mantraIndex: Int
    @Binding var selectedDate: Date
    @Binding var showStats: Bool
    @ObservedObject var store: MantraStore
    @Environment(\.colorScheme) var colorScheme

    private var currentMantra: LocalMantra? {
        guard mantraIndex < store.mantras.count else { return nil }
        return store.mantras[mantraIndex]
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [
                        AppTheme.background(for: colorScheme),
                        AppTheme.secondary(for: colorScheme)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Offline banner
                    if !store.isOnline {
                        HStack(spacing: 8) {
                            Image(systemName: "wifi.slash")
                            Text("Offline mode")
                        }
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(AppTheme.accent.opacity(0.9))
                    }

                    // Date Picker with Streak
                    HStack {
                        DatePickerView(selectedDate: $selectedDate, onDateChange: loadMantras)

                        // Streak badge
                        if store.currentStreak > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "flame.fill")
                                    .foregroundStyle(.orange)
                                Text("\(store.currentStreak)")
                                    .fontWeight(.bold)
                            }
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(AppTheme.card(for: colorScheme))
                            .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                    Spacer()

                    // Mantra Counter
                    if store.isLoading && store.mantras.isEmpty {
                        ProgressView()
                            .controlSize(.large)
                            .tint(AppTheme.accent)
                    } else if let mantra = currentMantra {
                        MantraCounterView(mantra: mantra) {
                            store.increment(mantra: mantra)
                        }
                    } else {
                        VStack(spacing: 16) {
                            Image(systemName: "leaf.fill")
                                .font(.system(size: 60))
                                .foregroundStyle(AppTheme.accent.opacity(0.5))
                            Text("Loading...")
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()
                    Spacer()
                }
            }
            .navigationTitle(currentMantra?.displayName ?? "Mantra")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.background(for: colorScheme), for: .navigationBar)
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
                            .rotationEffect(.degrees(store.hasPendingSync ? 360 : 0))
                            .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: store.hasPendingSync)
                    }
                }
            }
        }
    }

    private func loadMantras() {
        Task {
            await store.loadMantras(for: selectedDate)
        }
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
            }

            // Date display
            VStack(spacing: 2) {
                Text(selectedDate, format: .dateTime.weekday(.wide))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(selectedDate, format: .dateTime.day().month(.abbreviated))
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            .frame(minWidth: 80)

            Button {
                guard !isToday else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
                }
                onDateChange()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(isToday ? .gray : AppTheme.accent)
                    .frame(width: 40, height: 40)
                    .background(AppTheme.card(for: colorScheme))
                    .clipShape(Circle())
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
