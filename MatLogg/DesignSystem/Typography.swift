import SwiftUI

enum AppTypography {
    static let display = Font.system(size: 48, weight: .medium, design: .default)
    static func startupTitle(size: CGFloat) -> Font {
        .system(size: size, weight: .medium, design: .default)
    }
    static let hero = Font.system(.largeTitle, design: .rounded, weight: .heavy)
    static let heroValue = Font.system(.largeTitle, design: .default, weight: .medium).monospacedDigit()
    static let title = Font.system(.title2, design: .rounded, weight: .semibold)
    static let sectionTitle = Font.system(.headline, design: .rounded, weight: .semibold)
    static let body = Font.system(.body, design: .default, weight: .regular)
    static let bodyEmphasis = Font.system(.body, design: .default, weight: .semibold)
    static let secondary = Font.system(.subheadline, design: .default, weight: .regular)
    static let secondaryEmphasis = Font.system(.subheadline, design: .default, weight: .semibold)
    static let caption = Font.system(.caption, design: .default, weight: .regular)
    static let captionEmphasis = Font.system(.caption, design: .default, weight: .semibold)
}
