import Foundation

@main
enum DebugVideoProviderTests {
    static func main() {
        let videoPath = "/Users/baojian/Downloads/IMG_8262.MOV"
        let pairedURL = DebugFormAnalysisVideoProvider.videoURL(from: [
            "FitGenius",
            "-FitGeniusSeedFormCoachDemo",
            "-FitGeniusDebugFormVideo",
            videoPath
        ])

        expect(pairedURL?.path == videoPath, "paired launch argument should resolve the following path")

        let equalsURL = DebugFormAnalysisVideoProvider.videoURL(from: [
            "FitGenius",
            "-FitGeniusDebugFormVideo=\(videoPath)"
        ])

        expect(equalsURL?.path == videoPath, "equals-style launch argument should resolve the inline path")

        let missingURL = DebugFormAnalysisVideoProvider.videoURL(from: [
            "FitGenius",
            "-FitGeniusDebugFormVideo"
        ])

        expect(missingURL == nil, "missing path should return nil")

        print("DebugVideoProviderTests passed")
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        if !condition() {
            print("DebugVideoProviderTests failed: \(message)")
            exit(1)
        }
    }
}
