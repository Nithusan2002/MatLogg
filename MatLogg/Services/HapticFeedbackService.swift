import Foundation
import UIKit
import AVFoundation

class HapticFeedbackService {
    static let shared = HapticFeedbackService()
    
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let selection = UISelectionFeedbackGenerator()
    
    private init() {
        impactLight.prepare()
        impactMedium.prepare()
        impactHeavy.prepare()
        selection.prepare()
    }
    
    enum FeedbackType {
        case barcodeDetected      // 3x light taps
        case loggingSuccess       // 2x medium taps
        case error                // 1x heavy tap
        case stepperTap          // 1x light tap
        case favoriteToggle      // 1x light tap
        case selectItem          // selection feedback
    }
    
    func trigger(_ type: FeedbackType, isEnabled: Bool = true) {
        guard isEnabled else { return }
        
        switch type {
        case .barcodeDetected:
            triggerPattern([0.1, 0.05, 0.1, 0.05, 0.1])
        case .loggingSuccess:
            triggerPattern([0.1, 0.1, 0.1])
        case .error:
            impactHeavy.impactOccurred()
        case .stepperTap:
            impactLight.impactOccurred()
        case .favoriteToggle:
            impactLight.impactOccurred()
        case .selectItem:
            selection.selectionChanged()
        }
    }
    
    private func triggerPattern(_ pattern: [TimeInterval]) {
        var delay = 0.0
        for interval in pattern {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.impactLight.impactOccurred()
            }
            delay += interval
        }
    }
}
