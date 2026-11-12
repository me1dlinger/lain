# English | [简体中文](./README-zh.md)

<div align="center">
  <img src="./app_icons/icon.png" width="160" alt="Lain Icon"/>

  <br />

  # Lain (临音)

  _"A private music oasis in the digital world."_

</div>

Lain is a cross-platform music player for local libraries and self-hosted media services, supporting Android, iOS, Windows, Linux, and macOS.

Currently supports:
- Local
- WebDAV
- Navidrome
- Emby
- Feiniu Music (special thanks to [huya688zdx](https://github.com/huya688zdx) for the contribution)

## About this project

Lain is a **derivative work** of [Sylvakru](https://github.com/AfalpHy/sylvakru) (formerly Particle Music),
originally created by [AfalpHy](https://github.com/AfalpHy). It is developed here as an **independent project**,
not as a GitHub fork: it has its own application identifier, its own release channel and its own development
direction, and it no longer takes changes from the upstream repository automatically.

The upstream project is the foundation of everything here; this repository starts from its last commit and moves
on from there. It stays open source under the same license as the upstream project —
the [Apache License 2.0](./LICENSE). Upstream copyright notices are kept in [NOTICE](./NOTICE); every change made
here is listed in the git history and summarised below and in the release notes.

### What has been changed in this derivative

**Identity**

- Application name: Sylvakru / 森露 → **Lain / 临音**; Dart package `sylvakru` → `lain`.
- Application identifier and every MethodChannel, iOS bundle id, App Group, Linux and Windows binary name follow
  `com.meidlinger.sylvakru`.
- Runtime files (`playback`, single-instance lock and port, iOS keeper file) and the download folder are `lain_*` /
  `Lain`.
- Update check points at this repository; the original README was rewritten (both languages) and `BUILDING.md` was
  added.

**Playback and media session**

- A track no longer replays itself when a stream reports the end of a buffered segment as the end of the song:
  completions are classified by position, a duplicate end-of-track is ignored, and a second open of the track being
  opened is refused.
- Head units no longer get stuck on the previous track: the media item is published in the same instant as the
  track, and the artwork is handed over as a `content://` URI on Android so the session update is not racing the
  next one.
- A stream that ends no longer restarts from the beginning; the relay passes a known `Content-Length` through so a
  stalled transfer cannot be mistaken for the end of the file.
- `[media]` and `[playback]` diagnostics in the app log (exportable from the settings) and on `adb logcat`.

**Library and metadata**

- One rule decides which songs belong to an artist, for the artist list, the artist page and the big-picture view
  alike; a tag holding `D、E` or `D, E` is split on the ideographic comma and the full-width forms as well, so an
  artist no longer collects songs whose tag merely contains its name.
- Artist biographies and images are cached per artist name across sources and launches, and can be refreshed from
  the artist list.

**Android experience**

- A single home page, server manager, sorting sheet, listening statistics, home-screen widgets (now playing and
  playlists), lyric line in the system media session, playlists and downloads, playlist import/export.
- Streamed songs show which ones are cached, and a song's cached cover, lyric and size are one tap away in its menu.
- The playlist download button really downloads audio.

**Packaging**

- `compileSdk 37.0` support, a lowered Gradle heap for low-memory machines, and a documented build path in
  [BUILDING.md](./BUILDING.md); `generate_deb.sh` / `generate_rpm.sh` for Linux packages.

**Bug fixes carried in this line**

- iOS portrait vibration setting was swallowed by an empty `if`.
- The "settings count" shown in the settings page was hard-coded and out of date.
- Long-pressing an artist to refresh its cache was possible only in the portrait artist list.

## USB Exclusive Mode (Android)

USB Exclusive Mode is not part of this build; for that please use the
[upstream fork](https://github.com/huya688zdx/sylvakru) maintained by [huya688zdx](https://github.com/huya688zdx).

## Supported Formats

| File Format | Metadata Format(s)           |
|-------------|------------------------------|
| AAC (ADTS)  | `ID3v2`, `ID3v1`             |
| Ape         | `APE`, `ID3v2`\*, `ID3v1`    |
| AIFF        | `ID3v2`, `Text Chunks`       |
| FLAC        | `Vorbis Comments`, `ID3v2`\* |
| MP3         | `ID3v2`, `ID3v1`, `APE`      |
| MP4         | `iTunes-style ilst`          |
| MPC         | `APE`, `ID3v2`\*, `ID3v1`\*  |
| Opus        | `Vorbis Comments`            |
| Ogg Vorbis  | `Vorbis Comments`            |
| Speex       | `Vorbis Comments`            |
| WAV         | `ID3v2`, `RIFF INFO`         |
| WavPack     | `APE`, `ID3v1`               |

\* The tag will be **read only**, due to lack of official support

## Audio Processing

- [audio_tags_lofty](https://github.com/AfalpHy/audio_tags_lofty.git) — for reading and writing audio tags (based on lofty)
- [media_kit](https://github.com/media-kit/media-kit.git) — for audio playback (based on mpv/FFmpeg)

## Run & Build

Install Flutter by following the [official Flutter installation guide](https://docs.flutter.dev/install/manual).

### Ubuntu/Debian

```shell
# Flutter dependencies:
sudo apt install clang lld cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libsecret-1-dev

# audio lib
sudo apt install libmpv-dev

git clone git@github.com:me1dlinger/lain.git
cd lain
# check the development environment
flutter doctor -v
# run in debug mode
flutter run
# run in release mode
flutter run --release
# build
flutter build linux
# if you want to generate a .deb package
flutter build linux && ./generate_deb.sh

# if you want to generate a .rpm package
sudo apt install rpm
flutter build linux && ./generate_rpm.sh
```

### Windows

Install [Visual Studio](https://visualstudio.microsoft.com/).

```shell
git clone git@github.com:me1dlinger/lain.git
cd lain
# check the development environment
flutter doctor -v
# run in debug mode
flutter run
# run in release mode
flutter run --release
# build
flutter build windows
```

### macOS & iOS

Install Xcode and the Xcode Command Line Tools by following the [official Apple Developer download page](https://developer.apple.com/download/all/).

```shell
git clone git@github.com:me1dlinger/lain.git
cd lain

# install CocoaPods
brew install cocoapods

# check the development environment
flutter doctor -v
# run in debug mode
flutter run
# run in release mode
flutter run --release
# build
flutter build macos

# build an unsigned ipa
flutter build ios --release --no-codesign && \
mkdir -p Payload && \
cp -r build/ios/iphoneos/Runner.app Payload/ && \
zip -r lain.ipa Payload && \
rm -rf Payload
```

### Android

Install [Android Studio](https://developer.android.com/studio) and Android SDK Command-line Tools

```shell
git clone git@github.com:me1dlinger/lain.git
cd lain
# accept the SDK licenses
flutter doctor --android-licenses
# check the development environment
flutter doctor -v
# run in debug mode
flutter run
# run in release mode
flutter run --release
# build
flutter build apk
# split abi
flutter build apk --split-per-abi
# build TV
flutter build apk --dart-define=TV=true
```

See [BUILDING.md](./BUILDING.md) for the Android toolchain notes this project needs
(`compileSdk 37.0`, JDK 17, a low Gradle heap on small machines).

## Screenshots

### On Mobile

- iPhone
<div>
    <img src="./screenshots/mobile0.png" width="270" height="540" />
    <img src="./screenshots/mobile1.png" width="270" height="540" />
    <img src="./screenshots/mobile2.png" width="270" height="540" />
</div>

<div>
    <img src="./screenshots/mobile3.png" width="270" height="540" />
    <img src="./screenshots/mobile4.png" width="270" height="540" />
    <img src="./screenshots/mobile5.png" width="270" height="540" />
</div>

![](./screenshots/mobile6.png)
![](./screenshots/mobile7.png)
![](./screenshots/mobile8.png)

- iPad

![](./screenshots/mobile9.png)
![](./screenshots/mobile10.png)
![](./screenshots/mobile11.png)
![](./screenshots/mobile12.png)

### On Desktop

![](./screenshots/desktop0.png)
![](./screenshots/desktop1.png)
![](./screenshots/desktop2.png)
![](./screenshots/desktop3.png)
![](./screenshots/desktop4.png)
![](./screenshots/desktop5.png)
![](./screenshots/desktop6.png)

## License

[Apache License 2.0](./LICENSE). Lain is a derivative work of
[Sylvakru](https://github.com/AfalpHy/sylvakru) by [AfalpHy](https://github.com/AfalpHy); see
[NOTICE](./NOTICE) for the upstream copyright.
