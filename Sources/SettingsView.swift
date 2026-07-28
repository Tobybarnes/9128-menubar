import SwiftUI

struct SettingsView: View {
    @ObservedObject var lastFM: LastFMManager
    @ObservedObject var launchAtLogin: LaunchAtLoginController

    var body: some View {
        Form {
            Section("General") {
                Toggle(
                    "Open 9128 when I log in",
                    isOn: Binding(
                        get: { launchAtLogin.isEnabled },
                        set: { launchAtLogin.setEnabled($0) }
                    )
                )
                if let error = launchAtLogin.errorMessage {
                    Text(error).font(.caption).foregroundStyle(.orange)
                }
            }

            Section("Last.fm") {
                HStack {
                    Circle()
                        .fill(lastFM.isConnected ? BrandAssets.accent : Color.secondary.opacity(0.5))
                        .frame(width: 7, height: 7)
                    Text(lastFM.connectionLabel)
                        .foregroundStyle(lastFM.isConnected ? .primary : .secondary)
                    Spacer()
                }

                actionButtons

                if let message = lastFM.activityMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text("Each listener connects their own Last.fm account. The app scrobbles after half the track or two minutes. Radio duration is confirmed when the next track starts, so short tracks may appear on Last.fm a little later.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section("About") {
                Text(versionLabel)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
        .formStyle(.grouped)
        .frame(width: 470)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.bottom, 8)
    }

    private var versionLabel: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
        let beta = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "3"
        return "Version \(version) · Beta \(beta)"
    }

    @ViewBuilder
    private var actionButtons: some View {
        switch lastFM.state {
        case .connected:
            Button("Disconnect", role: .destructive) { lastFM.disconnect() }
        case .waitingForApproval:
            HStack {
                Button("I've approved it") {
                    Task { await lastFM.finishAuthorization() }
                }
                .buttonStyle(.borderedProminent)
                .tint(BrandAssets.accent)
                Button("Start again") {
                    Task { await lastFM.connect() }
                }
            }
        case .connecting:
            HStack {
                ProgressView().controlSize(.small)
                Text("Contacting Last.fm…").foregroundStyle(.secondary)
            }
        case .disconnected, .failed:
            Button("Connect Last.fm") {
                Task { await lastFM.connect() }
            }
            .buttonStyle(.borderedProminent)
            .tint(BrandAssets.accent)
            .disabled(!lastFM.configurationIsAvailable)
        }
    }
}
