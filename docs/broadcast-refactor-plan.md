# 车机广播重构方案

> 状态：核心行为已实现（2026-11-20）；类级拆分仍可按后续阶段继续
> 目标版本：下一批
> 对比基线：`sylvakru` 4.6.1（`E:\Fun\code\sylvakru-src`）与当前 `lain`（`6d21662`）

## 0. 最新代码已经完成的止血

在 `6d21662` 里已经做了几项有效修复，方案不会推翻它们：

- 自定义布局现在是歌词开关：布局里放了原词/翻译，就按布局取歌词。
- 恢复了整首歌稳定的 media id，不再给歌词行加 `#序号`。
- 经典蓝牙路由有了独立的直接发布、60ms 状态补发、切歌后 0/450ms/2s 补发。
- 经典蓝牙不再发布浏览队列，避免车机读队列项而绕过歌词。
- 经典蓝牙增加完整封面形态：`artUri` + 可抓取 URI + `artCacheFile` 位图。
- 增加“经典蓝牙广播”手动强制开关，处理路由识别不到的车机。

这些修复解决的是“当前实现下的具体故障”。本方案要解决的是更底层的问题：文本、歌词、封面仍然共用同一个发布函数和同一个时间门，仍然会在不同源/车机组合下互相拖累。

### 本次已实现（2026-11-20）

- 歌词更新对所有车机路径立即发布，不再只对经典蓝牙 force；发布后统一补 `PlaybackState`。
- `load()` 在播放器打开、会话激活后强制重发当前条目，修复首曲/切歌时车机错过早期 metadata。
- `play()` 在会话激活后对智能互联路径再补发一次当前条目。
- 无损切歌（gapless）的切歌发布改为强制立即发布。
- 封面小图生成失败时回退原图路径，并强制刷新媒体会话；本地封面不再因为缩图失败而整张消失。
- 保留 `6d21662` 的稳定 media id、经典蓝牙队列抑制和自定义布局逻辑。

`updateServiceMediaItem()` 仍然是文本/封面共享的 `MediaItem` 构造器，但触发、状态补发和封面重试已经独立：文本更新不等封面，封面更新也不改文本。后续阶段可以按文档继续把构造器拆成两个发布器类。

## 1. 结论

当前文本广播和封面广播耦合在一个带延迟门的 `MediaBroadcaster` 里，而且文本更新路径与 `sylvakru` 已验证可用的实现相差很大。继续在当前逻辑上打补丁，会不断出现“这个车好了、那个源坏了”的问题。

建议把广播拆成两个独立发布器：

1. **文本发布器（NowPlayingPublisher）**
   - 以 `sylvakru` 的直接发布逻辑为基线。
   - 每次切歌、每次歌词行变化，立即重建并发布 `MediaItem`。
   - 发布后立即补一次 `PlaybackState`，让车机重新读取当前条目。
   - 自定义两行/三行歌词只放在“生成文本”这一层，不参与发布时机。

2. **封面发布器（ArtworkPublisher）**
   - 独立解析、缩小、重试和发布封面。
   - 文本更新永远携带“当前已发布的封面”，不会因为歌词更新把封面清空。
   - 封面失败时回退原图；本地封面必须同时覆盖 `artCacheFile` 和可用的 `artUri`。
   - 封面成功或失败都只触发一次“带当前文本的封面刷新”，不反过来影响歌词。

这样无论本地源、Navidrome、Emby、WebDAV，还是智能互联车机、纯蓝牙 AVRCP 车机，文本和封面都有自己的稳定路径。

---

## 2. 两个工程的广播差异

### 2.1 `sylvakru` 4.6.1 的做法

关键代码：`sylvakru-src/lib/base/audio_handler.dart`

- 在 `load()` 中先打开播放器，再调用 `updateServiceMediaItem()`。
- `updateServiceMediaItem()` 直接 `mediaItem.add(MediaItem(...))`，没有合并门、没有最少间隔、没有 1.5 秒的切歌静默期。
- 每次歌词行变化时：
  - 调用 `updateServiceMediaItem(currentSong, lyric: 当前行)`；
  - 紧接着调用 `updatePlaybackState()`。
- `MediaItem` 只设置标准字段：`title`、`artist`、`album`、`artUri`、`duration`。
- 封面只用 `File(picture.path).uri`，没有 `artCacheFile`，所以文本/歌词稳定，但封面在车机上不可用。

