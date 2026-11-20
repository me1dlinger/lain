# 下一批功能实现文档

> 调研日期：2026-11-18
> 基线：调研时 versionCode 951192；实现结果已落至 951197。
> 状态：调研完成；其中第 1、2、3 项已于 2026-11-18 实现（第 3 项的跨服务器回退仅做到本地回退）。第 4 项统一外壳/命令面板/首次引导仍只调研、不实现。
>
> 覆盖四项：
> 1. 曲库歌词全文搜索
> 2. 播放会话日记 + 今日回忆
> 3. 离线与多源可靠性包
> 4. 统一外壳 + 命令面板 + 首次引导

---

## 0. 先看这里：四个共同约束

这些约束会直接影响四项功能的可实施范围，先统一列出：

1. **运行期只有单一活动源。**
   `sourceType`、`isStreamSource`、`streamClient` 都是进程级全局。配置层可以有多台服务器，但播放、库、缓存只认当前活动源。多源回退不能假设可以同时持有多个客户端。

2. **库和缓存按 SourceType 存放，不按 serverId。**
   `<appSupport>/<sourceType.name>/metadata.db`、caches、pictures、lyrics 都是同类型服务器共享。两台 Navidrome 会共用同一个库和缓存目录。因此：
   - 跨服务器等价曲目回退在首发版只能安全使用“当前源 + 本地库 + 当前源缓存”；
   - 同类型第二台服务器必须先完成按 serverId 重建库的迁移，才能作为可靠的 fallback；
   - 健康仪表盘可以按 serverId 建模，但不能假装隔离了库。

3. **歌词解析结果不持久化。**
   `parsedLyrics` 只在内存里，应用重启后重新解析；数据库只保存部分来源的原始歌词文本。全文索引必须自己保存可检索文档，不能依赖 `parsedLyrics` 长期存在。

4. **首次引导没有独立完成标记。**
   `version.json` 在 `Loader.init` 阶段就会写入；如果用户在首次引导中途杀掉应用，下一次启动 `firstLaunch` 会变成 false，引导被跳过。新的 onboarding 必须有独立的 `onboarding.json` 状态机。

---

# 1. 曲库歌词全文搜索

## 1.1 现状结论

### 歌词来源与解析

- 解析入口是 `lib/base/services/lyric.dart` 的 `setParsedLyrics`，`parsedLyrics != null` 时直接返回。
- 支持 LRC、增强 LRC（karaoke token）、TTML，以及 LRC 同时间戳第二行作为翻译。
- 歌词来源：
  - 本地 / WebDAV：歌曲标签里的 `lyrics`；没有时读同目录 sidecar `.lrc` / `.ttml` / `.xml`。WebDAV 会把 sidecar 下载到 `song.lrcPath`。
  - Navidrome / Feiniu：先读 `song.lrcPath` 缓存；不存在时调用服务端歌词接口，成功后写缓存。
  - Emby：使用歌曲元数据里的 `lyrics`。
- `song.lrcPath` 位于 `<support>/<source>/lyrics`，可被缓存目录设置重定向。
- `clearLrcCache`、删除缓存条目、删除歌曲时都会清掉对应缓存/解析结果，但不会通知任何索引。

### 关键代码位置

| 内容 | 位置 |
| --- | --- |
| 歌词模型与解析 | `lib/base/services/lyric.dart` |
| 歌词入口 | `setParsedLyrics`、`_readSidecarLyrics`、`applyLrcParsing`、`applyTtmlParsing` |
| 歌词字段 | `lib/base/my_audio_metadata.dart`：`parsedLyrics`、`lrcPath`、`lyricsTimeOffset` |
| 歌词缓存路径 | `lib/base/utils/path.dart`：`getLrcPath`、`getCachesPath` |
| 现有歌词搜索 | `lib/base/widgets/lyric_search_dialog.dart`（搜网易云/QQ，不是库内搜索） |
| 数据库 | `lib/base/data/database.dart`、`lib/base/extensions/metadata_extension.dart` |
| 元数据写入 | `lib/base/data/library.dart`：`_saveMetadata`、`updateMetadata`、`applyRename`、`removeSongFromLibrary` |
| 搜索页 | `lib/portrait_view/global_search_page.dart` |
| 搜索历史 | `lib/base/data/search_history.dart` |

### 数据库现状

- `MetadataItems` 一张表，`lyrics` 是其中一列；`schemaVersion = 8`。
- 每个 source 一个 `metadata.db`。
- `_saveMetadata` 是“删除全表再插入”，不是行级增量；所以不能依赖 SQLite trigger 判断歌词变化。
- 当前没有任何 FTS/LIKE 搜索，全局搜索是内存线性扫描。
- 当前依赖 `sqlite3 3.8.0`，其构建描述默认包含 FTS5；但必须在运行时实际检测，不能只凭版本假设。

