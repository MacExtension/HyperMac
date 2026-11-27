import Foundation
import IOKit
import IOKit.pwr_mgt
import AppKit
import Combine

public enum CaffeinateDuration: Int, CaseIterable, Identifiable {
    case indefinite = 0
    case min15 = 900
    case min30 = 1800
    case hour1 = 3600
    case hour2 = 7200

    public var id: Int { self.rawValue }

    public var title: String {
        switch self {
        case .indefinite: return tr("Vô hạn", "Infinite")
        case .min15: return "15m"
        case .min30: return "30m"
        case .hour1: return "1h"
        case .hour2: return "2h"
        }
    }
}

// MARK: - Caffeinate Manager (Native Apple IOKit Keep-Awake)

@MainActor
public class CaffeinateManager: ObservableObject {
    public static let shared = CaffeinateManager()

    private enum Preferences {
        static let duration = "caffeinate_selected_duration"
        static let enabled = "caffeinate_enabled"
        static let expiresAt = "caffeinate_expires_at"
    }

    @Published public var isActive: Bool = false
    @Published public var selectedDuration: CaffeinateDuration = .indefinite
    @Published public var remainingSeconds: Int = 0
    @Published public var remainingFormatted: String = ""

    private var assertionID: IOPMAssertionID = 0
    private var countdownTimer: Timer?
    private var expiresAt: Date?

    private init() {
        let defaults = UserDefaults.standard
        selectedDuration = CaffeinateDuration(rawValue: defaults.integer(forKey: Preferences.duration)) ?? .indefinite

        // The OS assertion belongs to this process. Release it on quit without
        // clearing the user's choice, so a new process can restore it.
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.stopForTermination()
            }
        }

        guard defaults.bool(forKey: Preferences.enabled) else { return }
        if selectedDuration == .indefinite {
            enable(duration: .indefinite)
        } else {
            let timestamp = defaults.double(forKey: Preferences.expiresAt)
            if timestamp > Date().timeIntervalSince1970 {
                activate(duration: selectedDuration, expiresAt: Date(timeIntervalSince1970: timestamp))
            } else {
                defaults.set(false, forKey: Preferences.enabled)
                defaults.removeObject(forKey: Preferences.expiresAt)
            }
        }
    }

    public func toggle() {
        if isActive {
            disable()
        } else {
            enable(duration: selectedDuration)
        }
    }

    public func enable(duration: CaffeinateDuration = .indefinite) {
        activate(duration: duration, expiresAt: duration == .indefinite ? nil : Date().addingTimeInterval(TimeInterval(duration.rawValue)))
    }

    private func activate(duration: CaffeinateDuration, expiresAt: Date?) {
        self.selectedDuration = duration
        let defaults = UserDefaults.standard
        defaults.set(duration.rawValue, forKey: Preferences.duration)
        if let expiresAt, expiresAt <= Date() {
            disable()
            return
        }

        if assertionID == 0 {
            let type = kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString
            let reason = "HyperMac Keep-Awake (Anti-Sleep)" as CFString
            let result = IOPMAssertionCreateWithName(
                type,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                reason,
                &assertionID
            )
            if result == kIOReturnSuccess {
                appLog("☕️ CaffeinateManager: Native IOKit display assertion active (ID: \(assertionID))")
            } else {
                appLog("⚠️ CaffeinateManager: Failed to create assertion (Error: \(result))")
                disable()
                return
            }
        }

        self.isActive = true
        self.expiresAt = expiresAt
        self.remainingSeconds = expiresAt.map { max(0, Int(ceil($0.timeIntervalSinceNow))) } ?? 0
        updateRemainingFormatted()
        defaults.set(true, forKey: Preferences.enabled)
        if let expiresAt {
            defaults.set(expiresAt.timeIntervalSince1970, forKey: Preferences.expiresAt)
        } else {
            defaults.removeObject(forKey: Preferences.expiresAt)
        }

        countdownTimer?.invalidate()
        countdownTimer = nil
        if duration != .indefinite {
            countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.tick()
                }
            }
        }
    }

    public func disable() {
        stopForTermination()
        UserDefaults.standard.set(false, forKey: Preferences.enabled)
        UserDefaults.standard.removeObject(forKey: Preferences.expiresAt)
    }

    private func stopForTermination() {
        countdownTimer?.invalidate()
        countdownTimer = nil

        if assertionID != 0 {
            let res = IOPMAssertionRelease(assertionID)
            appLog("☕️ CaffeinateManager: Display assertion released (Result: \(res == kIOReturnSuccess))")
            assertionID = 0
        }

        self.isActive = false
        self.expiresAt = nil
        self.remainingSeconds = 0
        self.remainingFormatted = ""
    }

    public func setDuration(_ duration: CaffeinateDuration) {
        self.selectedDuration = duration
        UserDefaults.standard.set(duration.rawValue, forKey: Preferences.duration)
        if isActive {
            enable(duration: duration)
        }
    }

    private func tick() {
        guard isActive, let expiresAt else { return }

        let remaining = max(0, Int(ceil(expiresAt.timeIntervalSinceNow)))
        if remaining > 0 {
            remainingSeconds = remaining
            updateRemainingFormatted()
        } else {
            disable()
            // Send user notification when timer expires
            let script = "display notification \"Hết thời gian hẹn giờ giữ màn hình. Màn hình đã trở lại chế độ ngủ bình thường của macOS.\" with title \"☕️ Chống sleep màn kết thúc\""
            DispatchQueue.global(qos: .utility).async {
                _ = shell("osascript -e '\(script)'")
            }
        }
    }

    private func updateRemainingFormatted() {
        if selectedDuration == .indefinite {
            remainingFormatted = "∞"
            return
        }
        let hours = remainingSeconds / 3600
        let minutes = (remainingSeconds % 3600) / 60
        let seconds = remainingSeconds % 60
        if hours > 0 {
            remainingFormatted = String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            remainingFormatted = String(format: "%02d:%02d", minutes, seconds)
        }
    }
}