这说明：**文本和歌词的实时性来自“直接发布 + 每次补 PlaybackState”，不是因为某个车机协议的特殊处理。**

### 2.2 当前 `lain` 的做法

关键代码：

- `lib/base/audio_handler.dart`：`updateServiceMediaItem()`、`_updateCurrentLyricIndex()`
- `lib/base/services/media_broadcast.dart`：`MediaBroadcaster`
- `lib/base/services/media_session_item.dart`：`buildServiceMediaItem()`
- `lib/base/services/media_art.dart`：封面缩小与缓存
- `lib/base/data/car_display.dart`：两行/三行文本组合

当前实现比参考实现多了这些机制：

- 切歌前后有 `debounce`、`minGap`、`lyricGap`、`trackSettle`。
- 歌词行可能被合并、延后，或者等待切歌静默期。
- 切歌发布发生在播放器打开之前。
- 歌词更新只发 `mediaItem`，不补 `PlaybackState`。
- 封面通过 `_prepareSmallArt()` 异步生成，失败后在同一广播代次内可能不再重试。
- 封面模式会清空 `fileUri` / `fetchUri`，只依赖 `artCacheFile`。

`6d21662` 已经给经典蓝牙加了直接发布和状态补发，也加了完整封面形态；但**智能互联路径仍然走旧时间门，文本发布仍在播放器打开之前，歌词更新仍不补 PlaybackState**。文本、封面仍由同一个 `updateServiceMediaItem()` 触发，因此两者无法独立重试或独立失败。

这些差异正好对应你观察到的现象。

---

## 3. 根因分析

### 3.1 文本和歌词延迟

`MediaBroadcaster` 的时间参数是为“防止连按下一首时车机排队读条目”设计的，但它同时作用到了正常歌词：

- 切歌后 `trackSettle` 约 1.5 秒，期间歌词更新会等待。
- 两行歌词之间 `lyricGap` 约 0.8 秒。
- 较快的歌词会先被替换成最新行，车机只看到“第三句”，观感上像吞了第二句。
- 文本发布后没有补 `PlaybackState`，部分车机不会主动重新读取刚变化的 metadata，直到暂停/播放状态变化。

参考实现没有这些延迟，所以它在两台车上都能实时更新。

`6d21662` 在经典蓝牙路由上绕过了这些门，但智能互联路由仍然使用 `MediaBroadcaster` 的 `lyricGap` / `trackSettle`，并且歌词更新没有补 `PlaybackState`。这就是为什么同一份代码在经典蓝牙上比智能互联上更“实时”的结构性原因。

### 3.2 本地源信息更新不及时

当前 `load()` 在播放器打开前发布条目；部分车机在会话尚未激活时收到 metadata 会忽略，等下一次状态变化才读。流媒体源因为打开链路更长，反而更容易在会话激活后收到更新，所以出现“流媒体正常、本地不正常”的差异。

另外，当前本地源会走 `_prepareForPlayback()`，在封面/歌词准备上等待；如果这段等待和发布时机交错，车机可能先读到旧条目，再等下一次歌词才刷新。

### 3.3 本地封面不广播

`6d21662` 的 `ClassicCoverMode.full` 已经把 `fileUri` + 可抓取 URI + `artCacheFile` 一起发布，这是正确的方向。但封面链路仍然是单路径，剩余问题在“封面是否真的生成出来”：

1. `artCacheFile` 依赖异步小图；小图生成失败时，`_resolveSmallArt()` 只记录失败，不会自动用原图补发。
2. 同一广播代次内失败会被失败记忆压住；本地源没有“原图兜底 + 延迟重试”的独立路径。
3. 本地源在首次发布时封面文件可能还没准备好；如果之后 `_whenCoverReady()` 只更新小图而没有重新构造可发布的封面状态，车机就一直拿到空封面。
4. 文本更新和封面更新共用 `updateServiceMediaItem()`；一次歌词刷新可能重新计算封面状态，但封面的失败/重试没有独立生命周期。

所以完整封面形态能解决“有路径但车机读不到”的一部分问题，但不能保证“本地封面一定被生成并补发”。

### 3.4 纯蓝牙老车机

经典蓝牙 AVRCP 对“同一 media id 只改标题”不一定发送 track changed 事件。`6d21662` 已经做了正确的调整：稳定 media id、直接发布、60ms 状态补发、切歌后补发、经典路由不发布浏览队列。这些应该保留。