### 现有搜索页的限制

- `GlobalSearchPage` 的筛选索引固定为：全部、歌曲、专辑、艺术家、歌单。
- `_search` 是同步内存扫描；歌词搜索需要异步 DB 查询，不能直接塞进现有同步函数。
- 最近搜索仍然是 `search_history.json`，可以复用。

## 1.2 推荐方案

### 1.2.1 独立索引库，而不是改 metadata.db

新增每 source 一个派生库：

```text
<appSupport>/<sourceType.name>/lyrics_index.db
```

理由：

- 派生数据可单独删除、重建，不动用户元数据库；
- FTS5 创建失败不会让 metadata 迁移失败；
- 本地库频繁全表重写，不会与索引争锁；
- 后续可按 source 清理索引。

如果希望合并进 `MetadataDB`，则应升级到 schema 9，并允许“FTS 创建失败时只保留普通表”的降级路径。首发推荐独立库。

### 1.2.2 表结构

```sql
lyric_documents(
  song_id TEXT PRIMARY KEY,
  content_hash TEXT NOT NULL,
  format TEXT,              -- lrc / ttml / embedded
  line_count INTEGER,
  char_count INTEGER,
  indexed_at INTEGER,
  status INTEGER             -- ok / empty / parse_failed / too_large
)

lyric_lines(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  song_id TEXT NOT NULL,
  line_index INTEGER NOT NULL,
  start_ms INTEGER,
  end_ms INTEGER,
  text TEXT NOT NULL,
  translation TEXT,
  is_translation INTEGER NOT NULL DEFAULT 0
)

lyric_lines_fts USING fts5(
  text,
  translation,
  content='lyric_lines',
  content_rowid='id',
  tokenize='trigram'
)

lyric_index_meta(key TEXT PRIMARY KEY, value TEXT NOT NULL)
```

`lyric_index_meta` 记录：

- `schema_version`
- `tokenizer`
- `dirty`（索引中途中断）
- `last_full_index`
- `fts_available`

触发器只维护 `lyric_lines_fts`；全量重建时先清空，再执行 FTS `rebuild`，避免逐行写入过慢。

### 1.2.3 索引器

新增 `LyricIndexer`（建议 `lib/base/services/lyric_indexer.dart`）：

- `indexSong(song)`：
  - 已有可信 `parsedLyrics` 时直接复用行；
  - 否则按来源读取原始歌词：本地/WebDAV 标签或 sidecar、Emby `song.lyrics`、Navidrome/Feiniu 已存在的 `lrcPath`；
  - 生成 `content_hash`，未变则跳过；
  - 解析在 isolate 中完成，只回传结构化行，不把整首歌词发送到主 isolate。
- `indexAll({force})`：
  - 先索引本地/Emby 已有文本；
  - 再索引已缓存的流媒体歌词；
  - **默认不为 Navidrome/Feiniu 逐首发网络请求**；只有用户显式开启“索引服务器歌词”才允许逐首拉取。
- 写入主 isolate 的 DB executor，批量事务约 50 首/批。
- 进度使用 `ValueNotifier<(done,total)?>`，与现有缓存进度风格一致。
- 用 generation / CancelToken 支持取消；库切换或全量重建时旧任务在下一首边界退出。
- 用 `SingleFlight` 合并重复触发。

### 1.2.4 触发与对账

必须覆盖这些路径：

- 歌曲元数据更新：`Library.updateMetadata`。
- 重命名：`applyRename` / `renameStoredRow`。
- 移除歌曲：`removeSongFromLibrary`。
- 删除缓存：`deleteCacheEntry` / `deleteCachedSong`。
- 清空歌词缓存：`clearLrcCache`。
- 同步完成：用 `library.songList` 的 id 集合删除孤儿 `lyric_documents`，再补索引。
- 播放/预缓存解析歌词后：可增量更新该首。

同步期间 `library.canModify == false` 时不要启动全量索引；同步结束用 `library.changeNotifier` 做 2 秒防抖。

### 1.2.5 查询

```dart
class LyricHit {
  final String songId;
  final String lineText;
  final String? translation;
  final Duration? start;
  final int lineIndex;
  final String matchedField; // text / translation
  final double score;
}
```

查询策略：

- 查询词长度 ≥ 3：FTS5 `MATCH` + `bm25`。
- 中文 1–2 字：trigram 不可用，改用 `instr(lower(text || ' ' || coalesce(translation,'')), lower(?)) > 0`。
- 按 `song_id` 聚合：每首歌只取排名最高的一行，再按分数排序。
- 结果用 `library.id2Song[songId]` 解析；不存在的跳过。
- 返回 `LyricSearchResult { hits, songCount, lineCount, offset, ftsAvailable }`。

