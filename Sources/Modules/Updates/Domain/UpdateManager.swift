import Foundation
import AppKit
import Combine
import CryptoKit

// MARK: - Update Status States

public enum UpdateState: Equatable {
    case idle
    case checking
    case upToDate(version: String)
    case updateAvailable(version: String, notes: String)
    case downloading
    case extracting
    case readyToRestart
    case failed(String)
}

// MARK: - Update Manager

@MainActor
public class UpdateManager: NSObject, ObservableObject {
    public static let shared = UpdateManager()
    nonisolated public static let currentVersion: String = "2.0.0"

    nonisolated private static let localBuildPathInfoKey = "HyperMacLocalBuildPath"
    nonisolated private static let bundleIdentifier = "com.opensource.hypermac"
    nonisolated private static let releaseFeedKey = "update_release_feed"
    nonisolated private static let releaseLastCheckKey = "update_release_last_check"
    nonisolated private static let releaseNextRetryKey = "update_release_next_retry"
    nonisolated private static let automaticCheckInterval: TimeInterval = 6 * 60 * 60

    public var usesLocalBuild: Bool {
        Bundle.main.object(forInfoDictionaryKey: Self.localBuildPathInfoKey) is String
    }

    @Published public var state: UpdateState = .idle
    @Published public var showUpdateModal: Bool = false
    @Published public var hasNewUpdate: Bool = false
    @Published public var latestVersionString: String = ""
    @Published public var releaseNotes: String = ""
    @Published public var autoCheckEnabled: Bool = true {
        didSet {
            UserDefaults.standard.set(autoCheckEnabled, forKey: "hypermac_auto_check_updates")
            configureAutomaticChecks()
        }
    }

    private var localBuildURL: URL?
    private var runningExecutableFingerprint: String?
    private var releaseFeed: GitHubUpdateFeed?
    private var automaticCheckTimer: Timer?
    private var automaticCheckGeneration = 0

    private enum LocalBuildError: Error, Sendable {
        case notFound
        case invalidBundle
        case buildIsOlder
        case alreadyCurrent
        case io(String)
    }

    private struct LocalBuildSnapshot: Sendable {
        let appURL: URL
        let version: String
        let hasUpdate: Bool
    }

    private struct StagedAppBuild: Sendable {
        let appURL: URL
        let stagingDirectoryURL: URL
    }

    public override init() {
        super.init()
        if let executableURL = Bundle.main.executableURL {
            self.runningExecutableFingerprint = try? Self.fileFingerprint(at: executableURL)
        }

        if UserDefaults.standard.object(forKey: "hypermac_auto_check_updates") != nil {
            self.autoCheckEnabled = UserDefaults.standard.bool(forKey: "hypermac_auto_check_updates")
        } else {
            self.autoCheckEnabled = true
        }

        configureAutomaticChecks()
    }

