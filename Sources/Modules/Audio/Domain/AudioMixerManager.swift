import AppKit
import AudioMixerBridge
import Combine
import CoreAudio
import Darwin
import Foundation

struct MixerApplication: Identifiable, Equatable {
    let id: String             // bundle identifier
    let name: String
    let processIDs: [AudioObjectID]
    let icon: NSImage?

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id && lhs.name == rhs.name && lhs.processIDs == rhs.processIDs
    }
}

private func audioAddress(_ selector: AudioObjectPropertySelector,
                          scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> AudioObjectPropertyAddress {
    AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
}

/// A private CoreAudio tap captures one application's sound. The aggregate device
/// sends its Float32 stream directly to the current output in the same IO cycle.
/// Muted-when-tapped lets CoreAudio restore normal playback if the IOProc stops.
private final class MixerTapSession {
    let processIDs: [AudioObjectID]
    let outputID: AudioObjectID
    private var tapID: AudioObjectID = kAudioObjectUnknown
    private var aggregateID: AudioObjectID = kAudioObjectUnknown
    private var ioProcID: AudioDeviceIOProcID?
    private var state: OpaquePointer?
    private var started = false

    init(processIDs: [AudioObjectID], outputID: AudioObjectID, gain: Float) throws {
        self.processIDs = processIDs
        self.outputID = outputID
        do { try configure(gain: gain) } catch { stop(); throw error }
    }

    private func configure(gain: Float) throws {
        guard #available(macOS 14.2, *) else {
            throw MixerError.message("Mixer cần macOS 14.2 trở lên")
        }
        let description = CATapDescription()
        description.name = "HyperMac App Mixer"
        description.processes = processIDs
        description.isPrivate = true
        description.isMixdown = true
        description.isMono = false
        description.muteBehavior = .mutedWhenTapped
        try check(AudioHardwareCreateProcessTap(description, &tapID), "Tạo bộ thu âm thanh")

        let outputUID = try stringProperty(outputID, kAudioDevicePropertyDeviceUID)
        let tapUID = try stringProperty(tapID, kAudioTapPropertyUID)
        let composition: [String: Any] = [
            kAudioAggregateDeviceNameKey: "HyperMac Mixer",
            kAudioAggregateDeviceUIDKey: UUID().uuidString,
            kAudioAggregateDeviceSubDeviceListKey: [[kAudioSubDeviceUIDKey: outputUID]],
            kAudioAggregateDeviceMainSubDeviceKey: outputUID,
            kAudioAggregateDeviceTapListKey: [[kAudioSubTapUIDKey: tapUID]],
            kAudioAggregateDeviceIsPrivateKey: true
        ]
        try check(AudioHardwareCreateAggregateDevice(composition as CFDictionary, &aggregateID),
                  "Tạo thiết bị âm thanh")

        // The DSP bridge interprets buffers as Float32. Never read/mute a tap
        // unless both sides of the aggregate expose matching PCM sample rates.
        let input = try format(aggregateID, scope: kAudioObjectPropertyScopeInput)
        let output = try format(aggregateID, scope: kAudioObjectPropertyScopeOutput)
        let valid = [input, output].allSatisfy {
            $0.mFormatID == kAudioFormatLinearPCM &&
            ($0.mFormatFlags & kAudioFormatFlagIsFloat) != 0 &&
            $0.mBitsPerChannel == 32
        }
        guard valid, input.mSampleRate == output.mSampleRate else {
            throw MixerError.message("Định dạng âm thanh của thiết bị chưa được hỗ trợ")
        }

        guard let newState = HyperMacMixerCreate() else {
            throw MixerError.message("Không cấp phát được bộ trộn")
        }
        state = newState
        HyperMacMixerSetGain(newState, gain)
        try check(AudioDeviceCreateIOProcIDWithBlock(&ioProcID, aggregateID, nil) {
            _, inputData, _, outputData, _ in
            HyperMacMixerProcess(newState, inputData, outputData)
        }, "Khởi tạo bộ trộn")
        try check(AudioDeviceStart(aggregateID, ioProcID), "Bắt đầu trộn âm thanh")
        started = true
    }

    func setGain(_ gain: Float) {
        if let state { HyperMacMixerSetGain(state, gain) }
    }

    func stop() {
        if aggregateID != kAudioObjectUnknown {
            if started { _ = AudioDeviceStop(aggregateID, ioProcID); started = false }
            if let ioProcID { _ = AudioDeviceDestroyIOProcID(aggregateID, ioProcID) }
            ioProcID = nil
            _ = AudioHardwareDestroyAggregateDevice(aggregateID)
            aggregateID = kAudioObjectUnknown
        }
        if tapID != kAudioObjectUnknown {
            if #available(macOS 14.2, *) { _ = AudioHardwareDestroyProcessTap(tapID) }
            tapID = kAudioObjectUnknown
        }
        if let state { HyperMacMixerDestroy(state); self.state = nil }
    }

    deinit { stop() }

    private func check(_ status: OSStatus, _ operation: String) throws {
        guard status == noErr else { throw MixerError.message("\(operation) thất bại (\(status))") }
    }

    private func stringProperty(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector) throws -> String {
        var address = audioAddress(selector)
        var size = UInt32(MemoryLayout<CFString?>.size)
        var result: Unmanaged<CFString>?
        try check(AudioObjectGetPropertyData(object, &address, 0, nil, &size, &result), "Đọc mã thiết bị")
        guard let result else { throw MixerError.message("Không tìm thấy mã thiết bị") }
        return result.takeRetainedValue() as String
    }

    private func format(_ object: AudioObjectID, scope: AudioObjectPropertyScope) throws -> AudioStreamBasicDescription {
        var address = audioAddress(kAudioDevicePropertyStreamFormat, scope: scope)
        var value = AudioStreamBasicDescription()
        var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        try check(AudioObjectGetPropertyData(object, &address, 0, nil, &size, &value), "Đọc định dạng âm thanh")
        return value
    }
}