### 1.2.6 UI 接入

- `_SearchResults` 增加 `lyrics`；`total` 计入。
- 筛选 chip 增加第 5 项“歌词”，索引为 5。
- “全部”模式只显示前 3–5 条歌词命中；歌词专属筛选显示完整结果。
- 行内容：封面、歌名/歌手、命中的歌词行与翻译、查询高亮、时间戳。
- 点击：
  1. 解析该结果歌曲集合与目标索引；
  2. `audioHandler.setPlayQueue(...)`；
  3. `audioHandler.seek(max(0, start - song.lyricsTimeOffset))`；
  4. 可选打开 `LyricsPageLayer`。
- 长按沿用 `showSongOptions`。
- 搜索页的查询要改成异步，保留 140ms 防抖，并用 generation 防止旧查询覆盖新查询。
- 顶部“最佳结果”不纳入歌词行，避免“播放”和“跳到歌词”语义混淆。

### 1.2.7 回退与容量

- 启动检测 FTS5：
  - `SELECT sqlite_compileoption_used('ENABLE_FTS5')`；
  - 尝试创建 `tokenize='trigram'`。
- FTS 不可用：保留 `lyric_lines`，查询用 `instr/LIKE`。
- 连普通索引库也不可用：仅扫描当前会话已解析的 `parsedLyrics`，并明确提示“仅当前会话歌词”。
- 容量估算：FTS trigram 常为原文 2–4 倍；10 万首可能 0.5–1.5 GB。单首歌词超过 1–2 MB 时记为 `too_large` 不索引。

## 1.3 分阶段任务

1. 建 `LyricIndexDB` / FTS 检测 / 表与迁移。
2. 解析 isolate + `LyricIndexer.indexSong` + 批量写。
3. 接入库更新、删除、缓存清理、同步对账。
4. 查询服务 + 短词回退 + 结果测试。
5. 搜索页“歌词”分组与跳转。
6. 后台全量索引进度/取消 + 设置开关（是否索引服务器歌词）。

## 1.4 验收

- 本地、WebDAV、Emby 已有歌词、Navidrome/Feiniu 已缓存歌词都能按任意子串命中。
- 结果能定位到歌词行时间，并考虑 `lyricsTimeOffset`。
- 未缓存的服务器歌词不会触发隐式全库网络请求。
- 删除缓存/移除歌曲后不再命中。
- 首次索引可取消，重启可续；索引失败不影响播放和现有搜索。
- 中文 2 字、英文、翻译行、karaoke 行、同时间戳翻译都有测试。

## 1.5 风险

- FTS5 tokenizer 与 SQLite 版本差异；
- 索引体积与首次构建耗时；
- 歌词缓存目录可被用户迁移，索引路径必须跟随 source 配置；
- 本地库全表重写不能依赖 trigger，必须做集合对账；
- 播放中解析歌词与索引写入的并发。

**工作量：M（约 3–5 天）**

---

# 2. 播放会话日记 + 今日回忆

## 2.1 现状结论

### 统计只有聚合，没有会话

- `lib/base/data/stats.dart` 的 `StatsSong / StatsDay / StatsYear` 只记录按年、按天的次数与毫秒。
- 歌曲键是 `title|artist` 小写，不是 song id；不能恢复队列。
- `recordPlay` 在切歌时按当前时间归日，跨午夜会归到后一天。
- `history.dart` 只维护最多播放、最近播放、久别重逢，不是时间线。

### 现有播放计时的唯一入口

- `audio_handler.dart` 的 `updateIsPlaying` 维护 `_playLastSyncTime` / `_playedDuration`。
- `load()` 和 gapless 的 `_promoteGaplessNext()` 在离开当前曲时计算 `times = played / duration`。
- 只有 `times > 0.67` 才调用 `history.addSongTimes` 和 `stats.recordPlay`。
- 跳过、未听完、暂停后切歌都不会进入统计。会话日记必须自己记录所有离开事件。

### 队列与状态持久化

- 每个 source 有 `play_queue_state.json`、`play_state.json`、`position_state.json`。
- 队列只保存 id；恢复时用 `library.id2Song` 解析，缺失/离线不可用的会被丢弃。
- 现有“启动继续播放”由 `_tryPlay` + `position_state` 完成，不能和会话恢复混淆。

### 可用的边界

- 自然边界：应用启动/`loadStates`、切源、`setPlayQueue`、`clear/justClear`、歌词预览、滑动移除任务、睡眠定时、音频焦点中断。
- 睡眠暂停与用户暂停目前只差 `sleepTimerOnNotifier` / `needPause`；可记录原因。

