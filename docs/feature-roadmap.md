# 临音（Lain）下一阶段功能路线图

> 生成日期：2026-11-16
> 范围：本地曲库、流媒体源（Navidrome / Emby / 飞牛音乐）、全音源通用能力，以及一份单独的视觉与体验思考清单。
> 方法：只读代码与现有 API，核对 `lib/` 下的实现、设置入口、数据表和三个流媒体客户端；不修改源码、不提交。
> 结论：当前版本已经把“播放、缓存、下载、广播、评论、本地工具、统计、车机”这些主干做得很完整。下一步最值得补的是**播放质量与曲库整理效率**，而不是再堆新页面。

---

## 0. 阅读说明

### 0.1 优先级

| 优先级 | 含义 |
| --- | --- |
| P1 | 下一版就值得做，直接改善日常使用或补上明显空白 |
| P2 | 之后一到两个版本做，需要一些设计、迁移或真机验证 |
| P3 | 有空再做，收益真实但不如 P1/P2 普遍 |

### 0.2 工作量

| 工作量 | 含义 |
| --- | --- |
| S | 约 1 天内，1–3 个文件，主要是 UI 或一个 API 调用 |
| M | 约 2–5 天，涉及数据表迁移、多个页面或跨层逻辑 |
| L | 一周以上，涉及播放器重构、平台配置或较大的交互设计 |

### 0.3 共同成本与边界

- 所有新文案都要同时写入 `lib/l10n/app_zh.arb` 与 `lib/l10n/app_en.arb`，再生成 `lib/l10n/generated/`。
- 数据表改动按 `lib/base/data/database.dart` 现有的 `schemaVersion` + `MigrationStrategy.onUpgrade` 方式做，不要重建表。
- **服务端只做读、歌单、收藏和播放上报，不做标签写入**：Navidrome、Emby、飞牛目前都没有给客户端写音频标签的 API。标签编辑只能留在本地曲库。
- Navidrome 的智能歌单（NSP）是服务器文件系统里的文件，Subsonic API 不能创建；因此“智能歌单”只能做客户端规则，不能承诺写回服务器。
- 飞牛音乐公开/已用接口很有限，见 `lib/base/services/feiniu_client.dart`：`/track/list`、`/playlist/*`、`/favorite-track/*`、`/play-history/list`、`/lyric/list`、`/event/report`、`/track/stream`。没有随机、相似、流派、评分、扫描触发等接口；飞牛上对应功能应隐藏或降级为本地过滤。

### 0.4 已实现、不再列入本路线图

以下能力已经在代码里，不再作为“新增功能”提出：

| 已实现 | 主要代码 |
| --- | --- |
| 广播模式 / 封面广播模式 / 车机歌词 | `lib/base/data/cover_broadcast_mode.dart`、`lib/base/services/media_broadcast.dart` |
| 缓存与下载管理、任务暂停/继续、按音质缓存 | `lib/base/services/cache_download_manager.dart`、`lib/base/services/download_manager.dart`、`lib/base/widgets/cache_tasks_page.dart` |
| 品质标识 HR/SQ/HQ、缓存标识、收藏标识 | `lib/base/widgets/quality_badge.dart`、`lib/base/widgets/cache_badge.dart` |
| 局域网直连、地址自动切换 | `lib/base/data/lan_direct_setting.dart`、`lib/base/data/config.dart`、三个客户端的 `getStreamUrl` |
| 评论 / 评论服务器 / 楼层回复 | `lib/base/services/comment_client.dart`、`lib/base/widgets/comment_page.dart` |
| 本地工具：命名、整理、刮削、歌词时间轴、专辑时间轴 | `lib/base/widgets/local_library_tools_page.dart`、`lib/base/services/library_organizer.dart`、`lib/base/services/metadata_scraper.dart`、`lib/base/widgets/lyric_timeline_page.dart`、`lib/base/widgets/album_timeline_page.dart` |
| 听歌统计、年度/月度热力图、专辑时间轴 | `lib/base/data/stats.dart`、`lib/base/widgets/stats_page.dart`、`lib/base/data/album_timeline.dart` |
| 驾驶模式、横竖屏、大屏模式 | `lib/portrait_view/pages/driving_mode_page.dart`、`lib/big_picture_view/` |
| 服务器状态页、统计卡片、地址延迟 | `lib/base/widgets/server_status_page.dart`、`lib/base/services/navidrome_client.dart` |
| 首页小组件（2x2 / 4x2） | `lib/base/services/home_widget_service.dart` |
| 歌词逐字/卡拉 OK、翻译行、歌词偏移 | `lib/base/services/lyric.dart`、`lib/base/widgets/lyric_list_view.dart`、`MyAudioMetadata.lyricsTimeOffset`、`lib/portrait_view/pages/portrait_lyrics_page.dart` |
| 歌单手动离线下载 | `lib/base/widgets/cache_group_page.dart` + `showCacheDownloadDialog` |
| 播放模式、队列排序、多选基础操作 | `lib/base/audio_handler.dart`、`lib/landscape_view/pages/play_queue_page.dart`、`lib/base/widgets/selectable_song_list_page.dart` |

---

## 0.5 本轮已落地（2026-11-16）

以下条目已按路线图实现，并各自保留独立提交，便于回滚：

