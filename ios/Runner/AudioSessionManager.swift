import AVFoundation

class AudioSessionManager: NSObject {

    typealias InterruptionHandler = (_ began: Bool, _ shouldResume: Bool) -> Void

    var onInterruption: InterruptionHandler?

    func configure() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [])
        try session.setActive(true)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: session
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: session
        )
    }

    @objc private func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch type {
        case .began:
            onInterruption?(true, false)

        case .ended:
            let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            let shouldResume = options.contains(.shouldResume)
            onInterruption?(false, shouldResume)

        @unknown default:
            break
        }
    }

    @objc private func handleRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }

        // Pause when headphones are unplugged
        if reason == .oldDeviceUnavailable {
            onInterruption?(true, false)
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
