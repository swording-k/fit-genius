import AVFoundation
import Combine
import PhotosUI
import SwiftUI

struct ExerciseTutorialView: View {
    let exercise: Exercise
    let template: ExerciseTemplate
    let clip: ExerciseTutorialClip

    @StateObject private var playback: TutorialPlaybackController
    @StateObject private var selectedVideo = TemporaryComparisonVideo()
    @State private var photoItem: PhotosPickerItem?
    @State private var showComparison = false

    private var preferChinese: Bool {
        Locale.preferredLanguages.first?.hasPrefix("zh") ?? false
    }

    init(exercise: Exercise, template: ExerciseTemplate, clip: ExerciseTutorialClip) {
        self.exercise = exercise
        self.template = template
        self.clip = clip
        _playback = StateObject(wrappedValue: TutorialPlaybackController(clip: clip))
    }

    var body: some View {
        let pickerTitle = selectedVideo.url == nil
            ? "planned_exercise_choose_your_video"
            : "planned_exercise_choose_another_video"
        let resolvedPlaybackURL = clip.resolvedPlaybackURL()

        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let player = playback.player {
                    ControlledVideoPlayer(player: player)
                        .frame(maxWidth: .infinity)
                        .aspectRatio(9.0 / 16.0, contentMode: .fit)
                        .background(Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: 14))

                    Button {
                        playback.toggle()
                    } label: {
                        Label(
                            playback.isPlaying ? "comparison_pause" : "comparison_play",
                            systemImage: playback.isPlaying ? "pause.fill" : "play.fill"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    ContentUnavailableView(
                        "planned_exercise_tutorial_external_only",
                        systemImage: "link",
                        description: Text("planned_exercise_tutorial_external_only_message")
                    )
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(clip.creatorName)
                        .font(.headline)
                    Text(clip.sourceTitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Link(destination: clip.sourceURL) {
                        Label("planned_exercise_source", systemImage: "arrow.up.right.square")
                    }
                }

                if let note = clip.localizedFramingNote(preferChinese: preferChinese) {
                    GroupBox("planned_exercise_match_camera") {
                        Text(note)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                if resolvedPlaybackURL != nil {
                    VStack(alignment: .leading, spacing: 10) {
                        PhotosPicker(selection: $photoItem, matching: .videos) {
                            Label(
                                pickerTitle,
                                systemImage: "video.badge.plus"
                            )
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)

                        if selectedVideo.isLoading {
                            ProgressView("planned_exercise_loading_your_video")
                        }

                        if let error = selectedVideo.errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.orange)
                        }

                        Button {
                            playback.pause()
                            showComparison = true
                        } label: {
                            Label("planned_exercise_compare_video", systemImage: "rectangle.split.2x1")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(selectedVideo.url == nil)
                    }
                }
            }
            .padding()
        }
        .navigationTitle(template.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showComparison) {
            if let referenceURL = resolvedPlaybackURL, let userURL = selectedVideo.url {
                ExerciseVideoComparisonView(
                    exerciseName: template.displayName,
                    referenceURL: referenceURL,
                    userURL: userURL,
                    referenceClipStart: clip.playbackRange.lowerBound,
                    referenceClipEnd: clip.playbackRange.upperBound
                )
            }
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task { await selectedVideo.load(item) }
        }
        .onDisappear {
            playback.pause()
        }
        .hidesGlobalModeToggle()
    }
}

@MainActor
private final class TutorialPlaybackController: ObservableObject {
    let player: AVPlayer?
    @Published private(set) var isPlaying = false

    private let clipStart: Double
    private let clipEnd: Double
    private var boundaryObserver: Any?

    init(clip: ExerciseTutorialClip) {
        clipStart = clip.playbackRange.lowerBound
        clipEnd = clip.playbackRange.upperBound
        if let url = clip.resolvedPlaybackURL() {
            let player = AVPlayer(url: url)
            self.player = player
            player.seek(to: CMTime(seconds: clipStart, preferredTimescale: 600))
            boundaryObserver = player.addBoundaryTimeObserver(
                forTimes: [NSValue(time: CMTime(seconds: clipEnd, preferredTimescale: 600))],
                queue: .main
            ) { [weak self] in
                Task { @MainActor [weak self] in
                    guard let self, let player = self.player else { return }
                    player.pause()
                    player.seek(to: CMTime(seconds: self.clipStart, preferredTimescale: 600))
                    self.isPlaying = false
                }
            }
        } else {
            player = nil
        }
    }

    func toggle() {
        guard let player else { return }
        if isPlaying {
            pause()
        } else {
            if player.currentTime().seconds >= clipEnd {
                player.seek(to: CMTime(seconds: clipStart, preferredTimescale: 600))
            }
            player.play()
            isPlaying = true
        }
    }

    func pause() {
        player?.pause()
        isPlaying = false
    }

    deinit {
        if let boundaryObserver, let player {
            player.removeTimeObserver(boundaryObserver)
        }
    }
}

private final class TemporaryComparisonVideo: ObservableObject {
    @Published private(set) var url: URL?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    @MainActor
    func load(_ item: PhotosPickerItem) async {
        isLoading = true
        errorMessage = nil
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                throw CocoaError(.fileReadUnknown)
            }
            removeCurrentFile()
            let destination = FileManager.default.temporaryDirectory
                .appendingPathComponent("fitgenius-comparison-\(UUID().uuidString).mov")
            try data.write(to: destination, options: .atomic)
            url = destination
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func removeCurrentFile() {
        guard let url else { return }
        try? FileManager.default.removeItem(at: url)
        self.url = nil
    }

    deinit {
        if let url {
            try? FileManager.default.removeItem(at: url)
        }
    }
}