| 功能 | 对应提交 | 说明 |
| --- | --- | --- |
| C1 ReplayGain / 音量归一化 | `3a88711` | 关闭 / 按单曲 / 按专辑，设置持久化，切歌前重新应用 |
| C11 播放速度 | `3a88711` | 0.5x–2.0x，播放中即时生效 |
| C7 播放淡入淡出 | `5c03c62` | 开始、暂停、切歌时短促渐入渐出，可关闭；手机端回到播放器自身音量而非应用滑杆默认值 |
| C6 清空撤销 | `af1c9fb` | 清空前保存队列、索引与位置，底部撤销条恢复并继续播放 |
| B8 播放会话与进度上报 | `af1c9fb` | 媒体会话位置每秒更新，通知栏、锁屏与车机进度不再只靠事件跳变 |
| A3 本地自动增量扫描 | `a5ecbaf` | 启动后、回前台与设定间隔触发，复用 mtime 判断，只读改动文件 |
| B3 服务器状态页“立即扫描” | `0e62e62` | 调用 Subsonic `startScan`，需管理员账号；确认后读取扫描状态 |
| B5 离线缓存库模式 | `87ac4f9` | 离线时可选本地库或当前服务器缓存；数据库不裁剪，退出模式无需重新同步 |
| A1 曲库体检 + A2 重复分组 | `2327325` | 汇总缺标签/封面/歌词，按标题、艺术家与时长分桶分组；只读，不改文件 |
| D6 骨架屏 | `4566171` | 歌曲列表与专辑/艺术家/歌单列表加载时使用骨架占位 |
| D1 列表到详情共享封面 | `293d628` | 歌单行改用歌单自身的稳定 tag，与详情页一致；专辑/艺术家沿用已有 tag |
| D2 切歌封面交叉淡入 | `32ed258` | `CoverArtWidget` 以封面身份为 key 做淡入淡出 |
| D4 歌词页封面呼吸 / 视差 | `64947f1` | 播放时轻微缩放呼吸，竖屏翻页时反向位移并略微缩小 |
| D7 进度条时间气泡 + 平滑推进 | `e3f37c8` | 拖动时显示目标时间；位置在播放器事件之间逐帧外推 |

尚未实现的重点：智能歌单、服务端搜索、相似 / InstantMix、无缝播放、批量操作扩展。路线图其余条目的优先级与边界仍然有效。

---

## 1. 推荐顺序（Top 10）

| 排名 | 功能 | 类别 | 工作量 | 优先级 | 一句话理由 |
| --- | --- | --- | --- | --- | --- |
| 1 | ReplayGain / 音量归一化 | C | S/M | P1 | 混合曲库和流媒体响度差是最影响听感的问题，mpv 原生支持，接一个设置即可 |
| 2 | 曲库体检 + 重复歌曲清理 | A | M | P1 | 把“库很乱”变成可执行清单，直接接到已有的刮削/命名/歌词工具 |
| 3 | 智能歌单 / 规则筛选 | C | M | P1 | 用现有标签和播放数据自动生成歌单，所有音源都能用 |
| 4 | 多选批量操作扩展 | C | M | P1 | 已有多选框架，补收藏/缓存/下载/评分后整理效率翻倍 |
| 5 | 本地自动增量扫描 | A | S/M | P1 | 本地库新增歌曲不必每次手动“开始扫描” |
| 6 | 搜索历史 + 高级筛选 | C | S/M | P1 | 全局搜索目前只搜三个字段且不记历史，改造成本低、每天都会用 |
| 7 | 服务端搜索 / 相似歌曲 | B | M | P2 | 把服务器已有的 search3、InstantMix 用起来，弥补本地缓存未同步时的空白 |
| 8 | 睡眠定时增强（淡出/播完专辑） | C | S | P2 | 现有定时器已经能用，补淡出和“播完当前队列”体验提升明显 |
| 9 | 离线缓存库模式 | B | M | P2 | 断网时不必强制切到本地库，继续听当前服务器已缓存的内容 |
| 10 | 队列历史与清空撤销 | C | M | P2 | 队列只有当前一份，误清空无法恢复；快照成本低、价值直接 |

---

## 2. A 类：本地曲库专属功能

> 只对 `sourceType == .local` 开放，入口按现有 `isLocalLibrary` 判断。不要用 `isNotStreamSource`，因为 WebDAV 也是远程源。

### A1. 曲库体检（Library Health）

**功能**：新增一个“曲库体检”页，汇总缺标题/艺术家/专辑/封面/歌词、无年份、低码率、路径失效、疑似重复等项，点进去直接跳到已有的单曲或批量修复工具。用户第一次能看清自己的库到底缺什么。

**可行性依据**：`lib/base/widgets/metadata_completion_page.dart` 已有 `songHasMissingTags`、`songHasMissingCover`、`songHasMissingLyrics`、`countSongsMissingTags`；`lib/base/data/database.dart` 的 `MetadataItems` 已有 `genre/year/bitrate/samplerate/size/duration/path`；`Folder.pathAndModified` 可判断文件是否还在；`LocalLibraryToolsPage` 是现成入口。缺的是汇总页、低码率阈值、路径失效对比和“体检项 → 修复动作”的映射。

**价值**：把“感觉库很乱”变成有优先级的可执行清单，并且复用已经做好的刮削、命名、歌词工具，不需要重复造轮子。

**工作量**：M　　**优先级**：P1

### A2. 重复歌曲检测与清理

**功能**：按“标题 + 艺术家 + 时长（允许 ±2 秒）”或“文件大小 + 路径”分组，可选用文件头尾各 1 MB 的 SHA-256 做内容确认；并排显示码率、大小、路径，支持保留一个、其余移入回收站或仅从曲库移除。

**可行性依据**：`MetadataItems` 已有 `title/artist/duration/size/path`；`crypto` 已是依赖；`lib/base/services/library_organizer.dart` 的 journal/undo 模式可复用于“移入回收站/撤销”。当前代码没有任何去重分组或音频指纹逻辑。

**价值**：直接节省存储空间，避免同一首歌在播放统计、随机播放和歌单里重复出现。

**工作量**：M　　**优先级**：P1/P2

### A3. 本地自动增量扫描

**功能**：可选在启动时、定时或连上 Wi-Fi 时扫描本地文件夹，只重新读取修改过的文件；新歌直接出现在“最近添加”，删除的文件从曲库消失，并给出简短结果提示。

