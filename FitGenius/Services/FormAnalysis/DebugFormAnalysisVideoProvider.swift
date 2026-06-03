#if DEBUG
import Foundation

enum DebugFormAnalysisVideoProvider {
    static let videoPathArgument = "-FitGeniusDebugFormVideo"

    static var launchVideoURL: URL? {
        videoURL(from: ProcessInfo.processInfo.arguments)
    }

    static func videoURL(from arguments: [String]) -> URL? {
        for (index, argument) in arguments.enumerated() {
            if argument == videoPathArgument,
               arguments.indices.contains(index + 1) {
                return URL(fileURLWithPath: arguments[index + 1])
            }

            if argument.hasPrefix("\(videoPathArgument)=") {
                let path = String(argument.dropFirst(videoPathArgument.count + 1))
                guard !path.isEmpty else { return nil }
                return URL(fileURLWithPath: path)
            }
        }

        return nil
    }
}
#endif
