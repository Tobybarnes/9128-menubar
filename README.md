# 9128 for macOS

An unofficial menu-bar player for [9128.live](https://9128.live/).

The app plays the live 320 kbps stream and shows the current track, artist, artwork, and recently played tracks. Bandcamp buttons open searches for the selected track because the station feed does not provide exact release links.

It also includes:

- Last.fm authorization for each listener, with session data kept in Keychain
- scrobbling after half the track or two minutes
- remembered volume
- copy track and artist
- launch at login
- in-app update checks
- links to 9128 and Bandcamp
- settings and quit controls

## Build

Requirements: macOS 14 or newer, Xcode 16 or newer, and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
xcodegen generate
xcodebuild -project Radio9128.xcodeproj -scheme Radio9128 -configuration Release build
```

The app does not keep Last.fm developer credentials in the repository. To build your own copy, add an API key and shared secret to `Config/Secrets.xcconfig`. Each listener can then connect their own Last.fm account in Settings; the resulting session key is stored in the macOS Keychain.

Version 1.0 uses [Sparkle](https://sparkle-project.org/) for in-app updates. Open Settings and choose `Check for Updates…` to check the signed update feed.

The app uses the favicon from [A Strangely Isolated Place](https://www.astrangelyisolatedplace.com/) for its menu-bar and app icon. This project is not affiliated with 9128, ASIP, Radio.co, Bandcamp, or Last.fm.
