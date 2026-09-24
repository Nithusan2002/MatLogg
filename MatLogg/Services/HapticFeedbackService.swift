import Foundation
import UIKit

final class HapticFeedbackService {
    static let shared = HapticFeedbackService()
    
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let selection = UISelectionFeedbackGenerator()
    private let notification = UINotificationFeedbackGenerator()
    
    private init() {
        impactLight.prepare()
        selection.prepare()
        notification.prepare()
    }
    
    enum FeedbackType {
        case barcodeDetected
        case loggingSuccess
        case error
        case favoriteToggle
        case selectItem
    }
    
    func trigger(_ type: FeedbackType, isEnabled: Bool = true) {
        guard isEnabled else { return }
        
        switch type {
        case .barcodeDetected:
            impactLight.impactOccurred()
        case .loggingSuccess:
            notification.notificationOccurred(.success)
        case .error:
            notification.notificationOccurred(.error)
        case .favoriteToggle:
            selection.selectionChanged()
        case .selectItem:
            selection.selectionChanged()
        }
    }
}
