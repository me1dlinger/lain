# 简体中文 | [English](./README-en.md)

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
[AfalpHy](https://github.com/AfalpHy) 创建。本仓库作为**独立工程**维护，有独立的应用标识、独立的发行渠道和独立的
发展方向，也不再自动跟随上游仓库的改动。

上游工程是这里一切的基础，本仓库从它的最后一个提交出发，在此之上继续演进。本工程仍以与上游相同的许可证开源——
[Apache License 2.0](./LICENSE)；上游的版权声明保留在 [NOTICE](./NOTICE) 中，本工程所做的每一处改动都记录在
git 历史里，并在各版本的发行说明中汇总。

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
