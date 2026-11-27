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

// MARK: - TAB 2: Shortcuts & Window Controls View

struct ShortcutsTabView: View {
    @ObservedObject private var shortcuts = ShortcutManager.shared
    @ObservedObject var displayManager: DisplayManager
    @ObservedObject var snapManager: WindowSnapManager
    @ObservedObject var windowManager: WindowManager
    @ObservedObject var clipboardManager: ClipboardManager
    @ObservedObject var caffeinateManager: CaffeinateManager = CaffeinateManager.shared
    @ObservedObject var launchAtLoginManager: LaunchAtLoginManager = LaunchAtLoginManager.shared
    @ObservedObject var finderCutPasteManager: FinderCutPasteManager = FinderCutPasteManager.shared
    @ObservedObject var screenshotManager: ScreenshotManager = ScreenshotManager.shared

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 10) {
                ShortcutSettingsCard()

                // Accessibility Alert if not granted
                if !displayManager.hasAccessibility {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.secondary)
                            .font(.system(size: FS.subhead))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(tr("Cần cấp quyền Trợ năng (Accessibility)", "Accessibility Permission Required"))
                                .font(.system(size: FS.label, weight: .semibold))
                            Text(tr("Bật HyperMac trong Cài đặt hệ thống để phím tắt hoạt động.", "Enable HyperMac in System Settings to allow shortcut interception."))
                                .font(.system(size: FS.caption))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button(tr("Cấp quyền", "Grant")) {
                            displayManager.requestAccessibility()
                        }
                        .font(.system(size: FS.caption, weight: .semibold))
                        .controlSize(.mini)
                    }
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: Rad.sm).fill(Color.orange.opacity(0.12)))
                }

                // Launch at Login Card
                HStack(spacing: 8) {
                    Image(systemName: "power.circle.fill")
                        .font(.system(size: FS.title))
                        .foregroundStyle(Color.accentColor)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(tr("Khởi động cùng macOS", "Launch at Login"))
                            .font(.system(size: FS.label, weight: .semibold))
                        Text(tr("Tự động chạy HyperMac ngay khi đăng nhập vào máy Mac", "Automatically start HyperMac upon logging in"))
                            .font(.system(size: FS.caption))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Toggle("", isOn: Binding<Bool>(
                        get: { launchAtLoginManager.isEnabled },
                        set: { launchAtLoginManager.setEnabled($0) }
                    ))
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .labelsHidden()
                }
                .padding(10)
                .cardBackground()

                // Caffeinate (Anti-Sleep) Control Card
                CaffeinateCardView(caffeinateManager: caffeinateManager)

                // Menu Bar Hider (Gom gọn thanh Status Bar) Card
                MenuBarHiderCardView()

                // Finder Cut & Paste (Windows-style ⌘X ➔ ⌘V) Card
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "scissors")
                            .font(.system(size: FS.body, weight: .semibold))
                            .foregroundStyle(Color.accentColor)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(tr("Cắt & Dán tệp trong Finder (⌘X ➔ ⌘V)", "Finder Cut & Paste (⌘X ➔ ⌘V)"))
                                .font(.system(size: FS.label, weight: .semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                            Text(tr("Cắt và di chuyển tệp như trên Windows (bấm ⌘X để cắt, ⌘V để di chuyển)", "Cut & move files Windows-style (press ⌘X to cut, ⌘V to move)"))
                                .font(.system(size: FS.caption))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if finderCutPasteManager.isEnabled {
                            Button {
                                withAnimation(.easeInOut(duration: 0.18)) {
                                    finderCutPasteManager.isDetailsExpanded.toggle()
                                }
                            } label: {
                                Image(systemName: finderCutPasteManager.isDetailsExpanded ? "chevron.up" : "chevron.down")
                                    .font(.system(size: FS.caption, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 20, height: 20)
                                    .background(Circle().fill(Color.primary.opacity(finderCutPasteManager.isDetailsExpanded ? 0.08 : 0.04)))
                            }
                            .buttonStyle(.plain)
                            .help(finderCutPasteManager.isDetailsExpanded ? tr("Thu gọn chi tiết", "Collapse details") : tr("Xem chi tiết phím tắt", "View shortcut details"))
                        }

                        Toggle("", isOn: Binding<Bool>(
                            get: { finderCutPasteManager.isEnabled },
                            set: { finderCutPasteManager.isEnabled = $0 }
                        ))
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                        .labelsHidden()
                    }

                    if finderCutPasteManager.isEnabled && finderCutPasteManager.isDetailsExpanded {
                        Divider().opacity(0.35)

                        VStack(spacing: 5) {
                            ShortcutGrid {
                                shortcutPill(key: "⌘ + X", desc: tr("Cắt tệp / thư mục", "Cut file / folder"))
                                shortcutPill(key: "⌘ + V", desc: tr("Di chuyển đến đây", "Move here"))
                                shortcutPill(key: "esc", desc: tr("Huỷ cắt", "Cancel cut"))
                                shortcutPill(key: "⌘ + C", desc: tr("Chuyển sang Copy", "Switch to Copy"))
                            }

                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: FS.caption))
                                    .foregroundStyle(.secondary)
                                Text(tr("Tự động nhận diện khi đổi tên hoặc tìm kiếm: vẫn cắt văn bản bình thường.", "Smart context: text cutting remains untouched while renaming or searching."))
                                    .font(.system(size: FS.caption))
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                            .padding(.top, 2)
                        }
                    }
                }
                .padding(10)
                .cardBackground()

                // AltTab Card
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "macwindow.on.rectangle")
                            .font(.system(size: FS.body))
                            .foregroundStyle(Color.accentColor)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(tr("Chuyển cửa sổ", "Window Switcher"))
                                .font(.system(size: FS.label, weight: .semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                            Text(tr("Thay thế AltTab với live preview độc lập & chuẩn MRU", "AltTab replacement with live preview & MRU order"))
                                .font(.system(size: FS.caption))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if windowManager.isAltTabEnabled {
                            Button {
                                withAnimation(.easeInOut(duration: 0.18)) {
                                    windowManager.isDetailsExpanded.toggle()
                                }
                            } label: {
                                Image(systemName: windowManager.isDetailsExpanded ? "chevron.up" : "chevron.down")
                                    .font(.system(size: FS.caption, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 20, height: 20)
                                    .background(Circle().fill(Color.primary.opacity(windowManager.isDetailsExpanded ? 0.08 : 0.04)))
                            }
                            .buttonStyle(.plain)
                            .help(windowManager.isDetailsExpanded ? tr("Thu gọn chi tiết", "Collapse details") : tr("Xem chi tiết phím tắt", "View shortcut details"))
                        }

                        Toggle("", isOn: Binding<Bool>(
                            get: { windowManager.isAltTabEnabled },
                            set: { windowManager.isAltTabEnabled = $0 }
                        ))
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                        .labelsHidden()
                    }

                    if windowManager.isAltTabEnabled && windowManager.isDetailsExpanded {
                        Divider().opacity(0.35)

                        // Multi-monitor screen isolation toggle
                        HStack(spacing: 6) {
                            Image(systemName: "display.2")
                                .font(.system(size: FS.caption))
                                .foregroundStyle(.secondary)

                            VStack(alignment: .leading, spacing: 1) {
                                Text(tr("Chỉ hiện cửa sổ trên màn hình hiện tại", "Only show windows on current display"))
                                    .font(.system(size: FS.caption, weight: .semibold))
                                Text(tr("Lọc riêng các cửa sổ thuộc màn hình con trỏ chuột đang đứng", "Filter windows belonging to the display where cursor is located"))
                                    .font(.system(size: FS.caption))
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Toggle("", isOn: Binding<Bool>(
                                get: { windowManager.showOnlyCurrentScreenWindows },
                                set: { windowManager.showOnlyCurrentScreenWindows = $0 }
                            ))
                            .toggleStyle(.switch)
                            .controlSize(.mini)
                            .labelsHidden()
                        }
                        .padding(.vertical, 2)

                        // AltTab Shortcuts Guide
                        ShortcutGrid {
                            shortcutPill(key: shortcuts.primaryTitle(.switchWindows), desc: tr("Chuyển tiếp", "Forward"))
                            shortcutPill(key: "Shift + " + shortcuts.primaryTitle(.switchWindows), desc: tr("Lùi lại", "Backward"))
                            shortcutPill(key: "↑↓←→", desc: tr("Duyệt lưới", "Grid nav"))
                            shortcutPill(key: "W", desc: tr("Đóng", "Close"))
                            shortcutPill(key: "Q", desc: tr("Thoát App", "Quit App"))
                        }

                        if !windowManager.hasScreenRecording {
                            HStack(spacing: 6) {
                                Image(systemName: "camera.viewfinder")
                                    .font(.system(size: FS.caption))
                                    .foregroundStyle(.secondary)
                                Text(tr("Cần quyền Ghi màn hình để hiện ảnh chụp cửa sổ thực tế.", "Screen Recording permission needed for actual window snapshots."))
                                    .font(.system(size: FS.caption))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Button(tr("Cấp quyền", "Grant")) {
                                    windowManager.requestScreenRecordingPermission()
                                }
                                .font(.system(size: FS.caption, weight: .semibold))
                                .controlSize(.mini)
                            }
                            .padding(5)
                            .background(RoundedRectangle(cornerRadius: Rad.sm).fill(Color.accentColor.opacity(0.08)))
                        }
                    }
                }
                .padding(10)
                .cardBackground()

                // Window Snapping (Rectangle) Card
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "rectangle.split.2x1")
                            .font(.system(size: FS.body))
                            .foregroundStyle(Color.accentColor)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(tr("Chia cửa sổ", "Window Snapping"))
                                .font(.system(size: FS.label, weight: .semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                            Text(tr("Bố trí cửa sổ nhanh với độ trễ 0ms", "Instant window positioning with 0ms latency"))
                                .font(.system(size: FS.caption))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if snapManager.isSnapEnabled {
                            Button {
                                withAnimation(.easeInOut(duration: 0.18)) {
                                    snapManager.isDetailsExpanded.toggle()
                                }
                            } label: {
                                Image(systemName: snapManager.isDetailsExpanded ? "chevron.up" : "chevron.down")
                                    .font(.system(size: FS.caption, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 20, height: 20)
                                    .background(Circle().fill(Color.primary.opacity(snapManager.isDetailsExpanded ? 0.08 : 0.04)))
                            }
                            .buttonStyle(.plain)
                            .help(snapManager.isDetailsExpanded ? tr("Thu gọn chi tiết", "Collapse details") : tr("Xem chi tiết", "View details"))
                        }

                        Toggle("", isOn: Binding<Bool>(
                            get: { snapManager.isSnapEnabled },
                            set: { snapManager.isSnapEnabled = $0 }
                        ))
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                        .labelsHidden()
                    }

                    if snapManager.isSnapEnabled && snapManager.isDetailsExpanded {
                        Divider().opacity(0.35)
                        WindowDisplayTransferModeView(settings: .shared)
                        Divider().opacity(0.35)

                        VStack(spacing: 5) {
                            ShortcutGrid {
                                shortcutPill(key: shortcuts.primaryTitle(.leftHalf), desc: tr("Nửa trái", "Left Half"))
                                shortcutPill(key: shortcuts.primaryTitle(.rightHalf), desc: tr("Nửa phải", "Right Half"))
                                shortcutPill(key: shortcuts.primaryTitle(.topHalf), desc: tr("Nửa trên", "Top Half"))
                                shortcutPill(key: shortcuts.primaryTitle(.bottomHalf), desc: tr("Nửa dưới", "Bottom Half"))
                            }
                            ShortcutGrid {
                                shortcutPill(key: shortcuts.primaryTitle(.maximize), desc: tr("Toàn màn hình", "Maximize"))
                                shortcutPill(key: shortcuts.primaryTitle(.center), desc: tr("Căn giữa", "Center"))
                                shortcutPill(key: shortcuts.primaryTitle(.restoreWindow), desc: tr("Khôi phục kích thước", "Restore size"))
                                shortcutPill(key: shortcuts.primaryTitle(.topLeft), desc: tr("Góc trên trái", "Top left"))
                            }
                            ShortcutGrid {
                                shortcutPill(key: shortcuts.primaryTitle(.nextDisplay), desc: tr("Sang màn hình phải", "Next Display"))
                                shortcutPill(key: shortcuts.primaryTitle(.previousDisplay), desc: tr("Sang màn hình trái", "Previous Display"))
                            }
                        }
                    }
                }
                .padding(10)
                .cardBackground()

                // Clipboard Manager (Maccy Replacement) Card
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "doc.on.clipboard.fill")
                            .font(.system(size: FS.body))
                            .foregroundStyle(Color.accentColor)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(tr("Lịch sử Clipboard", "Clipboard History"))
                                .font(.system(size: FS.label, weight: .semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                            Text(tr("Lịch sử sao chép thông minh, tìm kiếm & dán tức thì", "Smart clipboard history, search & instant paste"))
                                .font(.system(size: FS.caption))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if clipboardManager.isMonitoringEnabled {
                            Button {
                                withAnimation(.easeInOut(duration: 0.18)) {
                                    clipboardManager.isDetailsExpanded.toggle()
                                }
                            } label: {
                                Image(systemName: clipboardManager.isDetailsExpanded ? "chevron.up" : "chevron.down")
                                    .font(.system(size: FS.caption, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 20, height: 20)
                                    .background(Circle().fill(Color.primary.opacity(clipboardManager.isDetailsExpanded ? 0.08 : 0.04)))
                            }
                            .buttonStyle(.plain)
                            .help(clipboardManager.isDetailsExpanded ? tr("Thu gọn chi tiết", "Collapse details") : tr("Xem chi tiết cài đặt", "View settings details"))
                        }

                        Toggle("", isOn: Binding<Bool>(
                            get: { clipboardManager.isMonitoringEnabled },
                            set: { clipboardManager.isMonitoringEnabled = $0 }
                        ))
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                        .labelsHidden()
                    }

                    if clipboardManager.isMonitoringEnabled && clipboardManager.isDetailsExpanded {
                        Divider().opacity(0.35)

                        // Shortcuts & Quick Actions
                        ShortcutGrid {
                            shortcutPill(key: shortcuts.primaryTitle(.clipboard), desc: tr("Mở bảng HUD", "Open HUD"))
                            shortcutPill(key: "1..9", desc: tr("Dán tức thì", "Instant Paste"))
                            shortcutPill(key: "⌥P", desc: tr("Ghim", "Pin"))
                            shortcutPill(key: "⌥⌫", desc: tr("Xóa", "Delete"))
                        }

                        // Storage limit + automatic cleanup + HUD shortcut options
                        VStack(alignment: .leading, spacing: 5) {
                            HStack(spacing: 4) {
                                Text(tr("Giới hạn:", "Max items:"))
                                    .font(.system(size: FS.caption))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 80, alignment: .leading)

                                ForEach([50, 100, 200, 500], id: \.self) { count in
                                    optionChip("\(count)", selected: clipboardManager.maxItemsCount == count) {
                                        clipboardManager.maxItemsCount = count
                                    }
                                }
                                optionChip("∞", selected: clipboardManager.hasUnlimitedHistory) {
                                    clipboardManager.maxItemsCount = 0
                                }

                                Spacer()

                                Text("\(clipboardManager.items.count) " + tr("mục lưu", "items stored"))
                                    .font(.system(size: FS.caption))
                                    .foregroundStyle(.secondary)
                            }

                            HStack(spacing: 4) {
                                Text(tr("Tự động xoá:", "Auto cleanup:"))
                                    .font(.system(size: FS.caption))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 80, alignment: .leading)

                                ForEach([0, 7, 30, 90], id: \.self) { days in
                                    optionChip(days == 0 ? tr("Không", "Never") : "\(days) " + tr("ngày", "days"),
                                               selected: clipboardManager.autoCleanupDays == days) {
                                        clipboardManager.autoCleanupDays = days
                                    }
                                }

                            }

                            HStack(spacing: 8) {
                                Button {
                                    clipboardManager.cleanupNow()
                                } label: {
                                    Text(tr("Dọn ngay", "Clean now"))
                                        .font(.system(size: FS.caption, weight: .medium))
                                        .lineLimit(1)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 4)
                                        .background(RoundedRectangle(cornerRadius: Rad.sm).fill(Color.primary.opacity(0.06)))
                                        .foregroundStyle(Color.primary)
                                }
                                .buttonStyle(.plain)
                                .help(tr("Xoá mục chưa ghim cũ hơn \(clipboardManager.autoCleanupDays > 0 ? "\(clipboardManager.autoCleanupDays) ngày" : "30 ngày")", "Delete unpinned items older than \(clipboardManager.autoCleanupDays > 0 ? "\(clipboardManager.autoCleanupDays) days" : "30 days")"))

                                Button {
                                    clipboardManager.requestClearAllUnpinned()
                                } label: {
                                    Text(clipboardManager.pendingClearAllConfirm ? tr("Chắc chắn?", "Confirm?") : tr("Xoá tất cả", "Clear all"))
                                        .font(.system(size: FS.caption, weight: .medium))
                                        .lineLimit(1)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 4)
                                        .background(RoundedRectangle(cornerRadius: Rad.sm).fill(clipboardManager.pendingClearAllConfirm ? Color.red.opacity(0.14) : Color.primary.opacity(0.06)))
                                        .foregroundStyle(Tone.bad)
                                }
                                .buttonStyle(.plain)
                                .help(tr("Xoá mọi mục chưa ghim (bấm 2 lần để xác nhận)", "Delete all unpinned items (click twice to confirm)"))
                            }

                            if let message = clipboardManager.cleanupMessage {
                                Text(message)
                                    .font(.system(size: FS.caption, weight: .medium))
                                    .foregroundStyle(Color.orange.opacity(0.95))
                                    .fixedSize(horizontal: false, vertical: true)
                                    .transition(.opacity)
                            }

                            if clipboardManager.hasUnlimitedHistory {
                                Text(clipboardManager.autoCleanupDays == 0
                                     ? tr("Không giới hạn số mục: nên bật tự động xoá để tránh phình bộ nhớ.", "Unlimited items: recommended to enable auto-cleanup to save memory.")
                                     : tr("Không giới hạn số mục • tự động xoá sau \(clipboardManager.autoCleanupDays) ngày.", "Unlimited items • auto-cleans after \(clipboardManager.autoCleanupDays) days."))
                                    .font(.system(size: FS.caption))
                                    .foregroundStyle(Color.orange.opacity(0.9))
                            }
                        }

                        // Ignore passwords toggle
                        HStack(spacing: 6) {
                            Image(systemName: "lock.shield")
                                .font(.system(size: FS.caption))
                                .foregroundStyle(.secondary)
                            Text(tr("Tự động bỏ qua mật khẩu (1Password, Bitwarden, Keychain)", "Auto-ignore passwords (1Password, Bitwarden, Keychain)"))
                                .font(.system(size: FS.caption))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Toggle("", isOn: Binding<Bool>(
                                get: { clipboardManager.ignoreConcealedTypes },
                                set: { clipboardManager.ignoreConcealedTypes = $0 }
                            ))
                            .toggleStyle(.switch)
                            .controlSize(.mini)
                            .labelsHidden()
                        }

                        // Open HUD Button
                        Button {
                            clipboardManager.toggleHUD()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "macwindow")
                                    .font(.system(size: FS.caption))
                                Text(tr("Mở bảng Clipboard HUD (\(shortcuts.primaryTitle(.clipboard)))", "Open Clipboard HUD (\(shortcuts.primaryTitle(.clipboard)))"))
                                    .font(.system(size: FS.caption, weight: .semibold))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .frame(maxWidth: .infinity)
                            .background(RoundedRectangle(cornerRadius: Rad.sm).fill(Color.primary.opacity(0.06)))
                            .foregroundStyle(.primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(10)
                .cardBackground()

                // Screenshot (LightShot / ⌘⇧1) Card
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: FS.body))
                            .foregroundStyle(Color.accentColor)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(tr("Chụp ảnh màn hình", "Screenshot Snipping"))
                                .font(.system(size: FS.label, weight: .semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                            Text(tr("Kéo chọn vùng, vẽ bút đỏ chú thích, ⌘C sao chép, ⌘S lưu tệp", "LightShot-style: crop area, red pen annotations, ⌘C copy, ⌘S save"))
                                .font(.system(size: FS.caption))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if screenshotManager.isScreenshotEnabled {
                            Button {
                                withAnimation(.easeInOut(duration: 0.18)) {
                                    screenshotManager.isDetailsExpanded.toggle()
                                }
                            } label: {
                                Image(systemName: screenshotManager.isDetailsExpanded ? "chevron.up" : "chevron.down")
                                    .font(.system(size: FS.caption, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 20, height: 20)
                                    .background(Circle().fill(Color.primary.opacity(screenshotManager.isDetailsExpanded ? 0.08 : 0.04)))
                            }
                            .buttonStyle(.plain)
                            .help(screenshotManager.isDetailsExpanded ? tr("Thu gọn chi tiết", "Collapse details") : tr("Xem chi tiết cài đặt", "View settings details"))
                        }

                        Toggle("", isOn: Binding<Bool>(
                            get: { screenshotManager.isScreenshotEnabled },
                            set: { screenshotManager.isScreenshotEnabled = $0 }
                        ))
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                        .labelsHidden()
                    }

                    if screenshotManager.isScreenshotEnabled && screenshotManager.isDetailsExpanded {
                        Divider().opacity(0.35)

                        // Shortcuts & Quick Actions Grid
                        ShortcutGrid {
                            shortcutPill(key: shortcuts.primaryTitle(.screenshot), desc: tr("Mở chụp ảnh", "Start Snipping"))
                            shortcutPill(key: "⌘C", desc: tr("Sao chép ảnh", "Copy Image"))
                            shortcutPill(key: "⌘S", desc: tr("Lưu ảnh PNG", "Save PNG"))
                            shortcutPill(key: "⎋", desc: tr("Huỷ bỏ", "Cancel"))
                        }

                        // Capture Now Button
                        Button {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                screenshotManager.startCapture()
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: FS.caption))
                                Text(tr("Chụp màn hình ngay", "Capture Screenshot Now"))
                                    .font(.system(size: FS.caption, weight: .semibold))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .frame(maxWidth: .infinity)
                            .background(RoundedRectangle(cornerRadius: Rad.sm).fill(Color.primary.opacity(0.06)))
                            .foregroundStyle(.primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(10)
                .cardBackground()

                // Mouse Chording Card
                HStack(spacing: 8) {
                    Image(systemName: "cursorarrow.click.2")
                        .font(.system(size: FS.body))
                        .foregroundStyle(Color.accentColor)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(tr("Bấm đồng thời Chuột Trái + Phải mở F3", "Left + Right click opens Mission Control (F3)"))
                            .font(.system(size: FS.label, weight: .semibold))
                        Text(tr("Mở Mission Control ngay trên chuột mà không cần chạm bàn phím", "Trigger Mission Control directly from mouse without keyboard"))
                            .font(.system(size: FS.caption))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Toggle("", isOn: Binding<Bool>(
                        get: { displayManager.isMouseChordEnabled },
                        set: {
                            displayManager.isMouseChordEnabled = $0
                            UserDefaults.standard.set($0, forKey: "mouse_chord_enabled")
                        }
                    ))
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .labelsHidden()
                }
                .padding(10)
                .cardBackground()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    private func optionChip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: FS.caption, weight: selected ? .semibold : .medium))
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(selected ? Color.accentColor : Color.primary.opacity(0.06)))
                .foregroundStyle(selected ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
    }

    private func shortcutPill(key: String, desc: String) -> some View {
        HStack(spacing: 6) {
            Text(desc)
                .font(.system(size: FS.caption))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 4)
            Text(key)
                .font(.system(size: FS.caption, weight: .medium, design: .monospaced))
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, 5)
                .padding(.vertical, 1.5)
                .background(RoundedRectangle(cornerRadius: Rad.sm).fill(Color.primary.opacity(0.07)))
        }
        .frame(maxWidth: .infinity)
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