### UI 基础

- `StatsPage` 已有年度选择、今日榜单、热力图、排名列表。
- `AnnualReportPage` 已有按 source/coverId 取历史封面的逻辑，可直接复用。
- 分享卡已有 9:16 PNG 导出和系统分享管线。

## 2.2 推荐数据模型

`PlaybackSession`：

- `id`
- `startedAt` / `lastActivityAt` / `endedAt?`
- `endReason`：`idle | sourceSwitch | queueCleared | stopped | taskRemoved | appExit | midnight`
- `sourceType` / `serverId` / `sourceKey`
- `outputLabel` / `outputType`（可来自音频输出页）
- `playMode`
- `queue[]`：`{id,title,artist,album,coverId,durationMs}`
- `queueIndex`
- `events[]`
- 聚合：`listenedMs`、`trackCount`、`completedCount`、`skippedCount`
- `resumedFromSessionId?`

`SessionEvent`：

- `songId`
- 标题/艺术家/专辑快照
- `startedAt` / `endedAt`
- `playedMs` / `trackDurationMs` / `completionRatio`
- `positionAtEnd`
- `endedBy`：`completed | next | previous | queueChange | sourceSwitch | stop | repeatOne | error`
- `seekCount`（可选）

存储：

```text
<appSupport>/playback_sessions.json
{"version":1,"sessions":[...]}
```

- 原子写：临时文件 + rename。
- 损坏/缺失 = 空历史，不能阻塞播放。
- 按 5 年或 3000 条裁剪；没有事件的历史删除。
- 跨午夜拆分为两段，保证“今日回忆”日期正确。
- 备份服务可选择包含或明确排除该文件。

## 2.3 采集接入点

建议只加一层 `SessionRecorder`，不重写播放器的计时逻辑：

- `load()` 离开当前曲、`_promoteGaplessNext()` 交接处：
  - 现有 `stats.recordPlay` 旁边调用 recorder，无论是否达到 0.67 都记录；
  - 传入 `endedBy`。
- `updateIsPlaying`：`notePlayState(isPlaying)`，用于实时累计播放时间和空闲计时。
- `setPlayQueue` / `clear` / `justClear` / `sync`：结束或重建会话。
- `startLyricPreview` / `stopLyricPreview`：不创建会话，并暂停当前会话计时。
- `onTaskRemoved`：结束并 flush。
- `ViewEntry` 已有的生命周期回调：paused/detached 时 flush。
- 每 5 分钟周期 flush，降低被系统杀掉的损失。
- 防止 `load()` 和 gapless 重复 finalize 同一首：用 `(songId, startedAt)` 去重。

## 2.4 会话边界规则

- 第一次 `play()` 从空闲开始：新建会话。
- 队列编辑、自动切歌、gapless、重复播放同一队列：保持同一会话。
- 切换源、清空队列、歌词预览、应用退出：结束。
- 暂停超过 30 分钟：结束；再次播放新建会话。
- 睡眠定时暂停：结束原因记为 `sleepTimer`。
- 跨午夜：拆分，旧段 `midnight` 结束，新段从零点后第一首开始。
- 恢复会话不自动发生在启动时；只在页面中显式“恢复这段队列”。

## 2.5 今日回忆

查询：

- 找所有 `startedAt` 的月/日等于今天、年份小于今年的会话；
- 按年分组，降序；
- 每年显示：几年前的今天、会话数、总时长、曲目数、代表歌曲/艺术家、来源。
- 没有会话历史时，回退到现有 `stats.year(y).days[YYYY-MM-DD]` 和 `topSongsOfDay`，显示“仅统计快照”，不能恢复队列。
- 封面：先用 `library.id2Song`，否则复用 `AnnualReportPage` 的 coverId/source 缓存查找。

## 2.6 UI

新增：

- `SessionDiaryPage`：按天分组的时间线、年份/来源筛选、每日总时长、会话卡片。
- `SessionDetailPage`：事件列表、结束原因、完成比例、累计时长、队列、分享卡、恢复队列。
- 今日回忆可以作为日记页顶部卡片，也可以从听歌报告进入。

入口：

- 首页新增“听歌日记”按钮或并入听歌报告入口；
- 设置 → 听歌报告；
- 报告页今日榜单旁链接。

交互：

- 事件行点击播放可解析歌曲；长按歌曲菜单。
- 会话详情“恢复这段队列”会重建队列并设置位置；缺失歌曲跳过且保留记录。
- 分享卡复用现有 PNG 导出/分享管线。

## 2.7 验收

