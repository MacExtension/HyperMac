import Foundation

/// Metadata attached to the stable `latest` release, fetched without the REST API.
struct GitHubUpdateFeed: Codable, Sendable {
    let schema: Int
    let commit: String
    let version: String
    let notes: String
    let archiveSHA256: String

    enum CodingKeys: String, CodingKey {
        case schema, commit, version, notes
        case archiveSHA256 = "archive_sha256"
    }

    var isValid: Bool {
        schema == 1
            && Self.isLowercaseHex(commit, count: 40)
            && Self.isLowercaseHex(archiveSHA256, count: 64)
            && !version.isEmpty
    }

    func differs(from installedCommit: String?) -> Bool {
        installedCommit?.lowercased() != commit
    }

    private static func isLowercaseHex(_ value: String, count: Int) -> Bool {
        value.utf8.count == count && value.utf8.allSatisfy {
            ($0 >= 48 && $0 <= 57) || ($0 >= 97 && $0 <= 102)
        }
    }
}
