// SPDX-License-Identifier: GPL-3.0-only
import SwiftUI

// MARK: - Top Tab Navigation Bar

struct TopTabBar: View {
    @Binding var selectedTab: Int

    var body: some View {
        HStack(spacing: 3) {
            tabButton(index: 0, title: tr("Màn hình", "Displays"), icon: "display")
            tabButton(index: 1, title: tr("Phần cứng", "Hardware"), icon: "bolt.batteryblock")
            tabButton(index: 2, title: tr("Phím tắt", "Shortcuts"), icon: "keyboard")
            tabButton(index: 3, title: tr("Dọn dẹp", "Cleaner"), icon: "sparkles")
        }
        .padding(3)
        .background(RoundedRectangle(cornerRadius: Rad.sm).fill(Color.primary.opacity(0.05)))
        .padding(.horizontal, 10)
        .padding(.bottom, 6)
    }

    private func tabButton(index: Int, title: String, icon: String) -> some View {
        Button {
            selectedTab = index
        } label: {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: FS.caption, weight: .semibold))
                Text(title)
                    .font(.system(size: FS.caption, weight: selectedTab == index ? .semibold : .medium))
                    .lineLimit(1)
            }
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity)
            .contentShape(RoundedRectangle(cornerRadius: Rad.sm))
            .background(
                RoundedRectangle(cornerRadius: Rad.sm)
                    .fill(selectedTab == index ? Color.accentColor : Color.clear)
            )
            .foregroundStyle(selectedTab == index ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
    }
}
