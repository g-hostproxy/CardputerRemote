import SwiftUI

enum CyberTheme: String, CaseIterable, Identifiable {
    case neonGreen = "Neon Green"
    case cyberPink = "Cyber Pink"
    case electricPurple = "Electric Purple"
    case laserRed = "Laser Red"
    case matrixTeal = "Matrix Teal"
    
    var id: String { self.rawValue }
    
    var accentColor: Color {
        switch self {
        case .neonGreen: return Color(red: 0.0, green: 1.0, blue: 0.4)
        case .cyberPink: return Color(red: 1.0, green: 0.0, blue: 0.498)
        case .electricPurple: return Color(red: 0.749, green: 0.0, blue: 1.0)
        case .laserRed: return Color(red: 1.0, green: 0.101, blue: 0.101)
        case .matrixTeal: return Color(red: 0.0, green: 0.941, blue: 1.0)
        }
    }
    
    var glowColor: Color {
        return accentColor.opacity(0.6)
    }
}

class ThemeManager: ObservableObject {
    private let themeKey = "saved_cyber_theme"
    
    @Published var currentTheme: CyberTheme {
        didSet {
            UserDefaults.standard.set(currentTheme.rawValue, forKey: themeKey)
        }
    }
    
    init() {
        let savedName = UserDefaults.standard.string(forKey: themeKey) ?? CyberTheme.neonGreen.rawValue
        self.currentTheme = CyberTheme(rawValue: savedName) ?? .neonGreen
    }
}

// MARK: - Floating Particles & Matrix FX (Ported from proven architecture)
struct FloatingParticlesView: View {
    let themeColor: Color

    private struct Particle: Identifiable {
        let id = UUID()
        let x: CGFloat
        let y: CGFloat
        let size: CGFloat
        let opacity: Double
        let speed: Double
    }

    @State private var particles: [Particle] = (0..<24).map { _ in
        Particle(x: CGFloat.random(in: 0...1), y: CGFloat.random(in: 0...1), size: CGFloat.random(in: 2...4), opacity: Double.random(in: 0.15...0.45), speed: Double.random(in: 8...20))
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let now = timeline.date.timeIntervalSinceReferenceDate
                for particle in particles {
                    let yOffset = (now * particle.speed).truncatingRemainder(dividingBy: size.height + 20)
                    let currentY = (particle.y * size.height - yOffset + size.height + 20).truncatingRemainder(dividingBy: size.height + 20)
                    let currentX = particle.x * size.width
                    let rect = CGRect(x: currentX, y: currentY, width: particle.size, height: particle.size)
                    context.opacity = particle.opacity
                    context.fill(Path(ellipseIn: rect), with: .color(themeColor))
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
