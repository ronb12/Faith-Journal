import SwiftUI

class ThemeManager: ObservableObject {
    @Published var currentTheme: Theme = .default
    
    static let shared = ThemeManager()
    
    enum Theme: String, CaseIterable {
        case `default` = "Default"
        case sunset = "Sunset"
        case ocean = "Ocean"
        case forest = "Forest"
        case lavender = "Lavender"
        case golden = "Golden"
        case midnight = "Midnight"
        case spring = "Spring"
        case pink = "Pink"
    }
    
    var colors: ThemeColors {
        switch currentTheme {
        case .default:
            return ThemeColors(
                primary: Color(red: 0.4, green: 0.2, blue: 0.8),
                secondary: Color(red: 0.9, green: 0.6, blue: 0.2),
                accent: Color(red: 0.2, green: 0.8, blue: 0.6),
                background: Color(red: 0.98, green: 0.96, blue: 1.0),
                cardBackground: Color.white,
                text: Color(red: 0.1, green: 0.1, blue: 0.2),
                textSecondary: Color(red: 0.4, green: 0.4, blue: 0.5)
            )
        case .sunset:
            return ThemeColors(
                primary: Color(red: 0.9, green: 0.3, blue: 0.3),
                secondary: Color(red: 1.0, green: 0.7, blue: 0.3),
                accent: Color(red: 0.8, green: 0.4, blue: 0.6),
                background: Color(red: 1.0, green: 0.95, blue: 0.9),
                cardBackground: Color.white,
                text: Color(red: 0.3, green: 0.2, blue: 0.2),
                textSecondary: Color(red: 0.6, green: 0.4, blue: 0.4)
            )
        case .ocean:
            return ThemeColors(
                primary: Color(red: 0.2, green: 0.6, blue: 0.9),
                secondary: Color(red: 0.4, green: 0.8, blue: 1.0),
                accent: Color(red: 0.1, green: 0.8, blue: 0.7),
                background: Color(red: 0.95, green: 0.98, blue: 1.0),
                cardBackground: Color.white,
                text: Color(red: 0.1, green: 0.2, blue: 0.4),
                textSecondary: Color(red: 0.4, green: 0.5, blue: 0.6)
            )
        case .forest:
            return ThemeColors(
                primary: Color(red: 0.2, green: 0.7, blue: 0.3),
                secondary: Color(red: 0.6, green: 0.8, blue: 0.4),
                accent: Color(red: 0.8, green: 0.6, blue: 0.2),
                background: Color(red: 0.96, green: 0.98, blue: 0.95),
                cardBackground: Color.white,
                text: Color(red: 0.1, green: 0.3, blue: 0.1),
                textSecondary: Color(red: 0.4, green: 0.5, blue: 0.4)
            )
        case .lavender:
            return ThemeColors(
                primary: Color(red: 0.6, green: 0.4, blue: 0.9),
                secondary: Color(red: 0.8, green: 0.6, blue: 1.0),
                accent: Color(red: 0.9, green: 0.4, blue: 0.8),
                background: Color(red: 0.98, green: 0.96, blue: 1.0),
                cardBackground: Color.white,
                text: Color(red: 0.3, green: 0.2, blue: 0.4),
                textSecondary: Color(red: 0.5, green: 0.4, blue: 0.6)
            )
        case .golden:
            return ThemeColors(
                primary: Color(red: 0.9, green: 0.7, blue: 0.2),
                secondary: Color(red: 1.0, green: 0.8, blue: 0.4),
                accent: Color(red: 0.8, green: 0.5, blue: 0.2),
                background: Color(red: 1.0, green: 0.98, blue: 0.95),
                cardBackground: Color.white,
                text: Color(red: 0.4, green: 0.3, blue: 0.1),
                textSecondary: Color(red: 0.6, green: 0.5, blue: 0.3)
            )
        case .midnight:
            return ThemeColors(
                primary: Color(red: 0.3, green: 0.2, blue: 0.8),
                secondary: Color(red: 0.6, green: 0.4, blue: 1.0),
                accent: Color(red: 0.2, green: 0.8, blue: 0.9),
                background: Color(red: 0.05, green: 0.05, blue: 0.1),
                cardBackground: Color(red: 0.1, green: 0.1, blue: 0.15),
                text: Color.white,
                textSecondary: Color(red: 0.7, green: 0.7, blue: 0.8)
            )
        case .spring:
            return ThemeColors(
                primary: Color(red: 0.8, green: 0.4, blue: 0.6),
                secondary: Color(red: 0.6, green: 0.8, blue: 0.4),
                accent: Color(red: 0.4, green: 0.6, blue: 0.8),
                background: Color(red: 0.98, green: 0.95, blue: 0.98),
                cardBackground: Color.white,
                text: Color(red: 0.3, green: 0.2, blue: 0.3),
                textSecondary: Color(red: 0.5, green: 0.4, blue: 0.5)
            )
        case .pink:
            return ThemeColors(
                primary: Color(red: 0.95, green: 0.4, blue: 0.7),
                secondary: Color(red: 1.0, green: 0.6, blue: 0.8),
                accent: Color(red: 0.9, green: 0.3, blue: 0.6),
                background: Color(red: 1.0, green: 0.98, blue: 0.99),
                cardBackground: Color.white,
                text: Color(red: 0.3, green: 0.1, blue: 0.2),
                textSecondary: Color(red: 0.6, green: 0.4, blue: 0.5)
      