**可行性依据**：`Folder.setFileAndModified()` 已经返回 `pathAndModified` 与 `pathAndCreated`；`Library.sync()` 已按修改时间判断是否需要重新解析；缺的是设置项、调度器，以及避免每次启动都全量扫的策略。`Loader.load()` 在本地源下目前只读数据库，不会自动扫描。

**价值**：本地用户不再需要每次手动点“开始扫描”，新下载的歌自动入库存。

**工作量**：S/M　　**优先级**：P1

### A4. 批量标签编辑

**功能**：多选歌曲后统一设置专辑艺术家、专辑、流派、年份、碟号、封面或歌词，先给出变更预览再批量写入。适合合辑、原声带、多碟专辑整理。

**可行性依据**：`lib/base/services/metadata_write.dart` 的 `writeSongTags` 已能写入标签、封面和歌词；`lib/base/widgets/edit_metadata.dart` 已有单曲字段表单；`SelectableSongListPage` 已有多选状态。缺的是“只改选中字段、其余保留”的批量表单和顺序写入/撤销。

**价值**：比逐首编辑快一个数量级，且能复用现有写标签和封面缓存刷新逻辑。

**工作量**：M　　**优先级**：P2

### A5. 本地删除 / 从曲库移除 / 在文件夹中显示

**功能**：多选后提供“仅从曲库移除（保留文件）”“删除文件（可选回收站）”“在文件管理器中显示”三个动作，删除前明确影响范围。

**可行性依据**：`Library.sync()` 会按 `validId` 丢弃已不存在的歌曲；`Folder.songList`、`_songIdListFile` 可同步维护；当前没有公开的本地文件删除或单曲移除方法。`LibraryOrganizer` 的 journal 机制可以借鉴来做可撤销删除。

**价值**：补齐本地曲库管理的最后一环；现在只能去系统文件管理器删文件，再等一次全量扫描。

**工作量**：M　　**优先级**：P2

### A6. 单文件夹重扫

**功能**：在本地文件夹列表里对某个根目录单独重扫，只处理该目录，结束后显示新增/移除数量，不影响其他文件夹和正在播放的队列。

**可行性依据**：`Library.sync()` 已遍历 `folderList` 并复用 `Folder.setFileAndModified()`；缺一个 `syncFolder(folder)` 入口、局部 `_saveMetadata` 和进度提示。

**价值**：多根目录、大曲库用户不必为了一个目录跑全库扫描。

**工作量**：S/M　　**优先级**：P2

### A7. DSD / CUE 支持

**功能**：扫描并播放 `.dsf`、`.dff`；把 `.cue` 当作专辑索引，整轨文件按 CUE 切分显示为多首。先生效于本地源。

**可行性依据**：播放层 media_kit/mpv/FFmpeg 支持 DSD 与 CUE 解复用；`lib/base/data/folder.dart` 的 `_loftySupportedExts` 目前不含 `dsf/dff/cue`；`_parseMetadataIfNeed` 依赖 lofty 读标签，读不到时需要回退到文件名/目录信息。缺 CUE 解析与“整轨 + 分轨”的数据模型。

**价值**：面向本地无损/发烧友曲库，是现在本地源最明显的格式空白。

**工作量**：L　　**优先级**：P3

### A8. 系统“打开方式 / 分享到临音”

**功能**：从系统文件管理器或分享面板把音频文件、文件夹发给临音，直接播放单文件或把文件夹加入本地曲库。

**可行性依据**：Android 清单目前只有 `MAIN/LAUNCHER`，没有 `ACTION_VIEW` 的音频 intent-filter；iOS `Info.plist` 也没有 `CFBundleDocumentTypes`。`file_picker`、`Folder`、`Loader` 已能消费路径，缺的是平台入口和启动参数处理。

**价值**：减少“先打开 App、再添加文件夹、再扫描”的步骤，也方便从下载目录直接试听。

**工作量**：M　　**优先级**：P2/P3

### A9. 歌词 / 封面批量导出

**功能**：把本地歌曲的 `.lrc` 与封面按目录结构批量导出到用户选择的文件夹，用于备份或迁移到其他播放器。

**可行性依据**：`song.lrcPath`、`song.picture.path` 已存在；`lib/base/services/lyric.dart` 已有 sidecar 读取与写回；`path_provider`/`file_picker` 已有。缺导出入口和命名规则。

**价值**：本地工具目前能改元数据，但不能把成果整体带走；导出后用户不会被锁在应用里。

**工作量**：S　　**优先级**：P3

### A10. 更多刮削源（MusicBrainz / Discogs）

**功能**：在现有网易云、QQ 音乐之外增加 MusicBrainz、Discogs 等元数据源，覆盖外文、古典和冷门唱片。

**可行性依据**：`lib/base/services/metadata_scraper.dart` 已抽象出 `MetadataProvider`、`ScrapedCandidate`、`RateLimitException`，新增 provider 不改刮削 UI；目前只有 `NetEaseProvider` 与 `QqMusicProvider`。需要处理 MusicBrainz 的 User-Agent/速率限制。

**价值**：中文曲库之外的补全准确率会明显提高，且完全复用现有批量刮削、候选卡和撤销流程。

**工作量**：M　　**优先级**：P2/P3

---

## 3. B 类：流媒体源专属功能

### 3.1 API 支持矩阵（先看这里）

