import SwiftUI
import UIKit

@MainActor
final class MealShareRenderingService: MealShareRendering {
    func render(snapshot: MealShareSnapshot, style: MealShareStyle, photo: UIImage?, content: MealShareContent = MealShareContent(), format: MealShareFormat = .story) async throws -> UIImage {
        // Let the progress state draw before the bounded main-actor rendering work.
        await Task.yield()
        try Task.checkCancellation()
        let renderer = ImageRenderer(content: MealShareCardView(snapshot: snapshot, style: style, photo: photo, content: content, format: format)
            .environment(\.dynamicTypeSize, .large)
            .environment(\.locale, Locale(identifier: "nb_NO")))
        renderer.proposedSize = ProposedViewSize(width: format.canvasSize.width, height: format.canvasSize.height)
        renderer.scale = 3
        renderer.isOpaque = true
        guard let image = renderer.uiImage else { throw CocoaError(.coderInvalidValue) }
        // Newly rendered pixels contain no original photo metadata. Keep the payload in memory.
        return image
    }
}
