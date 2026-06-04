import AVFoundation
import UIKit

enum PoseOverlayRendererError: LocalizedError {
    case frameUnavailable
    case imageEncodingFailed

    var errorDescription: String? {
        switch self {
        case .frameUnavailable:
            return NSLocalizedString("form_error_feedback_frame_unavailable", comment: "")
        case .imageEncodingFailed:
            return NSLocalizedString("form_error_feedback_image_failed", comment: "")
        }
    }
}

struct PoseOverlayRenderer {
    func render(videoURL: URL, plan: PoseFeedbackPlan) async throws -> Data {
        let asset = AVURLAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = CMTime(seconds: 0.12, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = CMTime(seconds: 0.12, preferredTimescale: 600)

        let time = CMTime(seconds: plan.frame.timestamp, preferredTimescale: 600)
        let source = try await generator.image(at: time).image
        let image = UIImage(cgImage: source)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)

        let annotated = renderer.image { context in
            image.draw(in: CGRect(origin: .zero, size: image.size))
            context.cgContext.setLineCap(.round)
            context.cgContext.setLineJoin(.round)

            for segment in plan.segments {
                guard let start = plan.frame.point(segment.start),
                      let end = plan.frame.point(segment.end) else { continue }
                let highlighted = plan.highlightedJoints.contains(segment.start)
                    || plan.highlightedJoints.contains(segment.end)
                context.cgContext.setStrokeColor(
                    highlighted ? UIColor.systemRed.cgColor : UIColor.systemGreen.cgColor
                )
                context.cgContext.setLineWidth(max(5, image.size.width * 0.006))
                context.cgContext.move(to: point(start, imageSize: image.size))
                context.cgContext.addLine(to: point(end, imageSize: image.size))
                context.cgContext.strokePath()
            }

            for (joint, jointPoint) in plan.frame.joints where jointPoint.confidence >= 0.25 {
                let center = point(jointPoint, imageSize: image.size)
                let highlighted = plan.highlightedJoints.contains(joint)
                let radius = max(highlighted ? 12 : 7, image.size.width * (highlighted ? 0.012 : 0.007))
                let rect = CGRect(
                    x: center.x - radius,
                    y: center.y - radius,
                    width: radius * 2,
                    height: radius * 2
                )
                context.cgContext.setFillColor(
                    highlighted ? UIColor.systemRed.cgColor : UIColor.systemGreen.cgColor
                )
                context.cgContext.fillEllipse(in: rect)
                context.cgContext.setStrokeColor(UIColor.white.cgColor)
                context.cgContext.setLineWidth(max(2, image.size.width * 0.002))
                context.cgContext.strokeEllipse(in: rect)
            }
        }

        guard let data = annotated.jpegData(compressionQuality: 0.86) else {
            throw PoseOverlayRendererError.imageEncodingFailed
        }
        return data
    }

    private func point(_ joint: JointPoint, imageSize: CGSize) -> CGPoint {
        CGPoint(
            x: joint.x * imageSize.width,
            y: (1 - joint.y) * imageSize.height
        )
    }
}

