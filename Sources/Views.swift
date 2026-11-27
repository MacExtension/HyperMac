// SPDX-License-Identifier: GPL-3.0-only
// HyperMac — Copyright (C) 2026 Nguyễn Khắc Đại

import SwiftUI

// MARK: - Main MenuBar View (Tabbed & Organized Architecture)

/* Hallmark · pre-emit critique: P5 H5 E5 S5 R5 V5 */
public struct MainView: View {
    @ObservedObject var displayManager: DisplayManager
    @ObservedObject var batteryManager: BatteryManager = BatteryManager.shared
    @ObservedObject var snapManager: WindowSnapManager = WindowSnapManager.shared
    @ObservedObject var windowManager: WindowManager = WindowManager.shared
    @ObservedObject var clipboardManager: ClipboardManager = ClipboardManager.shared
    @ObservedObject var caffeinateManager: CaffeinateManager = CaffeinateManager.shared
    @ObservedObject var updateManager: UpdateManager = UpdateManager.shared
    @ObservedObject var thermalManager: ThermalManager = ThermalManager.shared
    @ObservedObject var virtualDisplayManager: VirtualDisplayManager = VirtualDisplayManager.shared
    @ObservedObject var launchAtLoginManager: LaunchAtLoginManager = LaunchAtLoginManager.shared
    @ObservedObject var finderCutPasteManager: FinderCutPasteManager = FinderCutPasteManager.shared
    @ObservedObject var cleanerManager: SystemCleanerManager = SystemCleanerManager.shared
    @ObservedObject var permissionsManager: PermissionsManager = PermissionsManager.shared
    @ObservedObject var languageManager: LanguageManager = LanguageManager.shared
    @ObservedObject var screenshotManager: ScreenshotManager = ScreenshotManager.shared

    public init(displayManager: DisplayManager) {
        self.displayManager = displayManager
    }

    public var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Modern Sleek Header Bar
                ModernHeaderBar(
                    batteryManager: batteryManager,
                    caffeinateManager: caffeinateManager,
                    updateManager: updateManager,
                    thermalManager: thermalManager,
                    onSelectThermal: {
                        displayManager.selectedMainTab = 1
                        thermalManager.selectedSection = 1
                    }
                )

                // Top Tab Navigation Bar
                TopTabBar(selectedTab: Binding<Int>(
                    get: { displayManager.selectedMainTab },
                    set: { displayManager.selectedMainTab = $0 }
                ))

                Divider().padding(.horizontal, 10)

                // Active Tab Content View
                Group {
                    switch displayManager.selectedMainTab {
                    case 0:
                        DisplaysTabView(
                            displayManager: displayManager,
                            permissionsManager: permissionsManager,
                            virtualDisplayManager: virtualDisplayManager
                        )
                    case 1:
                        HardwareCareTabView(
                            batteryManager: batteryManager,
                            thermalManager: thermalManager
                        )
                    case 2:
                        ShortcutsTabView(
                            displayManager: displayManager,
                            snapManager: snapManager,
                            windowManager: windowManager,
                            clipboardManager: clipboardManager,
                            caffeinateManager: caffeinateManager,
                            launchAtLoginManager: launchAtLoginManager,
                            finderCutPasteManager: finderCutPasteManager
                        )
                    case 3:
                        CleanerTabView(cleanerManager: cleanerManager)
                    default:
                        DisplaysTabView(
                            displayManager: displayManager,
                            permissionsManager: permissionsManager,
                            virtualDisplayManager: virtualDisplayManager
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                Divider().padding(.horizontal, 10)

                // Minimal Footer
                FooterView(updateManager: updateManager)
            }
            .id(languageManager.currentLanguage)

            // Update Modal Overlay
            if updateManager.showUpdateModal {
                UpdateModalView(updateManager: updateManager)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }


        }
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: updateManager.showUpdateModal)
        .frame(width: 380, height: 570)
        .alert(isPresented: Binding<Bool>(
            get: { displayManager.showAlert },
            set: { displayManager.showAlert = $0 }
        )) {
            Alert(
                title: Text(tr("Thông báo", "Notice")),
                message: Text(displayManager.alertMessage ?? ""),
                dismissButton: .default(Text(tr("Đã hiểu", "OK")))
            )
        }
    }
}

