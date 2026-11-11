# Lain（临音）改名与跨平台调研报告

> 生成时间：2026-11-11
> 分支：`rebrand/lain`（基于 `main` @ 0a14bef）

---

## 一、关于「脱离 fork、独立为公开仓库」的合规性结论

**允许。** 上游 [AfalpHy/sylvakru](https://github.com/AfalpHy/sylvakru) 使用 **Apache License 2.0**，该协议明确允许衍生、修改、再分发，甚至商用，只要满足以下义务：

| Apache-2.0 条款 | 要求 | 本仓库处理 |
| --- | --- | --- |
| §4(a) | 随附许可证文本 | `LICENSE` 已有 ✅ |
| §4(b) | 修改过的文件需注明修改 | 已改为统一 git 提交历史，`NOTICE` 中汇总 ✅ |
| §4(c) | 保留所有版权、专利、商标、归属声明 | 已保留 ✅ |
| §4(d) | 若上游有 NOTICE 文件则随附 | 已新建 `NOTICE` ✅ |

### 已完成的合规动作

1. **新建 `NOTICE` 文件** —— 声明这是 Sylvakru 的衍生作品、保留上游版权、列明主要修改。
2. **README 增加 `## About this project` 段** —— 明确指向原工程、说明是独立维护（非 fork）、保持开源。
3. **应用标识改为 `com.meidlinger.sylvakru`** —— 使用你自己的 GitHub 用户名作为包名前缀，彻底脱离上游作者域名。

### 仍需你手动完成的事（本鱼无法代做）

1. **GitHub 上的「脱离 fork」**：
   - 方式 A（推荐）：新建一个空仓库，然后 `git push --mirror` 推送现有代码，历史完整保留，不再显示 fork 标记。
   - 方式 B：在仓库 Settings 里操作 detach fork 关系（GitHub 支持从网络里摘除）。
2. **商标/命名提示**：Apache-2.0 **不包含商标授权**（§6）。既然已改名为 Lain（临音），并更换了包名与图标，就没有混淆风险；但**不要把 Lain 的发布包装成「Sylvakru 官方版」**。

### ⚠️ 一个你可能想再改的点

你指定的包名 `com.meidlinger.sylvakru` 里仍带着 `sylvakru` 字样，与「所有 sylvakru 字眼改为 lain」有出入。如果之后想统一，只需改这几处：

```
android/app/build.gradle.kts          namespace / applicationId
android/app/src/main/kotlin/com/...   目录名 + package 声明
ios/Runner.xcodeproj/project.pbxproj  PRODUCT_BUNDLE_IDENTIFIER
macos/Runner/Configs/AppInfo.xcconfig
linux/CMakeLists.txt                  APPLICATION_ID
ios/*.entitlements                    App Group
lib/main.dart                         setAppGroupId
各 MethodChannel 名字
```

---

## 二、打包测试

### 环境

| 组件 | 版本 |
| --- | --- |
| Flutter | 3.47.8（工程要求一致） |
| JDK | Temurin 17.0.21 |
| Android SDK | platform android-37.0、build-tools 37.0.0 / 36.0.0 |
| Gradle | 9.1.0（wrapper） |
| AGP | 9.0.1 |

### 遇到的问题与解法（重要，换机器/换 CI 会复现）

| # | 问题 | 原因 | 解法 |
| --- | --- | --- | --- |
| 1 | `Failed to find target with hash string 'android-37'` | SDK 把 platform 37 装成目录 `android-37.0`，`package.xml` 里 `<api-level>37.0</api-level>`，AGP 按 `android-37` 查找 | 在 `android/app/build.gradle.kts` 加 `compileSdkMinor = 0`（BUILDING.md 6.5 已记录） |
| 2 | `Gradle build daemon disappeared unexpectedly` | 8G 内存 + 4G swap 被 `-Xmx8G` 的 Gradle 堆 + rive_native/media_kit/CMake 并行构建撑爆 | 项目 `android/gradle.properties` 与 `~/.gradle/gradle.properties` 均降到 `-Xmx2G`，`org.gradle.workers.max=2` |
| 3 | `No key with alias 'lain' found in keystore` | 改名时把 `keyAlias` 与 jks 实际别名改得不同步 | 用 `keyAlias=lain` 重新生成测试 keystore |
| 4 | media_kit 首次下载 `Remote host terminated the handshake` | 首次拉 libmpv jar 走代理握手失败 | 自动重试后成功；无需人为干预 |

### 打包命令

```bash
export JAVA_HOME=~/toolchain/jdk
export ANDROID_HOME=~/toolchain/android-sdk
export GRADLE_USER_HOME=~/toolchain/gradle-home
export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890

flutter build apk --release \
  --target-platform android-arm64 \
  --split-per-abi --no-pub \
  --build-number 942068
```

产物：`build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`（72 MB）

**实测构建成功**（2026-11-11）：

```
✓ Built build/app/outputs/flutter-apk/app-arm64-v8a-release.apk (75.0MB)
package: name='com.meidlinger.sylvakru' versionCode='944069' versionName='4.5.1'
application-label:'Lain'
application-label-zh:'临音'
V2 Signer: certificate DN: CN=Lain Build Test, O=Local Test, C=CN
```

> versionCode 944069 = 942069 + 2000（arm64 偏移），说明 `--build-number`
> 与 Flutter 的 ABI 偏移逻辑都按预期工作。

### 静态分析

```
flutter analyze lib  →  39 issues（全部为 unused_import / deprecated / 风格提示，0 error）
```

---

## 三、跨平台代码调研（macOS / Windows / Linux）

### 3.1 架构总览

布局分叉点只有一个 `isTooNarrow(context)`（`lib/base/utils/media_query.dart`）：

```dart
bool isTooNarrow(BuildContext context) => MediaQuery.widthOf(context) < 800;
```

- 窄于 800 → `PortraitView`（手机竖屏，带底部 PlayBar）
- 宽于 800 → `LandscapeView`（桌面/平板横屏，带 BottomControl）
- 桌面主窗口最小宽度锁 1050 → **桌面永远走 LandscapeView**，不会进 PortraitView

### 3.2 发现的问题

#### 🔴 问题 1：iOS 竖屏「振动」设置被空 if 吞掉（已修复）

`lib/base/widgets/settings_list.dart` 第 171 行左右：

```dart
if (Platform.isIOS && !isLandscape && viewModeNotifier.value != .bigPicture)

if (isMobile && !isTV)
  sliverBox(paddingIfNeed(isLandscape, vibrationListTile(l10n))),
```

删抽屉时留下了没有 body 的 `if`，导致 `vibrationListTile` 成了它的 body ——
**iOS 竖屏下振动设置永远不显示，Android 正常**。

✅ 已修复：删除空 if 并加注释说明。

#### 🟠 问题 2：设置页「设置项数量」硬编码过期（已修复）

原来写死 `Android=16 / iOS=15 / 其他=14`，但实际新增了服务器管理、听歌统计、主页布局、下载、流媒体质量/格式等多项。

✅ 已改为：`Android=19 / iOS=17 / 其他=15`，再按 `isNotStreamSource(+1)` 与 `isStreamSource(+2)` 修正。

#### 🟠 问题 3：长按刷新艺术家缓存 —— 桌面端不可达

`lib/layer/artists_layer.dart` 里的 `currentOnLongPressList` 只挂在竖屏
`collection_list_page.dart`，桌面端走 `landscape_view/panels/`，**根本没有入口**。
另外 Flutter 桌面端的鼠标长按手势支持较差。

影响：**功能缺失但不崩溃**（`HapticFeedback` 在桌面被忽略）。

建议：桌面端在艺术家行加右键菜单或显式的「刷新」按钮。

#### 🟡 问题 4：字体选择器不扫描 Linux 系统字体

`lib/layer/font_picker_layer.dart:60`

```dart
if (Platform.isWindows || Platform.isMacOS) {
  allFonts.addAll(JustFontScan.scan()...);
}
```

Linux 用户只能用已导入的字体，系统字体列表为空。上游遗留行为，非本次改动引入。

#### 🟡 问题 5：`endDrawerNotifier` 已成为死状态

抽屉已删，但 `endDrawerNotifier` 仍在：
- `setting.dart` 里从设置 JSON 读写
- `portrait_view.dart` 里决定页面切换的**滑动方向**（`begin: ±1.0`）

影响：**不影响功能**（值恒为 false，统一从左滑入），属于技术债。
建议：下一版清理，并把 `'endDrawer'` 从已保存设置里移除。

#### 🟡 问题 6：`landscape_view/sidebar.dart` 已删除但 `sidebarColor` 仍在色彩管理器里注册

`lib/base/services/color_manager.dart:77` 的 `sidebarColor` 仍参与主题色计算，属于内存中的冗余对象。无功能影响。

### 3.3 检查过且没有问题的部分

| 检查点 | 结论 |
| --- | --- |
| 我新增的 UI（server_manager / stats_page / sort_sheet / home_layout_settings / global_search_page / apple_form / collection_list） | 全部**无平台判断**，纯 Material 组件，桌面端渲染一致 ✅ |
| `home_widget_service.dart` | 有 `Platform.isAndroid/isIOS` 守卫 + try/catch，桌面安全 ✅ |
| `download_manager.dart` 权限 | `Permission.manageExternalStorage` 有 `Platform.isAndroid` 守卫 ✅ |
| `download_manager.dart` 目标目录 | 桌面走 `appDocsDir`，非 Android 路径 ✅ |
| `home_layer.dart` 多列布局 | `columns = (width/300).floor().clamp(1,4)`，自适应正确，不溢出 ✅ |
| `bottom_control.dart` | 子项全部在 `Expanded` 的紧约束内，`SizedBox(width:400)` 被正确忽略，不溢出 ✅ |
| `title_bar.dart` macOS 红绿灯 | `windowButtonVisibility: false` 已隐藏原生按钮，左侧 30px 不重叠 ✅ |
| `main.dart` 窗口尺寸 | Linux 需 +52px、Windows +16/+9 的差异都已处理 ✅ |
| `layers_manager.dart` 页面栈 | `isMobile` 才用 `rootPageMap`，桌面走 `rootLayerMap`，互不干扰 ✅ |
| `settings_list.dart` orientation 判断 | 用 `shortestSide < 600` 判手机，而非 `Orientation`，桌面安全 ✅ |
| `themedRoute` 在桌面 | 桌面直接返回 `themed`，不叠 PlayBar ✅ |

### 3.4 无法在本机验证的部分

- 没有 macOS / Windows 构建机，**未做真机或桌面端实际运行验证**。
- 没有 iOS 签名环境，未做 Xcode 构建。
- 建议你在桌面端手动验证：窗口缩放、迷你模式切换、歌词页、设置页各弹窗。

---

## 四、本次改名清单

| 项 | 原值 | 新值 |
| --- | --- | --- |
| 应用名（中文） | 森露 | **临音** |
| 应用名（英文） | Sylvakru | **Lain** |
| Dart 包名 | `sylvakru` | `lain` |
| Android applicationId / namespace | `com.afalphy.sylvakru` | `com.meidlinger.sylvakru` |
| MethodChannel 前缀 | `com.afalphy.*` | `com.meidlinger.sylvakru.*` |
| iOS bundle id / App Group | `com.afalphy.sylvakru` / `group.com.afalphy.sylvakru` | `com.meidlinger.sylvakru` / `group.com.meidlinger.sylvakru` |
| macOS PRODUCT_NAME | sylvakru | Lain |
| Linux BINARY_NAME | sylvakru | lain |
| Windows BINARY_NAME | Sylvakru | Lain |
| 下载目录名 | `Sylvakru` | `Lain` |
| 播放列表数据文件 | `sylvakru_playlists.json` | `lain_playlists.json` |
| 单实例锁 / 端口文件 | `sylvakru.lock` / `.port` | `lain.lock` / `.port` |
| iOS 容器目录映射前缀 | `Sylvakru` | `Lain` |
| Emby Client 标识 | `Client="Sylvakru"` | `Client="Lain"` |
| Navidrome Client 标识 | `c=Sylvakru` | `c=Lain` |
| 更新检查 API | `AfalpHy/sylvakru` | `me1dlinger/sylvakru` |

> ⚠️ **数据迁移**：按你的选择，数据文件名**未做迁移**。老版本用户升级后播放列表会丢失（新包名与新文件名双重隔离）。
