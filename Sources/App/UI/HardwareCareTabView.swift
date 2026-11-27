// SPDX-License-Identifier: GPL-3.0-only
import SwiftUI

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
                    title: batteryManager.hasBattery
                        ? tr("Pin & Nguồn SMC", "Battery & Power SMC")
                        : tr("Nguồn AC", "AC Power"),
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
                    AudioMixerCardView()

                    if thermalManager.selectedSection == 0 {
                        if batteryManager.hasBattery {
                            BatteryCardView(batteryManager: batteryManager, onSelectThermalSection: {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                    thermalManager.selectedSection = 1
                                }
                            })
                        } else {
                            DesktopPowerCardView()
                        }
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
