import Foundation

private let appLogLock = NSLock()
private let appLogURL = URL(fileURLWithPath: "/tmp/displaycontrol.log")
private let appLogArchiveURL = URL(fileURLWithPath: "/tmp/displaycontrol.log.1")
private let maxAppLogBytes: UInt64 = 2 * 1024 * 1024

public func appLog(_ message: String) {
    appLogLock.lock()
    defer { appLogLock.unlock() }
    let line = "[\(Date())] \(message)\n"
    print(line, terminator: "")
    if let data = line.data(using: .utf8) {
        let currentSize = (try? appLogURL.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(UInt64.init) ?? 0
        if currentSize + UInt64(data.count) > maxAppLogBytes {
            try? FileManager.default.removeItem(at: appLogArchiveURL)
            try? FileManager.default.moveItem(at: appLogURL, to: appLogArchiveURL)
        }
        if let handle = try? FileHandle(forWritingTo: appLogURL) {
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
            _ = try? handle.close()
        } else {
            try? data.write(to: appLogURL, options: .atomic)
        }
    }
}
