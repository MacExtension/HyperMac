// SPDX-License-Identifier: GPL-3.0-only
import SwiftUI

// MARK: - Virtual Display (Dummy Screen) Card View

struct VirtualDisplayCardView: View {
    @ObservedObject var virtualDisplayManager: VirtualDisplayManager = VirtualDisplayManager.shared
    @ObservedObject var launchAtLoginManager: LaunchAtLoginManager = LaunchAtLoginManager.shared

    var body: some View {
        VStack(spacing: 8) {
            // Main Row: Icon, Title, Badge, Settings button, and Switch
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: Rad.sm)
                        .fill(virtualDisplayManager.isVirtualDisplayActive ? Color.accentColor.opacity(0.10) : Color.primary.opacity(0.06))
                        .frame(width: 28, height: 28)

                    Image(systemName: "display.2")
                        .font(.system(size: FS.title, weight: .semibold))
                        .foregroundStyle(virtualDisplayManager.isVirtualDisplayActive ? Color.accentColor : Color.secondary)
                }

                VStack(alignment: .leading, spacing: 1.5) {
                    HStack(spacing: 6) {
                        Text(tr("Màn hình ảo (Dummy Display)", "Virtual Display (Dummy Display)"))
                            .font(.system(size: FS.body, weight: .semibold))

                        if virtualDisplayManager.isVirtualDisplayActive {
                            HStack(spacing: 3) {
                                Circle()
                                    .fill(Color.accentColor)
                                    .frame(width: 5, height: 5)
                                Text("\(virtualDisplayManager.currentResolution.width)×\(virtualDisplayManager.currentResolution.height)")
                                    .font(.system(size: FS.caption, weight: .semibold, design: .monospaced))
                            }
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(Capsule().fill(Color.accentColor.opacity(0.10)))
                            .foregroundStyle(Color.accentColor)
                        }
                    }

                    Text(virtualDisplayManager.isVirtualDisplayActive
                         ? tr("Đang phát ảo · Tăng tốc GPU cho Parsec / TeamViewer", "Virtual screen active · GPU accelerated for Parsec / TeamViewer")
                         : tr("Tạo màn hình ảo cho máy gập, Mac mini headless", "Create dummy display for clamshell mode or headless Mac mini"))
                        .font(.system(size: FS.caption))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Expand / Collapse Settings Toggle Button
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        virtualDisplayManager.isCardExpanded.toggle()
                    }
                } label: {
                    Image(systemName: virtualDisplayManager.isCardExpanded ? "chevron.up.circle.fill" : "gearshape")
                        .font(.system(size: FS.body))
                        .foregroundStyle(virtualDisplayManager.isCardExpanded ? Color.accentColor : Color.secondary)
                        .padding(4)
                        .background(Circle().fill(Color.primary.opacity(0.04)))
                }
                .buttonStyle(.plain)
                .help(virtualDisplayManager.isCardExpanded ? tr("Thu gọn tùy chọn", "Collapse options") : tr("Tùy chỉnh độ phân giải, HiDPI, Bảo mật", "Customize resolution, HiDPI, Privacy"))

                Toggle("", isOn: Binding<Bool>(
                    get: { virtualDisplayManager.isVirtualDisplayActive },
                    set: { _ in
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            virtualDisplayManager.toggleVirtualDisplay()
                        }
                    }
                ))
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
            }

            // Expanded Settings Panel
            if virtualDisplayManager.isCardExpanded || virtualDisplayManager.isVirtualDisplayActive {
                VStack(spacing: 7) {
                    Divider().opacity(0.4)

                    // Resolution Preset Header
                    HStack {
                        Text(tr("ĐỘ PHÂN GIẢI MÀN HÌNH ẢO", "VIRTUAL DISPLAY RESOLUTION"))
                            .font(.system(size: FS.caption, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(virtualDisplayManager.currentResolution.width)×\(virtualDisplayManager.currentResolution.height) @ \(Int(virtualDisplayManager.currentResolution.refreshRate))Hz")
                            .font(.system(size: FS.caption, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Color.accentColor)
                    }

                    // Resolution Preset Grid (2 columns)
                    resolutionGrid

                    if virtualDisplayManager.currentResolution.isUltrawide {
                        Text(tr("Mirror: trong Cài đặt hệ thống → Màn hình, chọn Tối ưu hóa cho HyperMac Virtual Display.",
                                "Mirroring: in System Settings → Displays, choose Optimize for HyperMac Virtual Display."))
                            .font(.system(size: FS.caption))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if !virtualDisplayManager.isVirtualDisplayActive {
                        Text(virtualDisplayManager.statusMessage)
                            .font(.system(size: FS.caption))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // Bottom Quick Options: HiDPI toggle & Blackout Screen (Privacy)
                    quickOptionsRow
                }
            }
        }
        .padding(10)
        .cardBackground()
    }

    private var resolutionGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 5), GridItem(.flexible(), spacing: 5)], spacing: 5) {
            ForEach(Array(virtualDisplayManager.resolutions.enumerated()), id: \.offset) { index, res in
                Button {
                    virtualDisplayManager.selectedResolutionIndex = index
                } label: {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(virtualDisplayManager.selectedResolutionIndex == index ? Color.accentColor : Color.secondary.opacity(0.3))
                            .frame(width: 4.5, height: 4.5)

                        Text(res.isUltrawide ? "\(res.width) × \(res.height) UW" : res.name)
                            .font(.system(size: FS.caption, weight: virtualDisplayManager.selectedResolutionIndex == index ? .semibold : .medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4.5)
                    .background(
                        RoundedRectangle(cornerRadius: Rad.sm)
                            .fill(virtualDisplayManager.selectedResolutionIndex == index
                                  ? Color.accentColor.opacity(0.10)
                                  : Color.primary.opacity(0.04))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Rad.sm)
                            .stroke(virtualDisplayManager.selectedResolutionIndex == index
                                    ? Color.accentColor.opacity(0.5)
                                    : Color.clear, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .help("\(res.name) · \(Int(res.refreshRate)) Hz")
                .accessibilityLabel("\(res.name), \(Int(res.refreshRate)) Hz")
                .accessibilityAddTraits(virtualDisplayManager.selectedResolutionIndex == index ? .isSelected : [])
            }
        }
    }

    private var quickOptionsRow: some View {
        HStack(spacing: 6) {
            // HiDPI toggle
            Button {
                virtualDisplayManager.isHiDPIEnabled.toggle()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: virtualDisplayManager.isHiDPIEnabled ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: FS.caption))
                        .foregroundStyle(virtualDisplayManager.isHiDPIEnabled ? Color.accentColor : Color.secondary)
                    Text("Retina (HiDPI)")
                        .font(.system(size: FS.caption, weight: .medium))
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 3.5)
                .background(RoundedRectangle(cornerRadius: Rad.sm).fill(Color.primary.opacity(0.04)))
            }
            .buttonStyle(.plain)
            .help(tr("HiDPI giúp hiển thị văn bản và icon siêu mịn chuẩn Retina", "HiDPI renders razor-sharp Retina text and icons"))

            Spacer()

            // Blackout Primary Display for Remote Privacy
            Button {
                virtualDisplayManager.toggleBlackoutPrimaryScreen()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: virtualDisplayManager.isBlackoutPrimaryActive ? "eye.slash.fill" : "eye.slash")
                        .font(.system(size: FS.caption))
                        .foregroundStyle(virtualDisplayManager.isBlackoutPrimaryActive ? Color.orange : Color.secondary)
                    Text(virtualDisplayManager.isBlackoutPrimaryActive ? tr("Đang tắt màn thật", "Primary Screen Off") : tr("Tắt tối màn thật", "Blackout Primary"))
                        .font(.system(size: FS.caption, weight: .medium))
                        .foregroundStyle(virtualDisplayManager.isBlackoutPrimaryActive ? Color.orange : Color.primary)
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 3.5)
                .background(
                    RoundedRectangle(cornerRadius: Rad.sm)
                        .fill(virtualDisplayManager.isBlackoutPrimaryActive ? Color.orange.opacity(0.10) : Color.primary.opacity(0.04))
                )
            }
            .buttonStyle(.plain)
            .help(tr("Tắt tối đen màn hình máy thật để chống nhìn trộm khi bạn điều khiển từ xa qua Parsec / TeamViewer", "Turn primary screen pitch black to prevent shoulder-surfing during remote sessions"))
        }
        .padding(.top, 2)
    }
}