    private func configureAutomaticChecks() {
        automaticCheckGeneration += 1
        let generation = automaticCheckGeneration
        automaticCheckTimer?.invalidate()
        automaticCheckTimer = nil
        guard autoCheckEnabled else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            guard let self, self.autoCheckEnabled,
                  self.automaticCheckGeneration == generation else { return }
            self.checkForUpdates(silent: true)
        }
        automaticCheckTimer = Timer.scheduledTimer(withTimeInterval: Self.automaticCheckInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.autoCheckEnabled else { return }
                self.checkForUpdates(silent: true)
            }
        }
    }

    // MARK: - Version Comparison

    nonisolated public static func isVersion(_ v1: String, greaterThan v2: String) -> Bool {
        let clean1 = v1.trimmingCharacters(in: CharacterSet(charactersIn: "vV \t\n"))
        let clean2 = v2.trimmingCharacters(in: CharacterSet(charactersIn: "vV \t\n"))

        let parts1 = clean1.split(separator: ".").compactMap { Int($0) }
        let parts2 = clean2.split(separator: ".").compactMap { Int($0) }

        let count = max(parts1.count, parts2.count)
        for i in 0..<count {
            let p1 = i < parts1.count ? parts1[i] : 0
            let p2 = i < parts2.count ? parts2[i] : 0
            if p1 > p2 { return true }
            if p1 < p2 { return false }
        }
        return false
    }

    public func checkForUpdates(silent: Bool = false) {
        if !silent { showUpdateModal = true }
        if case .checking = state { return }
        if case .downloading = state { return }
        if case .extracting = state { return }
        if case .readyToRestart = state { return }
        if usesLocalBuild {
            checkLocalBuild(silent: silent)
        } else {
            checkGitHubRelease(silent: silent)
        }
    }

    // MARK: - Check Local Build

    /// So sánh app đang chạy với `build/HyperMac.app` của source local.
    private func checkLocalBuild(silent: Bool) {
        if !silent {
            self.showUpdateModal = true
        }
        self.state = .checking

        let currentAppURL = Bundle.main.bundleURL.standardizedFileURL
        let runningFingerprint = runningExecutableFingerprint
        Task { [weak self] in
            let result = await Task.detached(priority: .utility) {
                Result { try Self.inspectLocalBuild(currentAppURL: currentAppURL, runningFingerprint: runningFingerprint) }
            }.value

            guard let self else { return }
            switch result {
            case .success(let snapshot):
                self.localBuildURL = snapshot.appURL
                self.latestVersionString = snapshot.version
                let installedVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? Self.currentVersion
                self.releaseNotes = snapshot.hasUpdate && snapshot.version == installedVersion
                    ? tr("Cùng số phiên bản, nhưng bản build có nội dung mới. Chỉ áp dụng sau khi bạn bấm Cập nhật.",
                         "The version number is unchanged, but the build has new content. It applies only after you choose Update.")
                    : tr("Đã so sánh ứng dụng đang chạy với HyperMac.app trong thư mục build.",
                         "Compared the running app with HyperMac.app in the build folder.")
                self.hasNewUpdate = snapshot.hasUpdate

                if snapshot.hasUpdate {
                    self.state = .updateAvailable(
                        version: snapshot.version,
                        notes: self.releaseNotes
                    )
                    appLog("✨ UpdateManager: Local build update available at \(snapshot.appURL.path)")
                } else {
                    self.state = .upToDate(version: snapshot.version)
                    appLog("✅ UpdateManager: Running app matches local build \(snapshot.appURL.path)")
                }

            case .failure(let error):
                self.hasNewUpdate = false
                if silent {
                    self.state = .idle
                } else {
                    let localError = error as? LocalBuildError ?? .io(error.localizedDescription)
                    self.state = .failed(self.message(for: localError))
                }
                appLog("⚠️ UpdateManager: Local build check failed: \(error)")
            }
        }
    }

    // MARK: - Check GitHub Release

    /// Release builds read the small `update.json` asset; no GitHub REST API call.
    private func checkGitHubRelease(silent: Bool) {
        if !silent { showUpdateModal = true }
        let defaults = UserDefaults.standard
        let now = Date().timeIntervalSince1970
        let retryAt = defaults.double(forKey: Self.releaseNextRetryKey)
        if retryAt > now {
            state = silent ? .idle : .failed(releaseRateLimitMessage)
            return
        }

        if silent,
           now - defaults.double(forKey: Self.releaseLastCheckKey) < Self.automaticCheckInterval {
            if let cached = defaults.data(forKey: Self.releaseFeedKey),
               let feed = try? JSONDecoder().decode(GitHubUpdateFeed.self, from: cached),
               feed.isValid {
                applyReleaseFeed(feed)
            } else {
                state = .idle
            }
            return
        }

        state = .checking
        defaults.set(now, forKey: Self.releaseLastCheckKey)
        Task { [weak self] in
            do {
                let feed = try await GitHubReleaseClient.fetchFeed()
                guard let self else { return }
                self.applyReleaseFeed(feed)
                if let encoded = try? JSONEncoder().encode(feed) {
                    defaults.set(encoded, forKey: Self.releaseFeedKey)
                }
                defaults.removeObject(forKey: Self.releaseNextRetryKey)
            } catch {
                guard let self else { return }
                if let releaseError = error as? GitHubReleaseError,
                   case .httpStatus(let status, let retryAfter) = releaseError,
                   status == 403 || status == 429 {
                    defaults.set(Date().timeIntervalSince1970 + max(60, retryAfter ?? 3600),
                                 forKey: Self.releaseNextRetryKey)
                }
                self.state = silent ? .idle : .failed(self.releaseErrorMessage(error))
                appLog("⚠️ UpdateManager: GitHub release feed failed: \(error)")
            }
        }
    }

    private func applyReleaseFeed(_ feed: GitHubUpdateFeed) {
        releaseFeed = feed
        latestVersionString = feed.version
        releaseNotes = feed.notes
        let installedCommit = Bundle.main.object(forInfoDictionaryKey: "HyperMacBuildCommit") as? String
        let installedVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? Self.currentVersion
        let hasUpdate = !Self.isVersion(installedVersion, greaterThan: feed.version)
            && feed.differs(from: installedCommit)
        hasNewUpdate = hasUpdate
        state = hasUpdate
            ? .updateAvailable(version: "Latest", notes: feed.notes)
            : .upToDate(version: "Latest")
        appLog("✅ UpdateManager: GitHub release feed checked (commit: \(feed.commit), update: \(hasUpdate))")
    }

    private var releaseRateLimitMessage: String {
        tr("GitHub tạm giới hạn lượt kiểm tra. Bạn có thể mở Releases để tải thủ công.",
           "GitHub is temporarily limiting checks. You can open Releases to download manually.")
    }

    private func releaseErrorMessage(_ error: Error) -> String {
        if let releaseError = error as? GitHubReleaseError {
            switch releaseError {
            case .httpStatus(403, _), .httpStatus(429, _):
                return releaseRateLimitMessage
            case .httpStatus(404, _):
                return tr("Release chưa có dữ liệu cập nhật. Hãy mở GitHub Releases để tải thủ công.",
                          "The release has no update feed yet. Open GitHub Releases to download manually.")
            case .invalidFeed:
                return tr("Dữ liệu cập nhật từ GitHub không hợp lệ. Chưa cài bản mới.",
                          "GitHub's update feed is invalid. No update was installed.")
            default:
                break
            }
        }
        return tr("Không thể kiểm tra GitHub. Kiểm tra kết nối hoặc mở Releases để tải thủ công.",
                  "Could not check GitHub. Check your connection or open Releases to download manually.")
    }

    private nonisolated static func inspectLocalBuild(
        currentAppURL: URL,
        runningFingerprint: String? = nil
    ) throws -> LocalBuildSnapshot {
        guard let buildURL = findLocalBuild() else {
            throw LocalBuildError.notFound
        }
        guard isValidHyperMacBundle(at: buildURL) else {
            throw LocalBuildError.invalidBundle
        }

        let currentBundle = Bundle(url: currentAppURL) ?? Bundle.main
        let buildBundle = Bundle(url: buildURL)
        let currentVersion = currentBundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? Self.currentVersion
        let buildVersion = buildBundle?.infoDictionary?["CFBundleShortVersionString"] as? String ?? Self.currentVersion

        if isVersion(currentVersion, greaterThan: buildVersion) {
            throw LocalBuildError.buildIsOlder
        }

        let currentFingerprint = try appFingerprint(at: currentAppURL)
        let buildFingerprint = try appFingerprint(at: buildURL)
        let buildExecutable = buildURL.appendingPathComponent("Contents/MacOS/HyperMac")
        let buildExecutableFingerprint = try fileFingerprint(at: buildExecutable)
        let hasUpdate = isVersion(buildVersion, greaterThan: currentVersion)
            || currentFingerprint != buildFingerprint
            || (runningFingerprint != nil && runningFingerprint != buildExecutableFingerprint)

        return LocalBuildSnapshot(appURL: buildURL, version: buildVersion, hasUpdate: hasUpdate)
    }

    private nonisolated static func findLocalBuild() -> URL? {
        let fileManager = FileManager.default
        if let configuredPath = Bundle.main.object(forInfoDictionaryKey: localBuildPathInfoKey) as? String,
           !configuredPath.isEmpty {
            let configured = URL(fileURLWithPath: configuredPath).standardizedFileURL
            return isLocalBuildCandidate(configured, fileManager: fileManager) ? configured : nil
        }

        let runningAppURL = Bundle.main.bundleURL.standardizedFileURL
        if runningAppURL.deletingLastPathComponent().lastPathComponent == "build",
           isLocalBuildCandidate(runningAppURL, fileManager: fileManager) {
            return runningAppURL
        }

        // Bản local cũ chưa có Info.plist key: chỉ xem đúng dự án HyperMac.
        let legacyBuild = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Desktop/Code/HyperMac/build/HyperMac.app", isDirectory: true)
            .standardizedFileURL
        return isLocalBuildCandidate(legacyBuild, fileManager: fileManager) ? legacyBuild : nil
    }

    private nonisolated static func isLocalBuildCandidate(_ url: URL, fileManager: FileManager) -> Bool {
        fileManager.fileExists(atPath: url.path)
            && Bundle(url: url)?.bundleIdentifier == bundleIdentifier
            && fileManager.isExecutableFile(atPath: url.appendingPathComponent("Contents/MacOS/HyperMac").path)
    }

    private nonisolated static func isValidHyperMacBundle(at appURL: URL) -> Bool {
        let executablePath = appURL.appendingPathComponent("Contents/MacOS/HyperMac").path
        guard FileManager.default.isExecutableFile(atPath: executablePath),
              Bundle(url: appURL)?.bundleIdentifier == bundleIdentifier else { return false }

        // Verify the local bundle before allowing it to replace the running app.
        let verifier = Process()
        verifier.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        verifier.arguments = ["--verify", "--deep", "--strict", "--verbose=0", appURL.path]
        verifier.standardOutput = FileHandle.nullDevice
        verifier.standardError = FileHandle.nullDevice
        do {
            try verifier.run()
            verifier.waitUntilExit()
            return verifier.terminationStatus == 0
        } catch {
            return false
        }
    }

    private nonisolated static func appFingerprint(at appURL: URL) throws -> String {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: appURL,
            includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
            options: []
        ) else {
            throw LocalBuildError.io("Could not read app bundle contents.")
        }

        var files: [URL] = []
        for case let fileURL as URL in enumerator {
            let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            if values.isRegularFile == true || values.isSymbolicLink == true {
                files.append(fileURL)
            }
        }
        files.sort { $0.path < $1.path }

        var hasher = SHA256()
        for fileURL in files {
            let relativePath = String(fileURL.path.dropFirst(appURL.path.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            hasher.update(data: Data(relativePath.utf8))

            let values = try fileURL.resourceValues(forKeys: [.isSymbolicLinkKey])
            if values.isSymbolicLink == true {
                let destination = try fileManager.destinationOfSymbolicLink(atPath: fileURL.path)
                hasher.update(data: Data(destination.utf8))
            } else {
                hasher.update(data: try Data(contentsOf: fileURL, options: [.mappedIfSafe]))
            }
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private nonisolated static func fileFingerprint(at fileURL: URL) throws -> String {
        let data = try Data(contentsOf: fileURL, options: [.mappedIfSafe])
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private func message(for error: LocalBuildError) -> String {
        switch error {
        case .notFound:
            return tr("Không tìm thấy HyperMac.app trong thư mục build local.", "HyperMac.app was not found in a local build folder.")
        case .invalidBundle:
            return tr("HyperMac.app trong build không hợp lệ hoặc chữ ký đã bị thay đổi.", "The HyperMac.app in build is invalid or its signature has changed.")
        case .buildIsOlder:
            return tr("Bản build local cũ hơn ứng dụng đang chạy nên không thể cập nhật.", "The local build is older than the running app and cannot be installed.")
        case .alreadyCurrent:
            return tr("Ứng dụng đã trùng với bản build local.", "The app already matches the local build.")
        case .io(let detail):
            return tr("Không thể đọc bản build local: \(detail)", "Could not read the local build: \(detail)")
        }
    }

    // MARK: - Install Local Build

    public func startUpdate() {
        if usesLocalBuild {
            startLocalUpdate()
        } else {
            startReleaseUpdate()
        }
    }

    private func startLocalUpdate() {
        guard hasNewUpdate else { return }
        let targetURL = Bundle.main.bundleURL.standardizedFileURL
        self.state = .extracting
        let runningFingerprint = self.runningExecutableFingerprint
        Task { [weak self] in
            let result = await Task.detached(priority: .userInitiated) {
                Result {
                    let snapshot = try Self.inspectLocalBuild(
                        currentAppURL: targetURL,
                        runningFingerprint: runningFingerprint
                    )
                    guard snapshot.hasUpdate else { throw LocalBuildError.alreadyCurrent }

                    let stagingDirectory = FileManager.default.temporaryDirectory
                        .appendingPathComponent("HyperMac-local-update-\(UUID().uuidString)", isDirectory: true)
                    try FileManager.default.createDirectory(at: stagingDirectory, withIntermediateDirectories: true)
                    let stagedAppURL = stagingDirectory.appendingPathComponent("HyperMac.app", isDirectory: true)
                    do {
                        try FileManager.default.copyItem(at: snapshot.appURL, to: stagedAppURL)
                        guard Self.isValidHyperMacBundle(at: stagedAppURL) else {
                            throw LocalBuildError.invalidBundle
                        }
                        return StagedAppBuild(appURL: stagedAppURL, stagingDirectoryURL: stagingDirectory)
                    } catch {
                        try? FileManager.default.removeItem(at: stagingDirectory)
                        throw error
                    }
                }
            }.value

            guard let self else { return }
            switch result {
            case .success(let stagedBuild):
                self.performInPlaceUpdate(stagedBuild: stagedBuild, targetURL: targetURL)
            case .failure(let error as LocalBuildError):
                self.state = .failed(self.message(for: error))
            case .failure(let error):
                self.state = .failed(self.message(for: .io(error.localizedDescription)))
            }
        }
    }

    private func startReleaseUpdate() {
        guard hasNewUpdate, let feed = releaseFeed else { return }
        let targetURL = Bundle.main.bundleURL.standardizedFileURL
        state = .downloading
        Task { [weak self] in
            do {
                let staged = try await GitHubReleaseClient.downloadAndStage(
                    feed: feed,
                    installedAppURL: targetURL
                )
                guard let self else {
                    try? FileManager.default.removeItem(at: staged.stagingDirectoryURL)
                    return
                }
                self.state = .extracting
                self.performInPlaceUpdate(
                    stagedBuild: StagedAppBuild(
                        appURL: staged.appURL,
                        stagingDirectoryURL: staged.stagingDirectoryURL
                    ),
                    targetURL: targetURL
                )
            } catch {
                guard let self else { return }
                self.state = .failed(self.releaseInstallErrorMessage(error))
                appLog("⚠️ UpdateManager: GitHub release download failed: \(error)")
            }
        }
    }

    private func releaseInstallErrorMessage(_ error: Error) -> String {
        if let releaseError = error as? GitHubReleaseError {
            switch releaseError {
            case .digestMismatch:
                return tr("Tệp tải về không khớp SHA-256. App hiện tại được giữ nguyên.",
                          "The download does not match its SHA-256 digest. The current app was kept.")
            case .invalidArchive, .invalidBundle, .commitMismatch:
                return tr("Gói cập nhật không hợp lệ. App hiện tại được giữ nguyên.",
                          "The update package is invalid. The current app was kept.")
            case .signatureMismatch:
                return tr("Chữ ký của bản tải về không khớp app đang dùng. Chưa cài bản mới.",
                          "The downloaded app's signature does not match the installed app. No update was installed.")
            case .httpStatus(403, _), .httpStatus(429, _):
                return releaseRateLimitMessage
            default:
                break
            }
        }
        return tr("Không thể tải bản cập nhật. App hiện tại được giữ nguyên; bạn có thể mở GitHub Releases.",
                  "Could not download the update. The current app was kept; you can open GitHub Releases.")
    }

    public func openReleasePage() {
        NSWorkspace.shared.open(GitHubReleaseClient.releasePageURL)
    }

    public func openBuildFolder() {
        let folderURL: URL
        if let localBuildURL {
            folderURL = localBuildURL.deletingLastPathComponent()
        } else if let configuredPath = Bundle.main.object(forInfoDictionaryKey: Self.localBuildPathInfoKey) as? String {
            folderURL = URL(fileURLWithPath: configuredPath).deletingLastPathComponent()
        } else {
            folderURL = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Desktop/Code", isDirectory: true)
        }
        NSWorkspace.shared.open(folderURL)
    }

    private func performInPlaceUpdate(stagedBuild: StagedAppBuild, targetURL: URL) {
        let fileManager = FileManager.default
        let currentPID = ProcessInfo.processInfo.processIdentifier
        let parentURL = targetURL.deletingLastPathComponent()
        let token = UUID().uuidString
        let newURL = parentURL.appendingPathComponent(".HyperMac.\(token).new", isDirectory: true)
        let backupURL = parentURL.appendingPathComponent(".HyperMac.\(token).backup", isDirectory: true)
        let scriptURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("hypermac-local-updater-\(token).sh")
        let logURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("hypermac-local-updater-\(token).log")

        let script = """
        #!/bin/bash
        exec > \(Self.shellQuote(logURL.path)) 2>&1

        PID=\(Self.shellQuote(String(currentPID)))
        PARENT=\(Self.shellQuote(parentURL.path))
        APP=\(Self.shellQuote(targetURL.path))
        NEW=\(Self.shellQuote(newURL.path))
        BAK=\(Self.shellQuote(backupURL.path))
        STAGED=\(Self.shellQuote(stagedBuild.appURL.path))
        STAGING_DIR=\(Self.shellQuote(stagedBuild.stagingDirectoryURL.path))
        SCRIPT=\(Self.shellQuote(scriptURL.path))

        fail_replace() {
            echo "App replacement failed: $1"
            /bin/rm -rf "$NEW"
            if [ -d "$BAK" ] && [ ! -d "$APP" ]; then /bin/mv "$BAK" "$APP"; fi
            exit 1
        }

        if [ "${1:-}" = "--replace" ]; then
            /bin/rm -rf "$NEW"
            /bin/cp -R "$STAGED" "$NEW" || fail_replace "copy failed"
            [ -x "$NEW/Contents/MacOS/HyperMac" ] || fail_replace "missing executable"
            /usr/bin/codesign --verify --deep --strict --verbose=0 "$NEW" || fail_replace "signature check failed"

            if [ -e "$APP" ]; then
                /bin/mv "$APP" "$BAK" || fail_replace "could not back up current app"
            fi
            if /bin/mv "$NEW" "$APP"; then
                echo "HyperMac update installed."
                /bin/rm -rf "$BAK"
                exit 0
            fi
            /bin/rm -rf "$APP"
            if [ -e "$BAK" ]; then /bin/mv "$BAK" "$APP"; fi
            fail_replace "could not replace current app"
        fi

        fail_update() {
            echo "Update failed: $1"
            if [ -d "$APP" ]; then /usr/bin/open -a "$APP"; fi
            /bin/rm -rf "$STAGING_DIR"
            /bin/rm -f "$SCRIPT"
            exit 1
        }

        echo "Waiting for HyperMac process $PID to exit..."
        while /bin/kill -0 "$PID" 2>/dev/null; do /bin/sleep 0.2; done
        /bin/sleep 0.3

        if [ -w "$PARENT" ]; then
            /bin/bash "$SCRIPT" --replace || fail_update "could not replace app"
        else
            # /Applications có thể cần quyền quản trị; osascript chỉ chạy bước thay app.
            /usr/bin/osascript -e 'on run argv' \\
                -e 'do shell script "/bin/bash " & quoted form of (item 1 of argv) & " --replace" with administrator privileges' \\
                -e 'end run' "$SCRIPT" || fail_update "administrator authorization failed"
        fi

        /usr/bin/open -a "$APP"
        /bin/sleep 4
        /bin/rm -rf "$STAGING_DIR"
        /bin/rm -f "$SCRIPT"
        """

        do {
            try script.write(to: scriptURL, atomically: true, encoding: .utf8)
            try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: scriptURL.path)

            let updateProcess = Process()
            updateProcess.executableURL = URL(fileURLWithPath: "/bin/bash")
            updateProcess.arguments = [scriptURL.path]
            updateProcess.standardInput = FileHandle.nullDevice
            updateProcess.standardOutput = FileHandle.nullDevice
            updateProcess.standardError = FileHandle.nullDevice
            try updateProcess.run()

            self.state = .readyToRestart
            appLog("✨ UpdateManager: Installing validated app from \(stagedBuild.appURL.path) to \(targetURL.path)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                NSApplication.shared.terminate(nil)
            }
        } catch {
            try? fileManager.removeItem(at: stagedBuild.stagingDirectoryURL)
            try? fileManager.removeItem(at: scriptURL)
            self.state = .failed(tr("Không thể khởi động tiến trình cập nhật: \(error.localizedDescription)", "Could not start the updater: \(error.localizedDescription)"))
        }
    }

    private nonisolated static func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
