// SPDX-License-Identifier: GPL-3.0-only
import SwiftUI

// MARK: - Empty State

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "display.trianglebadge.exclamationmark")
                .font(.system(size: FS.display))
                .foregroundStyle(.tertiary)
            Text(tr("Không tìm thấy màn hình nào", "No displays detected"))
                .font(.system(size: FS.label))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}
