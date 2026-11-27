// SPDX-License-Identifier: GPL-3.0-only
import SwiftUI

// MARK: - Caffeinate (Anti-Sleep) Card View

struct CaffeinateCardView: View {
    @AppStorage("caffeinate_details_expanded") private var showDetails = false
    @ObservedObject var caffeinateManager: CaffeinateManager

    var body: some View {
        VStack(spacing: 8) {
            // Main Row: Icon, Title, Badge, and Switch
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: Rad.sm)
                        .fill(Color.primary.opacity(0.06))
                        .frame(width: 28, height: 28)

                    Image(systemName: "cup.and.saucer.fill")
                        .font(.system(size: FS.title, weight: .semibold))
                        .foregroundStyle(caffeinateManager.isActive ? Color.accentColor : Color.secondary)
                }

                VStack(alignment: .leading, spacing: 1.5) {
                    HStack(spacing: 6) {
                        Text(tr("Chống sleep màn", "Keep Screen Awake"))
                            .font(.system(size: FS.body, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)

                        if caffeinateManager.isActive {
                            HStack(spacing: 3) {
                                Circle()
                                    .fill(Color.accentColor)
                                    .frame(width: 5, height: 5)
                                Text(caffeinateManager.remainingFormatted)
                                    .font(.system(size: FS.caption, weight: .medium, design: .monospaced))
                                    .lineLimit(1)
                                    .fixedSize()
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1.5)
                            .background(Capsule().fill(Color.primary.opacity(0.06)))
                            .foregroundStyle(.secondary)
                        }
                    }

                    Text(tr("Giữ màn hình luôn sáng như 'caffeinate -d' trong Terminal", "Prevents display sleep, similar to 'caffeinate -d' in Terminal"))
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
                Toggle("", isOn: Binding<Bool>(
                    get: { caffeinateManager.isActive },
                    set: { _ in caffeinateManager.toggle() }
                ))
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
            }

            // Collapsing details leaves the active assertion and timer unchanged.
            if showDetails {
            HStack(spacing: 6) {
                ForEach(CaffeinateDuration.allCases) { duration in
                    Button {
                        caffeinateManager.setDuration(duration)
                    } label: {
                        Text(duration.title)
                            .font(.system(size: FS.caption, weight: caffeinateManager.selectedDuration == duration ? .semibold : .medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3.5)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: Rad.sm)
                                    .fill(caffeinateManager.selectedDuration == duration
                                          ? Color.accentColor
                                          : Color.primary.opacity(0.05))
                            )
                            .foregroundStyle(
                                caffeinateManager.selectedDuration == duration
                                ? Color.white
                                : Color.primary
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            }
        }
        .padding(10)
        .cardBackground()
    }
}

// Hallmark · component: virtual display presets · genre: modern-minimal · theme: HyperMac native
// Hallmark · pre-emit critique: P4 H4 E4 S5 R5 V4
// Existing FS/Rad tokens, native controls; component scope, no page macrostructure.