- 连续听 20 首生成 1 个会话、20 个事件，播放毫秒和完成比例正确。
- 10 秒跳过的歌记录为 skipped，不计入完成播放。
- 10 分钟内暂停/恢复仍为同一会话；40 分钟空闲拆分。
- 今日回忆能显示往年同一天；旧安装回退到统计聚合。
- 恢复队列只恢复幸存歌曲，不改变启动继续播放行为。
- 日记不改变现有 `stats.recordPlay` 的统计口径。

## 2.8 风险

- `load()` 与 gapless 双计数；
- 应用被杀丢失最后一次 flush；
- 跨午夜/夏令时；
- 服务器 id 变化后历史来源解析；
- 备份/清理统计时是否同时删除日记，需要用户明确选择；
- 事件日志体积与隐私。

**工作量：M（约 3–5 天）**

---

# 3. 离线与多源可靠性包

拆成四个可独立交付的子项：

1. 离线 scrobble 队列
2. 同步差异预览
3. 等价曲目回退
4. 源健康仪表盘

## 3.1 离线 scrobble 队列

### 现状

- `history.addSongTimes` 在播放完成后直接 `streamClient?.scrobble(song.id)`，失败静默。
- `audio_handler._reportServerProgress` 只对全局 `streamClient` 上报，忽略错误。
- 各客户端错误被 `safeRequest` 统一吞成 null，无法区分网络、认证、无效 id。
- 没有持久化重试队列。

### 设计

文件：`<appSupport>/scrobble_queue.json`

事件字段：

```text
id = serverId:songId:startedAtMs:seq
serverId, sourceType, songId,
title, artist, album, durationMs, listenedMs,
startedAtMs, finishedAtMs,
origin,             // native | cache | local | fallback:<serverId>
attempts, nextAtMs, state, lastErrorKind
```

规则：

- 上限 5000，溢出把最旧 pending 移到 `scrobble_dead.json`（上限 200）。
- 入队去重键 `(serverId,songId,startedAtMs)`。
- 入队点：`load()` 的完成统计块、gapless 的完成统计块；同时保留在线即时上报。
- 发送前写 `attempting`；成功后删除；崩溃恢复 `attempting -> pending`（至少一次）。
- 退避：`min(30s * 2^(attempts-1), 6h)`，最多 12 次转 dead。
- 401/403 认证失败不指数重试，冻结到该 server 凭据变更或手动重试。
- flush 触发：启动完成、60 秒 tick、入队后、应用 resume、同步成功。
- 事件只保存 serverId；发送时按 `config.servers` 找到服务器并构造对应客户端。
- Navidrome scrobble 尽量带 `time`；Feiniu 使用真实 `occurredAt`；Emby 没有时间戳，需在文档中说明重启窗口可能重复。

### 需要先改的底层

- `StreamClient` 的 scrobble/report 返回值改为可分类结果（network/auth/invalid/server），或在 `safeRequest` 保留错误类型。
- 各客户端补时间参数支持。

## 3.2 同步差异预览

### 现状

- 本地/WebDAV：`Folder.setFileAndModified` 可低成本得到 path → modified/created，预览很容易。
- 流媒体：`Library.sync` 先清空 `songList/id2Song` 和 metadata，再分页拉取；中途失败会留下空/半库。
- 重命名不识别，旧 path 删除 + 新 path 新增。
- 缓存、播放列表引用都可通过现有 id 和缓存文件名算出影响。

### 设计

新页面 `SyncPreviewPage`，流程改为：

```text
Loader.previewSync()
  -> SyncPreview（数据/计数/样本/影响）
  -> 用户确认
  -> Loader.applySync(preview)
```

预览内容：

- 新增、删除、重命名、元数据变化、未变；
- 缓存影响：将不再被引用的歌曲/字节；
- 播放列表影响：多少列表、多少引用将失效；
- 警告：删除不可撤销、空扫描保护。

存储：

```text
<appSupport>/sync_preview.json  // 只存摘要，不存完整库
```

- 样本最多 200 条；大库只存计数。
- 流媒体预览拉取的分页数据保留在内存，apply 复用同一批数据，避免二次拉取。
- 本地/WebDAV 预览不写库。
- apply 必须使用事务/临时库+原子切换，或先备份 metadata.db；失败可回滚。
- `autoSync()` 不显示预览，只记录快照/健康数据。
- 入口：设置音乐源、修改文件夹、同步按钮。

## 3.3 等价曲目回退

### 现状

- 每个 source 独立库；同类型多服务器共享库和缓存。
- 没有文件内容哈希；只能用元数据匹配。
- 播放解析只在 `_resolvePlaybackUri` 汇聚，普通播放和 gapless 都经过它。

### 匹配算法

规范化：

- 小写、全角转半角、去 `feat./ft.` 和标点、压缩空白。
- 拼音串只作平局裁决。

硬门槛：

