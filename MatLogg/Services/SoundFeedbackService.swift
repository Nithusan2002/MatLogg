import Foundation
import AVFoundation
import AudioToolbox

class SoundFeedbackService {
    static let shared = SoundFeedbackService()
    
    private var audioPlayer: AVAudioPlayer?
    
    enum SoundType {
        case barcodeDetected
        case loggingSuccess
        case error
        case offlineWarning
        case syncSuccess
        
        var filename: String {
            switch self {
            case .barcodeDetected:
                return "barcode_ding"
            case .loggingSuccess:
                return "logging_success"
            case .error:
                return "error_beep"
            case .offlineWarning:
                return "offline_warning"
            case .syncSuccess:
                return "sync_success"
            }
        }
    }
    
    func play(_ sound: SoundType, isEnabled: Bool = true) {
        guard isEnabled else { return }
        
        // For MVP, we'll use system sounds
        // In production, we'd use our custom sound files
        playSystemSound(for: sound)
    }
    
    private func playSystemSound(for sound: SoundType) {
        let soundID: SystemSoundID
        
        switch sound {
        case .barcodeDetected:
            soundID = 1001  // Beep/Ding sound
        case .loggingSuccess:
            soundID = 1000  // Bell sound
        case .error:
            soundID = 1050  // Alert sound
        case .offlineWarning:
            soundID = 1057  // Warning sound
        case .syncSuccess:
            soundID = 1000  // Bell sound
        }
        
        AudioServicesPlaySystemSound(soundID)
    }
}