private enum MixerError: LocalizedError {
    case message(String)
    var errorDescription: String? {
        if case let .message(value) = self { return value }
        return nil
    }
}

@MainActor
final class AudioMixerManager: ObservableObject {
    static let shared = AudioMixerManager()

    @Published private(set) var applications: [MixerApplication] = []
    @Published private(set) var errorMessage: String?
    @Published private(set) var enabled = UserDefaults.standard.bool(forKey: "mixer_enabled")

    private var levels = UserDefaults.standard.dictionary(forKey: "mixer_levels") as? [String: Int] ?? [:]
    private var sessions: [String: MixerTapSession] = [:]
    private var timer: Timer?
    private var popoverVisible = false
    private var levelsBeforeMute: [String: Int] = [:]
    private var processListener: AudioObjectPropertyListenerBlock?
    private var outputListener: AudioObjectPropertyListenerBlock?
    private var observationFailed = false

    private init() {
        let snappedLevels = levels.mapValues(Self.snappedLevel)
        if snappedLevels != levels {
            levels = snappedLevels
            UserDefaults.standard.set(levels, forKey: "mixer_levels")
        }
        if enabled && levels.values.contains(where: { $0 != 100 }) { refresh() }
        syncTimer()
    }

    private static func snappedLevel(_ level: Int) -> Int {
        Int((Double(max(0, min(200, level))) / 10).rounded()) * 10
    }

    func setPopoverVisible(_ visible: Bool) {
        popoverVisible = visible
        if visible { refresh() }
        else { applications = [] }
        syncTimer()
    }

    func setEnabled(_ value: Bool) {
        enabled = value
        UserDefaults.standard.set(value, forKey: "mixer_enabled")
        if !value { stopAll() }
        else { refresh() }
        syncTimer()
    }