- 时长差 > 8 秒直接拒绝。

评分：

- 时长 ≤1.5s +40，≤3s +25，≤5s +10；
- size 相等 +30；
- format 相等 +5；
- title 精确 +20，token Jaccard ≥0.8 +10；
- artist 精确 +15；
- album 精确 +10；
- track + disc 相等 +5。

接受：

- ≥85 strong，70–84 probable；
- 最佳候选领先第二候选 ≥15，否则放弃；
- 本地候选要求文件存在。

回退顺序：

1. 当前歌曲缓存；
2. 活动服务器（含地址级 failover/relay）；
3. 主动 re-probe 当前服务器；
4. 其他服务器（首发只建议使用已完成分 server 存储迁移的源；否则不启用）；
5. 本地库；
6. 失败，沿用现有停止/提示。

Hook：

- 扩展 `_PlaybackSource` 增加 `originServerId` / `nativeSongId` / `originSourceType` / `matchConfidence`。
- `_reportServerProgress` 与 scrobble 使用实际播放源，而不是全局 `streamClient`。
- 队列/媒体会话仍显示当前歌曲，但后台知道来源。

## 3.4 源健康仪表盘

### 现状

- `ServerLibraryStats` 有延迟、扫描、统计信息；
- `ServerStatusPage` 打开时强制拉取，只有 Navidrome/Emby 有入口；
- 没有持久化健康历史，只有 `lastGoodUrl`。

### 设计

文件：`<appSupport>/source_health.json`

```text
sources[serverId] = {
  name, sourceType,
  addresses[{key, hostHint, lastOkAt, lastFailAt,
              latencyMs, consecutiveFailures, lastErrorKind}],
  library{songCount,lastScanAt,scanning,canScan},
  sync{lastSyncAt,lastResult,lastDurationMs},
  queue{pending,dead,lastSentAt},
  cacheBytes
}
```

- 地址只保存打码 host + 哈希 key，不保存密码或完整 URL。
- 采样：5 分钟一次、前台恢复、同步后；同 server 60 秒内不重复探测。
- 复用 `Config._probe`，需要从私有方法改为可复用服务。
- 页面 `SourceHealthPage`：全局横幅 → 每源卡片 → 立即测试全部。
- 点击卡片进入现有 `ServerStatusPage`；状态页改为先显示缓存再后台刷新。
- 入口：服务器列表顶部、设置“源与可靠性”。

## 3.5 上线顺序

1. scrobble 队列 + 错误分类 + 健康数据文件。
2. 同步差异预览（本地/WebDAV 先行，再做流媒体）。
3. 等价曲目回退（先只允许缓存/本地/活动源）。
4. 健康仪表盘。

## 3.6 验收

- 飞行模式完整播放 ≥2/3 后产生 1 条队列事件；恢复网络按退避发送，成功清空；重启不丢。
- 本地/WebDAV 预览计数与实际应用一致；取消后库不变。
- 流媒体 apply 失败不产生空库。
- 第二源可用时回退播放同一曲，上报发往实际播放源。
- 仪表盘显示所有源的健康、扫描、同步、待发送队列。
- 不保存密码，地址打码。

## 3.7 风险

1. 同类型多服务器共享 metadata/cache —— 首发限制跨服务器回退。
2. 流媒体同步破坏性 —— 必须原子 apply 或临时库。
3. 错误不可分类 —— 先改客户端返回类型。
4. Emby 离线补记无时间戳 —— 文档化重复窗口。
5. 探测风暴/耗电 —— 限频，跳过离线/移动数据。
6. 重命名误判 —— 必须唯一最佳候选门槛。
7. 分页上限 —— 服务端可能截断，预览要校验数量。

**工作量：L（约 6–9 天，可拆成 4 个 PR）**

---

# 4. 统一外壳 + 命令面板 + 首次引导

## 4.1 现状结论

### 视图与导航

- `ViewEntry` 在 normal 模式按 `isTooNarrow` 选择 Portrait / Landscape；TV 强制 BigPicture。
- 所有布局判断只有 `width < 800`，没有平板/桌面专用分支。
- 根页面由 `layersManager` 管理，`switchRootLayer` 是切换而不是 push；细节页挂在各 layer 自己的 Navigator。
- `settings` 也是一个 root layer；设置子页通过 `pushSettingsPage` 推入 layer navigator。
- PlayBar 在 Portrait 是绝对定位 overlay；Landscape 使用 `BottomControl`；`themedRoute` 又会给全屏 route 注入一个 PlayBar。
- BigPicture 有自己独立的页面/顶部标签导航，不使用 `rootLayerMap`。
- 没有侧栏；旧的 sidebar 逻辑已移除。

### 命令面板基础

