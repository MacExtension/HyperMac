import Foundation
import Testing
@testable import HyperMac

struct UpdateFeedTests {
    @Test func stableTagStillDetectsAChangedBuild() throws {
        let commit = String(repeating: "a", count: 40)
        let digest = String(repeating: "b", count: 64)
        let json = """
        {"schema":1,"commit":"\(commit)","version":"2.0.0","notes":"Latest","archive_sha256":"\(digest)"}
        """
        let feed = try JSONDecoder().decode(GitHubUpdateFeed.self, from: Data(json.utf8))

        #expect(feed.isValid)
        #expect(!feed.differs(from: commit))
        #expect(feed.differs(from: String(repeating: "c", count: 40)))
        #expect(feed.differs(from: nil))
    }

    @Test func rejectsMalformedUpdateMetadata() {
        let commit = String(repeating: "a", count: 40)
        let digest = String(repeating: "b", count: 64)
        #expect(!GitHubUpdateFeed(schema: 2, commit: commit, version: "2.0.0", notes: "", archiveSHA256: digest).isValid)
        #expect(!GitHubUpdateFeed(schema: 1, commit: "latest", version: "2.0.0", notes: "", archiveSHA256: digest).isValid)
        #expect(!GitHubUpdateFeed(schema: 1, commit: commit, version: "2.0.0", notes: "", archiveSHA256: "sha256:abc").isValid)
    }
}
