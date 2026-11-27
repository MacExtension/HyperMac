// SPDX-License-Identifier: GPL-3.0-only
import SwiftUI

// MARK: - Footer

/* Hallmark · component: footer-license-pill · genre: macos-native · theme: system-tokens · pre-emit critique: P5 H5 E5 S5 R5 V4 */
struct FooterView: View {
    @ObservedObject var updateManager: UpdateManager

    var body: some View {
        HStack {
            HStack(spacing: 4) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: FS.caption))
                    .foregroundStyle(.secondary)
                Text(tr("GPLv3 • Miễn phí", "GPLv3 • Free"))
                    .font(.system(size: FS.caption))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .help(tr("HyperMac — Copyright © 2026 Nguyễn Khắc Đại • Giấy phép mã nguồn mở GNU GPLv3", "HyperMac — Copyright © 2026 Nguyen Khac Dai • GNU GPLv3 Open Source License"))

            Spacer()

            // Author Link Button
            Button {
                if let url = URL(string: "https://dub.sh/tL0ar4i") {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: FS.caption))
                    Text(tr("Tác giả", "Author"))
                        .font(.system(size: FS.caption, weight: .medium))
                        .lineLimit(1)
                }
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, 6)
                .padding(.vertical, 2.5)
                .background(
                    Capsule().fill(Color.primary.opacity(0.06))
                )
                .foregroundStyle(Color.primary)
            }
            .buttonStyle(.plain)
            .help(tr("Xem trang tác giả", "View author profile"))

        }
        .padding(.horizontal, 14)
        .padding(.vertical, 5)
    }
}
