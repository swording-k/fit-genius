import PhotosUI
import SwiftData
import SwiftUI

struct FormAnalysisView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var auth: AuthViewModel
    @Bindable var exercise: Exercise
    @StateObject private var viewModel = FormAnalysisViewModel()
    @State private var selectedVideo: PhotosPickerItem?
    @State private var selectedVideoData: Data?
    @State private var recordedVideoURL: URL?
    @State private var showVideoCamera = false
    @State private var didApplyRecommendation = false
    @State private var didLoadDebugLaunchVideo = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(exercise.name)
                            .font(.headline)
                        Text("form_analysis_instruction")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Picker("form_analysis_exercise_type", selection: $viewModel.selectedExerciseType) {
                        ForEach(FormExerciseType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                } header: {
                    Text("form_analysis_title")
                }

                Section {
                    PhotosPicker(selection: $selectedVideo, matching: .videos) {
                        Label(selectedVideoData == nil ? NSLocalizedString("form_analysis_select_video", comment: "") : NSLocalizedString("form_analysis_reselect_video", comment: ""), systemImage: "video")
                    }

                    Button {
                        showVideoCamera = true
                    } label: {
                        Label("form_analysis_record_video", systemImage: "video.badge.plus")
                    }
                    .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))

                    if !UIImagePickerController.isSourceTypeAvailable(.camera) {
                        Text("form_analysis_no_camera")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Button {
                        if let data = selectedVideoData {
                            Task {
                                await viewModel.analyze(
                                    videoData: data,
                                    exercise: exercise,
                                    modelContext: modelContext,
                                    userId: auth.currentUserId
                                )
                            }
                        }
                    } label: {
                        HStack {
                            if viewModel.isAnalyzing {
                                ProgressView()
                            }
                            Text(viewModel.isAnalyzing ? NSLocalizedString("form_analysis_running", comment: "") : NSLocalizedString("form_analysis_start", comment: ""))
                        }
                    }
                    .disabled(selectedVideoData == nil || viewModel.isAnalyzing)
                }

                if let error = viewModel.errorMessage {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                    }
                }

                if let summary = viewModel.summary {
                    Section {
                        HStack {
                            Text("form_analysis_score")
                            Spacer()
                            Text("\(summary.score)")
                                .font(.title.bold())
                                .foregroundColor(scoreColor(summary.score))
                        }

                        if summary.issues.isEmpty {
                            Label("form_analysis_stable", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        } else {
                            ForEach(summary.issues, id: \.code) { issue in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(issue.title)
                                        .font(.headline)
                                    Text(issue.detail)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    } header: {
                        Text("form_analysis_result")
                    }

                    Section {
                        Text(summary.recommendation)
                        Button {
                            viewModel.applyRecommendation(to: exercise, modelContext: modelContext)
                            didApplyRecommendation = true
                        } label: {
                            Label(didApplyRecommendation ? NSLocalizedString("form_analysis_applied", comment: "") : NSLocalizedString("form_analysis_apply", comment: ""), systemImage: didApplyRecommendation ? "checkmark.circle.fill" : "wand.and.stars")
                        }
                        .disabled(didApplyRecommendation)
                    } header: {
                        Text("form_analysis_coach_advice")
                    }

                    Section {
                        ForEach(summary.metrics, id: \.key) { metric in
                            HStack {
                                Text(metric.label)
                                Spacer()
                                Text(formattedMetric(metric))
                                    .foregroundColor(.secondary)
                            }
                        }
                    } header: {
                        Text("form_analysis_metrics")
                    }
                }
            }
            .navigationTitle("form_analysis_title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("form_analysis_close") { dismiss() }
                }
            }
            .onAppear {
                viewModel.inferExerciseType(from: exercise.name)
                loadDebugLaunchVideoIfNeeded()
            }
            .onChange(of: selectedVideo) { _, item in
                Task {
                    selectedVideoData = try? await item?.loadTransferable(type: Data.self)
                    viewModel.errorMessage = nil
                    viewModel.summary = nil
                    didApplyRecommendation = false
                }
            }
            .onChange(of: recordedVideoURL) { _, url in
                guard let url else { return }
                selectedVideoData = try? Data(contentsOf: url)
                viewModel.errorMessage = nil
                viewModel.summary = nil
                didApplyRecommendation = false
            }
            .sheet(isPresented: $showVideoCamera) {
                VideoCameraPicker(selectedVideoURL: $recordedVideoURL)
            }
        }
    }

    private func loadDebugLaunchVideoIfNeeded() {
        #if DEBUG
        guard !didLoadDebugLaunchVideo,
              let url = DebugFormAnalysisVideoProvider.launchVideoURL else { return }
        didLoadDebugLaunchVideo = true

        Task {
            do {
                let data = try Data(contentsOf: url)
                selectedVideoData = data
                viewModel.errorMessage = nil
                viewModel.summary = nil
                didApplyRecommendation = false
                await viewModel.analyze(
                    videoData: data,
                    exercise: exercise,
                    modelContext: modelContext,
                    userId: auth.currentUserId
                )
            } catch {
                viewModel.errorMessage = error.localizedDescription
            }
        }
        #endif
    }

    private func scoreColor(_ score: Int) -> Color {
        if score >= 85 { return .green }
        if score >= 70 { return .orange }
        return .red
    }

    private func formattedMetric(_ metric: FormMetric) -> String {
        switch metric.key {
        case "pose_quality":
            return String(format: "%.0f%%", metric.value * 100)
        case "detected_frames":
            return String(format: NSLocalizedString("form_analysis_frame_unit", comment: ""), Int(metric.value))
        default:
            return String(format: "%.2f", metric.value)
        }
    }
}