// MARK: - Modern Compact Header Bar

struct ModernHeaderBar: View {
    @ObservedObject var batteryManager: BatteryManager
    @ObservedObject var caffeinateManager: CaffeinateManager
    @ObservedObject var updateManager: UpdateManager
    @ObservedObject var thermalManager: ThermalManager = ThermalManager.shared
    @ObservedObject var languageManager: LanguageManager = LanguageManager.shared
    var onSelectThermal: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 8) {
            // Logo & Title
            HStack(spacing: 6) {
                Image(systemName: "command.circle.fill")
                    .font(.system(size: FS.value, weight: .bold))
                    .foregroundStyle(Color.accentColor)

                Text("HyperMac")
                    .font(.system(size: FS.title, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .layoutPriority(2)

                // Version Badge (Clickable to check for update)
                Button {
                    updateManager.checkForUpdates(silent: false)
                } label: {
                    HStack(spacing: 3) {
                        Text("v\(UpdateManager.currentVersion)")
                            .font(.system(size: FS.caption, weight: .semibold))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                        if updateManager.hasNewUpdate {
                            Circle()
                                .fill(Tone.good)
                                .frame(width: 5, height: 5)
                        }
                    }
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        Capsule().fill(
                            updateManager.hasNewUpdate
                            ? Tone.good.opacity(0.10)
                            : Color.primary.opacity(0.08)
                        )
                    )
                    .foregroundStyle(updateManager.hasNewUpdate ? Tone.good : Color.secondary)
                }
                .buttonStyle(.plain)
                .help(updateManager.hasNewUpdate ? tr("Có build local mới! Bấm để cập nhật", "A new local build is ready. Click to update") : tr("Kiểm tra bản build local", "Check the local build"))

                // Language Switcher Badge (vi / en) — Directly to the right of version badge
                Button {
                    languageManager.promptLanguageSwitch()
                } label: {
                    Text(languageManager.currentLanguage == .vi ? "vi" : "en")
                        .font(.system(size: FS.caption, weight: .semibold))
                        .foregroundStyle(Color.primary.opacity(0.85))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule().fill(Color.primary.opacity(0.08))
                        )
                }
                .buttonStyle(.plain)
                .fixedSize()
                .help(languageManager.currentLanguage == .vi ? "Bấm để chuyển sang Tiếng Anh (English)" : "Click to switch to Vietnamese (Tiếng Việt)")
            }

            Spacer()

            // Live Thermal Chip
            if thermalManager.cpuAvgTemp > 0 {
                Button {
                    onSelectThermal?()
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "thermometer.medium")
                            .font(.system(size: FS.caption))
                            .foregroundStyle(headerTempColor)
                        Text(String(format: "%.0f°C", thermalManager.displayTemp))
                            .font(.system(size: FS.caption, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)
                    }
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2.5)
                    .background(Capsule().fill(Color.primary.opacity(0.06)))
                }
                .buttonStyle(.plain)
                .help(tr("CPU trung bình: \(String(format: "%.1f°C", thermalManager.displayTemp)) • Nhân nóng nhất: \(String(format: "%.1f°C", thermalManager.cpuPeakTemp)). Bấm để mở kiểm soát nhiệt & quạt", "CPU average: \(String(format: "%.1f°C", thermalManager.displayTemp)) • Hottest core: \(String(format: "%.1f°C", thermalManager.cpuPeakTemp)). Click for thermals & fan controls"))
            }

            // Live Status Chip
            HStack(spacing: 4) {
                Image(systemName: statusIcon)
                    .font(.system(size: FS.caption, weight: .semibold))
                    .foregroundStyle(statusColor)

                Text(statusText)
                    .font(.system(size: FS.caption, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color.primary.opacity(0.06)))

            // Quit Button
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power")
                    .font(.system(size: FS.label, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(5)
                    .background(Circle().fill(Color.primary.opacity(0.05)))
            }
            .buttonStyle(.plain)
            .help(tr("Thoát HyperMac", "Quit HyperMac"))
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }

    private var headerTempColor: Color {
        switch thermalManager.thermalLevel {
        case .cool: return Tone.good
        case .warm: return .orange
        case .hot:  return .red
        }
    }

    private var statusColor: Color {
        if batteryManager.isProtectionEnabled && batteryManager.isBypassActive && batteryManager.isPluggedIn {
            return .accentColor
        } else if batteryManager.isCharging || (batteryManager.isPluggedIn && batteryManager.wattage > 0.05 && batteryManager.amperage > 0) {
            return Tone.good
        } else if batteryManager.isPluggedIn {
            return .secondary
        } else {
            return batteryManager.currentLevel <= 20 ? Tone.bad : .secondary
        }
    }

    private var statusIcon: String {
        if batteryManager.isProtectionEnabled && batteryManager.isBypassActive && batteryManager.isPluggedIn {
            return "lock.shield.fill"
        } else if batteryManager.isCharging || (batteryManager.isPluggedIn && batteryManager.wattage > 0.05 && batteryManager.amperage > 0) {
            return "bolt.fill"
        } else if batteryManager.isPluggedIn {
            return "powerplug.fill"
        } else {
            return "battery.50"
        }
    }

    private var statusText: String {
        if batteryManager.isProtectionEnabled && batteryManager.isBypassActive && batteryManager.isPluggedIn {
            return "\(batteryManager.chargeLimit)% Bypass"
        } else {
            return "\(batteryManager.currentLevel)%"
        }
    }
}

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

