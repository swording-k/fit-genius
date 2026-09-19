import AVFoundation
import SwiftUI
import UIKit

/// A transport-free video surface. The parent owns the AVPlayer so one set of
/// controls can drive two players without SwiftUI recreating playback state.
struct ControlledVideoPlayer: UIViewRepresentable {
    let player: AVPlayer
    var videoGravity: AVLayerVideoGravity = .resizeAspect

    func makeUIView(context: Context) -> ControlledVideoPlayerView {
        let view = ControlledVideoPlayerView()
        view.playerLayer.videoGravity = videoGravity
        return view
    }

    func updateUIView(_ view: ControlledVideoPlayerView, context: Context) {
        view.playerLayer.player = player
        view.playerLayer.videoGravity = videoGravity
    }
}

final class ControlledVideoPlayerView: UIView {
    override static var layerClass: AnyClass { AVPlayerLayer.self }

    var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }
}
