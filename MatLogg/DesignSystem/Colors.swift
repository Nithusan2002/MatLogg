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
    // Source classification only; these colors do not express nutritional quality.
    static let processingNonUltraSurface = Color(UIColor.appProcessingNonUltraSurface)
    static let processingUltraSurface = Color(UIColor.appProcessingUltraSurface)
    static let info = Color(UIColor.appInfo)
    // Nutri-Score calculation contributions; not food safety or technical status.
    static let nutritionPositiveContribution = Color(UIColor.appNutritionPositiveContribution)
    static let nutritionNegativeContribution = Color(UIColor.appNutritionNegativeContribution)
    static let warmSurface = Color(UIColor.appWarmSurface)
    static let mutedSurface = Color(UIColor.appMutedSurface)
    static let deepInk = Color(UIColor.appDeepInk)
    static let energyTint = info
    static let calorieBlue = energyTint
    static let energyChart = Color(UIColor.appEnergyChart)
    static let action = Color(UIColor.appAction)
    static let actionText = action
    static let errorText = action
    static let onVibrant = Color(UIColor.appOnVibrant)
    static let controlBorder = Color(UIColor.appControlBorder)
    
    // Fixed camera colors are independent of the interface appearance.
    static let imageViewerBackground = Color.black
    static let scannerText = Color.white
    static let scannerSecondaryText = scannerText.opacity(0.82)
    static let scannerMutedText = scannerText.opacity(0.85)
    static let scannerScrim = Color.black.opacity(0.28)
    static let scannerPanel = Color.black.opacity(0.68)
    static let scannerHintPanel = Color.black.opacity(0.52)
    static let scannerControl = Color.black.opacity(0.58)
    static let scannerGradientClear = Color.black.opacity(0)
    static let scannerShadow = Color.black.opacity(0.35)
    static let scannerControlBorder = scannerText.opacity(0.24)
    static let scannerPanelBorder = scannerText.opacity(0.28)
    static let scannerOutline = scannerText.opacity(0.75)

    static let chipFillSelected = brand.opacity(0.12)
    static let chipStroke = separator
    static let progressTrack = AppColors.ink.opacity(0.08)
    static let progressFill = brand.opacity(0.22)
    
    static let macroProteinTint = brand
    static let macroCarbTint = accent
    static let macroFatTint = success

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
    static let appEnergyChart = UIColor.dynamic(light: 0x187BA6, dark: 0x62C9FA)
    static let appAction = UIColor.dynamic(light: 0xC72E49, dark: 0xFF7182)
    static let appOnVibrant = UIColor(hex: 0x231937)
    static let appControlBorder = UIColor.dynamic(light: 0x9A8B82, dark: 0x8C7B72)
    static let appTextSecondary = UIColor.dynamic(light: 0x70656D, dark: 0xC9BDC3)
    static let appSeparator = UIColor.dynamic(light: 0xE9DDD4, dark: 0x453832)
    static let appBrand = UIColor.dynamic(light: 0xFF5268, dark: 0xFF7182)
    static let appAccent = UIColor.dynamic(light: 0xFFBF3F, dark: 0xFFD06D)
    static let appSuccess = UIColor.dynamic(light: 0x20B889, dark: 0x42D3A7)
    static let appProcessingNonUltraSurface = UIColor.dynamic(light: 0xE7F4EC, dark: 0x20352B)
    static let appProcessingUltraSurface = UIColor.dynamic(light: 0xFBE9E7, dark: 0x3D2728)
    static let appInfo = UIColor.dynamic(light: 0x35B8F4, dark: 0x62C9FA)
    static let appNutritionPositiveContribution = UIColor.dynamic(light: 0x16844A, dark: 0x63D493)
    static let appNutritionNegativeContribution = UIColor.dynamic(light: 0xC83E47, dark: 0xFF8790)
    
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
