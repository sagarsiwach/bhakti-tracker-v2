import SwiftUI

struct MantraCounterView: View {
    let mantra: LocalMantra
    var onTap: () -> Void
    @Environment(\.colorScheme) var colorScheme

    private var ringBackground: Color {
        colorScheme == .dark
            ? AppTheme.darkCard
            : Color(UIColor.systemGray5)
    }

    var body: some View {
        VStack(spacing: 24) {
            // Progress ring - tap target
            Button(action: onTap) {
                ZStack {
                    // Background ring
                    Circle()
                        .stroke(ringBackground, lineWidth: 16)
                        .frame(width: 240, height: 240)

                    // Progress ring
                    Circle()
                        .trim(from: 0, to: mantra.progress)
                        .stroke(
                            LinearGradient(
                                colors: [AppTheme.accent, AppTheme.accentLight],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 16, lineCap: .round)
                        )
                        .frame(width: 240, height: 240)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 0.15), value: mantra.count)

                    // Inner content
                    VStack(spacing: 8) {
                        Text("\(mantra.count)")
                            .font(.system(size: 72, weight: .light, design: .rounded))
                            .foregroundStyle(colorScheme == .dark ? .white : .primary)
                            .contentTransition(.numericText())
                            .animation(.snappy(duration: 0.1), value: mantra.count)

                        if let target = mantra.target {
                            Text("of \(target)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        if mantra.isComplete {
                            Label("Complete", systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(AppTheme.accent)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                }
            }
            .buttonStyle(CounterButtonStyle())
            .sensoryFeedback(.impact(flexibility: .soft), trigger: mantra.count)

            // Percentage
            Text("\(Int(mantra.progress * 100))%")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(AppTheme.accent)
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.1), value: mantra.count)
        }
    }
}

struct CounterButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
