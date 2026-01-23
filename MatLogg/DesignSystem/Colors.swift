import SwiftUI
import UIKit

enum AppColors {
    static let background = Color(UIColor.appBackground)
    static let surface = Color(UIColor.appSurface)
    static let ink = Color(UIColor.appInk)
    static let textSecondary = Color(UIColor.appTextSecondary)
    static let separator = Color(UIColor.appSeparator)
    static let brand = Color(UIColor.appBrand)
    static let accent = Color(UIColor.appAccent)
    
    static let chipFillSelected = brand.opacity(0.12)
    static let chipStroke = separator
    static let progressTrack = AppColors.ink.opacity(0.08)
    static let progressFill = brand.opacity(0.22)
    
    static let macroProteinTint = Color(UIColor.appProteinTint)
    static let macroCarbTint = Color(UIColor.appCarbTint)
    static let macroFatTint = Color(UIColor.appFatTint)
}

private extension UIColor {
    static let appBackground = UIColor.dynamic(light: 0xF6F7F9, dark: 0x0B0F17)
    static let appSurface = UIColor.dynamic(light: 0xFFFFFF, dark: 0x121826)
    static let appInk = UIColor.dynamic(light: 0x0B1220, dark: 0xEAF0FF)
    static let appTextSecondary = UIColor.dynamic(light: 0x5B6472, dark: 0xAAB3C2)
    static let appSeparator = UIColor.dynamic(light: 0xE6EAF0, dark: 0x232B3A)
    static let appBrand = UIColor.dynamic(light: 0xFF5A3C, dark: 0xFF6B52)
    static let appAccent = UIColor.dynamic(light: 0xFFB020, dark: 0xFFC04D)
    static let appProteinTint = UIColor(hex: 0x3B82F6)
    static let appCarbTint = UIColor(hex: 0x8B5CF6)
    static let appFatTint = UIColor(hex: 0xF59E0B)
    
    static func dynamic(light: UInt32, dark: UInt32) -> UIColor {
        UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        }
    }
    
    convenience init(hex: UInt32) {
        let red = CGFloat((hex >> 16) & 0xFF) / 255.0
        let green = CGFloat((hex >> 8) & 0xFF) / 255.0
        let blue = CGFloat(hex & 0xFF) / 255.0
        self.init(red: red, green: green, blue: blue, alpha: 1.0)
    }
}