| 能力 | Navidrome / Subsonic | Emby | 飞牛音乐 | 说明 |
| --- | --- | --- | --- | --- |
| 服务端搜索 | `search3.view` ✅（已用于空查询取歌） | `SearchTerm` ✅ | 未发现 | 飞牛只能本地过滤 |
| 相似歌曲 / InstantMix | `getSimilarSongs2` ✅（需按版本探测） | `/Items/{id}/InstantMix`、`/Items/{id}/Similar` ✅ | ❌ | 飞牛无相似接口 |
| 相似艺人 | `getArtistInfo2` 的 similarArtist ✅ | `/Items/{artistId}/Similar` ✅ | ❌ | 需新增解析 |
| 流派 / 按流派取歌 | `getGenres`、`getSongsByGenre` ✅ | `/Genres`、`/MusicGenres`、`/Items?GenreIds=` ✅ | ❌ | 飞牛无流派接口 |
| 触发服务器扫描 | `startScan.view` ✅（通常需管理员） | `POST /Library/Refresh` ✅ | ❌ | 状态可复用 `getScanStatus` |
| 播放进度上报 | `scrobble.view?submission=false` ✅ | `/Sessions/Playing/Progress` ✅ | 仅 `/event/report` | 目前都只在上报“播完” |
| 专辑/艺人收藏 | `star.view` / `unstar.view` ✅ | `/Users/{userId}/FavoriteItems/{id}` ✅ | 仅单曲收藏 | Emby 客户端未接实体收藏 |
| 书签 / 续播点 | `getBookmarks` / `createBookmark` ✅（需探测） | UserData 播放位置（需接） | ❌ | 跨端续播 |
| 随机歌曲 | `getRandomSongs.view` ✅ | `SortBy=Random`（需实测） | ❌ | 本地已有全量库时价值有限 |
| 网络电台 | `getInternetRadioStations` ✅（需实测） | 无同义接口 | ❌ | P3 |
| 写歌单 / 收藏 | ✅ | ✅ | ✅ | 现有客户端已接 |
| **写音频标签** | ❌ | ❌ | ❌ | 只能本地做，路线图不包含 |

### B1. 服务端搜索（与本地结果合并）

**功能**：全局搜索在本地 `library.songList` 之外并行请求服务器搜索，把尚未同步进本地的歌曲、专辑、艺人合并进来并去重。对刚在服务器加歌、或首次同步还没跑完的场景最有用。

**可行性依据**：`lib/portrait_view/global_search_page.dart` 目前只对 `library.songList` 做 `title/artist/album` 的本地 `contains`；`StreamClient` 没有 `search` 方法。Navidrome 的 `/rest/search3.view` 已在 `getSongs` 中使用（空 query 取全量），加 query/albumCount/artistCount 即可；Emby 的 `/Users/$userId/Items?SearchTerm=` 已有同类调用；飞牛没有验证到搜索参数，可隐藏服务端搜索并保留本地过滤。

**价值**：大曲库和刚改完服务器的用户不用等全量同步，也不会搜不到新歌。

**工作量**：M　　**优先级**：P2

### B2. 相似歌曲 / InstantMix / 相关艺人

**功能**：在歌曲、专辑、艺人菜单里增加“以此生成电台”或“播放相似歌曲”，结果由服务器相似度给出；艺人页增加“相似艺人”区块。没有相似接口的源回退到同流派/同艺人的本地筛选。

**可行性依据**：Navidrome 侧可用 `/rest/getSimilarSongs2.view` 与 `getArtistInfo2` 的 similarArtist；Emby 侧可用 `/Items/{id}/InstantMix`、`/Items/{id}/Similar`；现有 `NavidromeClient.getArtistInfo` 只取了 biography/image，`EmbyClient` 也没有相似方法。飞牛只有 `/track/list`，无相似接口，需隐藏或本地兜底。

**价值**：比“随机播放”更贴近用户当前口味，是流媒体源真正有服务器价值的功能之一。

**工作量**：M　　**优先级**：P2

### B3. 服务器状态页“立即扫描”

**功能**：在服务器状态页增加“立即扫描”按钮，显示扫描中/完成，并在完成后自动刷新歌曲数、专辑数和最近扫描时间。

**可行性依据**：`lib/base/widgets/server_status_page.dart` 已有刷新和 `libraryStats(forceRefresh: true)`；`NavidromeClient` 已有 `getScanStatus`，只差 `/rest/startScan.view`；Emby 用 `POST /Library/Refresh`。飞牛无接口，按钮不显示。

**价值**：服务器加歌后不必切到网页端；把状态页从“只看”变成“可操作”。

**工作量**：S　　**优先级**：P2

### B4. 弱网自适应转码 / 原文件回退

**功能**：播放失败、频繁缓冲或长时间无进度时，自动降一档码率重开当前曲；仍失败则回退原文件；网络恢复后可提示升回原设置。

**可行性依据**：`streamQualityNotifier`、`streamFormatNotifier` 与三个客户端的 `getStreamUrl` 已按全局设置生成转码 URL；`audio_handler.dart` 的加载 catch 已有“地址切换后重载”的恢复逻辑（约 1675 行），但没有码率回退。需要监听 buffering/error/position 停滞并控制重试次数。

**价值**：移动网络和弱 Wi-Fi 下不再直接停住，用户不必手动去设置里改音质。

**工作量**：M　　**优先级**：P2

### B5. 离线缓存库模式（不强制切本地库）

**功能**：当前源是流媒体且断网/用户主动进入离线时，保留该服务器的上下文，提供“离线库”视图：只显示已缓存歌曲、缓存歌单和缓存专辑，未缓存的置灰或隐藏。与现有“离线模式强制切到本地曲库”区分开。

**可行性依据**：`CachedSong`、`groupCacheBySong`、`cacheEntriesNotifier`、`song.cacheExist` 已能列出缓存内容；`lib/base/data/offline_setting.dart` 的 `offlineModeNotifier` 目前在 `Loader.init()` / `config.activateLocal()` 中直接切到本地源。缺的是按服务器缓存构建的浏览页和入口。

**价值**：地铁、飞机、服务器临时不可达时，用户仍能按自己的服务器曲库习惯听歌，而不是被迫换库。

**工作量**：M　　**优先级**：P2

### B6. 歌单离线自动同步（增量）

**功能**：每个歌单可开启“自动离线”：Wi-Fi 下自动补齐歌单里尚未缓存的新歌，歌单删歌时可选是否清理对应缓存；页面显示“已同步 / 待补 N 首”。

