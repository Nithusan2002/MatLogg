import SwiftUI

enum AppTypography {
    static let display = Font.system(size: 48, weight: .heavy, design: .rounded)
    static let hero = Font.system(.largeTitle, design: .rounded, weight: .heavy)
    static let title = Font.system(.title2, design: .rounded, weight: .bold)
    static let sectionTitle = Font.system(.headline, design: .rounded, weight: .heavy)
    static let body = Font.system(.body, design: .rounded, weight: .regular)
    static let bodyEmphasis = Font.system(.body, design: .rounded, weight: .semibold)
    static let caption = Font.system(.caption, design: .rounded, weight: .regular)
    static let captionEmphasis = Font.system(.caption, design: .rounded, weight: .bold)
}
