# 9128 for macOS

An unofficial personal menu-bar player for [9128.live](https://9128.live/).

The app plays the live 320 kbps stream and shows the current track, artist, artwork, and recently played tracks. Bandcamp buttons open searches for the selected track because the station feed does not provide exact release links.

It also includes:

- Last.fm authorization and scrobbling, with session data kept in Keychain
- the standard half-track or four-minute scrobble rule
- remembered volume
- copy track and artist
- launch at login
- links to 9128 and Bandcamp
- settings and quit controls

## Build

Requirements: macOS 14 or newer, Xcode 16 or newer, and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
xcodegen generate
xcodebuild -project Radio9128.xcodeproj -scheme Radio9128 -configuration Release build
```

The app does not keep Last.fm developer credentials in the repository. Add your API key and shared secret in Settings, then approve the app in the browser. The resulting session key is stored in the macOS Keychain.

The app uses the favicon from [A Strangely Isolated Place](https://www.astrangelyisolatedplace.com/) for its menu-bar and app icon. This project is not affiliated with 9128, ASIP, Radio.co, Bandcamp, or Last.fm.
