// SPDX-License-Identifier: GPL-3.0-only
import SwiftUI

// MARK: - Display Card View

struct DisplayCardView: View {
    var monitor: DisplayInfo
    @ObservedObject var displayManager: DisplayManager
    var isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header Row
            HStack(spacing: 6) {
                Image(systemName: monitor.isBuiltIn ? "laptopcomputer" : "display")
                    .font(.system(size: FS.body))
                    .foregroundStyle(monitor.isConnected ? Color.accentColor : Color.secondary)

                VStack(alignment: .leading, spacing: 1) {
                    Text(monitor.name)
                        .font(.system(size: FS.label, weight: .semibold))
                        .lineLimit(1)
                    Text("\(monitor.resolution) • \(monitor.isBuiltIn ? tr("Màn hình chính", "Built-in Display") : tr("Màn hình ngoài", "External Display"))")
                        .font(.system(size: FS.caption))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("\(Int(round(monitor.brightness * 100)))%")
                    .font(.system(size: FS.body, weight: .semibold, design: .rounded))
                    .foregroundStyle(monitor.isConnected ? Color.primary : Color.secondary)
            }

            if monitor.isConnected {
                // Brightness Slider
                Slider(
                    value: Binding<Double>(
                        get: { monitor.brightness },
                        set: { displayManager.setBrightness($0, for: monitor) }
                    ),
                    in: 0...1
                )
                .controlSize(.small)

                DisplayModeControls(displayID: monitor.id, manager: .shared) {
                    // Disconnect toggle
                    Button {
                        displayManager.toggleConnection(for: monitor)
                    } label: {
                        Text(monitor.isBuiltIn ? tr("Tắt màn", "Turn Off") : tr("Ngắt mềm", "Disconnect"))
                            .font(.system(size: FS.caption, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .disabled(monitor.isBuiltIn && !displayManager.canDisconnect(monitor))
                }
            } else {
                HStack {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(Color.orange.opacity(0.8))
                            .frame(width: 5, height: 5)
                        Text(tr("Đang ngắt mềm (Đã tắt)", "Disconnected (Turned Off)"))
                            .font(.system(size: FS.caption, weight: .medium))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        displayManager.toggleConnection(for: monitor)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "power")
                                .font(.system(size: FS.caption, weight: .semibold))
                            Text(tr("Bật lại", "Turn On"))
                                .font(.system(size: FS.caption, weight: .semibold))
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3.5)
                        .background(Capsule().fill(Color.accentColor))
                        .foregroundStyle(Color.white)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 2)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: Rad.sm)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: Rad.sm)
                        .stroke(isSelected ? Color.accentColor.opacity(0.6) : Color.primary.opacity(0.06), lineWidth: 1)
                )
        )
    }
}
