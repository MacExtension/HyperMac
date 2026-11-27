// SPDX-License-Identifier: GPL-3.0-only
import SwiftUI

// MARK: - Quick Actions Bar

struct QuickActionsBar: View {
    @ObservedObject var displayManager: DisplayManager

    var body: some View {
        HStack(spacing: 8) {
            if let ext = displayManager.monitors.first(where: { !$0.isBuiltIn }) {
                Button {
                    displayManager.toggleConnection(for: ext)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: ext.isConnected ? "display.slash" : "display")
                            .font(.system(size: FS.caption))
                        Text(ext.isConnected ? tr("Ngắt màn ngoài", "Disconnect External") : tr("Bật màn ngoài", "Connect External"))
                            .font(.system(size: FS.caption, weight: ext.isConnected ? .regular : .bold))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: Rad.sm).fill(Color(nsColor: .controlBackgroundColor)))
                    .foregroundStyle(ext.isConnected ? Color.primary : Color.accentColor)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            if displayManager.monitors.contains(where: { !$0.isConnected }) {
                Button {
                    displayManager.connectAllDisplays()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: FS.caption))
                        Text(tr("Bật tất cả màn hình", "Turn On All Displays"))
                            .font(.system(size: FS.caption, weight: .semibold))
                    }
                    .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
    }
}
