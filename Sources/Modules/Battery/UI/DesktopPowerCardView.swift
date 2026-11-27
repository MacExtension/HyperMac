import SwiftUI

/// Mac mini, Studio, iMac and Mac Pro have no battery telemetry or charge limit.
struct DesktopPowerCardView: View {
    @ObservedObject private var energy = ProcessEnergyManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "powerplug.fill")
                    .font(.system(size: FS.value))
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(tr("Nguồn AC trực tiếp", "Direct AC power"))
                        .font(.system(size: FS.subhead, weight: .semibold))
                    Text(tr("Máy Mac bàn · không có pin", "Desktop Mac · no battery"))
                        .font(.system(size: FS.caption))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button { energy.refreshProcesses() } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: FS.body))
                }
                .buttonStyle(.plain)
                .help(tr("Quét lại tiến trình", "Refresh processes"))
            }

            Divider()
            Text(tr("Đóng băng CPU", "Freeze CPU activity"))
                .font(.system(size: FS.body, weight: .semibold))
            if energy.processes.isEmpty {
                Text(tr("Không có tiến trình nặng.", "No heavy processes."))
                    .font(.system(size: FS.caption))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(energy.processes) { process in
                    HStack(spacing: 6) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(process.name)
                                .font(.system(size: FS.label, weight: .semibold))
                                .lineLimit(1)
                            Text(String(format: "%.1f%% CPU · PID %d", process.cpu, process.pid))
                                .font(.system(size: FS.caption))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(process.isFrozen ? tr("Rã đông", "Resume") : tr("Đóng băng", "Freeze")) {
                            if process.isFrozen { energy.resumeProcess(pid: process.pid) }
                            else { energy.freezeProcess(pid: process.pid) }
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: FS.caption, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                    }
                    .padding(6)
                    .background(RoundedRectangle(cornerRadius: Rad.sm).fill(Color.primary.opacity(0.04)))
                }
            }
            Text(tr("Tác vụ được rã đông tự động sau 15 giây.", "Processes resume automatically after 15 seconds."))
                .font(.system(size: FS.caption))
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .cardBackground()
        .onAppear { energy.refreshProcesses() }
    }
}
