// SPDX-License-Identifier: GPL-3.0-only
import SwiftUI

// MARK: - TAB 1: Displays View

struct DisplaysTabView: View {
    @ObservedObject var displayManager: DisplayManager
    @ObservedObject var permissionsManager: PermissionsManager = PermissionsManager.shared
    @ObservedObject var virtualDisplayManager: VirtualDisplayManager = VirtualDisplayManager.shared
    @ObservedObject var launchAtLoginManager: LaunchAtLoginManager = LaunchAtLoginManager.shared

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 8) {
                    // Centralized Permissions Card Hub
                    PermissionsCardView(permissionsManager: permissionsManager)

                    // Virtual Display (Dummy Screen for Remote Desktop / Headless)
                    VirtualDisplayCardView(virtualDisplayManager: virtualDisplayManager)

                    // F1/F2 cursor-based brightness setting
                    HStack(spacing: 8) {
                        Image(systemName: "keyboard")
                            .font(.system(size: FS.body))
                            .foregroundStyle(Color.accentColor)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(tr("F1 / F2 chỉnh màn hình theo con trỏ chuột", "F1 / F2 controls brightness at mouse cursor"))
                                .font(.system(size: FS.label, weight: .medium))
                            Text(tr("Bật để chỉnh cả màn ngoài theo chuột; Tắt để dùng mặc định của macOS", "On: adjust display under cursor; Off: revert to native macOS controls"))
                                .font(.system(size: FS.caption))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Toggle("", isOn: Binding<Bool>(
                            get: { displayManager.isCursorBased },
                            set: { displayManager.isCursorBased = $0 }
                        ))
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                        .labelsHidden()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .cardBackground()

                    // Display List
                    VStack(spacing: 8) {
                        if displayManager.monitors.isEmpty {
                            EmptyStateView()
                        } else {
                            ForEach(displayManager.monitors) { monitor in
                                DisplayCardView(
                                    monitor: monitor,
                                    displayManager: displayManager,
                                    isSelected: displayManager.selectedID == monitor.id
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }

            // Quick Actions Bar (Soft disconnect)
            QuickActionsBar(displayManager: displayManager)
        }
    }
}