// MARK: - In-App Update Modal View

struct UpdateModalView: View {
    @ObservedObject var updateManager: UpdateManager

    var body: some View {
        ZStack {
            // Dimmed semi-transparent backdrop
            Color.black.opacity(0.4)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    if case .extracting = updateManager.state {
                        // Prevent closing
                    } else if case .readyToRestart = updateManager.state {
                        // Prevent closing during relaunch
                    } else {
                        updateManager.showUpdateModal = false
                    }
                }

            // Modal Dialog Card
            VStack(spacing: 12) {
                // Header Bar
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                            .font(.system(size: FS.value, weight: .bold))
                            .foregroundStyle(Color.accentColor)

                        VStack(alignment: .leading, spacing: 0) {
                            Text(tr("Cập nhật HyperMac", "Update HyperMac"))
                                .font(.system(size: FS.body, weight: .semibold))
                            Text(tr("Phiên bản hiện tại: v\(UpdateManager.currentVersion)", "Current version: v\(UpdateManager.currentVersion)"))
                                .font(.system(size: FS.caption))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    Button {
                        updateManager.showUpdateModal = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: FS.subhead))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                Divider()

                // State Content
                switch updateManager.state {
                case .idle, .checking:
                    VStack(spacing: 10) {
                        ProgressView()
                            .controlSize(.regular)
                        Text(tr("Đang kiểm tra bản build local...", "Checking the local build..."))
                            .font(.system(size: FS.label))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 120)

                case .upToDate(let ver):
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: FS.huge))
                            .foregroundStyle(.secondary)

                        Text(tr("Bạn đang dùng bản build mới nhất!", "You are using the latest local build!"))
                            .font(.system(size: FS.body, weight: .semibold))

                        Text(tr("HyperMac v\(ver) đang trùng với bản trong thư mục build.", "HyperMac v\(ver) matches the app in the build folder."))
                            .font(.system(size: FS.caption))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 10)

