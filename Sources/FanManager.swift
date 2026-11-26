import Foundation
import AppKit

// MARK: - Direct AppleSMC Fan Telemetry Reader (Zero Process Spawn, 0% CPU)

private final class SMCFanReader {
    private let smc = AppleSMCClient()

    func readFanCount() -> Int {
        guard let count = smc.readKeyBytes("FNum")?.first else { return 0 }
        return Int(count)
    }

    func readFloat(key: String) -> Double? {
        guard let b = smc.readKeyBytes(key), b.count == 4 else { return nil }
        let bits = b.withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }
        let val = Double(Float(bitPattern: bits))
        return val.isFinite && val >= 0 ? val : nil
    }

    func readMode(key: String) -> Int? {
        smc.readKeyBytes(key)?.first.map(Int.init)
    }
}

/// SMC writes must finish in the order requested. A newer choice invalidates queued work
/// and callbacks from older choices, including delayed target verification.
private final class FanCommandExecutor {
    private let queue = DispatchQueue(label: "com.opensource.hypermac.fan-control", qos: .userInitiated)
    private let lock = NSLock()
    private var revision: UInt64 = 0

    func nextRevision() -> UInt64 {
        lock.lock()
        defer { lock.unlock() }
        revision &+= 1
        return revision
    }

    func isLatest(_ value: UInt64) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return revision == value
    }

    func execute(_ command: String, revision: UInt64, completion: @escaping (String, Int32) -> Void) {
        queue.async { [self] in
            guard isLatest(revision) else { return }
            let (output, code) = shell(command)
            DispatchQueue.main.async { completion(output, code) }
        }
    }

    func executeSync(_ command: String) -> (String, Int32) {
        _ = nextRevision()
        return queue.sync { shell(command) }
    }
}

/// Điều khiển tốc độ quạt (Apple Silicon M1–M5 Air/Pro/Max/Ultra) theo kiểu iStat Menus:
/// System Controlled / Medium / High / thanh trượt thủ công.
/// Đọc trực tiếp qua IOKit AppleSMC (0 tiến trình con); ghi đồng bộ toàn bộ quạt qua helper `displaycontrol-power`.
@MainActor
public final class FanManager: ObservableObject {
    public static let shared = FanManager()

    public enum Mode: Equatable {
        case system
        case medium
        case high
        case manual
    }

    nonisolated private static let requiredHelperVersion = PrivilegedHelper.requiredVersion
    nonisolated private static let helperPath = PrivilegedHelper.powerPath
    private static let safetyTempOn = 90.0
    private static let safetyTempOff = 80.0

    @Published public private(set) var fanCount: Int = 0
    @Published public private(set) var minRPM: Double = 0
    @Published public private(set) var maxRPM: Double = 0
    @Published public private(set) var currentRPM: Double = 0
    @Published public private(set) var mode: Mode = .system
    /// Tốc độ đích đang áp dụng (RPM) khi không ở System.
    @Published public private(set) var targetRPM: Double = 0
    @Published public private(set) var isHelperReady: Bool = false
    @Published public private(set) var isBusy: Bool = false
    @Published public private(set) var errorMessage: String? = nil
    @Published public private(set) var safetyTripped: Bool = false

    // UI View State (Stored here to prevent CommandLineTools SwiftUIMacros @State crash)
    @Published public var sliderPercent: Double = 50
    @Published public var isDragging: Bool = false

    public var isAvailable: Bool { fanCount > 0 && maxRPM > 0 }

    private let smcReader = SMCFanReader()
    private var fanRanges: [(min: Double, max: Double)] = []
    private var pollTimer: Timer?
    private var smcPath: String?
    private var pendingApply: DispatchWorkItem?
    private var isPopoverVisible = false
    private let commandExecutor = FanCommandExecutor()

    public var needsSafetyMonitoring: Bool { isAvailable && (mode != .system || safetyTripped) }

