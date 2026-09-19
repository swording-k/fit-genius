import AVFoundation
import Combine
import SwiftUI

struct ExerciseVideoComparisonView: View {
    let exerciseName: String
    @StateObject private var controller: VideoComparisonController
    @Environment(\.scenePhase) private var scenePhase

    init(
        exerciseName: String,
        referenceURL: URL,
        userURL: URL,
        referenceClipStart: Double,
        referenceClipEnd: Double
    ) {
        self.exerciseName = exerciseName
        _controller = StateObject(
            wrappedValue: VideoComparisonController(
                referenceURL: referenceURL,
                userURL: userURL,
                referenceClipStart: referenceClipStart,
                referenceClipEnd: referenceClipEnd
            )
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack(alignment: .top, spacing: 8) {
                    videoColumn(titleKey: "comparison_reference", player: controller.referencePlayer)
                    videoColumn(titleKey: "comparison_yours", player: controller.userPlayer)
                }

                if controller.isLoading {
                    ProgressView("comparison_preparing")
                } else if let error = controller.errorMessage {
                    ContentUnavailableView(
                        "comparison_unavailable",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )
                } else {
                    controls
                }
            }
            .padding()
        }
        .navigationTitle(exerciseName)
        .navigationBarTitleDisplayMode(.inline)
        .task { await controller.prepare() }
        .onDisappear { controller.pause() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { controller.pause() }
        }
        .hidesGlobalModeToggle()
    }

    private func videoColumn(titleKey: LocalizedStringKey, player: AVPlayer) -> some View {
        VStack(spacing: 6) {
            Text(titleKey)
                .font(.caption.bold())
            ControlledVideoPlayer(player: player)
                .aspectRatio(9.0 / 16.0, contentMode: .fit)
                .background(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .frame(maxWidth: .infinity)
    }

    private var controls: some View {
        VStack(spacing: 16) {
            Slider(
                value: Binding(
                    get: { controller.progress },
                    set: { controller.seek(to: $0) }
                ),
                in: 0...1
            )

            HStack {
                Button {
                    controller.togglePlayback()
                } label: {
                    Label(
                        controller.isPlaying ? "comparison_pause" : "comparison_play",
                        systemImage: controller.isPlaying ? "pause.fill" : "play.fill"
                    )
                }
                .buttonStyle(.borderedProminent)

                Picker("comparison_speed", selection: $controller.playbackRate) {
                    ForEach(VideoComparisonTimeline.supportedRates, id: \.self) { rate in
                        Text("\(rate.formatted())x").tag(rate)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: controller.playbackRate) { _, _ in controller.applyRate() }
            }

            offsetControl(
                titleKey: "comparison_reference_start",
                value: $controller.referenceOffset,
                range: controller.referenceOffsetRange
            )
            offsetControl(
                titleKey: "comparison_your_start",
                value: $controller.userOffset,
                range: controller.userOffsetRange
            )

            Text("comparison_manual_alignment_note")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func offsetControl(
        titleKey: LocalizedStringKey,
        value: Binding<Double>,
        range: ClosedRange<Double>
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(titleKey)
                Spacer()
                Text("\(value.wrappedValue, specifier: "%.1f")s")
                    .monospacedDigit()
                    .foregroundColor(.secondary)
            }
            Slider(value: value, in: range)
                .onChange(of: value.wrappedValue) { _, _ in controller.offsetDidChange() }
        }
    }
}

@MainActor
private final class VideoComparisonController: ObservableObject {
    let referencePlayer: AVPlayer
    let userPlayer: AVPlayer

    @Published var progress = 0.0
    @Published var playbackRate = 0.5
    @Published var referenceOffset: Double
    @Published var userOffset = 0.0
    @Published private(set) var isPlaying = false
    @Published private(set) var isLoading = true
    @Published private(set) var errorMessage: String?

    private let referenceURL: URL
    private let userURL: URL
    private let referenceClipEnd: Double
    private var referenceDuration = 0.0
    private var userDuration = 0.0
    private var timeObserver: Any?

    init(referenceURL: URL, userURL: URL, referenceClipStart: Double, referenceClipEnd: Double) {
        self.referenceURL = referenceURL
        self.userURL = userURL
        self.referenceOffset = referenceClipStart
        self.referenceClipEnd = referenceClipEnd
        referencePlayer = AVPlayer(url: referenceURL)
        userPlayer = AVPlayer(url: userURL)
        referencePlayer.isMuted = true
        userPlayer.isMuted = true
    }

    var referenceOffsetRange: ClosedRange<Double> {
        0...max(0.1, min(referenceDuration, referenceClipEnd) - 0.1)
    }

    var userOffsetRange: ClosedRange<Double> {
        0...max(0.1, userDuration - 0.1)
    }

    private var timeline: VideoComparisonTimeline {
        VideoComparisonTimeline(
            referenceDuration: min(referenceDuration, referenceClipEnd),
            userDuration: userDuration,
            referenceOffset: referenceOffset,
            userOffset: userOffset
        )
    }

    func prepare() async {
        guard isLoading else { return }
        do {
            async let referenceLoaded = loadDuration(url: referenceURL)
            async let userLoaded = loadDuration(url: userURL)
            let durations = try await (referenceLoaded, userLoaded)
            referenceDuration = durations.0
            userDuration = durations.1
            guard referenceDuration > 0, userDuration > 0 else {
                throw CocoaError(.fileReadCorruptFile)
            }
            referenceOffset = min(referenceOffset, referenceOffsetRange.upperBound)
            installTimeObserver()
            seek(to: 0)
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    func togglePlayback() {
        if isPlaying {
            pause()
            return
        }
        if progress >= 1 { seek(to: 0) }
        synchronizePlayers(playAfterSeek: true)
    }

    func pause() {
        referencePlayer.pause()
        userPlayer.pause()
        isPlaying = false
    }

    func seek(to proposedProgress: Double) {
        progress = min(max(0, proposedProgress), 1)
        synchronizePlayers(playAfterSeek: isPlaying)
    }

    func offsetDidChange() {
        pause()
        progress = 0
        synchronizePlayers(playAfterSeek: false)
    }

    func applyRate() {
        playbackRate = timeline.clampedRate(playbackRate)
        guard isPlaying else { return }
        referencePlayer.rate = Float(playbackRate)
        userPlayer.rate = Float(playbackRate)
    }

    private func synchronizePlayers(playAfterSeek: Bool) {
        let referenceTime = CMTime(seconds: timeline.referenceTime(progress: progress), preferredTimescale: 600)
        let userTime = CMTime(seconds: timeline.userTime(progress: progress), preferredTimescale: 600)
        referencePlayer.seek(to: referenceTime, toleranceBefore: .zero, toleranceAfter: .zero)
        userPlayer.seek(to: userTime, toleranceBefore: .zero, toleranceAfter: .zero)
        if playAfterSeek, timeline.commonDuration > 0 {
            let rate = Float(timeline.clampedRate(playbackRate))
            referencePlayer.playImmediately(atRate: rate)
            userPlayer.playImmediately(atRate: rate)
            isPlaying = true
        }
    }

    private func installTimeObserver() {
        guard timeObserver == nil else { return }
        timeObserver = referencePlayer.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.05, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let duration = self.timeline.commonDuration
                guard duration > 0 else { return }
                let next = (time.seconds - self.referenceOffset) / duration
                self.progress = min(max(0, next), 1)
                if self.progress >= 1 { self.pause() }
            }
        }
    }

    private func loadDuration(url: URL) async throws -> Double {
        let duration = try await AVURLAsset(url: url).load(.duration)
        return duration.seconds
    }

    deinit {
        if let timeObserver {
            referencePlayer.removeTimeObserver(timeObserver)
        }
    }
}