- 全局键盘只在 desktop 的 `keyboardInit` 注册 Space/Esc/F11；没有 Ctrl+K，也没有全局 Shortcuts/Actions。
- `isTyping` 只由少数输入框设置；GlobalSearchPage 没有设置，导致输入时按空格仍可能切换播放。
- 全局搜索已有：140ms 防抖、内存打分、最近搜索、歌曲/专辑/艺术家/歌单结果和动作。
- 动作入口分散但都可复用：播放/暂停、队列、A–B、每日推荐、设置分类、缓存下载、源切换。

### 首次引导

- `firstLaunch` 是 `Loader` 全局 bool。
- `Loader.init` 在 runApp 前就写 `version.json`；中途杀应用，下次 `firstLaunch=false`，引导被跳过。
- 现有引导是单页 source cards + “开始使用”，没有步骤状态、没有跳过、没有恢复。
- 权限在启动阶段请求，可能阻塞首帧。

## 4.2 统一外壳

### 推荐：混合外壳，不替换 layersManager

- 新增 `AppShell` 包裹 normal 模式的 `PortraitView` / `LandscapeView`；`mini`、`bigPicture` 不包裹。
- `AppShell` 是 Scaffold/Stack，**不是新的 Navigator**。在 root layers 外包 Navigator 会破坏 Android blank-page workaround 和 detail mount。
- 窄屏：底部目标栏。
- 宽屏（shortestSide ≥ 600 或 width ≥ 1000）：左侧 NavigationRail。
- 目标：主页、歌曲、专辑、艺术家、歌单/文件夹、搜索/命令、设置。
- 点击目标调用 `layersManager.switchRootLayer`，保留 `_rootHistory` 和 Android 返回语义。
- 高亮当前目标读 `currentRootLabel`。
- 细节路由继续留在各 layer navigator + `globalNavigatorKey`，shell 不拥有详情页。
- 窄屏把 PlayBar 移入 shell 底部 Stack，位于导航栏上方，移除 PortraitView 的绝对 overlay；全屏 `themedRoute` 仍保留自己的 PlayBar。
- 宽屏保留 BottomControl。
- 首版不动 BigPicture/MiniView/TV，只保证切回 normal 时 shell 重建。

### 不推荐首版做

- 用新 Navigator 重写 `rootLayerMap`；
- 把详情路由收归 shell；
- 同时替换 landscape/portrait/big picture 三套。

## 4.3 命令面板

### 模型

```text
CommandItem {
  id, kind, title, subtitle, keywords, icon,
  section, enabledReason, primaryAction, secondaryActions, score
}
```

章节：

- 动作
- 页面/目标
- 设置
- 歌曲/专辑/艺术家/歌单
- 最近

静态命令：

- 播放/暂停、上一首/下一首、±10 秒、音量；
- 播放模式、队列、A–B、每日推荐、统计；
- 设置分类（复用 `settingsCategoryKeywords`）；
- 视图模式切换、切换源、缓存/下载当前队列。

动态搜索：

- 复用现有搜索打分：精确 > 前缀 > 包含 > 词首；拼音用 `compareTitle`。
- 每类限制条数（歌曲 5、专辑/艺术家/歌单各 3、设置 6）。
- 120–160ms 防抖，generation 丢弃旧结果。
- 服务端搜索只在显式提交时触发，不逐字请求。

入口：

- 桌面 Ctrl+K；
- shell 搜索图标/导航项；
- 移动端长按 mini 播放器或封面。

键盘：

- ↑/↓ 选择，Enter 执行，Esc 关闭；
- Ctrl+Enter 执行次要动作，Tab 切章节；
- 输入时必须设置 `isTyping=true` 并在关闭时恢复，修复空格误触播放。

可用性：

- 禁用项保留并显示原因，不直接隐藏；
- 删除文件/移出曲库等破坏性动作不进入 v1 面板；
- 复用现有动作 helper，不重复搜索/路由逻辑。

## 4.4 首次引导

新状态文件：

```text
<appSupport>/onboarding.json
{completed, version, step, sourceType, serverId, firstLibraryReady}
```

规则：

- 只在完成或明确跳过时写 `completed=true`；
- 已有 `version.json` 的旧安装迁移为已完成；
- 现有 `version.json` 不再作为引导完成依据。

步骤：

1. 欢迎
2. 选择来源（本地默认，服务器/WebDAV 可选）
3. 配置（服务器列表或文件夹）
4. 连接/扫描（进度可取消）
5. 完成 + 第一次播放
6. 可跳过

本地优先：

