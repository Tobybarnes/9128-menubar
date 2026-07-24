import AppKit
import SwiftUI

struct PlayerPopover: View {
    @ObservedObject var radio: RadioService
    @ObservedObject var player: PlayerController
    @ObservedObject var lastFM: LastFMManager

    private var track: TrackMetadata {
        radio.currentTrack?.metadata ?? TrackMetadata(artist: "9128", title: "Live radio")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            nowPlaying
                .padding(.top, 16)
            controls
                .padding(.top, 16)

            if let error = player.errorMessage ?? radio.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(.top, 12)
            }

            Divider().padding(.vertical, 16)
            recentTracks
            Divider().padding(.vertical, 14)
            footer
        }
        .padding(18)
        .frame(width: 350)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        HStack {
            Text("9128")
                .font(.system(size: 24, weight: .bold, design: .rounded))
            Spacer()
            HStack(spacing: 6) {
                Circle()
                    .fill(radio.isOnline ? BrandAssets.accent : Color.secondary)
                    .frame(width: 7, height: 7)
                Text(radio.isOnline ? "LIVE" : "OFFLINE")
                    .font(.caption2.weight(.semibold))
                    .tracking(0.8)
            }
            .foregroundStyle(.secondary)
        }
    }

    private var nowPlaying: some View {
        HStack(spacing: 14) {
            artwork
                .frame(width: 92, height: 92)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text("NOW PLAYING")
                    .font(.caption2.weight(.semibold))
                    .tracking(0.8)
                    .foregroundStyle(.secondary)
                Text(track.title)
                    .font(.headline)
                    .lineLimit(3)
                    .textSelection(.enabled)
                Text(track.artist)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var artwork: some View {
        if let url = radio.currentTrack?.preferredArtworkURL {
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    artworkPlaceholder
                }
            }
        } else {
            artworkPlaceholder
        }
    }

    private var artworkPlaceholder: some View {
        ZStack {
            Color(nsColor: .controlBackgroundColor)
            Image(nsImage: BrandAssets.menuBarIcon)
                .resizable()
                .scaledToFit()
                .frame(width: 46, height: 46)
        }
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Button(action: player.toggle) {
                ZStack {
                    Circle().fill(BrandAssets.accent)
                    if player.isBuffering {
                        ProgressView().controlSize(.small).tint(.black)
                    } else {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .foregroundStyle(.black)
                            .offset(x: player.isPlaying ? 0 : 1)
                    }
                }
                .frame(width: 38, height: 38)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(player.isPlaying ? "Stop 9128" : "Play 9128")

            Image(systemName: "speaker.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
            Slider(value: $player.volume, in: 0...1)
                .tint(BrandAssets.accent)
                .accessibilityLabel("Volume")

            Button {
                if let url = track.bandcampSearchURL { NSWorkspace.shared.open(url) }
            } label: {
                Text("BC")
                    .font(.caption.weight(.bold))
                    .frame(width: 28, height: 28)
                    .background(BrandAssets.accent, in: RoundedRectangle(cornerRadius: 6))
                    .foregroundStyle(.black)
            }
            .buttonStyle(.plain)
            .help("Find this track on Bandcamp")

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(track.displayName, forType: .string)
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(.borderless)
            .help("Copy track and artist")
        }
    }

    @ViewBuilder
    private var recentTracks: some View {
        if radio.recentTracks.isEmpty {
            Text(radio.isRefreshing ? "Loading recently played…" : "No recent tracks yet")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 9) {
                Text("RECENTLY PLAYED")
                    .font(.caption2.weight(.semibold))
                    .tracking(0.8)
                    .foregroundStyle(.secondary)

                ForEach(Array(radio.recentTracks.enumerated()), id: \.offset) { _, item in
                    Button {
                        if let url = item.metadata.bandcampSearchURL { NSWorkspace.shared.open(url) }
                    } label: {
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(item.metadata.title)
                                    .lineLimit(1)
                                Text(item.metadata.artist)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Circle()
                    .fill(lastFM.isConnected ? BrandAssets.accent : Color.secondary.opacity(0.5))
                    .frame(width: 6, height: 6)
                Text(lastFM.isConnected ? "Last.fm on" : "Last.fm off")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                NSWorkspace.shared.open(RadioService.websiteURL)
            } label: {
                Image(systemName: "globe")
            }
            .buttonStyle(.borderless)
            .help("Open 9128.live")

            SettingsLink {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            .help("Settings")

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power")
            }
            .buttonStyle(.borderless)
            .help("Quit 9128")
        }
    }
}
