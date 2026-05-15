import AVFoundation
import Speech
import AppKit

@MainActor
final class PermissionsManager {
    static let shared = PermissionsManager()

    func requestMicrophone() async -> Bool {
        await withCheckedContinuation { cont in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                cont.resume(returning: granted)
            }
        }
    }

    func requestSpeechRecognition() async -> Bool {
        await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { status in
                cont.resume(returning: status == .authorized)
            }
        }
    }

    var hasAccessibility: Bool {
        AXIsProcessTrusted()
    }

    func requestAccessibility() {
        let key = "AXTrustedCheckOptionPrompt"
        let opts: NSDictionary = [key: true]
        _ = AXIsProcessTrustedWithOptions(opts)
    }
}
