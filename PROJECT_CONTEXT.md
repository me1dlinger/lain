# Lain（临音）工程背景 — 给下一个对话

> 整理时间：2026-11-12
> 工作目录：`/vol1/1000/Data/codes/sylvakru/sylvakru`
> 当前分支：`rebrand/lain`，HEAD = `5fc9aeb`

---

## 一、工程是什么

一个 Flutter 跨平台音乐播放器（Android / iOS / Windows / Linux / macOS），支持本地、WebDAV、Navidrome、Emby、飞牛音乐。

- **原名** Sylvakru（森露），上游 [AfalpHy/sylvakru](https://github.com/AfalpHy/sylvakru)，Apache-2.0
- **现名** **Lain（临音）**，由用户 Meidlinger 独立维护，不再作为 fork
- 用户几乎只在 **Android** 上开发和验证；iOS / macOS / Windows / Linux 同源但未实测

---

## 二、环境（这套工具链是现成的，直接用）

```bash
export PATH=$HOME/toolchain/flutter/bin:$PATH      # Flutter 3.47.8（与工程要求一致）
export JAVA_HOME=$HOME/toolchain/jdk               # Temurin 17.0.21
export ANDROID_HOME=$HOME/toolchain/android-sdk
export ANDROID_SDK_ROOT=$ANDROID_HOME
export GRADLE_USER_HOME=$HOME/toolchain/gradle-home
export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890
export no_proxy=localhost,127.0.0.1,maven.aliyun.com,mirrors.cloud.tencent.com
```

- 代理 **127.0.0.1:7890** 必须配，直连不通
- 本机是 NAS，**内存只有 8G + 4G swap**，Gradle 堆必须压到 `-Xmx2G`（项目 `android/gradle.properties` 已改好，别调回去）
- 机器：Debian 12，无 sudo，无 docker 权限

### 打包命令

```bash
flutter build apk --release \
  --target-platform android-arm64 \
  --split-per-abi --no-pub \
  --build-number <递增的数字>
```

产物：`build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`

### 打包踩过的坑（都已解决，别重踩）

| 坑 | 解法 |
| --- | --- |
| `Failed to find target with hash string 'android-37'` | `android/app/build.gradle.kts` 里的 `compileSdkMinor = 0`，**不要删** |
| `Gradle build daemon disappeared unexpectedly` | 内存爆了。`-Xmx2G` + `org.gradle.workers.max=2`，打之前 `free -m` 确认可用 ≥3G |
| `No key with alias` | `android/key.properties` 的 `keyAlias=lain`，jks 是 `android/lain-test.jks`（测试签名，密码 `testpass`） |
| 驱动下载超时 | 必须走代理；media_kit 的 jar 首次会失败一次自动重试 |

**签名文件不要提交**：`.gitignore` 已加 `/android/key.properties`、`/android/*.jks`。
**`android/local.properties`** 需存在，内容指向 `~/toolchain/android-sdk` 与 `~/toolchain/flutter`。

---

## 三、改名后的标识（全工程已统一）

| 项 | 值 |
| --- | --- |
| 应用名 | 中文 **临音** / 英文 **Lain** |
| Dart 包名 | `lain`（`package:lain/...`） |
| Android applicationId / namespace | `com.meidlinger.sylvakru` |
| MethodChannel 前缀 | `com.meidlinger.sylvakru.*` |
| iOS bundle id / App Group | `com.meidlinger.sylvakru` / `group.com.meidlinger.sylvakru` |
| macOS PRODUCT_NAME / Linux BINARY / Windows BINARY | Lain / lain / Lain |
| 数据文件 | `lain_playlists.json`、`lain.lock`、`lain.port`、`lain.keep` |

> ⚠️ 包名 `com.meidlinger.sylvakru` 里仍带 `sylvakru` 字样。用户明确指定的，**不要再自作主张改**。真要改需同步这 8 处：build.gradle.kts、kotlin 目录、iOS pbxproj、macOS AppInfo.xcconfig、linux CMakeLists、entitlements、main.dart 的 setAppGroupId、各 MethodChannel。

---

## 四、本轮已完成的提交

```
5fc9aeb fix(cache): the playlist download button downloaded nothing
e684adc fix(media): a head unit stuck on the previous track, and a stream replaying itself
7b8e356 docs: record the successful build and the review report
f00592e chore(rebrand): rename the project to Lain (临音)
0a14bef (origin/main) 用户原来的最后提交
```

详细报告在 [`REBRAND_AND_REVIEW.md`](./REBRAND_AND_REVIEW.md)（改名合规性 + 打包记录 + 跨平台调研）。

### 三个 bug 的根因（都修了，但未真机验证）

**1. 流媒体播完从头重播**
`audio_handler.dart` 的 `completed` 监听里，"假完成"守卫（缓冲段结束）原本对所有源生效。真结尾时 `position` 偶尔滞后 `duration` 一帧，判成假完成就 `_player.play()` 从头播。已限定 `isStreamSource` 才启用。

**2. 切歌后车机元数据完全不更新**
audio_service 包内部 `_observeMediaItem()` 的 `file://` 分支是唯一没有 `operationId != artFetchOperationId` 竞态检查的分支。连续切歌时旧的 `setMediaItem` 晚于新的落地，车机被回填成上一首。修复：Android 上封面改用 `content://`（FileProvider 已配好），走同步直发的分支。

**3. 缓存菜单下载按钮什么都不下载**
按钮接的是 `precacheSongs()`，它**只取封面和歌词**，不下载音频。新增 `library.downloadSongsToCache()` 走 `tryAddCache()`，已改接。

---

## 五、已知未修 / 待办

- **长按刷新艺术家缓存**：入口只挂在竖屏 `collection_list_page.dart`，**桌面端不可达**
- **`endDrawerNotifier` 死状态**：抽屉已删，但设置里还读写它（无功能影响，技术债）
- **`sidebarColor`** 仍注册在 colorManager（无影响）
- **字体选择器不扫 Linux 系统字体**（`font_picker_layer.dart:60`）
- **iOS 竖屏振动设置曾被空 if 吞掉** —— 已修
- **设置项计数** 曾硬编码过期 —— 已改为 19/17/15
- **本地源下缓存下载按钮空跑**：`tryAddCache` 第一行就 return 了本地源，该按钮在本地源下无意义（用户尚未决定是否隐藏）
- **批量缓存无断点续传**：串行下载，App 被杀后已完成的保留，剩余的不续

---

## 六、和用户协作的重要约定

1. **不要自己打包** —— 用户明确要求：**他说"打包"才打包**。提交可以主动。
2. **不要自己拉上游仓库** —— 用户说"我跟上游已经几乎没关系了"。
3. **不要自作主张改包名/品牌** —— 命名已定，改动前必须问。
4. 用户会中途喊"你一直停" —— 意思是 agent 卡住了，**直接继续干活**，不要解释。

---

## 七、调试建议

媒体会话相关日志用：

```bash
adb logcat | grep '\[media\]'
```

会看到：
```
[media] publish id=... art=file|none bitmap=yes|none fetch=... lyric="..." t=+123ms
[media] small art t=...
[media] cover ready for <id> in <ms>ms t=+<ms> (on disk: true|false)
[media] ready for <id> in <ms>ms
```

代码里 `_mediaLog()` 同时写 app 日志和 `debugPrint`。