真正需要整理的是：这些经典行为仍散落在 `updateServiceMediaItem()`、`_updateCurrentLyricIndex()`、`_publishQueueWindow()` 和 `_scheduleClassicBluetoothRefresh()` 里，和普通发布路径共用状态。方案把它收口成明确的 `classic` 策略，而不是继续在共享函数里加条件。

---

## 4. 目标架构

```text
播放器/歌词/封面事件
        │
        ▼
NowPlayingSnapshot
  - song id / version
  - 当前两行或三行文本
  - title / artist / album
  - 当前歌词行
  - 当前封面路径 / URI
        │
        ├───────────────┐
        ▼               ▼
NowPlayingPublisher  ArtworkPublisher
  - 文本立即发布       - 独立解析/缩小/重试
  - 补 PlaybackState   - 只刷新封面
        │               │
        └───────┬───────┘
                ▼
        buildServiceMediaItem()
                │
                ▼
        audio_service.mediaItem
        audio_service.playbackState
```

核心原则：

- **文本和封面共享数据，但不共享发布时机。**
- 文本发布永远不等待封面；没有封面也先发布文本。
- 封面发布永远不修改文本，只带当前文本重建一个条目。
- 任何一次发布都必须保留“当前已确认的封面”，除非切到新歌。
- 歌词更新不再经过 1.5 秒切歌静默期。

---

## 5. 关键设计

### 5.1 NowPlayingSnapshot

新增纯数据对象，作为唯一广播快照：

```dart
class NowPlayingSnapshot {
  final String songId;
  final int itemVersion;
  final String title;
  final String artist;
  final String album;
  final List<String> carLines;
  final String? lyric;
  final Duration? duration;
  final String? artCacheFile;
  final String? artUri;
  final String? fetchUri;
  final int? trackNumber;
  final int? trackCount;
}
```

`carLines` 由现有 `composeCarDisplayLines()` 生成，保持用户当前的两行/三行、字段顺序、分隔符逻辑不变。

映射规则：

- `title` = 第一行
- `artist` = 第二行
- `album` = 第三行
- `displayTitle` / `displaySubtitle` / `displayDescription` 与上面三个字段保持完全一致
- 第一行为空时回退歌曲标题（沿用现有逻辑）

### 5.2 文本发布器

新增 `NowPlayingPublisher`，替换当前 `MediaBroadcaster` 的文本职责。

行为：

- 切歌：立即发布当前快照；如果 80–120ms 内连续切歌，只保留最后一次。
- 歌词行变化：立即发布，不等待 `trackSettle`，不等待 `lyricGap`。极快的连续行可以在 120ms 内合并为最后一次，但正常歌词行不延迟。
- 每次发布后调用 `updatePlaybackState()`，让车机重新读取 metadata。
- 相同 `textKey + artKey` 才跳过，避免无意义刷新。
- 切歌时先发布一次，播放器打开/会话激活后再补一次“同一首歌的最新快照”，专门解决老车机首次 not found。
- 队列窗口仍然单独发布，只在队列签名变化时更新，不因歌词行刷新整个队列。

伪代码：

```dart
void publishText(NowPlayingSnapshot snapshot, {bool trackChange = false}) {
  if (trackChange) {
    _scheduleTrack(snapshot);     // 80ms 内的连按只保留最后一次
  } else {
    _publishNow(snapshot);        // 歌词立即发布
  }
}

void _publishNow(NowPlayingSnapshot snapshot) {
  if (snapshot.textKey == _lastTextKey &&
      snapshot.artKey == _lastArtKey) {
    return;
  }
  mediaItem.add(buildServiceMediaItem(snapshot));
  updatePlaybackState();
  _lastTextKey = snapshot.textKey;
  _lastArtKey = snapshot.artKey;
}
```

### 5.3 封面发布器

新增 `ArtworkPublisher`，独立维护当前歌曲的封面状态：

```text
ArtworkState:
  songId
  sourcePath
  smallPath?
  contentUri?
  lastPublishedKey?
  retryCount
```

流程：