**可行性依据**：手动入口已经存在：`lib/base/widgets/cache_group_page.dart` 对歌单调用 `showCacheDownloadDialog(context, playlist.songList)`，底层是 `cacheDownloadManager.start` + `library.tryAddCache`。缺每歌单的开关持久化、增量 diff 和启动/联网触发。现有的手动下载不应重复实现。

**价值**：通勤歌单一次设置后不用每次手动点下载，且只补新增歌曲，省流量。

**工作量**：M　　**优先级**：P2

### B7. 下载 / 缓存断点续传

**功能**：暂停、失败或 App 被杀后，从断点继续下载，而不是删除半成品重下整首；任务页显示“已下载 x%”。

**可行性依据**：`lib/base/services/download_manager.dart` 在暂停/失败时 `_deleteFile(path)`；`lib/base/data/library.dart` 的 `_downloadSongToCache` 也会删除 `.part`；`downloadSong` 接口没有 offset/Range 参数。需要给 `StreamClient.downloadSong` 增加 `resumeFrom`，并在 `.part` 旁保存元数据。Navidrome/Emby 的 HTTP 下载通常支持 Range，飞牛需实测。

**价值**：移动网络、大文件、长任务被中断时不再浪费已下载流量。

**工作量**：M　　**优先级**：P2

### B8. 播放会话与进度上报

**功能**：歌曲开始、暂停、进度变化和播完时同步给服务器，让服务器端“正在播放”、多端继续播放和播放统计更准确；仍保留本地“播完才计一次”的听歌报告规则。

**可行性依据**：`StreamClient.scrobble` 目前只在 `history.addSongTimes` 到达条件时调用；`EmbyClient.scrobble` 会立即 `POST /Sessions/Playing` 再 `Stopped`，中间没有进度。Navidrome 可用 `scrobble.view?submission=false`，Emby 用 `/Sessions/Playing/Progress`，飞牛只有 `/event/report` 的 `track_play`。

**价值**：多端/Navidrome 网页端能看到当前播放；服务器统计不再把一次播放记成零长度会话。

**工作量**：S/M　　**优先级**：P3

### B9. Emby 专辑 / 艺人收藏

**功能**：Emby 源也能像 Navidrome 一样收藏整张专辑和艺人，而不只是单曲。

**可行性依据**：`EmbyClient.updateStarredSongs` 已使用 `/Users/$userId/FavoriteItems/$id`，说明实体收藏 API 可用；但 `StreamClient.supportsEntityFavorites` 默认 `false`，`EmbyClient` 没有覆盖 `setStarred` / `getStarredIds`。Navidrome 已经实现，补 Emby 即可。

**价值**：补齐 Emby 用户的收藏习惯，专辑/艺人页的收藏按钮不再缺失。

**工作量**：S　　**优先级**：P3

### B10. 相似艺人区块

**功能**：艺人页底部显示相似艺人，可点进对方页面或直接播放其热门歌曲。

**可行性依据**：Navidrome 的 `getArtistInfo2` 返回 `similarArtist`，但现有 `NavidromeClient.getArtistInfo` 只解析 biography/image；Emby 可用 `/Items/{artistId}/Similar`。飞牛无接口，区块隐藏。

**价值**：在不引入推荐系统的前提下利用服务器已有数据做发现。

**工作量**：M　　**优先级**：P3

### B11. 服务器网络电台

**功能**：如果服务器配置了网络电台，在首页或“流媒体”页列出并播放；没有配置时不显示。

**可行性依据**：Subsonic 标准有 `getInternetRadioStations`；Navidrome/Emby 的实际支持需要在目标服务器上探测，飞牛没有。建议用能力探测：请求失败或返回空就隐藏入口，不把它做成必现功能。

**价值**：给服务器用户一个额外的内容来源，但优先级明显低于搜索/相似/离线。

**工作量**：M　　**优先级**：P3

---

## 4. C 类：全音源通用功能

### C1. ReplayGain / 音量归一化

**功能**：提供“关闭 / 单曲增益 / 专辑增益”三档，并支持 preamp 微调；让不同年代、不同母带的歌曲响度接近，切歌不再忽大忽小。

**可行性依据**：mpv 原生支持 `--replaygain=<no|track|album>`、`--replaygain-preamp`、`--replaygain-fallback`；项目已经在 `audio_handler.dart` 通过 `(_player.platform as NativePlayer).setProperty('af', af)` 设置滤镜，同样的 `setProperty('replaygain', ...)` 可用。缺的是设置项、持久化和在 `load()`/设置变更时应用。流媒体文件若没有 ReplayGain 标签则不生效，这是正常限制。

**价值**：这是混合曲库和流媒体播放最直接的声音体验提升；不需要改文件，也不需要服务器支持。

**工作量**：S/M　　**优先级**：P1

### C2. 智能歌单 / 规则筛选

**功能**：用户用规则组合（流派、年代、码率、采样率、时长、播放次数、最近播放、收藏、加入时间）保存一个“智能歌单”，列表随曲库变化自动更新；也可一键“固化”为普通歌单或服务器歌单。

**可行性依据**：`MetadataItems` 已有 `genre/year/bitrate/samplerate/duration/playCount/lastPlayed/album/artist/title`，`library.songList` 在内存中可直接求值；`playlistManager.createPlaylist` 与 `updatePlaylistSongs` 可把结果写成普通/服务器歌单。当前没有规则模型和智能歌单入口。**Navidrome 的 NSP 智能歌单是服务器文件，不能通过 Subsonic 创建，所以必须做客户端规则**。

**价值**：用已有标签和播放数据自动整理，比手动建歌单可持续，所有音源都能用。

**工作量**：M　　**优先级**：P1

### C3. 多选批量操作扩展

**功能**：在多选页增加批量收藏/取消收藏、批量缓存、批量下载、批量评分（评分功能落地后）、批量移入播放队列；本地源再提供批量移除/删除。现有的加入歌单、下一首播放、稍后播放、批量刮削保留。

