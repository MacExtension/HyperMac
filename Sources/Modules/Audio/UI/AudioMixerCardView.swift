import SwiftUI

struct AudioMixerCardView: View {
    @ObservedObject private var mixer = AudioMixerManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 6) {
                Image(systemName: "speaker.wave.2.fill")
                    .foregroundStyle(Color.accentColor)
                Text(tr("Âm lượng từng ứng dụng", "Per-app Volume"))
                    .font(.system(size: FS.title, weight: .semibold))
                Spacer()
                Toggle("", isOn: Binding(get: { mixer.enabled }, set: { mixer.setEnabled($0) }))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .disabled(!supported)
            }

            if !supported {
                Text(tr("Cần macOS 14.2 trở lên", "Requires macOS 14.2 or newer"))
                    .font(.system(size: FS.caption))
                    .foregroundStyle(.secondary)
            } else if mixer.enabled {
                if mixer.applications.isEmpty {
                    Text(tr("Chưa có ứng dụng đang phát âm thanh", "No application is playing audio"))
                        .font(.system(size: FS.caption))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(mixer.applications) { app in
                        appRow(app)
                    }
                }
                if let error = mixer.errorMessage {
                    Text(error)
                        .font(.system(size: FS.caption))
                        .foregroundStyle(Tone.bad)
                }
            } else {
                Text(tr("Bật để điều chỉnh 0–200% và tắt tiếng từng ứng dụng.",
                        "Enable to adjust each app from 0–200% or mute it."))
                    .font(.system(size: FS.caption))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .cardBackground()
    }

    private var supported: Bool {
        if #available(macOS 14.2, *) { return true }
        return false
    }

    private func appRow(_ app: MixerApplication) -> some View {
        HStack(spacing: 7) {
            if let icon = app.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 20, height: 20)
            } else {
                Image(systemName: "app.fill")
                    .frame(width: 20, height: 20)
            }
            Text(app.name)
                .font(.system(size: FS.label, weight: .medium))
                .lineLimit(1)
                .frame(width: 75, alignment: .leading)
            Slider(value: Binding(
                get: { Double(mixer.level(for: app)) },
                set: { mixer.setLevel(Int($0.rounded()), for: app) }
            ), in: 0...200, step: 10)
                .controlSize(.mini)
            Text("\(mixer.level(for: app))%")
                .font(.system(size: FS.caption, design: .monospaced))
                .frame(width: 36, alignment: .trailing)
            Button { mixer.toggleMute(for: app) } label: {
                Image(systemName: mixer.level(for: app) == 0 ? "speaker.slash.fill" : "speaker.wave.2")
                    .frame(width: 16)
            }
            .buttonStyle(.plain)
            .help(mixer.level(for: app) == 0 ? tr("Bật tiếng", "Unmute") : tr("Tắt tiếng", "Mute"))
        }
    }
}
