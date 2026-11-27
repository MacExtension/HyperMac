// SPDX-License-Identifier: GPL-3.0-only
import SwiftUI

// MARK: - Menu Bar Drawer (Ngăn kéo gom ứng dụng Status Bar) Card View

// Hallmark · native settings component · existing Theme tokens
struct MenuBarHiderCardView: View {
    @ObservedObject private var shortcuts = ShortcutManager.shared

    @AppStorage("menubar_drawer_details_expanded") private var showDetails = false
    @ObservedObject var manager = MenuBarHiderManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "menubar.rectangle")
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 3) {
                    Text(tr("Ngăn kéo Menu Bar", "Menu Bar Drawer"))
                        .font(.system(size: FS.label, weight: .semibold))
                    Text(tr("Truy cập các mục Menu Bar trong một bảng riêng.", "Access menu bar items in a separate panel."))
                        .font(.system(size: FS.caption))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) { showDetails.toggle() }
                } label: {
                    Image(systemName: showDetails ? "chevron.up" : "chevron.down")
                        .font(.system(size: FS.body, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(6)
                        .background(Circle().fill(Color.primary.opacity(0.04)))
                }
                .buttonStyle(.plain)
                .help(showDetails ? tr("Ẩn chi tiết", "Hide details") : tr("Hiện chi tiết", "Show details"))
                .accessibilityLabel(showDetails ? tr("Ẩn chi tiết", "Hide details") : tr("Hiện chi tiết", "Show details"))
                Toggle(tr("Bật ngăn kéo", "Enable drawer"), isOn: $manager.isEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.mini)
            }
            if showDetails {
                Divider()
                HStack {
                    Button { manager.toggle() } label: {
                        Label(manager.isExpanded ? tr("Đóng ngăn kéo", "Close drawer") : tr("Mở ngăn kéo", "Open drawer"), systemImage: "tray")
                    }
                    .controlSize(.small)
                    .disabled(!manager.isEnabled)
                    Spacer()
                    Text(shortcuts.primaryTitle(.menuBar))
                        .font(.system(size: FS.caption, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Text(tr("Dùng phím đã gán để mở bảng ứng dụng Menu Bar. Bấm ứng dụng để mở menu thật; kéo ☰ để đổi thứ tự icon trên thanh bar.", "Use your assigned shortcut to open menu bar apps. Click an app for its real menu; drag ☰ to reorder icons on the menu bar."))
                    .font(.system(size: FS.caption))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .cardBackground()
    }
}