**可行性依据**：`lib/base/widgets/selectable_song_list_page.dart` 已有 `isSelectedNotifierMap`、底部操作栏和 `_showLocalActions`；`playlist.add`、`cacheDownloadManager.start`、`downloadManager.startDownload`、`toggleFavoriteState` 都已存在。缺的是把这些动作接到多选结果上，并处理进度/失败提示。

**价值**：整理、离线准备和收藏操作从“逐首点”变成一次完成。

**工作量**：M　　**优先级**：P1

### C4. 搜索历史 + 高级筛选

**功能**：保存最近搜索词（可清除），支持 `流派:jazz`、`年份:1990-1999`、`码率>320`、`最近播放` 等过滤，并可与服务端搜索结果合并。

**可行性依据**：`GlobalSearchPage` 目前只有 `_matches` 对标题/艺术家/专辑做 contains，没有历史记录；`Setting.save()` 可以持久化历史列表；DB 与 `library.songList` 提供字段。缺的是查询解析、历史 UI 和结果排序。

**价值**：找歌从“重新输入”变成“点最近一次”，并能按标签/年代精确过滤。

**工作量**：S/M　　**优先级**：P1

### C5. 睡眠定时增强

**功能**：在现有“定时关闭 / 播完当前曲目暂停”基础上增加：15/30/60/90 分钟快捷项、最后 30 秒渐弱淡出、播完当前专辑或队列后停止、记住上次选择。

**可行性依据**：`lib/portrait_view/sleep_timer.dart` 已有 `remainTimesNotifier`、`pauseAfterCompletedNotifier`、`pauseTimer`；`audioHandler.setVolume` 可做音量渐变；`playQueue`/`currentIndex` 可判断队列/专辑边界。缺淡出函数、边界判断和快捷项。

**价值**：现有定时器会在最后一秒硬停，淡出和“播完这张专辑”更符合入睡/离场场景。

**工作量**：S　　**优先级**：P2

### C6. 队列历史与清空撤销

**功能**：保存最近 5–10 个队列快照；清空或替换队列后可以从“上次队列”恢复；队列页增加“另存为歌单”。删除当前歌曲时也可以撤销。

**可行性依据**：`audio_handler.dart` 已持久化当前 `play_queue_state.json`（`_playQueueState`），`clear()` 会直接清空；`playlistManager` 可创建歌单。缺历史快照文件和恢复入口。

**价值**：误点清空、临时切歌单后想回到原队列，都是高频小事故。

**工作量**：M　　**优先级**：P2

### C7. 均衡器预设

**功能**：在现有 9 段均衡器上增加内置预设（平直、流行、摇滚、人声、低音增强、古典）和“保存当前为自定义预设”，支持重命名/删除。

**可行性依据**：`lib/base/widgets/equalizer.dart` 已有 `freqs`/`gains` 九个频段与滑块；`audio_handler.applyEqualizer()` 生成 `superequalizer` 参数；`saveEqualizerState()` 已持久化 gains。缺预设模型与选择 UI。注意 iOS 上均衡器目前受 `isPremiumNotifier` 门控（`settings_list.dart` 的 `equalizerListTile`），要做预设需先决定是否维持该门控。

**价值**：大多数用户不会手动调九个滑块，预设让均衡器从“有但不用”变成“可用的调音工具”。

**工作量**：S/M　　**优先级**：P2

### C8. 评分（1–5 星）

**功能**：歌曲菜单/播放页可打 1–5 星，列表可按评分筛选/排序；评分可被智能歌单引用。Navidrome 可同步到服务器，其他源先本地保存。

**可行性依据**：`MetadataItems` 没有 rating 列，按现有 `schemaVersion` 迁移即可；`Subsonic` 有 `/rest/setRating.view`；`Emby`/飞牛没有确认的统一写接口，所以只做本地评分，避免“看起来同步了其实没写”。`library.updateMetadata`/`MetadataItemsCompanion` 可写入。

**价值**：用户自己的偏好数据，比“收藏”更细，能支撑智能歌单和排序。

**工作量**：M　　**优先级**：P2

### C9. 无缝播放（Gapless）

**功能**：连续专辑、现场、古典和电子混音在曲目之间没有静音或重建音频设备的间隙。

**可行性依据**：mpv 有 `--gapless-audio=weak`（默认）和 `--prefetch-playlist`；但当前 `audio_handler.dart` 是每首 `_player.open(Media(...))`（约 1640/1655 行），一首播完才开下一首，必然有 open 间隙。需要把“当前 + 下一首”作为 playlist 交给 mpv，或维护双播放器并交接媒体会话/队列。属于播放架构改动，风险高。

**价值**：对专辑型听众是明显体验提升，但只影响连续曲目，故不宜排在 P1。

**工作量**：L　　**优先级**：P2/P3

### C10. 交叉淡入淡出（Crossfade）

**功能**：自动切歌或手动切歌时，用 3–12 秒把旧曲淡出、新曲淡入；可只对自动切歌生效。

**可行性依据**：mpv 没有原生 crossfade 选项；当前是单个 `Player()` 实例。要做只能双播放器 + 两个音量包络，并与 `currentSongNotifier`、媒体会话、缓存预热、GA 统计协调。属于高成本实验项。

**价值**：DJ/派对/连续播放场景好听，但对普通专辑聆听可能反而破坏衔接，因此应默认关闭。

**工作量**：L　　**优先级**：P3

### C11. 播放速度

**功能**：0.5×–2.0× 变速播放，记住设置；适用于长音频、播客式内容或试听。

**可行性依据**：media_kit 的 `Player.setRate(double)`、`setPitch(double)` 已存在；当前只读取 `_player.state.rate`，没有 UI/设置。可加一个播放页菜单项和持久化 notifier。

**价值**：对音乐播放器是小众需求，但对长内容很有用；实现成本低。

**工作量**：S　　**优先级**：P3

