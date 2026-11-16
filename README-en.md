# [简体中文](./README.md) | English

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

## This Release

### Car and media session
- Bluetooth/head-unit metadata follows a track switch immediately; title, artist and duration no longer lag.
- Artwork can be a server URL, the local relay, a content provider URI, or the bitmap only; the broadcast carries a compressed thumbnail.
- Car lyrics are a separate switch: on, the primary line carries the current lyric and the secondary line reads "artist - title".
- On the LAN the phone can serve the artwork to the head unit directly.

### Playback
- Play modes: tap cycles list loop and shuffle; a long press enters repeat one. The queue marks the repeating song.
- Replay gain can be off, per track or per album, using the loudness tags in the files so a mixed library keeps a steady level.
- Playback speed is selectable from 0.5x to 2.0x and applies to the running player immediately.
- Fade in and out is a separate switch: the volume ramps up on start and down on pause or a track change.
- Audio focus offers exclusive, smart ducking and mix: exclusive pauses and does not resume by itself; ducking restores the original volume when the interruption ends.
- The queue supports drag reordering, play next, add to queue, reverse and a full queue page; clearing it shows an undo bar that restores and resumes it.
- The media session position advances every second for notifications, the lock screen and a head unit; Navidrome and Emby now receive the current track, position and paused state for their own now-playing view.
- New full-screen driving mode with a cover-blurred background that follows the theme, in portrait and landscape; reachable from the landscape lyrics page too.

### Library and browsing
- Multiple servers, each with public and LAN addresses and its own certificate option, including Feiniu; addresses fail over and are masked by default.
- New server status page: state, address and latency, speed-first selection, server information and library statistics, with a button to start a library scan on the server.
- Global search across songs, albums, artists and playlists.
- Album and artist pages with sorting, albums first, track numbers and album descriptions; artist artwork is decided consistently from the server and the cache.
- Artist pages add top songs and similar artists; album pages add More from this artist; detail headers use a scroll parallax.
- Song lists remember their sort order; recently added, play-count sorting and quality tags are available.
- Playlists support import, export and rename while keeping their added order; a playlist cover follows the first song in the chosen order.
- Comments: a song menu entry, a comment server, paging, hot/latest/time sorting, search, floor replies and display settings.
- Rebranded as Lain, with local music and offline-mode controls.
- The local library scans itself incrementally after launch, on return to the foreground and at the chosen interval; only files whose modified time changed are read again.
- The local music-source settings add an audio quality dashboard: tier mix, format mix, average bitrate, lossless share and the highest-quality songs, with animated rings and bars.
- For local songs, Song Info, tag search, lyric search and metadata editing now share one panel: tags can be edited and applied, a tag search returns to the panel, and lyrics can be searched or edited on the timeline and returned; format, bitrate and path are shown on the same page.
- A random 100-song shelf is available on the home page and redraws on refresh. A streamed source can use the server's random list; when that is off or unavailable it draws from songs saved on the device, and a local library always draws locally.
- New library checkup page: songs missing tags, a cover or lyrics, plus likely duplicates grouped by title, artist and duration. It only reports; no file is changed or deleted there.
- Offline mode can use the local library or the current server's already cached songs; the database is not pruned, so leaving the mode needs no resync.

### Cache and downloads
- Automatic caching can be controlled separately for songs, playlists and artists.
- Cache and download folders are configurable; changing either asks whether to move the existing files.
- The cache limit can be unlimited or 1/2/5/8 GB; the oldest cached songs are evicted first.
- Cache tasks show waiting/downloading/paused/completed/failed per song, with pause, resume and delete per task and global stop or clear.
- Caching uses the online quality and transcode format selected for the source, and the task page shows it.
- Downloads can pick a bitrate; on mobile data they queue and continue automatically on Wi-Fi or when the app opens, with progress shown.
- The download page holds the queue and completed records, with per-task and global continue, pause and delete; completed records show their cover.
- New LAN direct switch: on the LAN the app streams from the server without transcoding and without reading the cache.
- Streamed sources add a cache storage dashboard: cached audio/covers/lyrics/metadata, cache-limit usage, download tasks, largest cached songs and both storage paths.

### Home and statistics
- The home page is the single entry point, with customisable buttons and shelf order, recently added, Navidrome statistic cards and global search.
- Home-screen widgets in 2x2 and 4x2 layouts with cover and progress.
- The listening report includes annual statistics, a monthly heatmap and top songs/albums/artists; two thirds of a track counts as a play.
- The report now opens a full-screen Year in Review: four pages for the year's hours, artist, song and album, monthly rhythm and longest listening streak.

### Interface
- Light, dark and vivid themes; song rows can show HR/SQ/HQ quality tags with a separate vivid palette.
- Settings and home layout support long-press drag reordering; comment and lyric settings are grouped more clearly.
- Server and metadata forms share the app's grouped-card style; the lyrics page has one font control.
- Song and collection lists show skeleton placeholders while loading, so the layout does not jump.
- The cover crossfades on a track change, and album, artist and playlist rows share their cover with the detail page.
- The lyrics-page cover breathes gently while playing and shifts with a slight parallax during the swipe between pages; it can be turned off with Lyrics cover motion in Settings > User interface.
- Dragging the seek bar shows the target time above it, and the progress advances every frame instead of stepping once a second.
- Song-list and player menus share one bottom action sheet: a song card at the top and a single rounded card of evenly spaced actions.
- The player menu can change replay gain, playback speed, the fade switch and the audio focus mode without going back to settings; its song card carries the same copy button as the song-list sheet.
- The player cover can switch to a vinyl record: it turns while playing, stops when paused, and has grooves, a cover label and a tonearm.
- The player menu renders the current lyric, cover and song details as a 9:16 card, saves it and opens the system share sheet.
- The share card is customisable: top text, background blur/crop/aurora/mosaic/halftone, lyric size, cover size and translation visibility, with a live preview in settings.
- Server progress reporting can be switched off in settings: the periodic now-playing position stops, while the finished-play count is kept.


## About this project

Lain is a **derivative work** of [Sylvakru](https://github.com/AfalpHy/sylvakru) (formerly Particle Music),
originally created by [AfalpHy](https://github.com/AfalpHy). It is developed here as an **independent project**,
with its own application identifier, its own release channel and its own development direction, and it no longer
takes changes from the upstream repository automatically.

The upstream project is the foundation of everything here; this repository starts from its last commit and moves
on from there. It stays open source under the same license as the upstream project —
the [Apache License 2.0](./LICENSE). Upstream copyright notices are kept in [NOTICE](./NOTICE); every change made
here is listed in the git history and summarised in the release notes of each version.

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
