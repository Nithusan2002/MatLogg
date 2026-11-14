import SwiftUI

struct ErrorMessageView: View {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "exclamationmark.circle")
                .accessibilityHidden(true)
            Text(message)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(AppColors.errorText)
        .accessibilityElement(children: .combine)
    }
}
