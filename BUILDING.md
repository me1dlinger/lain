# 打包指南（Android）

这份文档记录把本工程打成一个可安装的 Android APK 所需的全部环境与命令，方便换一台电脑继续打包。
命令以 Windows + Git Bash 为例；macOS/Linux 把路径写法换成对应的即可。

---

## 0. 当前版本基线（每次发版后更新这里）

| 项 | 值 |
| --- | --- |
| 应用名 | Lain（中文：临音） |
| 包名 / applicationId | `com.meidlinger.lain` |
| 显示版本 versionName | `1.0.0-beta1` |
| 发布 ABI | 只发 **arm64-v8a** |
| Flutter 产物 | `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` |
| 对外分发文件名 | `lain-1.0.0-beta1-arm64-v8a.apk` |
| 最近一次规范构建的 versionCode | **946111**（对应 `--build-number 944111`） |
| 下一次打包的 build number | **944112**（预期 versionCode **946112**） |

**当前状态（2026-11-13）**

- 规范产物是 arm64 split APK；最近一次是 versionCode 946111（已核对 `aapt dump badging`，APK 约 70.4MB）。
- `build/app/outputs/flutter-apk/app-release.apk` 是误打的全量包（约 213MB、versionCode 1），**不要分发，也不要把它当作版本基线**；可以直接删除。
- 下一次打包用 `--build-number 944111`，得到 versionCode 946111；成功后把本节的“最近一次 versionCode”和“下一次 build number”各加 1。

**版本号规则**

- versionName 来自 `pubspec.yaml` 的 `version: 1.0.0-beta1+1`，同时必须同步 `lib/base/app.dart` 的 `const String versionNumber`（设置 → 关于页显示的是这个常量）。
- versionCode 由 `--build-number` 加 ABI 偏移得到；arm64-v8a 是 `buildNumber + 2000`。
- 不带 `--build-number` 时才会使用 `pubspec.yaml` 里的 `+1` 作为 versionCode（本工程曾因此打出 versionCode=1 的包）。**发版必须显式传 `--build-number`。**
- 不要改包名，不要打 universal APK，不要发 armeabi-v7a/x86_64。

---

## 1. 需要安装的东西

| 组件 | 版本 / 要求 | 说明 |
| --- | --- | --- |
| Flutter | 3.4x（本工程用 3.47.8 验证过） | `flutter --version` 能跑即可 |
| JDK | **17**（不要用 8/11） | Gradle 9 + AGP 9 要求 ≥17 |
| Android SDK | platforms;android-37.0、build-tools 37.x、NDK、CMake | 缺什么 Gradle 会提示 |
| Gradle | 用工程自带的 wrapper（`android/gradlew`） | 不要自己装 |

`android/app/build.gradle.kts` 里写死了 `compileSdk = 37`，`minSdk`/`targetSdk` 跟随 Flutter。

---

## 2. 一次性配置

### 2.1 `JAVA_HOME`

打包前把 JDK 17 指给 Gradle（每次新开终端都要设）：

```bash
export JAVA_HOME='D:\Work\JDK17'        # Windows 示例
# macOS/Linux 例：export JAVA_HOME=$(/usr/libexec/java_home -v 17)
```

### 2.2 `android/local.properties`（不提交，每台机器自己的）

内容是 SDK 与 Flutter 路径，`flutter build` 一般会自动生成；也可手写：

```properties
sdk.dir=E:\\android-sdk
flutter.sdk=E:\\Work\\flutter
```

### 2.3 `android/key.properties`（不提交，签名用）

`app/build.gradle.kts` 里 release 用这里的签名；缺少它只能打 debug。示例：

```properties
storeFile=E:/Fun/code/sylvakru/android/app/lain.jks
storePassword=******
keyAlias=lain
keyPassword=******
```

### 2.4 `~/.gradle/gradle.properties`（本机 Gradle 设置）

```properties
# 内存
# 8G 内存以下的机器务必压到 2G：rive_native / media_kit / CMake 三套原生构建
# 同时拉起时，-Xmx4G 或更高会把物理内存和 swap 吃满，Gradle daemon 会被
# OOM killer 干掉，报 "Gradle build daemon disappeared unexpectedly"。
org.gradle.jvmargs=-Xmx2G -XX:MaxMetaspaceSize=768m -XX:ReservedCodeCacheSize=192m

# 必须关掉并行：并行时 :jni 的 CMake 配置任务会互相抢临时文件
org.gradle.parallel=false

# 限制 worker 数，避免同时开太多原生编译进程
org.gradle.workers.max=2

# 跨盘 Kotlin 缓存会崩，关掉增量
kotlin.incremental=false
kotlin.compiler.execution.strategy=in-process

# 保持 daemon，冷启动很慢
org.gradle.daemon.idletimeout=86400000

# 国内网络：走代理（按自己的代理端口改）
systemProp.http.proxyHost=127.0.0.1
systemProp.http.proxyPort=7897
systemProp.https.proxyHost=127.0.0.1
systemProp.https.proxyPort=7897
systemProp.http.nonProxyHosts=localhost|127.*|[::1]|maven.aliyun.com|mirrors.cloud.tencent.com
```