1. 优先使用已存在的小图 `mediaArt.readyPath(path)`。
2. 没有小图则异步生成 `mediaArt.smallFor(path)`。
3. 小图失败时，**直接回退原图路径**，不能因为缩小失败就不发封面。
4. 本地源同时尝试 content URI；`artCacheFile` 和 `artUri` 都带上，车机用哪个都能工作。
5. 封面成功后触发一次 `publishArtwork(snapshot)`：
   - 抓取当前文本快照；
   - 用当前文本 + 新封面重建 `MediaItem`；
   - 补 `PlaybackState`；
   - 不改变歌词、不重置队列位置。
6. 封面失败后按 `0.5s / 2s / 5s` 重试，切歌即取消；不要永久记住本地封面失败。
7. 歌词更新时始终携带 `ArtworkState` 中最后一次成功的封面，绝不把封面字段清空。

封面模式继续保留为“交付策略”，而不是“是否发封面”：

- `full`：`artUri` + 可抓取 URI + `artCacheFile`；经典蓝牙默认
- `bitmap`：`artCacheFile` + 可用的 content URI
- `bitmapUri`：`artCacheFile` + content URI
- `largeBitmap`：优先原图，原图不可用则小图
- `relayUri`：在上述基础上增加 relay URL
- 本地库默认使用 `full`，小图优先、原图兜底

### 5.4 经典蓝牙 AVRCP 兼容策略

沿用 `6d21662` 已经验证的方向，只在检测到 A2DP / SCO / BLE 输出时启用，或手动强制：

- **整首歌保持稳定 media id**，不使用逐行 `#version`。最新代码已经证明，逐行 id 会让车机无法把当前项和浏览队列匹配起来。
- 切歌、歌词更新直接发布 item，再补一次 `PlaybackState`；首次播放和切歌后按 0 / 450ms / 2s 补发当前项，覆盖会话刚激活时车机读不到的情况。
- 不在经典蓝牙路由发布浏览队列，已有队列一次性清空，避免车机读队列项而绕过带歌词的会话项。
- 不设置长静默期；歌词行直接发布，必要时最多 120ms 合并。
- 非经典蓝牙路径（Android Auto、智能互联、USB）保持现有稳定 id、队列窗口和正常发布逻辑。

手动“经典蓝牙广播”开关继续保留，作为路由识别失败时的兜底；但它应该只改变“发布策略”，不改变文本和封面数据本身。

### 5.5 自定义歌词层

现有 `composeCarDisplayLines()` 和设置页已经满足需求，重构时保持不动：

- 两行/三行布局
- 原词/翻译/标题/艺术家/专辑自由组合
- 分隔符
- 歌词未到时回退标题
- 翻译缺失时回退原词

唯一变化是：`carLines` 在每次歌词行变化时重新生成，并作为 `NowPlayingSnapshot` 的文本来源；发布时机由发布器控制，不由组合层控制。

---

## 6. 代码改动清单

### 新增

- `lib/base/services/now_playing_snapshot.dart`
  - 快照、文本 key、封面 key、从歌曲/歌词/封面状态构建快照。
- `lib/base/services/now_playing_publisher.dart`
  - 文本发布、切歌合并、歌词即时发布、补 PlaybackState。
- `lib/base/services/artwork_publisher.dart`
  - 小图/原图/content URI 解析、重试、封面刷新。
- `test/now_playing_publisher_test.dart`
  - 切歌立即、歌词立即、连按合并、重复跳过、封面不丢。
- `test/artwork_publisher_test.dart`
  - 小图失败回退原图、本地封面重试、切歌取消旧任务。

### 修改

- `lib/base/audio_handler.dart`
  - `load()`：播放器打开后补一次发布；歌词变化改为调用新发布器。
  - 删除文本路径对 `MediaBroadcaster` 的直接依赖。
  - 保留队列窗口与现有播放逻辑。
- `lib/base/services/media_session_item.dart`
  - 输入从多个字符串改为 `NowPlayingSnapshot`；标准字段与 display 字段保持一致。
- `lib/base/services/media_broadcast.dart`
  - 只保留 generation / 异步结果防串台；删除文本时间门；或整体被新发布器替代。
- `lib/base/services/media_art.dart`
  - 增加“原图兜底”返回；本地源失败路径可观测。
- `lib/base/data/car_display.dart`
  - 基本不动，只作为文本生成器。
- `lib/base/services/broadcast_inspector.dart`
  - 增加 `text/art` 两个发布时间和失败原因，方便两台车实测。

### 暂不修改

- 车机设置页的两行/三行 UI
- 封面模式选择 UI
- 播放队列、播放器、音频路由
- 分享卡片、每日推荐等无关功能