// MARK: - TAB 0: Hardware Care, Battery & Thermal View

struct HardwareCareTabView: View {
    @ObservedObject var batteryManager: BatteryManager
    @ObservedObject var thermalManager: ThermalManager = ThermalManager.shared
    @ObservedObject var systemMonitor: SystemMonitorManager = SystemMonitorManager.shared

    var body: some View {
        VStack(spacing: 6) {
            // Segment Switcher: Pin & Nguồn vs Tản nhiệt & Quạt
            HStack(spacing: 4) {
                sectionButton(
                    index: 0,
                    title: tr("Pin & Nguồn SMC", "Battery & Power SMC"),
                    icon: "bolt.shield.fill"
                )
                sectionButton(
                    index: 1,
                    title: tr("Nhiệt độ & Cảm biến", "Thermals & Sensors"),
                    icon: "thermometer.sun.fill",
                    badge: thermalManager.cpuAvgTemp > 0 ? String(format: "%.0f°C", thermalManager.displayTemp) : nil
                )
            }
            .padding(3)
            .background(RoundedRectangle(cornerRadius: Rad.sm).fill(Color.primary.opacity(0.04)))
            .padding(.horizontal, 12)
            .padding(.top, 4)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 8) {
                    // Cuộn cùng nội dung phần cứng để card không đứng ngoài vùng cuộn.
                    FileTransferSpeedCard()

                    if thermalManager.selectedSection == 0 {
                        BatteryCardView(batteryManager: batteryManager, onSelectThermalSection: {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                thermalManager.selectedSection = 1
                            }
                        })
                    } else {
                        ThermalAndFanCardView(thermalManager: thermalManager, systemMonitor: systemMonitor)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
            }
        }
    }

    private func sectionButton(index: Int, title: String, icon: String, badge: String? = nil) -> some View {
        Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                thermalManager.selectedSection = index
            }
        } label: {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: FS.caption, weight: thermalManager.selectedSection == index ? .semibold : .medium))

                if let badge = badge, !badge.isEmpty {
                    Text(badge)
                        .font(.system(size: FS.caption, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(thermalManager.selectedSection == index ? Color.white.opacity(0.25) : Color.primary.opacity(0.08)))
                }
            }
            .padding(.vertical, 4.5)
            .frame(maxWidth: .infinity)
            .contentShape(RoundedRectangle(cornerRadius: Rad.sm))
            .background(
                RoundedRectangle(cornerRadius: Rad.sm)
                    .fill(thermalManager.selectedSection == index ? Color.accentColor : Color.clear)
            )
            .foregroundStyle(thermalManager.selectedSection == index ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
    }
}

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
