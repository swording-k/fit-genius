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
    private static let skeletonSegments = [
        PoseSegment(start: .leftShoulder, end: .rightShoulder),
        PoseSegment(start: .leftShoulder, end: .leftElbow),
        PoseSegment(start: .leftElbow, end: .leftWrist),
        PoseSegment(start: .rightShoulder, end: .rightElbow),
        PoseSegment(start: .rightElbow, end: .rightWrist),
        PoseSegment(start: .leftShoulder, end: .leftHip),
        PoseSegment(start: .rightShoulder, end: .rightHip),
        PoseSegment(start: .leftHip, end: .rightHip),
        PoseSegment(start: .leftHip, end: .leftKnee),
        PoseSegment(start: .leftKnee, end: .leftAnkle),
        PoseSegment(start: .rightHip, end: .rightKnee),
        PoseSegment(start: .rightKnee, end: .rightAnkle)
    ]

    func render(
        videoURL: URL,
        plan: PoseFeedbackPlan,
        summary: FormAnalysisSummary
    ) async throws -> Data {
        let asset = AVURLAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(
            width: FormAnalysisPerformancePolicy.feedbackMaxDimension,
            height: FormAnalysisPerformancePolicy.feedbackMaxDimension
        )
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
                context.cgContext.setLineWidth(max(6, image.size.width * (highlighted ? 0.009 : 0.006)))
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

            drawIssueCallouts(plan: plan, imageSize: image.size, context: context.cgContext)
            drawHeader(summary: summary, timestamp: plan.frame.timestamp, imageSize: image.size)
            drawFeedback(summary: summary, imageSize: image.size)
        }

        guard let data = annotated.jpegData(compressionQuality: 0.86) else {
            throw PoseOverlayRendererError.imageEncodingFailed
        }
        return data
    }

    private func drawIssueCallouts(plan: PoseFeedbackPlan, imageSize: CGSize, context: CGContext) {
        let padding = imageSize.width * 0.025
        let calloutWidth = imageSize.width * 0.38
        let calloutHeight = imageSize.width * 0.075
        for (index, annotation) in plan.annotations.prefix(2).enumerated() {
            guard let joint = annotation.joints.compactMap({ plan.frame.point($0) }).first else { continue }
            let target = point(joint, imageSize: imageSize)
            let preferredX = target.x < imageSize.width / 2
                ? target.x + imageSize.width * 0.05
                : target.x - calloutWidth - imageSize.width * 0.05
            let x = min(max(padding, preferredX), imageSize.width - padding - calloutWidth)
            let preferredY = target.y - calloutHeight - CGFloat(index) * (calloutHeight + padding * 0.4)
            let y = min(max(imageSize.width * 0.20, preferredY), imageSize.height - imageSize.width * 0.22)
            let rect = CGRect(x: x, y: y, width: calloutWidth, height: calloutHeight)

            context.setStrokeColor(UIColor.systemRed.withAlphaComponent(0.9).cgColor)
            context.setLineWidth(max(3, imageSize.width * 0.003))
            context.move(to: target)
            context.addLine(to: CGPoint(x: rect.midX, y: rect.midY))
            context.strokePath()

            UIColor.systemRed.withAlphaComponent(0.88).setFill()
            UIBezierPath(roundedRect: rect, cornerRadius: imageSize.width * 0.012).fill()
            drawText(
                annotation.title,
                in: rect.insetBy(dx: imageSize.width * 0.015, dy: imageSize.width * 0.012),
                font: .boldSystemFont(ofSize: imageSize.width * 0.026),
                color: .white
            )
        }
    }

    private func drawHeader(
        summary: FormAnalysisSummary,
        timestamp: Double,
        imageSize: CGSize
    ) {
        let padding = imageSize.width * 0.025
        let height = imageSize.width * 0.15
        let rect = CGRect(x: padding, y: padding, width: imageSize.width - padding * 2, height: height)
        UIColor.black.withAlphaComponent(0.72).setFill()
        UIBezierPath(roundedRect: rect, cornerRadius: imageSize.width * 0.018).fill()

        let title = "\(summary.exerciseType.displayName)  \(summary.score)"
        let subtitle = String(
            format: NSLocalizedString("form_overlay_key_frame_format", comment: ""),
            timestamp
        )
        drawText(
            title,
            in: CGRect(x: rect.minX + padding, y: rect.minY + height * 0.14, width: rect.width - padding * 2, height: height * 0.42),
            font: .boldSystemFont(ofSize: imageSize.width * 0.05),
            color: scoreColor(summary.score)
        )
        drawText(
            subtitle,
            in: CGRect(x: rect.minX + padding, y: rect.minY + height * 0.60, width: rect.width - padding * 2, height: height * 0.28),
            font: .systemFont(ofSize: imageSize.width * 0.032, weight: .medium),
            color: .white.withAlphaComponent(0.82)
        )
    }

    private func drawFeedback(summary: FormAnalysisSummary, imageSize: CGSize) {
        let padding = imageSize.width * 0.025
        let issueLines = summary.issues.prefix(2).map { "• \($0.title)" }
        let lines = issueLines.isEmpty
            ? [NSLocalizedString("form_overlay_no_major_issue", comment: "")]
            : issueLines
        let lineHeight = imageSize.width * 0.047
        let height = imageSize.width * 0.09 + lineHeight * CGFloat(lines.count)
        let rect = CGRect(
            x: padding,
            y: imageSize.height - padding - height,
            width: imageSize.width - padding * 2,
            height: height
        )
        UIColor.black.withAlphaComponent(0.76).setFill()
        UIBezierPath(roundedRect: rect, cornerRadius: imageSize.width * 0.018).fill()

        let label = summary.issues.isEmpty
            ? NSLocalizedString("form_overlay_result_stable", comment: "")
            : NSLocalizedString("form_overlay_result_attention", comment: "")
        drawText(
            label,
            in: CGRect(x: rect.minX + padding, y: rect.minY + imageSize.width * 0.018, width: rect.width - padding * 2, height: imageSize.width * 0.04),
            font: .boldSystemFont(ofSize: imageSize.width * 0.034),
            color: summary.issues.isEmpty ? .systemGreen : .systemRed
        )
        drawText(
            lines.joined(separator: "\n"),
            in: CGRect(x: rect.minX + padding, y: rect.minY + imageSize.width * 0.058, width: rect.width - padding * 2, height: lineHeight * CGFloat(lines.count)),
            font: .systemFont(ofSize: imageSize.width * 0.032, weight: .medium),
            color: .white
        )
    }

    private func drawText(_ text: String, in rect: CGRect, font: UIFont, color: UIColor) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingTail
        text.draw(
            in: rect,
            withAttributes: [
                .font: font,
                .foregroundColor: color,
                .paragraphStyle: paragraph
            ]
        )
    }

    private func scoreColor(_ score: Int) -> UIColor {
        if score >= 85 { return .systemGreen }
        if score >= 70 { return .systemOrange }
        return .systemRed
    }

    private func point(_ joint: JointPoint, imageSize: CGSize) -> CGPoint {
        CGPoint(
            x: joint.x * imageSize.width,
            y: (1 - joint.y) * imageSize.height
        )
    }

    func renderSkeletonFrame(
        poseFrame: PoseFrame,
        index: Int,
        total: Int,
        annotations: [FormCoachAnnotation] = []
    ) async throws -> Data {
        let size = CGSize(width: 900, height: 1200)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let highlightedJoints = Set(annotations.flatMap(\.resolvedJoints))
        let image = renderer.image { context in
            UIColor.systemBackground.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            drawSkeletonHeader(
                index: index,
                total: total,
                timestamp: poseFrame.timestamp,
                imageSize: size
            )

            let bodyRect = CGRect(
                x: size.width * 0.08,
                y: size.height * 0.14,
                width: size.width * 0.84,
                height: size.height * 0.70
            )
            let cg = context.cgContext
            cg.setLineCap(.round)
            cg.setLineJoin(.round)

            for segment in Self.skeletonSegments {
                guard let start = poseFrame.point(segment.start),
                      let end = poseFrame.point(segment.end) else { continue }
                let isHighlighted = highlightedJoints.contains(segment.start)
                    || highlightedJoints.contains(segment.end)
                cg.setStrokeColor((isHighlighted ? UIColor.systemRed : UIColor.systemGreen).cgColor)
                cg.setLineWidth(isHighlighted ? 9 : 6)
                cg.move(to: point(start, imageSize: bodyRect.size, origin: bodyRect.origin))
                cg.addLine(to: point(end, imageSize: bodyRect.size, origin: bodyRect.origin))
                cg.strokePath()
            }

            for (joint, jointPoint) in poseFrame.joints where jointPoint.confidence >= 0.25 {
                let center = point(jointPoint, imageSize: bodyRect.size, origin: bodyRect.origin)
                let isHighlighted = highlightedJoints.contains(joint)
                let radius: CGFloat = isHighlighted ? 15 : 9
                let rect = CGRect(
                    x: center.x - radius,
                    y: center.y - radius,
                    width: radius * 2,
                    height: radius * 2
                )
                (isHighlighted ? UIColor.systemRed : UIColor.systemGreen).setFill()
                UIBezierPath(ovalIn: rect).fill()
                UIColor.white.setStroke()
                UIBezierPath(ovalIn: rect).stroke()
            }

            drawSkeletonAnnotations(
                annotations: annotations,
                poseFrame: poseFrame,
                bodyRect: bodyRect,
                context: cg
            )
        }

        guard let data = image.jpegData(compressionQuality: 0.88) else {
            throw PoseOverlayRendererError.imageEncodingFailed
        }
        return data
    }

    private func drawSkeletonHeader(index: Int, total: Int, timestamp: Double, imageSize: CGSize) {
        let rect = CGRect(x: 0, y: 0, width: imageSize.width, height: imageSize.height * 0.11)
        UIColor.black.withAlphaComponent(0.82).setFill()
        UIBezierPath(rect: rect).fill()
        let title = String(
            format: NSLocalizedString("form_enrichment_frame_title_format", comment: ""),
            index + 1,
            total
        )
        let subtitle = String(format: NSLocalizedString("form_overlay_key_frame_format", comment: ""), timestamp)
        drawText(
            title,
            in: CGRect(x: 28, y: 18, width: imageSize.width - 56, height: 44),
            font: .boldSystemFont(ofSize: 34),
            color: .white
        )
        drawText(
            subtitle,
            in: CGRect(x: 28, y: 64, width: imageSize.width - 56, height: 34),
            font: .systemFont(ofSize: 24, weight: .medium),
            color: .white.withAlphaComponent(0.78)
        )
    }

    private func drawSkeletonAnnotations(
        annotations: [FormCoachAnnotation],
        poseFrame: PoseFrame,
        bodyRect: CGRect,
        context: CGContext
    ) {
        for (offset, annotation) in annotations.prefix(3).enumerated() {
            let joints = annotation.resolvedJoints
            guard let targetJoint = joints.compactMap({ poseFrame.point($0) }).first else { continue }
            let target = point(targetJoint, imageSize: bodyRect.size, origin: bodyRect.origin)
            let rectWidth = bodyRect.width * 0.58
            let rectHeight: CGFloat = 74
            let x = target.x < bodyRect.midX
                ? min(target.x + 34, bodyRect.maxX - rectWidth)
                : max(bodyRect.minX, target.x - rectWidth - 34)
            let y = min(max(bodyRect.minY + CGFloat(offset) * 86, target.y - rectHeight / 2), bodyRect.maxY - rectHeight)
            let rect = CGRect(x: x, y: y, width: rectWidth, height: rectHeight)

            context.setStrokeColor(UIColor.systemRed.cgColor)
            context.setLineWidth(4)
            context.move(to: target)
            context.addLine(to: CGPoint(x: rect.midX, y: rect.midY))
            context.strokePath()

            UIColor.systemRed.withAlphaComponent(0.92).setFill()
            UIBezierPath(roundedRect: rect, cornerRadius: 12).fill()
            drawText(
                annotation.label,
                in: rect.insetBy(dx: 16, dy: 12),
                font: .boldSystemFont(ofSize: 23),
                color: .white
            )
        }
    }

    private func point(_ joint: JointPoint, imageSize: CGSize, origin: CGPoint) -> CGPoint {
        CGPoint(
            x: origin.x + joint.x * imageSize.width,
            y: origin.y + (1 - joint.y) * imageSize.height
        )
    }
}