    private init() {
        smcPath = FanManager.locateSMC()
        refreshStatic()
        refreshRPM()
        checkHelper()
        let nc = NSWorkspace.shared.notificationCenter
        nc.addObserver(self, selector: #selector(willSleep), name: NSWorkspace.willSleepNotification, object: nil)
        nc.addObserver(self, selector: #selector(didWake), name: NSWorkspace.didWakeNotification, object: nil)
        startPolling()
        // Khởi động luôn ở System: nếu bản trước crash giữa chừng, trả toàn bộ quạt về auto.
        if isAvailable { restoreAllFansAutoAsync() }
    }

    // MARK: - Percent <-> RPM

    public func percent(forRPM rpm: Double) -> Int {
        guard maxRPM > 0 else { return 0 }
        return Int((rpm / maxRPM * 100).rounded())
    }

    public var minPercent: Int { percent(forRPM: minRPM) }

    public func rpm(forPercent pct: Double) -> Double {
        let raw = maxRPM * pct / 100
        return min(max(raw, minRPM), maxRPM)
    }

    public var mediumRPM: Double { rpm(forPercent: 50) }
    public var highRPM: Double { rpm(forPercent: 80) }

    // MARK: - Public actions

    public func selectSystem() {
        pendingApply?.cancel()
        mode = .system
        targetRPM = 0
        errorMessage = nil
        restoreAllFansAutoAsync(reportFailure: true)
    }

    public func selectMedium() { apply(rpm: mediumRPM, as: .medium) }
    public func selectHigh() { apply(rpm: highRPM, as: .high) }

    /// Gọi liên tục khi kéo thanh trượt; debounce để không gọi sudo mỗi pixel.
    public func setManual(rpm: Double) {
        guard !safetyTripped else {
            errorMessage = tr("Máy đang quá nóng, quạt do hệ thống điều khiển.",
                              "Mac is too hot; fan stays under system control.")
            return
        }
        let clamped = min(max(rpm.rounded(), minRPM), maxRPM)
        let revision = commandExecutor.nextRevision()
        mode = .manual
        targetRPM = clamped
        errorMessage = nil
        isBusy = true
        pendingApply?.cancel()
        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor in self?.apply(rpm: clamped, as: .manual, revision: revision) }
        }
        pendingApply = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
    }

    public func installHelperIfNeeded() {
        guard !isHelperReady else { return }
        BatteryManager.shared.installHelper { [weak self] _ in
            Task { @MainActor in self?.checkHelper() }
        }
    }

    /// Gọi khi thoát app (đồng bộ cho tất cả quạt 0..<fanCount).
    public func restoreSystemSync() {
        guard isAvailable else { return }
        pendingApply?.cancel()
        let (out, code) = commandExecutor.executeSync("sudo -n \(FanManager.helperPath) fan-auto all 2>&1")
        if code != 0 { appLog("⚠️ Fan restore on exit: code=\(code) \(out)") }
        mode = .system
        targetRPM = 0
    }

    // MARK: - Internals

    private func restoreAllFansAutoAsync(reportFailure: Bool = false, successMessage: String? = nil) {
        let revision = commandExecutor.nextRevision()
        isBusy = true
        commandExecutor.execute("sudo -n \(FanManager.helperPath) fan-auto all 2>&1", revision: revision) { [weak self] out, code in
            guard let self, self.commandExecutor.isLatest(revision) else { return }
            self.isBusy = false
            if code == 0 && out.contains("FAN_AUTO_OK") {
                if let successMessage { self.errorMessage = successMessage }
            } else {
                appLog("⚠️ Fan restore: code=\(code) \(out)")
                if reportFailure {
                    self.errorMessage = tr("Không xác nhận được quạt đã về Tự động.",
                                           "Could not confirm the fans returned to Auto.")
                }
            }
        }
    }

