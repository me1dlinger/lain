# [English](./README.md) | 简体中文

<div align="center">
  <img src="./app_icons/icon.png" width="160" alt="Lain Icon"/>

  <br />

  # 临音 (Lain)

  _"数字世界里的私人音乐绿洲。"_

</div>

临音是一个面向本地曲库与自建媒体服务的跨平台音乐播放器，支持 Android、iOS、Windows、Linux 与 macOS。

目前支持的音源：
- 本地
- WebDAV
- Navidrome
- Emby
- 飞牛音乐（特别感谢 [huya688zdx](https://github.com/huya688zdx) 的贡献）

## 关于本工程

临音是基于 [Sylvakru](https://github.com/AfalpHy/sylvakru)（原 Particle Music）的**二次开发**工程，原工程由
[AfalpHy](https://github.com/AfalpHy) 创建。本仓库作为**独立工程**维护，不采用 GitHub fork 的形式：它有独立的
应用标识、独立的发行渠道和独立的发展方向，也不再自动跟随上游仓库的改动。

上游工程是这里一切的基础，本仓库从它的最后一个提交出发，在此之上继续演进。本工程仍以与上游相同的许可证开源——
[Apache License 2.0](./LICENSE)；上游的版权声明保留在 [NOTICE](./NOTICE) 中，本工程所做的每一处改动都记录在
git 历史里，并在下方与各版本的发行说明中汇总。

### 二次开发了哪些东西

**工程与标识**

- 应用名：Sylvakru / 森露 → **Lain / 临音**；Dart 包名 `sylvakru` → `lain`。
- 应用标识与所有 MethodChannel、iOS Bundle id、App Group、Linux 与 Windows 可执行文件名统一为
  `com.meidlinger.sylvakru`。
- 运行时文件（播放列表、单实例锁与端口、iOS 保活文件）与下载目录改为 `lain_*` / `Lain`。
- 检查更新指向本仓库；README 按新工程重写（中英双语），并新增 [BUILDING.md](./BUILDING.md)。

**播放与媒体会话**

- 流媒体在「缓冲段结束」时被误报为「歌曲结束」的歌不会再自己重播一遍：完成事件按播放位置分类，同一首的结尾
  只处理一次，正在打开的那首不会再被打开第二次。
- 车机不会再卡在上一首：媒体项与歌曲在同一时刻下发，Android 上的封面改用 `content://` 交付，避免会话更新
  之间的竞态。
- 流播完不会从头重播：中继服务把已知的 `Content-Length` 透传下去，传输停顿不会被当成文件结束。
- 应用日志（设置里可导出）与 `adb logcat` 中的 `[media]`、`[playback]` 诊断行。

**曲库与元数据**

- 艺术家归属只由一个规则决定，艺术家列表、艺术家页与大图画视图共用：tag 里 `D、E`、`D, E` 这类写法会按半角与
  全角逗号、顿号一并拆分，艺术家不会再收进「名字只是被包含在 tag 里」的歌。
- 艺术家简介与头像按名字跨音源、跨启动缓存，并可在艺术家列表里长按刷新。

**Android 体验**

- 单一主页、服务器管理、排序抽屉、听歌统计、桌面小组件（正在播放与播放列表）、系统媒体会话里的歌词行、
  播放列表与下载、播放列表导入导出。
- 在线源的歌曲列表标出哪些已经缓存，三点菜单里能直接查看某首歌缓存的封面、歌词与占用大小。
- 播放列表的下载按钮现在真的会下载音频。

**打包**

- 支持 `compileSdk 37.0`，为低内存机器压低 Gradle 堆，打包路径记录在 [BUILDING.md](./BUILDING.md)；
  Linux 侧提供 `generate_deb.sh` / `generate_rpm.sh`。

**随本工程一起修掉的问题**

- iOS 竖屏「振动」设置曾被一个空 `if` 吞掉。
- 设置页显示的「设置项数量」曾被硬编码成过期数字。
- 长按刷新艺术家缓存此前只在竖屏艺术家列表里可达。

## USB 独占模式（Android）

USB 独占模式不在本工程中；需要该功能请使用由 [huya688zdx](https://github.com/huya688zdx) 维护的
[上游 fork](https://github.com/huya688zdx/sylvakru)。

## 支持的格式

| 文件格式 | 元数据格式                   |
|----------|------------------------------|
| AAC (ADTS) | `ID3v2`, `ID3v1`           |
| Ape        | `APE`, `ID3v2`\*, `ID3v1`  |
| AIFF       | `ID3v2`, `Text Chunks`     |
| FLAC       | `Vorbis Comments`, `ID3v2`\* |
| MP3        | `ID3v2`, `ID3v1`, `APE`    |
| MP4        | `iTunes-style ilst`        |
| MPC        | `APE`, `ID3v2`\*, `ID3v1`\* |
| Opus       | `Vorbis Comments`          |
| Ogg Vorbis | `Vorbis Comments`          |
| Speex      | `Vorbis Comments`          |
| WAV        | `ID3v2`, `RIFF INFO`       |
| WavPack    | `APE`, `ID3v1`             |

\* 因官方不支持，该类标签**只能读取**。

## 音频处理

- [audio_tags_lofty](https://github.com/AfalpHy/audio_tags_lofty.git) —— 读写音频标签（基于 lofty）
- [media_kit](https://github.com/media-kit/media-kit.git) —— 音频播放（基于 mpv/FFmpeg）

## 运行与构建

按照 [Flutter 官方安装文档](https://docs.flutter.dev/install/manual) 安装 Flutter。

### Ubuntu / Debian

```shell
# Flutter 依赖：
sudo apt install clang lld cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libsecret-1-dev

# 音频库
sudo apt install libmpv-dev

git clone git@github.com:me1dlinger/lain.git
cd lain
# 检查开发环境
flutter doctor -v
# 调试运行
flutter run
# 发布模式运行
flutter run --release
# 构建
flutter build linux
# 需要 .deb 包
flutter build linux && ./generate_deb.sh

# 需要 .rpm 包
sudo apt install rpm
flutter build linux && ./generate_rpm.sh
```

### Windows

安装 [Visual Studio](https://visualstudio.microsoft.com/)。

```shell
git clone git@github.com:me1dlinger/lain.git
cd lain
# 检查开发环境
flutter doctor -v
# 调试运行
flutter run
# 发布模式运行
flutter run --release
# 构建
flutter build windows
```

### macOS 与 iOS

按照 [Apple 开发者下载页](https://developer.apple.com/download/all/) 安装 Xcode 与命令行工具。

```shell
git clone git@github.com:me1dlinger/lain.git
cd lain

# 安装 CocoaPods
brew install cocoapods

# 检查开发环境
flutter doctor -v
# 调试运行
flutter run
# 发布模式运行
flutter run --release
# 构建
flutter build macos

# 构建未签名的 ipa
flutter build ios --release --no-codesign && \
mkdir -p Payload && \
cp -r build/ios/iphoneos/Runner.app Payload/ && \
zip -r lain.ipa Payload && \
rm -rf Payload
```

### Android

安装 [Android Studio](https://developer.android.com/studio) 与 Android SDK 命令行工具。

```shell
git clone git@github.com:me1dlinger/lain.git
cd lain
# 接受 SDK 许可
flutter doctor --android-licenses
# 检查开发环境
flutter doctor -v
# 调试运行
flutter run
# 发布模式运行
flutter run --release
# 构建
flutter build apk
# 按 ABI 拆分
flutter build apk --split-per-abi
# 构建 TV 版
flutter build apk --dart-define=TV=true
```

本工程 Android 侧需要的工具链说明（`compileSdk 37.0`、JDK 17、小内存机器下调低 Gradle 堆）见
[BUILDING.md](./BUILDING.md)。

## 截图

### 移动端

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

### 桌面端

![](./screenshots/desktop0.png)
![](./screenshots/desktop1.png)
![](./screenshots/desktop2.png)
![](./screenshots/desktop3.png)
![](./screenshots/desktop4.png)
![](./screenshots/desktop5.png)
![](./screenshots/desktop6.png)

## 许可证

[Apache License 2.0](./LICENSE)。临音是基于 [AfalpHy](https://github.com/AfalpHy) 的
[Sylvakru](https://github.com/AfalpHy/sylvakru) 的二次开发工程，上游版权声明见 [NOTICE](./NOTICE)。