### C12. 流派 / 年代浏览

**功能**：新增“流派”和“年代”入口，按 `genre`（支持 `/` 分隔的多值）和 `year` 聚合成列表，可整组播放/随机播放。

**可行性依据**：`MyAudioMetadata.genre` / `year` 已在 `MetadataItems` 与内存模型中；`artistAlbumManager` 已有类似的艺术家/专辑聚合；当前没有流派/年代页。流媒体源也已在全量同步时拿到 genre/year，因此不需要服务端接口；飞牛同样可用本地聚合。

**价值**：给“按风格听”提供一个直接入口，不依赖用户先建歌单。

**工作量**：M　　**优先级**：P2

### C13. 配置与歌单备份 / 恢复

**功能**：把设置、歌单、智能歌单、本地收藏、听歌统计打包导出，换机或重装后导入恢复；服务器歌单可选择重新从服务器拉取。

**可行性依据**：设置已集中写 `setting.json`（`Setting.save`），歌单在各源目录的 JSON 中，统计在 `listening_stats.json`；`file_picker` 已用于导入歌单。缺统一备份格式和恢复冲突处理（同名歌单、同 id 歌曲）。

**价值**：换机、重装、测试版回滚时不再丢设置和歌单。

**工作量**：M　　**优先级**：P2

### C14. 每曲续播 / 长音频书签

**功能**：为长曲、DJ set、有声书/播客记住每首的播放位置，再次打开时询问“从上次位置继续”或自动续播；流媒体源可选同步服务器书签。

**可行性依据**：当前只有全局 `position_state.json`（当前一首），DB 没有 per-song 位置字段。可加 `resumePosition/resumeUpdated` 列；Subsonic 有 `getBookmarks/createBookmark`，Emby 有 UserData 播放位置，飞牛没有。需要明确“短歌不弹续播”的阈值。

**价值**：音乐曲库中长内容越来越多，当前只能记住最后一首的位置。

**工作量**：M　　**优先级**：P3

### C15. Android Auto / CarPlay

**功能**：在车机原生界面浏览/播放，支持方向盘/语音控制；与现有蓝牙广播、局域网封面中继互补。

**可行性依据**：`audio_service` 已提供 Android `MediaBrowserService` 基础，`AndroidManifest.xml` 目前没有 automotive 描述文件；iOS 需要 CarPlay entitlement、scene 和审核配置。这是平台级工程，无法只靠 Dart 完成，且 iOS 需要开发者账号/审核。

**价值**：对以车机为主要场景的用户价值高，但成本也最高，放在最后。

**工作量**：L　　**优先级**：P3

### C16. 外部 scrobble（Last.fm / ListenBrainz）

**功能**：可选把播放记录同步到 Last.fm 或 ListenBrainz，服务端统计和第三方推荐都能用。

**可行性依据**：`history.addSongTimes` 是统一的播放计数入口，服务端已有 `scrobble`；外部服务需要用户自填 API key/token，并新增网络客户端。与本地听歌报告、服务器 scrobble 可以并存。

**价值**：已有 Last.fm 历史的用户会需要，但属于可选集成，优先级低。

**工作量**：M　　**优先级**：P3

---

## 5. D 类：视觉与体验思考清单（低优先级）

> 这里的项目都基于现有 Flutter/主题/路由能力，属于“做完更好用、但不做也不影响核心”的层级。实现时统一尊重系统“减少动态效果”设置。

### D1. 列表 → 详情共享封面过渡（Hero）

**功能**：从专辑/艺人/歌单列表点开详情时，封面从列表中的位置放大到详情头图，返回时缩回；播放条到歌词页已有 Hero，可沿用同一视觉语言。

**可行性依据**：`lib/base/widgets/cover_art_widget.dart` 是统一的封面组件；`song_list.dart` 的 `pushAlbumDetail` / `_pushSongListRoute` 负责详情跳转；`lib/portrait_view/play_bar.dart` 已有 `Hero(tag: 'cover')`。缺的是列表项与详情头图使用稳定、唯一的 Hero tag，并处理封面异步加载完成前的高度。

**价值**：页面切换的空间连续感更强，减少“突然换页”的割裂。

**工作量**：S/M　　**优先级**：P2

### D2. 切歌封面交叉淡入

**功能**：切歌时旧封面淡出、新封面淡入，而不是瞬间替换；新封面还在加载时保留旧图，避免闪白。

**可行性依据**：`CoverArtWidget` 以 `picture.id + changeNotifier` 作为 key，内部用 `Image` 和 `gaplessPlayback`；可在外层加 `AnimatedSwitcher` 或自绘 `FadeTransition`。缺的是动画包装和加载失败时的回退策略。

**价值**：播放条、歌词页、详情页的切歌观感更平滑。

**工作量**：S　　**优先级**：P2

### D3. 主题色 / 背景色平滑过渡

**功能**：随封面主色变化时，页面背景、玻璃层、按钮色在 300–500ms 内渐变，而不是瞬间跳色。

**可行性依据**：`lib/base/services/color_manager.dart` 已有 `currentCoverArtColor`、`backgroundCoverArtColor` 和多个 `MyColor`；页面用 `ValueListenableBuilder` 读取。可在根层用 `TweenAnimationBuilder<Color>` 或 `AnimatedContainer` 包一层。缺的是统一动画入口，避免每个页面各写一套。

**价值**：生动主题的“沉浸感”主要来自颜色连续性，这是性价比最高的视觉升级之一。

**工作量**：S/M　　**优先级**：P2

### D4. 歌词页封面呼吸 / 视差

**功能**：歌词页封面以非常轻微的缩放/位移随播放缓慢呼吸，歌词行聚焦时轻微放大；系统开启“减少动态效果”时关闭。

**可行性依据**：`lib/portrait_view/pages/portrait_lyrics_page.dart` 已有 `AnimatedContainer` 和模糊背景；`lyric_list_view.dart` 已有逐字进度与 `ShaderMask`。缺的是低频动画控制器与无障碍开关判断。

