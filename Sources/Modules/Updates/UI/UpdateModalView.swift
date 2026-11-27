// SPDX-License-Identifier: GPL-3.0-only
import SwiftUI

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
