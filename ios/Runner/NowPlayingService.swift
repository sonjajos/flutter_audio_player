import MediaPlayer

class NowPlayingService {

    typealias CommandHandler = (_ command: String) -> Void
    typealias SeekHandler = (_ positionSeconds: Double) -> Void

    var onCommand: CommandHandler?
    var onSeek: SeekHandler?

    func setup() {
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.isEnabled = true
        center.playCommand.addTarget { [weak self] _ in
            self?.onCommand?("play")
            return .success
        }

        center.pauseCommand.isEnabled = true
        center.pauseCommand.addTarget { [weak self] _ in
            self?.onCommand?("pause")
            return .success
        }

        center.nextTrackCommand.isEnabled = true
        center.nextTrackCommand.addTarget { [weak self] _ in
            self?.onCommand?("next")
            return .success
        }

        center.previousTrackCommand.isEnabled = true
        center.previousTrackCommand.addTarget { [weak self] _ in
            self?.onCommand?("previous")
            return .success
        }

        center.changePlaybackPositionCommand.isEnabled = true
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let posEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            self?.onSeek?(posEvent.positionTime)
            return .success
        }
    }

    func updateNowPlaying(
        title: String,
        artist: String,
        durationSeconds: Double,
        positionSeconds: Double,
        isPlaying: Bool
    ) {
        var info = [String: Any]()
        info[MPMediaItemPropertyTitle] = title
        info[MPMediaItemPropertyArtist] = artist
        info[MPMediaItemPropertyPlaybackDuration] = durationSeconds
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = positionSeconds
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    func clearNowPlaying() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
}
