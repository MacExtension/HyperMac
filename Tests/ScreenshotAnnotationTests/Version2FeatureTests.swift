import Foundation
import Testing
import AudioMixerBridge
import CoreAudio
@testable import HyperMac

struct Version2FeatureTests {
    @Test func fanCurveInterpolatesAndConstrainsPoints() {
        var curve = FanCurve()
        #expect(curve.percent(at: 40) == 25)
        #expect(curve.percent(at: 62.5) == 50)
        #expect(curve.percent(at: 100) == 100)
        curve.movePoint(at: 2, temperature: 100, percent: 150)
        #expect(curve.points[2].temperature == 78)
        #expect(curve.points[2].percent == 100)
        curve.movePoint(at: 2, temperature: 10, percent: -10)
        #expect(curve.points[2].temperature == 57)
        #expect(curve.points[2].percent == 0)
    }

    @Test func clipboardVaultRoundTripsAndAuthenticates() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("HyperMacVaultTest-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let vault = try ClipboardVault(directory: directory)
        let plain = Data("Nội dung nhạy cảm".utf8)
        let cipher = try vault.seal(plain, context: "history")
        #expect(cipher != plain)
        #expect(try vault.open(cipher, context: "history") == plain)
        #expect(throws: (any Error).self) { try vault.open(cipher, context: "image.png") }
        var tampered = cipher
        tampered[tampered.index(before: tampered.endIndex)] ^= 1
        #expect(throws: (any Error).self) { try vault.open(tampered, context: "history") }
        #expect(try ClipboardVault(directory: directory).open(cipher, context: "history") == plain)
        let keyFile = directory.appendingPathComponent("clipboard.key")
        let attributes = try FileManager.default.attributesOfItem(atPath: keyFile.path)
        #expect((attributes[.posixPermissions] as? Int) == 0o600)
    }

    @Test func audioMixerMutesAndLimitsBoostedPeaks() throws {
        let state = try #require(HyperMacMixerCreate())
        defer { HyperMacMixerDestroy(state) }
        var source: [Float] = [0.25, -0.25, 1, -1]
        var output: [Float] = [0, 0, 0, 0]
        source.withUnsafeMutableBytes { sourceBytes in
            output.withUnsafeMutableBytes { outputBytes in
                var inputBuffers = AudioBufferList(mNumberBuffers: 1,
                                                   mBuffers: AudioBuffer(mNumberChannels: 2,
                                                                         mDataByteSize: UInt32(sourceBytes.count),
                                                                         mData: sourceBytes.baseAddress))
                var outputBuffers = AudioBufferList(mNumberBuffers: 1,
                                                    mBuffers: AudioBuffer(mNumberChannels: 2,
                                                                          mDataByteSize: UInt32(outputBytes.count),
                                                                          mData: outputBytes.baseAddress))
                HyperMacMixerSetGain(state, 0)
                HyperMacMixerProcess(state, &inputBuffers, &outputBuffers)
                #expect(outputBytes.bindMemory(to: Float.self).allSatisfy { $0 == 0 })
                HyperMacMixerSetGain(state, 2)
                HyperMacMixerProcess(state, &inputBuffers, &outputBuffers)
            }
        }
        #expect(output[0] > source[0])
        #expect(output[2] <= 1 && output[2] > 0)
        #expect(output[3] >= -1 && output[3] < 0)

        var surround = [Float](repeating: -9, count: 8)
        source.withUnsafeMutableBytes { sourceBytes in
            surround.withUnsafeMutableBytes { outputBytes in
                var inputBuffers = AudioBufferList(mNumberBuffers: 1,
                                                   mBuffers: AudioBuffer(mNumberChannels: 2,
                                                                         mDataByteSize: UInt32(sourceBytes.count),
                                                                         mData: sourceBytes.baseAddress))
                var outputBuffers = AudioBufferList(mNumberBuffers: 1,
                                                    mBuffers: AudioBuffer(mNumberChannels: 4,
                                                                          mDataByteSize: UInt32(outputBytes.count),
                                                                          mData: outputBytes.baseAddress))
                HyperMacMixerSetGain(state, 1)
                HyperMacMixerProcess(state, &inputBuffers, &outputBuffers)
            }
        }
        #expect(surround == [0.25, -0.25, 0, 0, 1, -1, 0, 0])
    }
}