- 允许空库完成，落到首页空态，提供“添加文件夹/添加服务器”。
- 服务器流程用 `config.activateServer`；离线模式禁用远端，但允许缓存库。
- 权限请求移入文件夹/扫描步骤；启动权限请求保留为兼容，但不阻塞首帧。
- 首次播放：随机全部或前 N 首；无歌曲显示空态。
- 中断恢复：重开在保存的步骤，扫描用 `firstSync` 幂等续跑。

## 4.5 迁移阶段

1. 抽出 `CommandRegistry` / 导航动作服务，纯测试；修 `isTyping`。
2. 命令面板先上 Ctrl+K + 搜索入口，复用现有搜索结果。
3. 加 `AppShell`（normal only，feature flag）：窄屏底栏、宽屏 rail；移动 PlayBar。
4. 用 onboarding 状态机替换 `firstLaunchView`；持久化/旧用户迁移。
5. 清理 sidebar 时代假设，补 l10n、widget/golden 测试，再默认开启。

## 4.6 验收

- normal 模式在每个尺寸都有统一入口，当前目标高亮。
- Ctrl+K 打开/关闭，方向键+Enter 执行，焦点返回；输入时空格不播放。
- 面板覆盖页面、设置、歌曲/专辑/艺术家/歌单；禁用项显示原因。
- 移动端有可见入口，不只依赖硬件键盘。
- Android 返回、详情 pop、设置子页 pop 与 root history 保持原行为。
- onboarding 完成/跳过独立持久化；杀进程后从保存步骤恢复；空库/无服务器可用。
- BigPicture/MiniView/TV/全屏路由不受影响。
- analyze 与全部测试通过。

## 4.7 风险

- `version.json` 提前写入导致引导丢失；
- 在 root layers 外包 Navigator 会破坏 blank page/detail mount；
- PlayBar 重复或遮挡；
- BigPicture 进入时清空 layers，回 normal 要能重建；
- 桌面最小窗口 1050x700 与断点；
- 设置顺序持久化和 l10n 兼容。

**工作量：L（约 8–12 天，分 4–5 个阶段）**

---

# 5. 建议实施顺序与拆分

| 顺序 | 功能 | 依赖 | 建议拆分 | 预估 |
| --- | --- | --- | --- | --- |
| 1 | 曲库歌词全文搜索 | 无，独立 | 索引库/索引器/查询/UI | 3–5 天 |
| 2 | 播放会话日记 + 今日回忆 | 播放计时、统计 UI | 模型/采集/页面/今日回忆 | 3–5 天 |
| 3a | 离线 scrobble 队列 | 客户端错误分类 | 队列/重试/发送 | 2–3 天 |
| 3b | 同步差异预览 | 本地/WebDAV 扫描 | 预览/原子 apply/UI | 2–3 天 |
| 3c | 等价曲目回退 | 元数据匹配、源访问 | 匹配器/回退链/来源标记 | 2–3 天 |
| 3d | 源健康仪表盘 | 探测复用、健康文件 | 采样/页面/状态页改造 | 1–2 天 |
| 4a | 命令面板 | 搜索/动作服务 | 注册表/键盘/UI | 2–3 天 |
| 4b | 统一外壳 | layers 语义 | AppShell/目标栏/PlayBar | 3–5 天 |
| 4c | 首次引导 | onboarding 状态机 | 状态机/步骤/迁移 | 2–3 天 |

**建议先做 1 和 2**：它们独立、收益明确、不会碰导航和同步架构。  
**3 放在中间**：它需要改客户端错误类型和同步 apply，影响面较大。  
**4 最后**：外壳会碰到所有页面，适合单独一个版本集中验收。

---

# 6. 需要用户确认的决策

1. 歌词索引是否允许自动请求 Navidrome/Feiniu 的全部歌词，还是默认只索引已有/已缓存歌词。
2. 会话日记入口放在首页按钮还是听歌报告内部；是否允许“恢复这段队列”。
3. 离线 scrobble 队列是否默认开启，以及认证失败是否自动冻结。
4. 等价曲目回退首发是否只允许当前源/缓存/本地，暂不跨同类型第二服务器。
5. 统一外壳的宽屏形态：NavigationRail 还是保留 BottomControl + 可展开侧栏。
6. 首次引导是否允许空库完成并直接进首页。
7. 会话日记/歌词索引是否包含在现有备份文件中。

---

# 7. 结论

- 四项都能在当前架构上实现，但难度差异很大：
  - 歌词搜索和会话日记是独立功能，风险可控；
  - 离线可靠性包的核心难点不是 UI，而是**错误分类、破坏性同步和同类型多服务器共享存储**；
  - 统一外壳是四项里唯一会触碰所有页面和返回语义的，必须单独排期。
- 不建议四项同时开工。推荐顺序：**歌词全文搜索 → 会话日记 → 离线可靠性 → 外壳/命令面板/引导**。