---

## 7. 分阶段实施

### 阶段 0：可回滚开关

- 增加内部 `broadcastEngine` 开关（设置页不暴露，或只在 Debug 页暴露）。
- 保留旧路径，新增新发布器，先在一台车/一个源验证。

### 阶段 1：文本发布器

- 实现 `NowPlayingSnapshot` + `NowPlayingPublisher`。
- 切歌立即发布，播放器打开后补发，歌词立即发布并补 `PlaybackState`。
- 先不接封面新逻辑，验证本地/流媒体在智能互联车机和纯蓝牙车机上的文本、歌词、切歌。

### 阶段 2：封面发布器

- 实现独立 `ArtworkPublisher`。
- 本地封面：小图 → 原图 → content URI 逐级回退。
- 歌词更新携带最后成功封面；封面成功/失败不反向影响文本。
- 增加封面重试和观测字段。

### 阶段 3：经典蓝牙兼容

- 保留 A2DP/SCO/BLE 检测和手动强制开关。
- 经典蓝牙使用稳定 media id、直接发布、状态补发、切歌后补发、不发布浏览队列。
- 非经典路径保持现有稳定 id、队列窗口和正常发布逻辑。
- 把经典策略从共享函数里的条件判断收口为独立的 `BroadcastPolicy`。

### 阶段 4：清理

- 删除旧的时间门、重复的封面刷新入口和不再使用的 `MediaSnapshot` 分支。
- 更新 `BUILDING.md`、广播调试页和测试。

---

## 8. 验收矩阵

至少覆盖以下组合：

| 场景 | 信息首屏 | 切歌 | 歌词 | 封面 |
| --- | --- | --- | --- | --- |
| 本地源 + 智能互联车机 | 立即 | 立即 | 逐行 | 首曲出现，持续不消失 |
| 本地源 + 纯蓝牙车机 | 立即 | 立即 | 逐行 | 首曲出现，持续不消失 |
| Navidrome/Emby + 智能互联 | 立即 | 立即 | 逐行 | 正常 |
| Navidrome/Emby + 纯蓝牙 | 立即 | 立即 | 逐行 | 正常 |
| 快速连按下一首 | 只显示最终曲 | 不排队 | 不闪回旧行 | 最终曲封面正确 |
| 暂停/继续 | 不丢信息 | 不丢封面 | 回到当前行 | 不消失 |
| 锁屏/通知 | 与车机一致 | 一致 | 一致 | 一致 |

建议记录以下日志字段：

- `text publish`: songId、reason(track/lyric/art)、textKey、耗时
- `art publish`: songId、smallPath/original/contentUri、成功/失败
- `state publish`: playing、position、queueIndex
- `classic route`: on/off

---

## 9. 风险与边界

- 经典蓝牙保持稳定 media id；不要再用逐行 `#version`，否则会话项与浏览队列会对不上。
- 本地封面原图可能很大，必须优先小图；原图只在缩图失败时兜底。
- `audio_service` 的 `artCacheFile` 是异步加载，封面刷新仍要用 generation 防止旧封面覆盖新歌。
- 队列窗口不要因歌词刷新重建，否则 Binder payload 过大且会干扰车机队列。
- 不改变现有自定义歌词设置的数据格式；旧配置直接兼容。
- 不把密码、地址、日志中的隐私信息写入广播或备份。

---

## 10. 需要你确认的决策

1. **智能互联路径是否也改成“歌词立即发布 + 每次补 PlaybackState”**：这是 `sylvakru` 验证过的行为，也是本方案修复本地源文本延迟的关键；是否接受它替代当前的 `lyricGap` / `trackSettle`？
2. **本地封面默认策略**：`full`（`artUri` + 可抓取 URI + `artCacheFile`），小图优先、原图兜底；是否接受原图在缩图失败时作为兜底？
3. **经典蓝牙浏览队列**：是否继续像 `6d21662` 一样在经典路由完全不发布队列，还是保留队列但让当前项也带歌词？我建议先保持“不发布”，稳定后再评估。
4. **旧广播路径**：验证通过后是否直接删除旧的 `MediaBroadcaster` 时间门，还是保留一个 Debug 开关方便回退？

我建议：智能互联也走立即发布、本地封面 `full` 且原图兜底、经典路由继续不发布队列、旧时间门在两台车验证后删除，只保留 Debug 回退开关。
