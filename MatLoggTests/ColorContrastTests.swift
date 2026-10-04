import SwiftUI
import UIKit
import Testing
@testable import MatLogg

@MainActor
struct ColorContrastTests {
    @Test(arguments: [false, true])
    func normalTextMeetsContrastOnAppSurfaces(dark: Bool) {
        let surfaces = [AppColors.background, AppColors.surface, AppColors.warmSurface, AppColors.mutedSurface]
        for background in surfaces {
            for foreground in [AppColors.ink, AppColors.deepInk, AppColors.textSecondary, AppColors.actionText, AppColors.errorText] {
                #expect(contrast(foreground, background, dark: dark) >= 4.5)
            }
        }
    }

    @Test(arguments: [false, true])
    func filledControlsAndEnergyCardHaveReadableText(dark: Bool) {
        for background in [AppColors.brand, AppColors.energyTint] {
            #expect(contrast(AppColors.onVibrant, background, dark: dark) >= 4.5)
        }
        #expect(contrast(AppColors.energyChart, AppColors.surface, dark: dark) >= 3)
        #expect(contrast(AppColors.textSecondary, AppColors.surface, dark: dark) >= 3)
    }

    private func contrast(_ foreground: Color, _ background: Color, dark: Bool) -> Double {
        let traits = UITraitCollection(userInterfaceStyle: dark ? .dark : .light)
        let first = luminance(UIColor(foreground).resolvedColor(with: traits))
        let second = luminance(UIColor(background).resolvedColor(with: traits))
        return (max(first, second) + 0.05) / (min(first, second) + 0.05)
    }

    private func luminance(_ color: UIColor) -> Double {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        #expect(color.getRed(&red, green: &green, blue: &blue, alpha: &alpha))
        func linear(_ component: CGFloat) -> Double {
            let value = Double(component)
            return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }
}
