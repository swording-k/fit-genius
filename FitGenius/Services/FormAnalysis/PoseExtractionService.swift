import AVFoundation
import Foundation
import Vision

enum PoseExtractionError: LocalizedError {
    case videoTooShort
    case videoTooLong
    case noPoseDetected
    case unreadableVideo
    case poseDetectionUnavailable
    case unsupportedExercise
    case lowQualityVideo

    var errorDescription: String? {
        switch self {
        case .videoTooShort:
            return NSLocalizedString("form_error_video_too_short", comment: "")
        case .videoTooLong:
            return NSLocalizedString("form_error_video_too_long", comment: "")
        case .noPoseDetected:
            return NSLocalizedString("form_error_no_pose_detected", comment: "")
        case .unreadableVideo:
            return NSLocalizedString("form_error_unreadable_video", comment: "")
        case .poseDetectionUnavailable:
            return NSLocalizedString("form_error_pose_detection_unavailable", comment: "")
        case .unsupportedExercise:
            return NSLocalizedString("form_error_unsupported_exercise", comment: "")
        case .lowQualityVideo:
            return NSLocalizedString("form_error_low_quality_video", comment: "")
        }
    }
}

struct PoseExtractionService {
    func extractPoseSequence(from videoURL: URL, maxFrames: Int = 16) async throws -> PoseSequence {
        let asset = AVURLAsset(url: videoURL)
        let duration = try await asset.load(.duration)
        let seconds = CMTimeGetSeconds(duration)
        guard seconds.isFinite, seconds > 2 else { throw PoseExtractionError.videoTooShort }
        guard seconds <= 90 else { throw PoseExtractionError.videoTooLong }

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(
            width: FormAnalysisPerformancePolicy.extractionMaxDimension,
            height: FormAnalysisPerformancePolicy.extractionMaxDimension
        )
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero

        let sampleCount = max(3, min(maxFrames, Int(seconds * 2)))
        let times = (0..<sampleCount).map { index in
            CMTime(seconds: seconds * Double(index) / Double(max(sampleCount - 1, 1)), preferredTimescale: 600)
        }

        var frames: [PoseFrame] = []
        for time in times {
            guard let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) else { continue }
            if let frame = try detectPose(in: cgImage, timestamp: CMTimeGetSeconds(time)),
               PoseFrameQualityPolicy.isUsableForFormAnalysis(frame) {
                frames.append(frame)
            }
        }

        guard frames.count >= 2 else { throw PoseExtractionError.noPoseDetected }
        return PoseSequence(frames: frames)
    }

    private func detectPose(in image: CGImage, timestamp: Double) throws -> PoseFrame? {
        let request = VNDetectHumanBodyPoseRequest()
        let handler = VNImageRequestHandler(cgImage: image, orientation: .up, options: [:])
        do {
            try handler.perform([request])
        } catch {
            throw PoseExtractionError.poseDetectionUnavailable
        }

        guard let observation = request.results?.first else { return nil }
        let recognized = try observation.recognizedPoints(.all)
        var joints: [JointName: JointPoint] = [:]

        for (visionJoint, appJoint) in Self.jointMap {
            guard let point = recognized[visionJoint], point.confidence > 0.2 else { continue }
            joints[appJoint] = JointPoint(
                x: Double(point.location.x),
                y: Double(point.location.y),
                confidence: Double(point.confidence)
            )
        }

        return joints.count >= 6 ? PoseFrame(timestamp: timestamp, joints: joints) : nil
    }

    private static let jointMap: [VNHumanBodyPoseObservation.JointName: JointName] = [
        .nose: .nose,
        .neck: .neck,
        .root: .root,
        .leftShoulder: .leftShoulder,
        .rightShoulder: .rightShoulder,
        .leftElbow: .leftElbow,
        .rightElbow: .rightElbow,
        .leftWrist: .leftWrist,
        .rightWrist: .rightWrist,
        .leftHip: .leftHip,
        .rightHip: .rightHip,
        .leftKnee: .leftKnee,
        .rightKnee: .rightKnee,
        .leftAnkle: .leftAnkle,
        .rightAnkle: .rightAnkle
    ]
}