**价值**：让歌词页更“活”，但幅度必须小，避免干扰读词。

**工作量**：S　　**优先级**：P3

### D5. 队列拖拽的弹簧与触觉

**功能**：拖动队列歌曲时卡片抬起、带阴影和轻微缩放，经过其他行时触觉反馈，松手回弹到新位置。

**可行性依据**：`lib/landscape_view/pages/play_queue_page.dart` 使用 `SliverReorderableList`，可设置 `proxyDecorator`；`tryVibrate()` 已在多处使用。缺自定义 proxy 动画和边界触觉。

**价值**：队列重排是高频操作，反馈明确能减少误放。

**工作量**：S　　**优先级**：P3

### D6. 骨架屏加载

**功能**：首页、专辑/艺人列表、缓存页首次加载时显示与真实布局同形的骨架块，而不是中央转圈。

**可行性依据**：多个页面用 `_loaded` 布尔值 + `CircularProgressIndicator`（如 `local_music_page.dart`）；项目没有骨架组件。可用 `AnimatedOpacity`/渐变自行实现，不必新增依赖。

**价值**：感知加载更快，页面不会从空白突然“跳”出内容。

**工作量**：S　　**优先级**：P3

### D7. 拖动进度条时间气泡 + 平滑推进

**功能**：拖动进度条时在手指上方显示目标时间；播放中进度条以更细的步长平滑推进，而不是一秒一跳。

**可行性依据**：`lib/base/widgets/seekbar.dart` 已有 `dragValue` 与全轨道手势；`audioHandler.getPositionStream()` 直接转发 `_player.stream.position`。可加一个 250ms 的插值/补间，并在拖动时显示气泡。

**价值**：精确 seek 和长曲拖动时更好用，视觉上也更顺。

**工作量**：S　　**优先级**：P3

### D8. 大屏 / TV 待机屏保

**功能**：大屏模式或驾驶模式闲置一段时间后进入屏保：大封面 + 时钟/歌词，位置缓慢移动防止烧屏；触摸/按键退出。

**可行性依据**：`lib/big_picture_view/` 已有大屏面板体系，`driving_mode_page.dart` 已有沉浸布局；缺 idle timer 和屏保层。

**价值**：客厅/车机长时间显示时更体面，也减少烧屏风险。

**工作量**：S/M　　**优先级**：P3

### D9. 桌面端行悬停操作

**功能**：鼠标悬停在歌曲行时显示播放、收藏、菜单按钮，封面轻微放大；移出后恢复，不挤占移动端布局。

**可行性依据**：`lib/landscape_view/panels/song_list_panel.dart` 是桌面列表主体；`mini_view.dart` 已有 `MouseRegion` 示例。缺行级 hover 状态和按钮层。

**价值**：桌面端少一次右键/长按，操作更接近桌面音乐播放器习惯。

**工作量**：S　　**优先级**：P3

### D10. 歌词自动滚动缓动与当前行过渡

**功能**：切行时滚动使用缓动而非瞬移，当前行从暗到亮有短暂过渡；用户手动滚动后暂停自动跟随，过几秒恢复。

**可行性依据**：`lib/base/widgets/lyric_list_view.dart` 已有当前行索引、逐字进度和 `ShaderMask`；`scrollable_positioned_list` 已是依赖。缺滚动曲线、手动滚动检测和恢复计时。

**价值**：跟唱时视线更稳定，减少“歌词跳一下”的干扰。

**工作量**：S　　**优先级**：P3

### D11. 统计页图表入场动画

**功能**：打开听歌报告时，年度柱状图/热力图按月或按年依次绘制，数字滚动到最终值。

**可行性依据**：`lib/base/widgets/stats_page.dart` 与 `lib/base/data/stats.dart` 已有完整数据；缺 `TweenAnimationBuilder`/`AnimatedBuilder` 包装。属于纯视觉，不影响数据。

**价值**：年度报告更有仪式感，但属于“锦上添花”，排在最后。

**工作量**：S　　**优先级**：P3

---

## 6. 不建议做 / 明确排除

| 想法 | 原因 |
| --- | --- |
| 在 Navidrome / Emby / 飞牛上写音频标签 | 三者都没有给客户端的标签写入 API；只能本地编辑，再手动同步文件 |
| 通过 API 创建 Navidrome 智能歌单（NSP） | NSP 是服务器文件系统里的文件，Subsonic API 不提供创建；智能歌单必须做客户端规则 |
| 用服务器接口改飞牛的随机/相似/流派 | 飞牛现有接口中没有这些端点，不能假装支持 |
| 把歌词偏移再做一遍 | `lyricsTimeOffset` 已按曲持久化，竖屏歌词页和歌词时间轴页都能调 |
| 再做一套缓存/下载任务页 | `cache_download_manager.dart`、`download_manager.dart`、`cache_tasks_page.dart` 已完整 |
| 再做广播/封面模式、品质标识、LAN 直连、评论、首页小组件 | 均已实现，见 0.4 表 |

---

## 7. 实施顺序建议

1. **先做 P1 中的低成本高收益项**：C1 ReplayGain → A3 自动增量扫描 → C4 搜索历史/高级筛选 → C5 睡眠定时增强。
2. **再做曲库整理闭环**：A1 曲库体检 → A2 重复检测 → C3 批量操作扩展 → C2 智能歌单。
3. **最后做需要服务器/播放架构的项**：B1 服务端搜索 → B2 相似/InstantMix → B5 离线缓存库 → C9 无缝播放。
4. **D 类不单独排期**，跟随相关页面改造顺手完成（例如做 D1 时顺带做 D2/D3）。

> 注：本路线图只描述功能与可行性，不包含具体实现代码；所有服务端能力均以“服务器实际支持才显示入口”为原则，避免给用户一个必然失败的按钮。