                        Button {
                            updateManager.checkForUpdates(silent: false)
                        } label: {
                            Text(tr("Kiểm tra lại", "Check Again"))
                                .font(.system(size: FS.label, weight: .medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color.primary.opacity(0.08)))
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity, minHeight: 120)

                case .updateAvailable(let ver, let notes):
                    let displayVer = ver.hasPrefix("v") || ver.hasPrefix("V") ? ver : "v\(ver)"
                    VStack(spacing: 10) {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .font(.system(size: FS.subhead))
                                .foregroundStyle(.secondary)

                            Text(tr("Có bản build local mới: \(displayVer)", "A new local build is available: \(displayVer)"))
                                .font(.system(size: FS.body, weight: .semibold))
                                .foregroundStyle(Color.accentColor)
                        }

                        // Release Notes Box
                        VStack(alignment: .leading, spacing: 3) {
                            Text(tr("Bản build local:", "Local build details:"))
                                .font(.system(size: FS.caption, weight: .semibold))
                                .foregroundStyle(.secondary)

                            ScrollView(.vertical, showsIndicators: true) {
                                Text(notes)
                                    .font(.system(size: FS.caption))
                                    .lineSpacing(2)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(6)
                            }
                            .frame(height: 95)
                            .background(
                                RoundedRectangle(cornerRadius: Rad.sm)
                                    .fill(Color.primary.opacity(0.04))
                            )
                        }