    private func apply(rpm: Double, as newMode: Mode, revision pendingRevision: UInt64? = nil) {
        let revision = pendingRevision ?? commandExecutor.nextRevision()
        guard commandExecutor.isLatest(revision) else { return }
        guard isAvailable else { return }
        guard !safetyTripped else {
            mode = .system
            targetRPM = 0
            restoreAllFansAutoAsync(
                reportFailure: true,
                successMessage: tr("Máy đang quá nóng, quạt do hệ thống điều khiển.",
                                   "Mac is too hot; fan stays under system control."))
            return
        }
        guard isHelperReady else {
            mode = .system
            targetRPM = 0
            restoreAllFansAutoAsync(
                reportFailure: true,
                successMessage: tr("Cần cài helper (hỏi mật khẩu quản trị một lần).",
                                   "Helper install needed (one admin password prompt)."))
            return
        }
        pendingApply?.cancel()
        mode = newMode
        targetRPM = rpm
        errorMessage = nil
        isBusy = true

        // Tính tỷ lệ phần trăm tốc độ và áp dụng đồng bộ cho TOÀN BỘ quạt (F0, F1... trên Pro/Max/Ultra)
        let ratio = maxRPM > 0 ? min(max(rpm / maxRPM, 0), 1) : 0.5
        let count = max(1, min(fanCount, 4))
        var subCommands: [String] = []
        var expectedTargets: [Int] = []

        for i in 0..<count {
            let range = i < fanRanges.count ? fanRanges[i] : (min: minRPM, max: maxRPM)
            let fanRpm = Int(min(max((range.max * ratio).rounded(), range.min), range.max))
            expectedTargets.append(fanRpm)
            subCommands.append("sudo -n \(FanManager.helperPath) fan-set \(i) \(fanRpm)")
        }
        // Cùng một RPM: helper đặt tất cả quạt trong một lần mở Ftst. Gọi riêng từng
        // quạt sẽ mở Ftst lần hai, tạo khoảng trễ để macOS đổi lại mục tiêu quạt đầu.
        let fullCmd: String
        if count > 1, Set(expectedTargets).count == 1, let target = expectedTargets.first {
            fullCmd = "sudo -n \(FanManager.helperPath) fan-set all \(target) 2>&1"
        } else {
            fullCmd = subCommands.joined(separator: " && ") + " 2>&1"
        }

        commandExecutor.execute(fullCmd, revision: revision) { [weak self] out, code in
            guard let self, self.commandExecutor.isLatest(revision) else { return }
            let ok = code == 0 && out.contains("FAN_SET_OK")
            if !ok { appLog("⚠️ Fan helper apply: code=\(code) \(out)") }
            if !ok {
                self.mode = .system
                self.targetRPM = 0
                self.restoreAllFansAutoAsync(
                    reportFailure: true,
                    successMessage: tr("Không đặt được tốc độ quạt trên máy này.",
                                       "Could not set fan speed on this Mac."))
                return
            }
            // Ghi SMC có độ trễ: đọc lại sau ~1.5s rồi kiểm chứng.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                self?.verifyTarget(expected: expectedTargets, revision: revision)
            }
        }
    }

    private func verifyTarget(expected: [Int], revision: UInt64, attempt: Int = 0) {
        guard commandExecutor.isLatest(revision), mode != .system else { return }
        let observed = expected.indices.map { smcReader.readFloat(key: "F\($0)Tg") }
        let modes = expected.indices.map { smcReader.readMode(key: "F\($0)Md") }
        let matches = expected.indices.allSatisfy { i in
            modes[i] == 1 && observed[i].map { abs($0 - Double(expected[i])) <= 5 } == true
        }
        if matches {
            isBusy = false
            return
        }
        if attempt == 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) { [weak self] in
                self?.verifyTarget(expected: expected, revision: revision, attempt: 1)
            }
            return
        }
        appLog("⚠️ Fan verify: expected=\(expected) target=\(observed) mode=\(modes)")
        mode = .system
        targetRPM = 0
        errorMessage = tr("Đang trả quạt về Tự động...", "Returning fans to Auto...")
        let message = observed.contains(where: { $0 == nil }) || modes.contains(where: { $0 == nil })
            ? tr("Không đọc được trạng thái quạt (đã trả về Tự động).",
                 "Could not read fan state (returned to Auto).")
            : tr("macOS không giữ tốc độ quạt (đã trả về Tự động).",
                 "macOS did not keep the fan speed (returned to Auto).")
        restoreAllFansAutoAsync(reportFailure: true, successMessage: message)
    }

    public func checkHelper() {
        let path = FanManager.helperPath
        let reqVer = FanManager.requiredHelperVersion
        DispatchQueue.global(qos: .utility).async {
            let (out, code) = shell("sudo -n \(path) version 2>/dev/null")
            var ver = 0
            if code == 0, let r = out.range(of: "HELPER_VERSION:") {
                ver = Int(out[r.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines).prefix(while: { $0.isNumber })) ?? 0
            }
            DispatchQueue.main.async {
                self.isHelperReady = ver >= reqVer
            }
        }
    }

    private func refreshStatic() {
        // 1. Đọc trực tiếp từ IOKit AppleSMC (0ms, không tạo tiến trình)
        var count = smcReader.readFanCount()
        if count == 0, let smc = smcPath {
            let (n, _) = shell("'\(smc)' -k FNum -r 2>/dev/null")
            count = Int(FanManager.parseFloat(n))
        }
        fanCount = count
        guard fanCount > 0 else { return }

        var ranges: [(min: Double, max: Double)] = []
        for i in 0..<min(fanCount, 4) {
            let directMin = smcReader.readFloat(key: "F\(i)Mn")
            let directMax = smcReader.readFloat(key: "F\(i)Mx")
            var mn = directMin ?? 0
            var mx = directMax ?? 0
            if (directMin == nil || directMax == nil || mx <= 0), let smc = smcPath {
                mn = FanManager.parseFloat(shell("'\(smc)' -k F\(i)Mn -r 2>/dev/null").0)
                mx = FanManager.parseFloat(shell("'\(smc)' -k F\(i)Mx -r 2>/dev/null").0)
            }
            if mx > 0 {
                ranges.append((min: mn, max: mx))
            }
        }
        fanRanges = ranges
        if let first = ranges.first {
            minRPM = first.min
            maxRPM = first.max
        }
    }

    private func refreshRPM() {
        guard fanCount > 0 else { return }
        // Đọc trực tiếp tất cả quạt (F0Ac, F1Ac...) qua IOKit AppleSMC — lấy trung bình RPM thực tế
        var total: Double = 0
        var validCount = 0
        for i in 0..<min(fanCount, 4) {
            if let rpm = smcReader.readFloat(key: "F\(i)Ac") {
                total += rpm
                validCount += 1
            }
        }
        if validCount > 0 && (total > 0 || minRPM <= 0) {
            let avg = total / Double(validCount)
            if abs(avg - self.currentRPM) >= 5.0 || self.currentRPM == 0 {
                self.currentRPM = avg
            }
        } else if let smc = smcPath {
            DispatchQueue.global(qos: .utility).async {
                let rpm = FanManager.parseFloat(shell("'\(smc)' -k F0Ac -r 2>/dev/null").0)
                DispatchQueue.main.async {
                    if abs(rpm - self.currentRPM) >= 5.0 || self.currentRPM == 0 {
                        self.currentRPM = rpm
                    }
                }
            }
        }
    }

    public func setPopoverVisible(_ visible: Bool) {
        isPopoverVisible = visible
        if visible && fanCount > 0 {
            tick()
        }
        startPolling()
    }

    private func startPolling() {
        ThermalManager.shared.setFanThermalMonitorNeeded(needsSafetyMonitoring)
        guard fanCount > 0 else {
            pollTimer?.invalidate()
            pollTimer = nil
            return
        }
        let shouldRun = isPopoverVisible || mode != .system || safetyTripped
        guard shouldRun else {
            pollTimer?.invalidate()
            pollTimer = nil
            return
        }
        guard pollTimer == nil else { return }
        let t = Timer(timeInterval: 2.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        t.tolerance = 0.5
        RunLoop.main.add(t, forMode: .common)
        pollTimer = t
    }

    private func tick() {
        refreshRPM()
        enforceSafety()
        ThermalManager.shared.setFanThermalMonitorNeeded(needsSafetyMonitoring)
    }

    /// Ngưỡng an toàn: CPU/GPU >= 90°C thì ép về System, mở lại khi < 80°C.
    private func enforceSafety() {
        let t = ThermalManager.shared
        let hottest = max(t.cpuPeakTemp, t.gpuAvgTemp, t.hotspotTemp)
        if !safetyTripped, hottest >= FanManager.safetyTempOn {
            safetyTripped = true
            if mode != .system {
                selectSystem()
                errorMessage = tr("Quá nóng (≥90°C): đã trả quạt về hệ thống.",
                                  "Too hot (≥90°C): fan returned to system control.")
            }
        } else if safetyTripped, hottest < FanManager.safetyTempOff {
            safetyTripped = false
            errorMessage = nil
        }
    }

    @objc private func willSleep() { if mode != .system { selectSystem() } }
    @objc private func didWake() { checkHelper(); refreshRPM() }

    // MARK: - Helpers

    private static func locateSMC() -> String? {
        let candidates = [
            Bundle.main.path(forResource: "smc", ofType: nil),
            PrivilegedHelper.smcPath
        ].compactMap { $0 }
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    /// Phân tích dòng `  F0Ac  [flt ]  2985 (bytes ...)` hoặc `[ui8 ]  1 (...)` → số.
    nonisolated static func parseFloat(_ s: String) -> Double {
        guard let close = s.range(of: "]") else { return 0 }
        let rest = s[close.upperBound...].trimmingCharacters(in: .whitespaces)
        let token = rest.split(separator: " ").first.map(String.init) ?? ""
        return Double(token) ?? 0
    }
}