---

## 3. 打包命令

### 3.1 首次 / 换了依赖后

```bash
flutter pub get
```

> Windows 上 `pub get` 如果报 **“Building with plugins requires symlink support / 请启用开发者模式”**：
> 打开「设置 → 隐私和安全性 → 开发者选项 → 开发者模式」。启用一次即可。

依赖没变化、只是重新打包时，用 `--no-pub` 跳过这一步更快。

### 3.2 打 arm64 包（唯一发布方式）

```bash
export JAVA_HOME='D:\Work\JDK17'
flutter build apk --release \
  --target-platform android-arm64 \
  --split-per-abi \
  --no-pub \
  --build-number 944105
```

产物固定为：

```text
build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

预期版本：versionName `1.0.0-beta1`，versionCode `946105`。打包后必须核对：

```bash
AAPT=/e/android-sdk/build-tools/37.0.0/aapt.exe
"$AAPT" dump badging build/app/outputs/flutter-apk/app-arm64-v8a-release.apk | head -1
```

> **不要省略 `--target-platform android-arm64 --split-per-abi`，也不要省略 `--build-number`。**
> 省略它们会产出 `app-release.apk` 全量包，versionCode 变成 pubspec 的 `+1`（曾出现 versionCode=1、约 213MB 的包），既不是发布产物，也会导致覆盖安装失败。

### 3.3 版本号（versionCode）怎么算

`android/app/build.gradle.kts` 用 `flutter.versionCode`，它来自 `pubspec.yaml` 的 `version: 1.0.0-beta1+1` 里的 `+1`，
但**打包时用 `--build-number` 覆盖**。`1.0.0-beta1` 是显示给用户的 versionName，和不带后缀的 build number 是两件事。
按 ABI 加偏移（Flutter 的分包逻辑）：

| ABI | versionCode |
| --- | --- |
| arm64-v8a | `buildNumber + 2000` |
| armeabi-v7a | `buildNumber + 1000` |
| x86_64 | `buildNumber + 4000` |
| 通用（不 split） | `buildNumber` |

**每打一个新包，`--build-number` 一定要比上一版大**，否则手机上“覆盖安装”会失败。

### 3.4 其它 ABI（只用于本地调试，不发布）

本项目只发布 arm64-v8a。需要给旧 32 位设备临时调试时：

```bash
flutter build apk --release --target-platform android-arm --split-per-abi --no-pub --build-number <下一个 build number>
```

不要打 universal（不带 `--split-per-abi`）的包：它会产出 `app-release.apk`，versionCode 取 pubspec 的 `+1`，既不是发布产物，也容易造成覆盖安装失败。

### 3.5 发版检查清单

1. 确认在 `main`，工作区干净。
2. `flutter analyze lib`，必须 0 error。
3. 用 3.2 节的命令，`--build-number` 取第 0 节的“下一次 build number”。
4. 用 aapt 核对 versionName/versionCode；versionCode 必须大于设备上已安装的版本。
5. 产物拷出并命名为 `lain-1.0.0-beta1-arm64-v8a.apk`（版本名变了就改文件名）。
6. 把第 0 节的“最近一次 versionCode”和“下一次 build number”各加 1，再提交。

如果设备连接了电脑，可以先查已安装版本：

```bash
adb shell dumpsys package com.meidlinger.lain | grep -E "versionCode|versionName"
```

versionCode 必须严格递增。如果设备上曾装过更高 versionCode 的包（例如历史误出的 946088/946100），下一次构建要大于那个数。

---

## 4. 改了代码后要注意的生成步骤

### 4.1 改了数据库表（`lib/base/data/database.dart`）

```bash
dart run build_runner build
```

会重新生成 `database.g.dart`。改表结构时必须同时把 `schemaVersion` 加 1，并在 `onUpgrade` 里写迁移。

### 4.2 改了 `lib/l10n/*.arb`

```bash
flutter gen-l10n
```

会更新 `lib/l10n/generated/` 下的文件。**en 和 zh 两个 arb 都要加同一个 key**，只加一边会导致另一边回退成英文。

### 4.3 改了 `pubspec.yaml` 的版本

`version: 1.0.0-beta1+1` 中的 `1.0.0-beta1` 是显示给用户的版本名，`+1` 不用于正式打包（用 `--build-number`）。

改版本名时**必须同时改两处**，否则关于页和安装包会不一致：

1. `pubspec.yaml` 的 `version:`
2. `lib/base/app.dart` 的 `const String versionNumber = ...`

然后重新打包；Android 的 versionName 会用 pubspec 的值，关于页用 `versionNumber`。

---

## 5. 检查与测试

```bash
flutter analyze lib
flutter test
```

> 已知：`test/play_queue_logic_test.dart` 里有 8 个用例在测试环境就失败（`MyAudioMetadata` 构造需要非空 path），
> 与本工程打包无关，其余用例应全绿。

---

## 6. 常见问题

### 6.1 `:jni:configureCMakeRelWithDebInfo[...]` 报 “文件正被另一个程序使用 / 另一个程序正在使用此文件”

C++ 元数据生成会在 `build/jni/...` 写一个 timing 文件，**杀毒软件（360、Defender 等）扫描新文件时会短暂独占它**。

处理顺序：

1. 关掉/停用实时扫描（最简单）。
2. 还不行就停掉 Gradle daemon 再试：`cd android && ./gradlew --stop`。
3. 若杀毒软件没法关，可临时把 `jni` 模块的中间产物挪出工程目录：在 `android/build.gradle.kts`
   末尾临时加
   ```kotlin
   subprojects {
       if (project.name == "jni") {
           project.layout.buildDirectory.value(
               project.objects.directoryProperty().fileValue(
                   File(System.getProperty("java.io.tmpdir"), "lain-jni"),
               ),
           )
       }
   }
   ```
   **这是本机绕行补丁，打包成功后请删掉**（APK 输出路径不变）。

> `:jni` 这个模块不是本工程加的，它来自 `path_provider` → `path_provider_android` → `jni` 这条
> 普通插件依赖链，和 USB/DAC 分支无关，任何分支打包都会有。

### 6.2 Gradle 报 `Gradle requires JVM 17 or later ... currently JVM 8`

没设 `JAVA_HOME`。见 2.1。

### 6.3 `pub get` / 构建提示 symlink / 开发者模式

Windows 打开开发者模式（见 3.1）。临时应急可用 `--no-pub`（前提是 `.dart_tool/package_config.json` 已存在）。

### 6.4 下载依赖超时

配好 2.4 的代理；Gradle 发行版可用腾讯镜像（`android/gradle/wrapper/gradle-wrapper.properties` 里已设置）。

### 6.5 `compileSdk = 37` 提示需要 android-37.0

**这一项现在已经是工程里的固定配置，不要删。** `android/app/build.gradle.kts` 的 `android {}` 里有：

```kotlin
compileSdk = 37
compileSdkMinor = 0
```

原因：Android SDK 把 platform 37 装成了目录 `android-37.0`，`package.xml` 里写的是
`<api-level>37.0</api-level>`，而 AGP 9.0.1 按 `android-37` 这个 hash string 去查找，找不到就报：

```
Failed to find target with hash string 'android-37' in: <sdk>
```

`compileSdkMinor = 0` 让 AGP 按 `android-37.0`（即 37 + minor 0）解析，问题消失。
手动把平台目录改名成 `android-37` 是**没用的**：AGP 会重新下载一份 `android-37.0` 覆盖回去。

### 6.6 打包很慢

- 不要删 `build/`：增量构建快很多。
- 日常只打 `--target-platform android-arm64 --split-per-abi`。
- 保持 Gradle daemon 常驻（2.4 里的 `idletimeout`）。

### 6.7 `Gradle build daemon disappeared unexpectedly`

不是代码问题，是**内存被吃爆**：rive_native、media_kit、jni 三套原生构建会同时拉起
CMake / Kotlin / R8 进程，8G 内存 + 4G swap 很容易打满。按 2.4 把
`org.gradle.jvmargs` 降到 `-Xmx2G`、`org.gradle.workers.max=2`。

还要确认**工程自带的** `android/gradle.properties` 里的 `org.gradle.jvmargs` 也压下来了——
它的优先级高于 `~/.gradle/gradle.properties`，只改全局是不生效的。

彻底恢复的办法：`cd android && ./gradlew --stop`，然后重试。若之前有被中断的
`flutter build` 残留（`dartvm` / `dartaotruntime` 进程 PPID 变成 1，各占 1GB 以上），也一并清掉。

### 6.8 `No key with alias '...' found in keystore`

`android/key.properties` 里的 `keyAlias` 必须和 jks 文件里**实际生成的别名一致**。
改名后容易只改了 `key.properties` 而忘了 jks 里还是旧别名。用下面的命令查实际别名：

```bash
keytool -list -keystore android/<your>.jks -storepass <pass>
```

对不上就重新生成（旧包也就签不了名了，所以正式发布前务必确认 alias）:

---

## 7. 提交到仓库的边界

**可以提交**：`android/build.gradle.kts`、`android/app/build.gradle.kts`、`android/gradle.properties`、`android/gradle/wrapper/*`、`pubspec.yaml`/`pubspec.lock`、`lib/`、图标资源等。

**不要提交**（已在 `.gitignore`）：
- `android/key.properties`（签名密码）
- `android/local.properties`（本机 SDK/Flutter 路径）
- `build/`、`.dart_tool/`（构建产物）