    func level(for app: MixerApplication) -> Int { levels[app.id] ?? 100 }

    func setLevel(_ level: Int, for app: MixerApplication) {
        let clamped = Self.snappedLevel(level)
        levels[app.id] = clamped
        UserDefaults.standard.set(levels, forKey: "mixer_levels")
        if clamped == 100 {
            sessions.removeValue(forKey: app.id)?.stop()
        } else if enabled {
            if let session = sessions[app.id] { session.setGain(Float(clamped) / 100) }
            else { refresh() }
        }
        objectWillChange.send()
        syncTimer()
    }

    func toggleMute(for app: MixerApplication) {
        let current = level(for: app)
        if current == 0 { setLevel(levelsBeforeMute[app.id] ?? 100, for: app) }
        else {
            levelsBeforeMute[app.id] = current
            setLevel(0, for: app)
        }
    }

    private func syncTimer() {
        syncListeners()
        let needed = popoverVisible || (enabled && levels.values.contains { $0 != 100 } && observationFailed)
        if needed && timer == nil {
            let newTimer = Timer(timeInterval: 2, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in self?.refresh() }
            }
            newTimer.tolerance = 0.3
            RunLoop.main.add(newTimer, forMode: .common)
            timer = newTimer
        } else if !needed {
            timer?.invalidate()
            timer = nil
        }
    }

    private func syncListeners() {
        let needed = popoverVisible || (enabled && levels.values.contains { $0 != 100 })
        let system = AudioObjectID(kAudioObjectSystemObject)
        if needed && processListener == nil && !observationFailed {
            var processAddress = audioAddress(kAudioHardwarePropertyProcessObjectList)
            let processBlock: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
                Task { @MainActor [weak self] in self?.refresh() }
            }
            if AudioObjectAddPropertyListenerBlock(system, &processAddress, .main, processBlock) == noErr {
                processListener = processBlock
            } else {
                observationFailed = true
            }
            var outputAddress = audioAddress(kAudioHardwarePropertyDefaultOutputDevice)
            let outputBlock: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
                Task { @MainActor [weak self] in self?.refresh() }
            }
            if AudioObjectAddPropertyListenerBlock(system, &outputAddress, .main, outputBlock) == noErr {
                outputListener = outputBlock
            } else {
                observationFailed = true
            }
        } else if !needed {
            if let processListener {
                var address = audioAddress(kAudioHardwarePropertyProcessObjectList)
                _ = AudioObjectRemovePropertyListenerBlock(system, &address, .main, processListener)
                self.processListener = nil
            }
            if let outputListener {
                var address = audioAddress(kAudioHardwarePropertyDefaultOutputDevice)
                _ = AudioObjectRemovePropertyListenerBlock(system, &address, .main, outputListener)
                self.outputListener = nil
            }
            observationFailed = false
        }
    }

    private func stopAll() {
        for session in sessions.values { session.stop() }
        sessions.removeAll()
    }

    func stopForTermination() {
        stopAll()
        popoverVisible = false
        enabled = false
        syncTimer()
    }

    private func refresh() {
        guard enabled || popoverVisible else { return }
        let output = defaultOutputDevice()
        let found = audioApplications()
        if popoverVisible { applications = found }

        let active = Dictionary(uniqueKeysWithValues: found.map { ($0.id, $0.processIDs) })
        let stale = sessions.compactMap { bundleID, session in
            (active[bundleID] != session.processIDs || session.outputID != output) ? bundleID : nil
        }
        for bundleID in stale {
            sessions.removeValue(forKey: bundleID)?.stop()
        }
        guard enabled, output != kAudioObjectUnknown else { return }
        guard #available(macOS 14.2, *) else {
            errorMessage = "Mixer cần macOS 14.2 trở lên"
            return
        }
        for app in found where level(for: app) != 100 {
            let gain = Float(level(for: app)) / 100
            if let session = sessions[app.id] {
                session.setGain(gain)
            } else {
                do {
                    sessions[app.id] = try MixerTapSession(processIDs: app.processIDs, outputID: output, gain: gain)
                    errorMessage = nil
                } catch {
                    errorMessage = error.localizedDescription
                    appLog("🔊 Mixer: \(app.name): \(error.localizedDescription)")
                }
            }
        }
    }

    private func defaultOutputDevice() -> AudioObjectID {
        var address = audioAddress(kAudioHardwarePropertyDefaultOutputDevice)
        var value: AudioObjectID = kAudioObjectUnknown
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        let status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &value)
        return status == noErr ? value : kAudioObjectUnknown
    }

    private func audioApplications() -> [MixerApplication] {
        let system = AudioObjectID(kAudioObjectSystemObject)
        var address = audioAddress(kAudioHardwarePropertyProcessObjectList)
        var bytes: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &bytes) == noErr,
              bytes > 0 else { return [] }
        var objects = [AudioObjectID](repeating: 0, count: Int(bytes) / MemoryLayout<AudioObjectID>.size)
        let listStatus = objects.withUnsafeMutableBytes { buffer in
            AudioObjectGetPropertyData(system, &address, 0, nil, &bytes, buffer.baseAddress!)
        }
        guard listStatus == noErr else { return [] }
        objects = Array(objects.prefix(Int(bytes) / MemoryLayout<AudioObjectID>.size))

        var grouped: [String: (String, NSImage?, [AudioObjectID])] = [:]
        for object in objects {
            var pid: pid_t = 0
            var size = UInt32(MemoryLayout<pid_t>.size)
            address = audioAddress(kAudioProcessPropertyPID)
            guard AudioObjectGetPropertyData(object, &address, 0, nil, &size, &pid) == noErr,
                  pid != getpid(),
                  let app = applicationIdentity(for: pid) else { continue }
            let bundleID = app.id
            var running: UInt32 = 0
            size = UInt32(MemoryLayout<UInt32>.size)
            address = audioAddress(kAudioProcessPropertyIsRunningOutput)
            let status = AudioObjectGetPropertyData(object, &address, 0, nil, &size, &running)
            guard status == noErr,
                  running != 0 || sessions[bundleID] != nil || (enabled && levels[bundleID, default: 100] != 100) else {
                continue
            }
            var value = grouped[bundleID] ?? (app.name, app.icon, [])
            value.2.append(object)
            grouped[bundleID] = value
        }
        return grouped.map { MixerApplication(id: $0.key, name: $0.value.0,
                                               processIDs: $0.value.2.sorted(), icon: $0.value.1) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func applicationIdentity(for pid: pid_t) -> (id: String, name: String, icon: NSImage?)? {
        // Audio often originates in a browser's nested Helper.app. Use the
        // outermost .app bundle so every helper shares its parent volume.
        var pathBuffer = [CChar](repeating: 0, count: 4096)
        let pathLength = pathBuffer.withUnsafeMutableBufferPointer { buffer in
            proc_pidpath(pid, buffer.baseAddress, UInt32(buffer.count))
        }
        if pathLength > 0 {
            let path = String(cString: pathBuffer)
            if let range = path.range(of: ".app/") {
                let bundlePath = String(path[..<range.upperBound].dropLast())
                if let bundle = Bundle(path: bundlePath), let id = bundle.bundleIdentifier {
                    let running = NSWorkspace.shared.runningApplications.first { $0.bundleIdentifier == id }
                    let name = running?.localizedName ?? bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                        ?? URL(fileURLWithPath: bundlePath).deletingPathExtension().lastPathComponent
                    return (id, name, running?.icon ?? NSWorkspace.shared.icon(forFile: bundlePath))
                }
            }
        }
        guard let running = NSRunningApplication(processIdentifier: pid),
              let id = running.bundleIdentifier else { return nil }
        return (id, running.localizedName ?? id, running.icon)
    }
}
