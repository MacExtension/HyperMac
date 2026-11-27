import Foundation
import CryptoKit

enum GitHubReleaseError: Error, Sendable {
    case httpStatus(Int, retryAfter: TimeInterval?)
    case invalidResponse
    case invalidFeed
    case invalidArchive
    case digestMismatch
    case invalidBundle
    case commitMismatch
    case signatureMismatch
}

struct StagedGitHubRelease: Sendable {
    let appURL: URL
    let stagingDirectoryURL: URL
}

/// Uses a release asset instead of GitHub's IP-limited REST API.
enum GitHubReleaseClient {
    static let releasePageURL = URL(string: "https://github.com/MacExtension/HyperMac/releases/latest")!
    private static let feedURL = URL(string: "https://github.com/MacExtension/HyperMac/releases/download/latest/update.json")!
    private static let archiveURL = URL(string: "https://github.com/MacExtension/HyperMac/releases/download/latest/HyperMac.zip")!
    private static let bundleIdentifier = "com.opensource.hypermac"

    static func fetchFeed() async throws -> GitHubUpdateFeed {
        var request = URLRequest(url: feedURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("HyperMac-App", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw GitHubReleaseError.invalidResponse }
        guard http.statusCode == 200 else {
            throw GitHubReleaseError.httpStatus(http.statusCode, retryAfter: retryAfter(from: http))
        }
        guard data.count <= 128_000,
              let feed = try? JSONDecoder().decode(GitHubUpdateFeed.self, from: data),
              feed.isValid else {
            throw GitHubReleaseError.invalidFeed
        }
        return feed
    }

    static func downloadAndStage(
        feed: GitHubUpdateFeed,
        installedAppURL: URL
    ) async throws -> StagedGitHubRelease {
        guard feed.isValid else { throw GitHubReleaseError.invalidFeed }
        var request = URLRequest(url: archiveURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 60)
        request.setValue("HyperMac-App", forHTTPHeaderField: "User-Agent")
        let (downloadedURL, response) = try await URLSession.shared.download(for: request)
        guard let http = response as? HTTPURLResponse else { throw GitHubReleaseError.invalidResponse }
        guard http.statusCode == 200 else {
            throw GitHubReleaseError.httpStatus(http.statusCode, retryAfter: retryAfter(from: http))
        }

        let fileManager = FileManager.default
        let stagingDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("HyperMac-release-update-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: stagingDirectory, withIntermediateDirectories: true)
        do {
            let archive = stagingDirectory.appendingPathComponent("HyperMac.zip")
            try fileManager.moveItem(at: downloadedURL, to: archive)
            let archiveSize = try archive.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard archiveSize >= 100_000 && archiveSize <= 200_000_000 else {
                throw GitHubReleaseError.invalidArchive
            }
            guard try sha256Hex(of: archive) == feed.archiveSHA256 else {
                throw GitHubReleaseError.digestMismatch
            }
            try validateArchiveEntries(at: archive)

            let extracted = stagingDirectory.appendingPathComponent("extracted", isDirectory: true)
            try fileManager.createDirectory(at: extracted, withIntermediateDirectories: true)
            guard run("/usr/bin/ditto", ["-x", "-k", archive.path, extracted.path]) else {
                throw GitHubReleaseError.invalidArchive
            }

            let appURL = extracted.appendingPathComponent("HyperMac.app", isDirectory: true)
            let bundle = Bundle(url: appURL)
            guard bundle?.bundleIdentifier == bundleIdentifier,
                  fileManager.isExecutableFile(atPath: appURL.appendingPathComponent("Contents/MacOS/HyperMac").path),
                  run("/usr/bin/codesign", ["--verify", "--deep", "--strict", "--verbose=0", appURL.path]) else {
                throw GitHubReleaseError.invalidBundle
            }
            guard bundle?.object(forInfoDictionaryKey: "HyperMacBuildCommit") as? String == feed.commit else {
                throw GitHubReleaseError.commitMismatch
            }
            guard let currentRequirement = designatedRequirement(for: installedAppURL),
                  let newRequirement = designatedRequirement(for: appURL),
                  currentRequirement == newRequirement else {
                throw GitHubReleaseError.signatureMismatch
            }
            return StagedGitHubRelease(appURL: appURL, stagingDirectoryURL: stagingDirectory)
        } catch {
            try? fileManager.removeItem(at: stagingDirectory)
            throw error
        }
    }

    private static func retryAfter(from response: HTTPURLResponse) -> TimeInterval? {
        if let seconds = response.value(forHTTPHeaderField: "Retry-After").flatMap(TimeInterval.init),
           seconds > 0 { return seconds }
        if let reset = response.value(forHTTPHeaderField: "X-RateLimit-Reset").flatMap(TimeInterval.init) {
            return max(0, reset - Date().timeIntervalSince1970)
        }
        return nil
    }

    private static func sha256Hex(of fileURL: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: fileURL)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 1_048_576), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private static func validateArchiveEntries(at archive: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-Z", "-1", archive.path]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0, let listing = String(data: data, encoding: .utf8) else {
            throw GitHubReleaseError.invalidArchive
        }
        let entries = listing.split(separator: "\n").map(String.init)
        guard !entries.isEmpty,
              entries.contains("HyperMac.app/Contents/MacOS/HyperMac"),
              entries.allSatisfy({ entry in
                  entry.hasPrefix("HyperMac.app/")
                      && !entry.split(separator: "/").contains("..")
                      && !entry.contains("\\")
              }) else {
            throw GitHubReleaseError.invalidArchive
        }
    }

    private static func designatedRequirement(for appURL: URL) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        process.arguments = ["-d", "-r-", appURL.path]
        let output = Pipe()
        process.standardOutput = FileHandle.nullDevice
        process.standardError = output
        do {
            try process.run()
            let data = output.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0,
                  let text = String(data: data, encoding: .utf8),
                  let marker = text.range(of: "designated =>") else { return nil }
            let requirement = text[marker.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
            return requirement.isEmpty ? nil : requirement
        } catch {
            return nil
        }
    }

    private static func run(_ executable: String, _ arguments: [String]) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
}