                        // Action Buttons
                        VStack(spacing: 6) {
                            Button {
                                updateManager.startUpdate()
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: "arrow.down.circle.fill")
                                        .font(.system(size: FS.body, weight: .semibold))
                                    Text(tr("Cập nhật từ build local", "Update from local build"))
                                        .font(.system(size: FS.label, weight: .semibold))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 7)
                                .background(
                                    RoundedRectangle(cornerRadius: Rad.sm)
                                        .fill(Color.accentColor)
                                )
                                .foregroundStyle(Color.white)
                            }
                            .buttonStyle(.plain)

                            Button {
                                updateManager.openBuildFolder()
                            } label: {
                                Text(tr("Mở thư mục build", "Open build folder"))
                                    .font(.system(size: FS.caption))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity)

                case .extracting, .readyToRestart:
                    VStack(spacing: 10) {
                        ProgressView()
                            .controlSize(.regular)

                        Text(tr("Đang cài build local và chuẩn bị mở lại...", "Installing the local build and preparing to reopen..."))
                            .font(.system(size: FS.body, weight: .semibold))

                        Text(tr("Ứng dụng sẽ mở lại từ bản build local.", "The app will reopen from the local build."))
                            .font(.system(size: FS.caption))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 120)

                case .failed(let errorMsg):
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: FS.hero))
                            .foregroundStyle(.orange)

                        Text(tr("Không thể cập nhật từ build local", "Could not update from the local build"))
                            .font(.system(size: FS.body, weight: .semibold))

                        Text(errorMsg)
                            .font(.system(size: FS.caption))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 10)

                        HStack(spacing: 8) {
                            Button {
                                updateManager.checkForUpdates(silent: false)
                            } label: {
                                Text(tr("Thử lại", "Try Again"))
                                    .font(.system(size: FS.caption, weight: .medium))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Capsule().fill(Color.primary.opacity(0.08)))
                            }
                            .buttonStyle(.plain)

                            Button {
                                updateManager.openBuildFolder()
                            } label: {
                                Text(tr("Mở thư mục build", "Open build folder"))
                                    .font(.system(size: FS.caption, weight: .medium))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Capsule().fill(Color.accentColor.opacity(0.10)))
                                    .foregroundStyle(Color.accentColor)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 120)
                }

                Divider()

                // Preferences Row: Auto check on launch
                HStack {
                    Text(tr("Tự động kiểm tra build local khi mở HyperMac", "Automatically check the local build on startup"))
                        .font(.system(size: FS.caption))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Toggle("", isOn: Binding<Bool>(
                        get: { updateManager.autoCheckEnabled },
                        set: { updateManager.autoCheckEnabled = $0 }
                    ))
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .labelsHidden()
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: Rad.md)
                    .fill(Color(NSColor.windowBackgroundColor))
                    .shadow(color: Color.black.opacity(0.25), radius: 16, x: 0, y: 6)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Rad.md)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
            )
            .padding(.horizontal, 20)
        }
    }
}
