import SwiftUI

struct ConfettiView: View {
    @State private var particles: [ConfettiParticle] = []
    let colors: [Color] = [
        AppTheme.accent,
        AppTheme.accentLight,
        .yellow,
        .orange,
        .red,
        .green
    ]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(particles) { particle in
                    ConfettiPiece(particle: particle)
                }
            }
            .onAppear {
                createParticles(in: geometry.size)
            }
        }
        .allowsHitTesting(false)
    }

    private func createParticles(in size: CGSize) {
        for _ in 0..<50 {
            let particle = ConfettiParticle(
                x: CGFloat.random(in: 0...size.width),
                y: -20,
                color: colors.randomElement() ?? .orange,
                size: CGFloat.random(in: 8...16),
                rotation: Double.random(in: 0...360),
                velocity: CGFloat.random(in: 300...500),
                horizontalVelocity: CGFloat.random(in: -100...100)
            )
            particles.append(particle)
        }
    }
}

struct ConfettiParticle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    let color: Color
    let size: CGFloat
    let rotation: Double
    let velocity: CGFloat
    let horizontalVelocity: CGFloat
}

struct ConfettiPiece: View {
    let particle: ConfettiParticle
    @State private var offset: CGSize = .zero
    @State private var rotation: Double = 0
    @State private var opacity: Double = 1

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(particle.color)
            .frame(width: particle.size, height: particle.size * 0.6)
            .rotationEffect(.degrees(rotation))
            .offset(offset)
            .opacity(opacity)
            .position(x: particle.x, y: particle.y)
            .onAppear {
                withAnimation(.easeOut(duration: 2.5)) {
                    offset = CGSize(
                        width: particle.horizontalVelocity,
                        height: particle.velocity
                    )
                    rotation = particle.rotation + Double.random(in: 360...720)
                }
                withAnimation(.easeIn(duration: 2.5).delay(0.5)) {
                    opacity = 0
                }
            }
    }
}

struct CelebrationOverlay: View {
    let mantraName: String
    @Binding var isShowing: Bool

    var body: some View {
        ZStack {
            // Background blur
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(AppTheme.accent)
                    .symbolEffect(.bounce, value: isShowing)

                Text("\(mantraName.capitalized) Complete!")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)

                Text("Great job! Keep up the practice.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(40)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(radius: 20)
            .transition(.scale.combined(with: .opacity))

            ConfettiView()
        }
        .onTapGesture {
            withAnimation {
                isShowing = false
            }
        }
    }
}

#Preview {
    CelebrationOverlay(mantraName: "First", isShowing: .constant(true))
        .preferredColorScheme(.dark)
}
