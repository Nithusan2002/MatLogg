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
    static let success = Color(UIColor.appSuccess)
    static let info = Color(UIColor.appInfo)
    static let warmSurface = Color(UIColor.appWarmSurface)
    static let mutedSurface = Color(UIColor.appMutedSurface)
    static let deepInk = Color(UIColor.appDeepInk)
    static let calorieBlue = Color(UIColor.appCalorieBlue)
    
    static let chipFillSelected = brand.opacity(0.12)
    static let chipStroke = separator
    static let progressTrack = AppColors.ink.opacity(0.08)
    static let progressFill = brand.opacity(0.22)
    
    static let macroProteinTint = Color(UIColor.appProteinTint)
    static let macroCarbTint = Color(UIColor.appCarbTint)
    static let macroFatTint = Color(UIColor.appFatTint)

    static func mealTint(for mealType: String) -> Color {
        switch mealType.lowercased() {
        case "frokost": return info
        case "lunsj": return success
        case "middag": return brand
        default: return accent
        }
    }
}

private extension UIColor {
    static let appBackground = UIColor.dynamic(light: 0xFFF5E8, dark: 0x17120F)
    static let appSurface = UIColor.dynamic(light: 0xFFFCF7, dark: 0x241C18)
    static let appWarmSurface = UIColor.dynamic(light: 0xFCEBDD, dark: 0x30231D)
    static let appMutedSurface = UIColor.dynamic(light: 0xF4EDE6, dark: 0x2A2420)
    static let appInk = UIColor.dynamic(light: 0x24192E, dark: 0xFFF8F1)
    static let appDeepInk = UIColor.dynamic(light: 0x231937, dark: 0xFFF8F1)
    static let appCalorieBlue = UIColor.dynamic(light: 0x49B7ED, dark: 0x318FC0)
    static let appTextSecondary = UIColor.dynamic(light: 0x756A72, dark: 0xC9BDC3)
    static let appSeparator = UIColor.dynamic(light: 0xE9DDD4, dark: 0x453832)
    static let appBrand = UIColor.dynamic(light: 0xFF5268, dark: 0xFF7182)
    static let appAccent = UIColor.dynamic(light: 0xFFBF3F, dark: 0xFFD06D)
    static let appSuccess = UIColor.dynamic(light: 0x20B889, dark: 0x42D3A7)
    static let appInfo = UIColor.dynamic(light: 0x35B8F4, dark: 0x62C9FA)
    static let appProteinTint = UIColor.dynamic(light: 0xFF5268, dark: 0xFF7182)
    static let appCarbTint = UIColor.dynamic(light: 0xFFBF3F, dark: 0xFFD06D)
    static let appFatTint = UIColor.dynamic(light: 0x20B889, dark: 0x42D3A7)
    
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
