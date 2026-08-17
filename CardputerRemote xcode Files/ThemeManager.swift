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
    @Published var currentTheme: CyberTheme = .neonGreen
}
