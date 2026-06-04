import UIKit

enum MediaImagePreprocessorError: LocalizedError {
    case unreadableImage
    case encodingFailed
    case imageTooLarge

    var errorDescription: String? {
        switch self {
        case .unreadableImage:
            return NSLocalizedString("media_image_unreadable", comment: "")
        case .encodingFailed:
            return NSLocalizedString("media_image_encoding_failed", comment: "")
        case .imageTooLarge:
            return NSLocalizedString("media_image_too_large", comment: "")
        }
    }
}

struct MediaImagePreprocessor {
    static func normalizedJPEG(
        from data: Data,
        maxDimension: CGFloat = 1600,
        maxBytes: Int = 1_100_000
    ) throws -> Data {
        guard let source = UIImage(data: data) else {
            throw MediaImagePreprocessorError.unreadableImage
        }

        var encodedAnyImage = false
        let dimensions = [maxDimension, 1280, 1024, 800].filter { $0 <= maxDimension }
        for dimension in dimensions {
            let image = resized(source, maxDimension: dimension)
            for quality in stride(from: 0.84, through: 0.42, by: -0.08) {
                if let encoded = image.jpegData(compressionQuality: quality) {
                    encodedAnyImage = true
                    if encoded.count <= maxBytes {
                        return encoded
                    }
                }
            }
        }
        guard encodedAnyImage else {
            throw MediaImagePreprocessorError.encodingFailed
        }
        throw MediaImagePreprocessorError.imageTooLarge
    }

    private static func resized(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let longest = max(image.size.width, image.size.height)
        guard longest > maxDimension, longest > 0 else { return image }
        let scale = maxDimension / longest
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
