# 从 Tune Tree 引入四项本地音乐功能的详细设计

- 目标工程：`E:\Fun\code\sylvakru`（Flutter，应用名 Lain）
- 参考工程：`E:\Fun\code\tune-tree`（Flask + 原生 Web 前端）
- 本文范围：仅设计，不包含实现代码、不修改源码、不提交。
- 共同约束：四项功能只对本地音乐源开放；当前音源为 Navidrome / Emby / 飞牛 / WebDAV 时，入口、按钮、页面一律不存在，而不是置灰或显示为不可用。

---

## 0. 结论摘要

四项功能都落在“本地音乐”的既有页面体系内，不新建顶级设置分类，也不引入新的视觉语言：

| 功能 | 主入口 | 次级入口 | 页面形态 |
| --- | --- | --- | --- |
| 文件/文件夹命名格式 | 设置 → 音乐源 → 本地音乐工具 → 文件命名格式 | 歌曲行菜单“整理文件”；批量选择页“整理选中” | 设置子页 + 预览/执行页 |
| 元数据刮削与更新 | 设置 → 音乐源 → 本地音乐工具 → 元数据补全 | 编辑元数据弹窗“标签搜索”；歌曲行菜单“搜索标签” | 设置子页 + 结果弹窗 |
| 歌词时间轴快捷编辑 | 编辑元数据弹窗 → 歌词 → 歌词时间轴 | 歌曲行菜单“编辑歌词时间轴” | 全屏页（播放器 + 行列表） |
| 统计页专辑时间轴 | 设置 → 听歌报告 → 统计页“专辑时间轴”区块 | 本地音乐工具页快捷入口 | 设置子页（按日期分组） |

所有入口的显示条件统一为 `sourceType == .local`。不使用 `isNotStreamSource`，因为 WebDAV 虽然不属于流媒体协议，但同样是远程源，按本任务约束必须缺席。

---

## 1. 现有应用约定（设计必须遵守）

### 1.1 设置分类与设置列表

设置一级分类定义在 `lib/base/data/settings_category.dart`：

```dart
enum SettingsCategory {
  musicSource,
  userInterface,
  playbackLyrics,
  notifications,
  startupBackground,
  cacheDownloads,
  listeningReport,
  helpFeedback,
}
```

分类的图标和标题分别由 `settingsCategoryIcon`、`settingsCategoryTitle` 提供。一级分类没有“本地音乐”分类，本地入口在 `musicSource` 分类里，由 `lib/base/widgets/settings_list.dart` 的 `_categoryTiles` 生成：

```dart
case SettingsCategory.musicSource:
  return [
    serversListTile(context, l10n),
    localSourceListTile(context, l10n),
    offlineModeListTile(l10n),
    if (sourceType == .webdav) selectMusicFoldersListTile(context, l10n),
    syncListTile(context, l10n),
    if (isStreamSource) ...[
      lanDirectListTile(l10n),
      streamQualityListTile(context, l10n),
      streamFormatListTile(context, l10n),
    ],
    ...
  ];
```

这里已经存在按音源条件插入条目的写法，新增的本地工具条目应沿用同一模式。

### 1.2 设置子页外壳

`lib/base/widgets/local_music_page.dart` 提供 `opaqueSettingsPage`：

```dart
Widget opaqueSettingsPage({
  required BuildContext context,
  required String title,
  required Widget body,
}) {
  return ListenableBuilder(
    listenable: Listenable.merge([
      layersManager.backgroundChangeNotifier,
      panelColor.valueNotifier,
      pageBackgroundColor.valueNotifier,
    ]),
    builder: (context, child) {
      return Container(
        color: colorManager.getSpecificOpaqueBgColor(),
        child: myScaffold(
          context: context,
          body: body,
          label: '__pushed__',
          title: title,
        ),
      );
    },
  );
}
```

新增的设置子页全部通过 `pushSettingsPage(context, settingsPageRoute(() => Page()))` 打开，页面主体使用 `opaqueSettingsPage`，不再手写背景。

`lib/base/widgets/manage_music_folders.dart` 是 WebDAV/首次启动时的文件夹选择器，采用弹窗和左右分栏；它不是本设计的页面模板。本地音乐相关页面统一走 `LocalMusicSettingsPage` 的 `opaqueSettingsPage` 形态，避免出现第二套设置页外壳。

`lib/base/widgets/settings_page_route.dart` 的 `settingsPageRoute` 负责推入方向、返回方向和 iOS 的侧滑返回；不要用裸 `MaterialPageRoute` 代替设置子页导航。

### 1.3 分组卡片与表单控件

`lib/base/widgets/apple_form.dart` 提供：

- `appleSectionTitle(String title)`：15px，`colorManager.getSpecificTextColor().withAlpha(160)`，内边距 `20/18/20/8`。
- `AppleFormSection`：水平外边距 20，圆角 14，填充 `textColor.withAlpha(20)`，行之间使用 `MyDivider(thickness: 0.5)`。
- `appleFormRow(label, child)`：左右内边距 16，上下 4，标签 15px。
- `appleSwitchRow(label, valueNotifier)`：标签左、`MySwitch` 右。
- `appleTextField` / `appleTextFieldRow`：无边框、15px、按主题着色；单行右对齐，多行左对齐。
- `appleSegmented`：等宽分段选择器，背景 `textColor.withAlpha(24)`，选中 `withAlpha(38)`。
- `appleFilledButton`：全宽、`buttonColor.value`、StadiumBorder。
- `appleTextButton`：普通文字动作，默认主题文字色。
- `applePageRoute`：淡入路由；主要用于非设置页场景。

新页面不得自行写背景色、卡片色、强调色或阴影；需要“当前选中”时使用 `textColor.withAlpha(...)` 或 `colorManager.getSpecificSelectedItemColor()`，与现有列表一致。

### 1.4 颜色与主题

所有颜色从 `lib/base/services/color_manager.dart` 取：

- `getSpecificTextColor()`
- `getSpecificOpaqueBgColor()`
- `getSpecificBgColor()` / `getSpecificBgBaseColor()`
- `getSpecificIconColor()`
- `getSpecificSelectedItemColor()`
- `getSpecificDividerColor()`
- `buttonColor.value`（全局按钮色通知器）
- 全局 `dividerColor`、`iconColor.value`（见 `lib/base/app.dart`）

浅色、深色、vivid 三种主题都由这些值统一驱动，页面不得出现硬编码的白色、黑色、灰色或紫色。

### 1.5 本地歌曲的数据身份

本地歌曲的 `MyAudioMetadata.id` 就是文件路径（iOS 上经过 `convertIOSPath`），见：

- `lib/base/extensions/metadata_extension.dart`：`toMetadata()` 中 `validPath = id`；`toCompanion()` 中本地只写 `id`，不写 `path`。
- `lib/base/data/folder.dart`：`Folder` 的歌曲列表以 `id` 保存到 `folder_id_list` 之外的 `md5(id).json` 中。
- `lib/base/data/playlist.dart`：歌单文件保存的是 `List<String> _storedIds`。

因此“重命名文件”不是单纯的 `File.rename`，而是“文件移动 + 歌曲身份变更 + 所有 id 引用迁移”。这是功能一最大的风险点，后文会给出完整迁移方案。

### 1.6 本地 vs 远程的既有门控写法

项目中已有的本地限定写法：

- `lib/base/services/interaction.dart` 的 `showSongOptions` 内用 `if (isStreamSource)` 控制“下载”项。
- `lib/portrait_view/pages/song_list_page.dart`：

```dart
includeEdit: sourceType == .local && artist == null && album == null,
```

- `lib/landscape_view/panels/song_list_panel.dart` 同一条件。
- `lib/base/widgets/settings_list.dart` 一级菜单隐藏缓存分类：

```dart
if (isStreamSource || category != SettingsCategory.cacheDownloads)
```

- `lib/view_entry.dart` 用 `if (isNotStreamSource)` 控制本地文件夹卡片的显示。

本次四项功能统一使用 `sourceType == .local`。理由：`isNotStreamSource` 把 WebDAV 也算进来，而 WebDAV 的文件由远端管理，改名/写标签/读创建时间都不可靠，必须不在入口出现。

### 1.7 统计页

`lib/base/widgets/stats_page.dart` 的 `StatsPage` 是“听歌报告”页，由设置一级分类 `listeningReport` 直接推入。页面结构：

- 顶部 `_header`：返回按钮、标题、清空按钮。
- `ListView`：
  - `_yearPicker`（年份 ChoiceChip）
  - `_sectionTitle(l10n.yearlyActivity)` + `_card(_heatmap(...))`
  - 日榜、年度统计、热门歌曲、热门艺术家、热门专辑。

`_sectionTitle` 为 15px、`_textColor.withAlpha(160)`；`_card` 为水平外边距 20、内边距 14、圆角 16、`_textColor.withAlpha(20)`。新增“专辑时间轴”区块应复用这两个方法，而不是另写样式。

---

## 2. 总览：入口地图、导航图、本地限定规则

### 2.1 入口地图

```
设置
└─ 音乐源（SettingsCategory.musicSource）
   ├─ 服务器
   ├─ 本地音乐（现有长按配置入口）
   ├─ 本地音乐工具（本设计新增，仅 sourceType == .local 时出现）
   │  ├─ 文件命名格式        → LibraryNamingPage
   │  ├─ 整理文件结构        → LibraryOrganizePage（全库）
   │  ├─ 元数据补全          → MetadataCompletionPage
   │  └─ 专辑时间轴（快捷）  → AlbumTimelinePage
   ├─ 离线模式
   ├─ 管理音乐文件夹（仅 WebDAV）
   └─ 同步音乐库
└─ 听歌报告（SettingsCategory.listeningReport）
   └─ StatsPage
      └─ 专辑时间轴区块（仅 sourceType == .local）→ AlbumTimelinePage
```

```
歌曲列表
├─ 行尾三点菜单（showSongOptions）
│  ├─ 编辑元数据（现有，仅本地）
│  │  ├─ 标签搜索          → MetadataScrapeDialog
│  │  └─ 歌词 → 歌词时间轴 → LyricTimelinePage(returnOnly: true)
│  ├─ 搜索标签             → MetadataScrapeDialog（仅本地）
│  ├─ 编辑歌词时间轴       → LyricTimelinePage(returnOnly: false)
│  └─ 整理文件             → LibraryOrganizePage(单曲)
└─ 批量选择页（SelectableSongListPage）
   └─ 操作（仅本地）
      ├─ 整理选中          → LibraryOrganizePage(选中歌曲)
      └─ 批量搜索标签      → MetadataCompletionPage(选中歌曲)
```

### 2.2 导航图

```
SettingsList (音乐源)
  │ pushSettingsPage + settingsPageRoute
  ├─ LocalLibraryToolsPage
  │    ├─ LibraryNamingPage
  │    ├─ LibraryOrganizePage(scope: wholeLibrary)
  │    ├─ MetadataCompletionPage(scope: missingMetadata)
  │    └─ AlbumTimelinePage(range: month)
  │
StatsPage (听歌报告)
  ├─ AlbumTimelinePage(range: month)
  │
EditMetadata (dialog)
  ├─ MetadataScrapeDialog (dialog)
  └─ LyricTimelinePage(returnOnly: true)
       └─ pop(serializedLrc) → EditMetadata 的歌词控制器
  │
showSongOptions (dialog / bottom sheet)
  ├─ LibraryOrganizePage(scope: singleSong)
  ├─ MetadataScrapeDialog(song)
  └─ LyricTimelinePage(returnOnly: false)
```

### 2.3 本地限定规则

统一判定：

```dart
bool get isLocalLibrary => sourceType == .local;
```

设计上建议在 `lib/base/app.dart` 增加这个只读 getter，避免各页面各写一套条件。所有入口遵守：

1. 设置一级菜单：`if (isLocalLibrary) localLibraryToolsListTile(context, l10n)`。位置固定在 `musicSource` 分类的 `localSourceListTile` 之后、`offlineModeListTile` 之前：它属于本地库，紧贴“本地音乐”入口；只在本地出现，也不会把本地工具和服务器/WebDAV 条目混在一起。非本地时这个 `ListTile` 根本不进入 children。
2. 设置子页：`LocalLibraryToolsPage` 只从上面的入口推入；页面内部不提供 WebDAV/流媒体分支。
3. 歌曲菜单：`showSongOptions` 中“搜索标签”“编辑歌词时间轴”“整理文件”三项只在 `isLocalLibrary` 时加入 `children`，否则完全不存在。三项的固定顺序放在“歌曲信息”之后、现有“编辑元数据”之前：搜索标签 → 编辑歌词时间轴 → 整理文件 → 编辑元数据。
4. 批量选择页：顶部“操作”按钮只在 `isLocalLibrary` 且已选歌曲大于 0 时构建。
5. 统计页：`if (isLocalLibrary)` 才构建“专辑时间轴”区块；非本地时连 `_sectionTitle` 也不出现。
6. 页面/弹窗构造器内部再做一次 `assert(sourceType == .local)` 或构造时检查，作为防御；但不要用“置灰按钮”替代入口缺席。
7. 不允许把入口放在 WebDAV/Emby/Navidrome/飞牛的菜单里再隐藏，避免未来新增音源时漏掉。

### 2.4 本地音乐工具页结构

```
opaqueSettingsPage(title: "本地音乐工具")
└─ ListView(padding: top 8, bottom 100)
   ├─ appleSectionTitle("整理")
   ├─ AppleFormSection
   │   ├─ ListTile(
   │   │    leading: Icon(Icons.drive_file_rename_outline_rounded, size: 30, color: iconColor.value),
   │   │    title: Text("文件命名格式"),
   │   │    subtitle: Text(当前目录模板 + 文件名模板, 12px, textColor.withAlpha(150)),
   │   │    trailing: Icon(Icons.chevron_right_rounded)
   │   │  )
   │   ├─ ListTile(
   │   │    leading: Icon(Icons.drive_file_move_rounded, size: 30, color: iconColor.value),
   │   │    title: Text("整理文件结构"),
   │   │    subtitle: Text("预览后移动文件", 12px, textColor.withAlpha(150)),
   │   │    trailing: Icon(Icons.chevron_right_rounded)
   │   │  )
   │   └─ ListTile(
   │        leading: Icon(Icons.edit_note_rounded, size: 30, color: iconColor.value),
   │        title: Text("元数据补全"),
   │        subtitle: Text("N 首歌曲缺少标签", 12px, textColor.withAlpha(150)),
   │        trailing: Icon(Icons.chevron_right_rounded)
   │      )
   ├─ appleSectionTitle("浏览")
   └─ AppleFormSection
       └─ ListTile(
            leading: Icon(Icons.timeline_rounded, size: 30, color: iconColor.value),
            title: Text("专辑时间轴"),
            subtitle: Text("按添加时间浏览专辑", 12px, textColor.withAlpha(150)),
            trailing: Icon(Icons.chevron_right_rounded)
          )
```

说明：

- 图标尺寸 30 与设置页其它 `ListTile` 一致；图标颜色 `iconColor.value`。
- 副标题 12px、`textColor.withAlpha(150)`；不写额外颜色。
- 三个“整理”条目在同一张卡片内，用 `AppleFormSection` 的分隔线分开；“浏览”单独一张卡片。
- 页面本身只在本地可达；不显示任何远程音源的分支。

---

## 3. 功能一：按艺术家 / 专辑 / 歌曲标题命名文件与文件夹

### 3.1 参考实现

Tune Tree 的命名规则是固定的，不是用户模板：

`python/services/format_service.py`

```python
def build_target_filename(track) -> str:
    """Build  `TrackNum. Title[ - feat. X].ext`"""
    num = track["track_num"] or 0
    title = (track["title"] or track["filename"]).strip()
    ext = track["ext"]
    if not ext.startswith("."):
        ext = "." + ext
    title = re.sub(r'[\\/:*?"<>|]', "_", title)
    title = re.sub(r"\s+", " ", title).strip()
    feat_match = re.search(r"\(feat\.?\s*([^)]+)\)", title, re.IGNORECASE)
    if feat_match:
        feat = feat_match.group(1).strip()
        title = title[: feat_match.start()].strip()
        return f"{num:02d}. {title} - feat. {feat}{ext}"
    return f"{num:02d}. {title}{ext}"
```

目录名净化在 `python/utils/formatting.py` 的 `safe_dirname`：替换跨平台非法字符、删除控制字符、处理纯点号目录、以 `-` 开头、结尾点号、Windows 保留名（`con`、`nul`、`com1` 等）。

预览与冲突判定在 `python/services/format_service.py` 的 `preview_format`：

```python
if target_path == row["path"]:
    status = "skip"
elif file_key in seen_files:
    status = "skip"
elif target_path in existing_paths and existing_paths[target_path] != row["id"]:
    status = "conflict"
else:
    status = "normal"
```

执行顺序与回滚在 `execute_format`：

```python
# 第一步：移动文件。失败时文件仍在原位，只记错误。
shutil.move(str(src), str(dst))
# 第二步：写库。文件与 DB 无法共用同一个事务，所以写库失败时必须尽力把文件搬回原位，
# 否则文件已在新位置、DB 仍指向旧路径：UI 会显示「文件不存在」，
# 下次扫描还会把新位置当新文件插入，产生重复记录。
try:
    update_track_path_and_name(item["track_id"], str(dst), dst.name)
except Exception:
    shutil.move(str(dst), str(src))
```

前端预览在 `python/static/js/modules/format.js`：

- 打开 `format-modal`，先请求 `/format/batch-preview` 或 `/format/preview`。
- 多艺术家用 tab 分段，每个 tab 显示文件数，可移除。
- 每个条目显示“原文件名 / 新文件名 / 状态（正常、跳过、冲突）”。
- 底部“确认执行”调用 `/format/execute`。
- 只有存在选中项时，`artist.js` 的 `updateToolbar` 才把“格式化目录”按钮设为可见。

参考结论：Tune Tree 的核心价值是“先预览、再执行、冲突不移动、失败回滚”，命名模板本身很简单。引入时应保留这套流程，但把固定规则升级为可配置模板。

### 3.2 入口

主入口：

- 设置 → 音乐源 → “本地音乐工具”（新增，`isLocalLibrary` 时出现）。
- “本地音乐工具”页 → “文件命名格式”。
- “本地音乐工具”页 → “整理文件结构”。

次级入口：

- 歌曲行三点菜单 → “整理文件”，对单首歌曲打开 `LibraryOrganizePage(scope: singleSong)`。
- 批量选择页顶部“操作” → “整理选中”，对选中歌曲打开 `LibraryOrganizePage(scope: selection)`。位置固定在现有“完成”文字按钮的左侧，只在 `isLocalLibrary` 且已选歌曲大于 0 时出现。
- 当前歌曲列表的更多菜单（`song_list.dart` 的 `moreSheet`）可选增加“整理本列表”，与“导出歌单”同属本地动作；如果加入，必须和 `playlist != null && isNotStreamSource` 一样受 `sourceType == .local` 限制。

图标与标签：

| 位置 | 图标 | 标签 |
| --- | --- | --- |
| 设置一级 | `Icons.handyman_rounded` | 本地音乐工具 |
| 工具页 | `Icons.drive_file_rename_outline_rounded` | 文件命名格式 |
| 工具页 | `Icons.drive_file_move_rounded` | 整理文件结构 |
| 歌曲菜单 | `Icons.drive_file_move_rounded` | 整理文件 |
| 批量操作 | `Icons.drive_file_move_rounded` | 整理选中 |

隐藏规则：

- 非本地音源：一级“本地音乐工具”条目不构建；歌曲菜单三项不构建；批量选择页“操作”按钮不构建。
- 本地但音乐库为空：入口仍存在，页面显示空状态，不显示“开始整理”。

### 3.3 页面 / 弹窗结构

#### 3.3.1 `LibraryNamingPage`（设置子页）

```
opaqueSettingsPage(title: "文件命名格式")
└─ ListView(padding: top 8, bottom 100)
   ├─ appleSectionTitle("目录")
   ├─ AppleFormSection
   │   ├─ appleTextFieldRow("目录模板", dirController, placeholder: "{artist}/{album}")
   │   └─ 说明文字（12px，textColor.withAlpha(150)）
   ├─ appleSectionTitle("文件名")
   ├─ AppleFormSection
   │   ├─ appleTextFieldRow("文件名模板", fileController, placeholder: "{track:02}. {title}")
   │   ├─ appleSwitchRow("保留 feat. 信息", keepFeatNotifier)
   │   └─ 说明文字
   ├─ appleSectionTitle("预览")
   ├─ AppleFormSection(divided: false)
   │   ├─ appleFormRow("示例歌曲", Text(exampleTitle))
   │   ├─ appleFormRow("当前", SelectableText(exampleOldPath))
   │   └─ appleFormRow("整理后", SelectableText(exampleNewPath))
   └─ AppleFormSection(divided: false)
       └─ ListTile(leading: Icons.restart_alt_rounded, title: "恢复默认格式")
```

- 不使用全宽“保存”按钮；本页沿用应用的“改动即保存”习惯：文本输入在提交（回车/失焦）时校验并 `setting.save()`，开关即时保存。
- “恢复默认格式”是普通 `ListTile`，点击后 `showConfirmDialog`，确认后写回默认值。
- 顶部 `myScaffold` 不放“保存”动作；如果产品更希望显式保存，可在 `opaqueSettingsPage` 上扩展 `actions`，但不要自己写新 AppBar。

`opaqueSettingsPage` 目前不接受 `actions`。功能一（整理页）、功能二（批量搜索）、功能三（保存/重置）都需要顶部动作，建议最小扩展该 helper：

```dart
Widget opaqueSettingsPage({
  required BuildContext context,
  required String title,
  required Widget body,
  List<Widget>? actions,
})
```

向后兼容；不要为此新建另一套页面外壳。

#### 3.3.2 `LibraryOrganizePage`（预览 + 执行）

```
opaqueSettingsPage(
  title: "整理文件结构",
  actions: [TextButton("开始整理")],
)
├─ ListView(padding: top 8, bottom 100)
│  ├─ appleSectionTitle("概览")
│  ├─ AppleFormSection(divided: false)
│  │   └─ 统计行：正常 / 跳过 / 冲突 / 不允许
│  ├─ appleSectionTitle("目录预览")
│  ├─ AppleFormSection
│  │   └─ 每个艺术家目录一行；展开后显示专辑目录与文件
│  ├─ appleSectionTitle("变更列表")
│  └─ AppleFormSection
│      └─ 每个文件一行：原文件名 → 新文件名 + 状态
```

状态显示不新增颜色语义：

| 状态 | 显示 | 颜色 |
| --- | --- | --- |
| normal | “正常” | 主题文字色 |
| skip | “跳过” | `textColor.withAlpha(150)` |
| conflict | “冲突” | `Colors.red`（与现有删除确认一致） |
| blocked | “不允许” | `Colors.red` |

统计行使用与 `StatsPage._statTiles` 相同的视觉：数值 20px 粗体、标签 12px `withAlpha(160)`，容器 `textColor.withAlpha(38)`、圆角 12。不要另做一套“仪表盘”。

空状态、加载、错误：

- 生成预览时用 `showCenterLoading()`，完成后 `removeCenterLoading()`。
- 无任何可整理文件：`Center(Text(l10n.noData, 14px, textColor.withAlpha(150)))`，AppBar 的“开始整理”不显示。
- 预览生成失败：页面内用一行 14px 红字说明原因，保留“重试”文字按钮。
- 冲突全部存在但无 normal：统计照常显示，AppBar 动作隐藏。

#### 3.3.3 执行确认与进度

- 点击“开始整理”先 `showConfirmDialog(context, "整理文件")`。该弹窗的确认按钮本来就是红色，符合“移动文件”的不可逆性提示。
- 确认后弹出 `showAnimationDialog` 的进度框：标题“正在整理”，`CircularProgressIndicator`，`x / y`，一个“停止”文字按钮。停止只处理当前文件之后不再继续，已处理的不回滚（见 3.6 的“取消”策略）。
- 完成后关闭进度框，`showCenterMessage("已整理 N 个文件，跳过 M 个，失败 K 个")`。
- 若本次执行生成了完整日志，页面底部显示“撤销本次整理”文字按钮，保留到离开页面为止。

### 3.4 样式与主题

- 页面外壳：`opaqueSettingsPage`，标题 20px（`myScaffold` 的 `Text(style: .new())` 由主题提供），背景 `colorManager.getSpecificOpaqueBgColor()`。
- 分组：`appleSectionTitle` + `AppleFormSection`；行间距、圆角、分隔线全部用 helper 默认值。
- 输入框：`appleTextFieldRow`，不要自建 `InputDecoration` 或边框。目录模板和文件名模板是长字符串，`appleTextField` 的单行右对齐不适合；建议给它增加一个可选 `textAlign` 参数（默认保持右对齐，保持既有调用不变），模板输入传 `TextAlign.start`。这是对 `apple_form.dart` 的最小扩展，不另写文本框样式。
- 开关：`appleSwitchRow` + `MySwitch`。
- 统计：复用 `StatsPage` 的 `_statTiles` 写法（`textColor.withAlpha(38)`、圆角 12、数值 20 粗体）。
- 状态：正常/跳过使用主题文字色及其 alpha；冲突使用 `Colors.red`，与 `showConfirmDialog` 的确认按钮一致，不引入新色板。
- 页面背景、卡片背景、强调色一律不手写；不使用渐变、阴影、发光。
- 文案不使用表情符号。

### 3.5 交互流程

#### 命名格式设置

1. 打开“文件命名格式”，两个模板输入框显示当前值。
2. 用户编辑目录模板或文件名模板；输入过程中下方“预览”实时更新（防抖 200ms，纯字符串计算，不读磁盘）。
3. 提交时校验：
   - 目录模板不能为空。
   - 文件名模板必须包含 `{title}`，否则所有文件会重名。
   - 模板不能是绝对路径（以 `/`、`\`、盘符 `C:` 开头），不能包含 `..` 路径段。
   - 不允许未知占位符；遇到 `{foo}` 直接在说明文字中提示可用占位符。
4. 校验通过后写 `setting.save()`；校验失败不写入，输入框保持编辑状态，说明文字变为错误提示。
5. “恢复默认格式”需要确认；确认后两个模板和 `keepFeat` 回到默认。

#### 整理文件结构

1. 从工具页进入时 scope 为整个本地库；从歌曲菜单进入时为单曲；从批量选择进入时为选中歌曲。
2. 页面打开即生成预览（可取消）；预览只读，不移动任何文件。
3. 用户检查“变更列表”。冲突和不允许的条目默认不执行；跳过条目不执行。
4. 点击“开始整理” → 确认弹窗 → 进度框。
5. 执行完成后：
   - 页面刷新为“已完成”状态，统计行显示实际移动/跳过/失败。
   - 提供“撤销本次整理”（仅本次页面生命周期内，且所有新路径仍存在、旧路径为空时可用）。
   - 返回上一页时，歌曲列表、专辑/艺术家列表、歌单、文件夹页均已刷新。
6. 如果用户在进度框点“停止”：当前文件处理完后停止，剩余条目标记为“未处理”；已处理的文件保持新路径，不回滚；页面显示“已停止，处理了 x / y”。

#### 键盘行为

- 设置页文本输入使用系统默认键盘；不做自定义快捷键。
- 整理页无文本输入，回车不绑定动作，避免误触发。

### 3.6 数据与业务逻辑

#### 3.6.1 命名模型

新增 `lib/base/data/library_naming.dart`：

```
LibraryNamingFormat {
  String dirTemplate;    // 默认 "{artist}/{album}"
  String fileTemplate;   // 默认 "{track:02}. {title}"
  bool keepFeat;         // 默认 true
}
```

占位符：

| 占位符 | 含义 | 缺省值 |
| --- | --- | --- |
| `{artist}` | 歌曲艺术家标签 | Unknown Artist |
| `{albumArtist}` | 专辑艺术家标签 | 取 `{artist}` |
| `{album}` | 专辑标签 | Unknown Album |
| `{title}` | 歌曲标题标签；为空时取文件名（去扩展名） | 文件名 |
| `{track}` | 音轨号，不补零 | 00 |
| `{track:02}` | 音轨号补零到 2 位 | 00 |
| `{disc}` | 碟号 | 01 |
| `{year}` | 年份 | 0000 |
| `{ext}` | 扩展名，含点 | 原扩展名 |

说明：

- 模板中的 `/` 是目录分隔符；占位符值内部的 `/`、`\` 一律净化为 `_`，不会创建子目录。
- 模板支持多级目录，例如 `{artist}/{year} - {album}`。
- 文件名模板末尾自动补 `{ext}`（如果用户没写）；不允许用户去掉扩展名。
- `keepFeat` 打开时，从标题中提取 `(feat. X)`、`[feat. X]`、`（feat. X）`，标题主体保留，后缀统一为 ` - feat. X`。
- 净规则沿用 Tune Tree 的 `safe_dirname` 思路，在 Dart 侧实现一个 `sanitizePathSegment`：
  - `\ / : * ? " < > |` → `_`
  - 删除 ASCII 控制字符
  - 去除首尾空格
  - 纯点号（`.`、`..`）→ `_`
  - 以 `-` 开头 → `_-...`（避免命令行误判）
  - 结尾点号 → `_`
  - Windows 保留名（con、prn、aux、nul、com1-9、lpt1-9，大小写不敏感）追加 `_`
  - 空结果 → 对应缺省值
  - 单个路径段长度上限 120 字符；完整路径超过平台上限（Windows 260，Android/Linux 4096）时标记为 blocked
- 不能把模板中的 `/` 当成可净化的值；只有模板字面量决定层级。

#### 3.6.2 根目录解析

本地库可能有多个 `Folder`（`library.folderList`，来自 `folder_id_list.json`）。规则：

1. 对每首歌的 `song.path`，在所有本地 Folder 中找“路径前缀匹配且最长”的根。
2. 目标根 = 该根，不允许跨根移动。这样不会把 SD 卡上的歌搬到内部存储，也不会打乱用户配置的多个音乐目录。
3. 若歌曲不在任何根下（例如用户临时移除了文件夹），状态为 `blocked`，不参与整理。
4. 目标目录不得越过根：拼接后必须重新校验 `targetPath` 以根路径开头；否则 blocked。
5. 不删除根目录本身；只删除移动后变空的旧专辑/艺术家子目录，且从最深层向上删，遇到非空目录立即停止。

#### 3.6.3 预览算法

输入：scope（全库 / 一组歌曲）。

1. 取出 scope 内 `song.path != null` 且文件存在的歌曲；不存在记 `blocked("文件不存在")`。
2. 对每首：
   - 解析模板得到相对目录和文件名。
   - 计算 `targetPath`。
   - 若 `targetPath == oldPath` → `skip`。
   - 若目标路径是一个已存在的目录 → `blocked`。
   - 若目标文件存在且不是当前文件 → `conflict`。
   - 用规范化键 `lower(root)::lower(relative)::lower(stem)::lower(ext)` 检查同批次内重复 → 后出现者 `conflict`。
   - 否则 `normal`。
3. 目录树预览按 `artist → album → files` 分组；文件按音轨号排序，无音轨号排最后。
4. 结果返回给页面，包含 `items`、`normal/skip/conflict/blocked` 计数、`tree`。

边界：

- 两个文件音轨号相同、标题相同 → 第二个 conflict，不自动加 `(2)`。自动加序号会让“预览”与用户预期不一致；如需自动去重，作为后续开关。
- 标题为空时用原文件名去扩展名，避免产生 `00. .mp3`。
- 目标文件名与源文件仅大小写不同（Windows/macOS 大小写不敏感）：按同一文件处理为 skip；在 Linux 上按正常处理，但提示“仅大小写变化”可选。

#### 3.6.4 执行与身份迁移

执行前写日志：

```
appSupportDir/format_journal.json
{
  "version": 1,
  "state": "moving" | "committed",
  "createdAt": <millis>,
  "entries": [
    {
      "oldPath": "...",
      "newPath": "...",
      "oldId": "...",
      "newId": "...",
      "createdMillis": 123,
      "sidecars": [{"old": "...", "new": "..."}],
      "coverCache": {"old": "...", "new": "..."}
    }
  ]
}
```

执行顺序（每个 normal 条目）：

1. `Directory(newParent).create(recursive: true)`。
2. 若目标已存在则重新标记 conflict 并跳过（执行时再检查一次，防止预览后外部变化）。
3. `File(oldPath).rename(newPath)`；跨卷失败时退化为 `copy` + 删除源文件，但同一根内一般不会跨卷。
4. 移动同名 sidecar（仅当存在且目标不存在）：
   - `.lrc`、`.ttml`、`.xml`：歌词 sidecar。
   - `.jpg`、`.jpeg`、`.png`：同目录手工封面（如果存在，且不是多首歌共享的 `cover.jpg`/`folder.jpg`；共享封面不移动）。
5. 迁移 `file_created.json`：`fileCreationTimes` 增加 `moveEntry(oldPath, newPath, millis)`，把旧路径的创建时间搬到新路径，避免功能四的时间轴漂移。
6. 迁移封面缓存：`pictures/local/md5(oldId)` → `md5(newId)`（如果存在），并清掉 `mediaArt` 的缩略图缓存（`mediaArt.targetPathFor`）。
7. 当前歌曲/播放队列：
   - 若 `currentSongNotifier.value` 命中该歌，先暂停（`audioHandler.pause()`）。
   - 用新的 `MyAudioMetadata`（复制原对象、只替换 `id` 与 `path`）替换 `library.id2Song`、`library.songList`、所有 `Folder.songList`、`playQueue`、`currentSongNotifier`。
8. 歌单：`playlistManager` 中所有 `_storedIds` 做 oldId → newId 替换，并重写各自的 `songListFile`。
9. 文件夹列表：`Folder` 的 `md5(id).json` 做同样替换并重写。
10. 数据库：调用一个新增的 `library.applyRenames(List<(oldId,newId)>)`，在 drift 事务内 `insert(newRow)` + `delete(oldRow)`；行内容复制原歌曲的 `playCount`、`lastPlayed`、`lyricsTimeOffset`、`size` 等，标题等标签不变。`newId` 按平台规则计算：`Platform.isIOS ? convertIOSPath(newPath) : newPath`；若 `oldId == newId`（仅大小写变化），跳过数据库插入/删除，只做文件重命名和缓存/队列更新。
11. 全部成功后把 journal 置为 `committed`，删除 journal。
12. 删除空目录（从旧父目录向上，直到根，不含根）。
13. 刷新：
    - `library.changeNotifier.value++`
    - `artistAlbumManager.updateArtistAlbum()`
    - `layersManager.updateBackground()`
    - `mediaArt`/`Picture` 相关缓存按第 6 步清理
14. 结果统计返回页面。

失败与回滚：

- 文件移动失败：该条目记失败，继续下一个；已成功的不回滚（用户可在页面看到部分成功）。
- 数据库/身份迁移失败：对本次所有已移动条目执行逆操作（`newPath → oldPath`），删除新建的 DB 行，恢复歌单/文件夹 id；把 journal 留在 `moving` 供启动恢复。
- 启动恢复：`Loader.load()` 在本地音源、`library.load()` 之前检查 journal：
  - `state == "moving"`：对每个 entry，如果 `newPath` 存在且 `oldPath` 不存在，移回；如果两处都存在，保留并记录日志；删除 `newId` 的 DB 行（`old` 行如果还在则保留）。完成后删 journal。
  - `state == "committed"`：只删 journal，不再动文件。
- 撤销（页面内）：用同样算法反向执行，仅当所有 `newPath` 仍存在、`oldPath` 均未被占用、且本次页面未离开；否则按钮不显示或点击后提示无法撤销。

#### 3.6.5 与现有功能的关系

- 歌单：`playlist.dart` 只存 id，必须迁移；否则重命名后歌单直接少歌。
- 文件夹页：`folder.dart` 的 `_songIdListFile` 只存 id，必须迁移。
- 数据库：`MetadataItems.id` 是主键，必须同时插入新行和删除旧行；`library._saveMetadata()` 是全表重写，不能只改内存不写库。
- 播放队列/当前歌曲：`audioHandler.playQueue` 持有对象引用；替换对象后，如果正在播放，需要重新加载或至少更新当前项，否则进度/媒体通知仍指向旧对象。
- 添加时间：`file_created.json` 是路径键；不迁移会导致重启后专辑时间轴和“按添加时间排序”漂移。
- 封面：本地封面缓存按 `md5(id)`，不迁移会丢封面或显示旧封面。
- 收藏：本地专辑/艺术家收藏按名称保存（`localAlbumFavorites`、`localArtistFavorites`），文件名/目录变化不影响；但如果功能二改了专辑标签，收藏键会变化，这是既有行为。
- 统计：`stats.dart` 的歌曲键是 `title|artist`，不是 id，重命名文件不影响听歌统计。
- 搜索：无独立索引，列表内存过滤，重命名后刷新即可。
- 缓存：本地歌曲没有 `cachePath`（`MyAudioMetadata` 中仅非 local 设置），因此无音频缓存迁移问题；`pictures/local` 需要迁移。

#### 3.6.6 风险与性能

风险：

1. 身份迁移遗漏一处（歌单/文件夹/DB/队列）会造成“文件还在但列表少歌”。这是最高风险，必须按 3.6.4 的清单逐项验收。
2. Android 外置存储/SD 卡：`File.rename` 可能因权限失败；需 `Permission.manageExternalStorage` 检查，并逐条报错。
3. iOS 文件提供器路径（`isFileProviderStorePath`）与安全作用域书签：重命名可能失败或需要额外授权。设计上把这类歌曲标记 `blocked("iOS 文件提供器路径暂不支持移动")`，不做半成功。
4. 路径长度：超长路径在 Windows 上失败；预览阶段标记 blocked，不进入执行。
5. 大小写不敏感文件系统：仅大小写变化的重命名在 Windows/macOS 上需要“先改临时名再改目标名”；实现时作为特例处理，预览状态仍为 normal。
6. 正在播放：先暂停；如果用户不希望中断，可以把当前歌曲从本次 scope 排除并提示。
7. 并发扫描：执行期间 `Loader.busy` 为 true 时禁止开始整理；整理期间也不允许触发同步，避免扫描把半移动状态当成新文件。
8. 共享封面文件：`cover.jpg` 可能属于整张专辑，不能随单曲移动；只移动与歌曲同名的 sidecar。
9. `library.updateMetadata` 不写 `albumArtist`（见 4.6 的发现），重命名本身不涉及标签，但功能二的写入需要修这个缺口。
10. 撤销/日志文件：日志只保存路径和 id，不保存文件内容；撤销依赖文件仍在原位，不能替代备份。

性能：

- 预览：O(n) 字符串计算 + 一次存在性检查；1 万首约几十毫秒到几百毫秒，使用 `showCenterLoading` 不阻塞 UI。
- 执行：逐文件 I/O，移动是异步的；进度框每完成一个更新一次，不做每文件 setState 全页重建。
- 预览列表：`ListView.builder`/`SliverList`，不要一次性构建全部行。
- 数据库：一次事务批量插入/删除；不要逐条 commit。

### 3.7 验收点

1. 在 Navidrome、Emby、飞牛、WebDAV 下，设置页没有“本地音乐工具”，歌曲菜单没有“整理文件”，批量选择页没有“操作”，页面路由不可达。
2. 本地空库进入“整理文件结构”显示空状态，无“开始整理”。
3. 默认模板对 `title=Song, artist=Artist, album=Album, track=3` 生成 `Artist/Album/03. Song.<ext>`。
4. `Song (feat. X)` 在 `keepFeat` 开启时生成 `03. Song - feat. X.<ext>`；关闭时保留原标题。
5. `A/B:C*D?` 等非法字符被替换；`con`、`nul` 目录名追加下划线；`..` 路径段被拒绝。
6. 目标已存在的条目标为冲突且不移动；目标与当前相同的标为跳过且不移动；不在已配置根目录的标为不允许。
7. 执行后：新路径存在、旧路径不存在；不触发重新扫描，列表仍显示该歌；重启后歌单、文件夹页、播放次数、添加时间、封面都保持。
8. 模拟数据库写入失败：所有已移动文件回到旧路径，库中无新 id 行，无重复记录。
9. 执行中强制结束进程，再次启动：journal 恢复把文件移回旧路径，库可正常加载。
10. “撤销本次整理”在文件仍在新路径时可用，点击后全部回到旧路径；任一文件被外部改动后按钮提示不可撤销。
11. 移动后旧专辑目录若为空被删除，根目录保留；非空目录不删除。
12. 同一批次两首歌目标同名时，第二首为冲突，不产生覆盖。

---

## 4. 功能二：本地歌曲的元数据刮削与更新

### 4.1 参考实现

Tune Tree 的刮削由三个数据源和一套匹配评分组成。

`python/services/metadata_scraper.py`：

```python
TITLE_WEIGHT = 10
ARTIST_WEIGHT = 8
ALBUM_WEIGHT = 6
TRACK_WEIGHT = 5
YEAR_WEIGHT = 4
```

```python
if res_norm == kw_norm:
    score += weight
elif kw_norm in res_norm or res_norm in kw_norm:
    score += weight * 0.5
elif res_norm:
    score -= weight * 0.8
```

关键词优先级（`_build_search_keywords` 的注释）：

```text
1. 用户输入（user_input）- 最高优先级
2. 元数据标签（current_meta）
3. 文件名解析
4. 目录路径解析
```

搜索顺序（`search_all_apis`）：先网易云，0 条结果再 QQ 音乐，前两者都 0 条才用酷狗；每个源最多 5 条，按匹配分排序；歌曲详情用共享线程池并发抓取。酷狗返回 `errcode == 1002` 视为风控，终止该源。

写回标签在 `python/utils/metadata.py` 的 `write_metadata`：

```python
TAG_MAP = {
    "title": "title",
    "artist": "artist",
    "album": "album",
    "album_artist": "albumartist",
    "year": "date",
    "track_num": "tracknumber",
}
...
audio[tag_key] = [str(val)]
...
audio.save()
```

应用刮削结果在 `python/api/routes.py` 的 `api_apply_scraped_metadata`：

```python
for key in ["title", "artist", "album", "album_artist", "year", "track_num"]:
    if key in data and data[key] is not None:
        meta_fields[key] = data[key]
updated = write_metadata(row["path"], meta_fields)
...
if data.get("_cover_data"):
    write_cover(row["path"], cover_data, "image/jpeg")
...
if data.get("lyrics") is not None:
    write_lyrics(row["path"], data["lyrics"])
```

前端入口在 `python/static/js/modules/metadata-edit.js`：编辑弹窗右侧有“标签搜索”按钮；结果按源分组，每张卡片显示封面、标题、艺术家、专辑、音轨、年份；单击选中、双击直接确认；“换一批”用 `exclude_ids` 排除当前结果。批量入口在 `python/static/js/modules/batch-scrape.js`，按 5 首一组请求 `/tracks/batch-scrape`，用层叠卡片逐首应用/换一个/移除。

参考结论：核心是“多源候选 + 可解释的匹配评分 + 用户确认后写回 + 封面/歌词一并写”。Tune Tree 的批量卡片交互不必照搬，但候选分组、换一批、排除已看结果值得保留。

### 4.2 入口

主入口：

- 设置 → 音乐源 → 本地音乐工具 → “元数据补全”。
- 页面列出本地库中元数据不完整的歌曲，可单首搜索，也可勾选后批量搜索。

次级入口：

- 编辑元数据弹窗（`EditMetadata`）→ 标签搜索按钮。
- 歌曲行三点菜单 → “搜索标签”。
- 批量选择页顶部“操作”（“完成”左侧）→ “批量搜索标签”，仅本地且已选歌曲大于 0 时出现。

现有 `EditMetadata` 的打开条件：

```dart
includeEdit: sourceType == .local && artist == null && album == null,
```

`lib/base/services/interaction.dart` 和 `lib/landscape_view/panels/song_list_panel.dart` 都是这个条件。这意味着目前只有“所有歌曲”列表能编辑元数据。功能二要求“本地歌曲都能更新元数据”，建议把条件放宽为 `sourceType == .local`，让艺术家页、专辑页、文件夹页、歌单页的本地歌曲也能编辑/刮削。这是行为变化，列入待决策问题。

图标与标签：

| 位置 | 图标 | 标签 |
| --- | --- | --- |
| 工具页 | `Icons.edit_note_rounded` | 元数据补全 |
| 编辑元数据弹窗 | `Icons.search_rounded` | 标签搜索 |
| 歌曲菜单 | `Icons.search_rounded` | 搜索标签 |
| 结果弹窗 | `Icons.check_rounded` | 应用 |

隐藏规则：

- 非本地音源：工具页条目不出现；`EditMetadata` 当前不可达；歌曲菜单项不构建。
- 本地：即使没有任何缺少标签的歌曲，“元数据补全”入口仍存在，页面显示“全部歌曲元数据完整”的空状态。

### 4.3 页面 / 弹窗结构

#### 4.3.1 `MetadataCompletionPage`

```
opaqueSettingsPage(title: "元数据补全")
├─ ListView(padding: top 8, bottom 100)
│  ├─ appleSectionTitle("待补全歌曲")
│  ├─ 选择栏（普通 Row，与 SelectableSongListPage 顶部一致）
│  │   ├─ Checkbox("全选", activeColor: iconColor.value)
│  │   └─ Text("已选 N 首", 12px, textColor.withAlpha(150))
│  ├─ AppleFormSection(divided: true)
│  │   └─ 每首一行 ListTile
│  │       ├─ leading: CoverArtWidget(size: 44, borderRadius: 6)
│  │       ├─ title: 歌名（缺省显示文件名）
│  │       ├─ subtitle: 艺术家 - 专辑；后面跟缺失标记
│  │       └─ trailing: “搜索”文字按钮 / 忙碌时 16px CircularProgressIndicator
│  └─ myScaffold actions（仅本地）：TextButton("批量搜索选中")
```

批量动作放在顶部动作区，不放在列表底部：候选可能很多，底部按钮需要滚过整个列表才能触达。`opaqueSettingsPage` 为此增加可选 `actions` 参数（见 3.3.1），不新造页面外壳。

#### 4.3.1a 编辑元数据弹窗内的入口布局

`EditMetadata` 的现有结构是“封面 + 三个 `AppleFormSection`（标题/艺术家/专辑/专辑艺术家、流派/年份/音轨/碟号、歌词）+ 确认/取消”。功能二的入口放在封面之后、第一个字段卡片之前，功能三的入口放在歌词卡片内部：

```
Column
├─ 封面（现有）
├─ AppleFormSection(divided: false)
│   └─ ListTile(
│        leading: Icon(Icons.search_rounded, size: 22, color: iconColor.value),
│        title: Text("搜索标签"),
│        trailing: Icon(Icons.chevron_right_rounded),
│        onTap: 打开 MetadataScrapeDialog(song)
│      )
├─ AppleFormSection（现有标题字段）
├─ AppleFormSection（现有流派/年份字段）
└─ AppleFormSection（歌词）
    ├─ appleFormRow("歌词", appleTextField(_lyricsTextController, maxLines: 6))（现有）
    └─ ListTile(
         leading: Icon(Icons.timer_outlined, size: 22, color: iconColor.value),
         title: Text("歌词时间轴"),
         subtitle: Text("逐行调整 LRC 时间戳", 12px, textColor.withAlpha(150)),
         trailing: Icon(Icons.chevron_right_rounded),
         onTap: 打开 LyricTimelinePage(song, returnOnly: true)
       )
```

这样“搜索标签”和“歌词时间轴”都是普通 `ListTile`，与设置页一致；不把它们做成悬浮按钮、彩色按钮或图标工具栏。

行内容：

- 缺失标记只列存在问题的字段，例如“缺专辑”“缺封面”“缺歌词”，用 12px `textColor.withAlpha(150)`，不加彩色胶囊。
- 单首“搜索”直接打开 `MetadataScrapeDialog(song)`；批量“搜索”打开同一弹窗的批量模式，逐首处理。
- 不再使用 Tune Tree 的层叠卡片和滑动手势；应用现有的列表 + 弹窗交互。

空状态：

- 没有候选：`Center(Text("全部歌曲元数据完整"))`，不显示批量按钮。
- 扫描中：`CircularProgressIndicator`。
- 读取失败：`showCenterMessage`，页面保留已有列表。

候选判定（可配置）：

- `title == null || title.isEmpty`
- `artist == null || artist.isEmpty`
- `album == null || album.isEmpty`
- `track == null`
- `year == null`
- `!song.picture.isExist`（无内嵌封面）
- `song.lyrics == null || song.lyrics!.isEmpty`

默认只把前三项作为“缺失标签”，封面/歌词作为附加标记，避免把整个库都列进来。可在页面顶部加一个 `appleSegmented`：“仅缺标签 / 缺标签或封面 / 全部不完整”。

#### 4.3.2 `MetadataScrapeDialog`（单首结果弹窗）

沿用 `showAnimationDialog` 的弹窗形态，宽度 `isPhone ? 300 : 400`，高度 `max(350, screenHeight * 0.7)`，与 `EditMetadata` 一致。

```
Dialog
├─ 标题：“搜索标签”
├─ 查询区（AppleFormSection，可折叠）
│   ├─ appleTextFieldRow("歌名", titleController)
│   ├─ appleTextFieldRow("艺术家", artistController)
│   ├─ appleTextFieldRow("专辑", albumController)
│   ├─ appleTextFieldRow("音轨号", trackController, number: true)
│   └─ appleTextFieldRow("年份", yearController, number: true)
├─ 来源分区（每个有结果的源一段）
│   ├─ 小标题：来源名 + 数量 + “换一批”文字按钮
│   └─ 结果卡片列表（横向或纵向）
│       封面 64x64、歌名、艺术家、专辑、音轨/年份、匹配分
├─ 底部
│   ├─ appleTextButton("取消")
│   └─ appleFilledButton("应用", busy: applying)
```

结果卡片：

- 使用 `AppleFormSection` 的卡片行，而不是自带阴影的卡片；选中行使用 `textColor.withAlpha(38)`（与 `appleSegmented` 选中一致）。
- 封面用 `Image.memory`（候选自带 bytes）或占位 `Icons.album_rounded`。
- 来源名用普通 13px 文本，不做彩色胶囊；Tune Tree 的彩色源胶囊属于自定义视觉，不引入。
- 匹配分可以显示为“匹配 24”，用 12px alpha 150；不显示进度条或星级。

应用选项（放在结果列表下方，单个 `AppleFormSection`）：

- `appleSwitchRow("覆盖已有标签", overwriteNotifier)`，默认关闭。关闭时只填空字段；打开时用候选值覆盖非空字段。
- `appleSwitchRow("同时写入封面", coverNotifier)`，默认打开（候选有封面时）。
- `appleSwitchRow("同时写入歌词", lyricsNotifier)`，默认关闭（避免意外覆盖已有歌词）。
- 应用前展示差异：对每个将被修改的字段显示 `当前值 → 新值`，用 `appleFormRow` 两行；未变化的字段不列。

批量模式：

- 不打开多个弹窗，而是一个页面 `MetadataBatchReviewPage`（可从 `MetadataCompletionPage` 进入）：
  - 顶部进度“正在搜索 x / y”，可停止。
  - 结果按歌曲分组为 `AppleFormSection`：歌曲标题、当前标签、最佳候选、来源、匹配分、复选框“应用”。
  - 底部 `appleFilledButton("应用选中")`。
  - 每首的“换一个”只在该歌曲的候选列表内循环，不重新请求全部源；候选耗尽时置灰/隐藏。
- 逐首应用，每首完成更新进度；失败的歌曲保留在列表中并标记原因。

### 4.4 样式与主题

- 页面外壳：`opaqueSettingsPage`。
- 弹窗：`showAnimationDialog` + `SizedBox(width: 300/400, height: max(350, h*0.7))`，与 `EditMetadata`、`SongInfo` 一致。
- 分组：`AppleFormSection` / `appleSectionTitle`；弹窗内的字段用 `appleTextFieldRow`。
- 按钮：主操作用 `appleFilledButton`，取消用 `appleTextButton`。
- 来源/状态不用自定义颜色胶囊；需要弱化时用 `textColor.withAlpha(150)`。
- 封面：`CoverArtWidget`（列表）或 `Image.memory`（候选 bytes）。
- 不使用 Tune Tree 的 `--accent`、`--blue`、`--amber` 等 CSS 变量；全部映射到应用的 `colorManager` 与 `buttonColor.value`。
- 文案无表情符号。

### 4.5 交互流程

1. 从工具页进入“元数据补全”，加载候选列表；默认“仅缺标签”。
2. 单首点“搜索”：
   - 打开 `MetadataScrapeDialog`，查询字段预填当前标签（空则按文件名解析）。
   - 自动发起一次搜索，显示各源结果；用户可修改查询字段后点“搜索”重试。
   - 选择一张结果 → 显示差异 → 确认“应用”。
   - 应用时按钮进入 busy 状态，禁止重复点击；完成后关闭弹窗，列表刷新，该歌从未补全列表移除。
3. 批量：
   - 勾选歌曲 → “批量搜索选中” → 逐首请求，显示进度；可随时停止，已完成的保留。
   - 结果页逐首复核；默认只勾选“最佳结果匹配分达到阈值”的歌曲，阈值可在页面说明中写明（例如 18 分），低分默认不勾选。
   - “应用选中”逐首写入，失败项留在列表。
4. “换一批”：
   - 每个源维护当前已展示的 `sourceId` 列表，请求时作为 `exclude_ids`；返回为空则提示“该来源没有更多结果”。
   - 换一批后清空当前选择，避免选到已消失的条目。
5. 取消：
   - 未应用前关闭弹窗无副作用。
   - 应用中不允许关闭；进度页提供“停止”，停止后已完成项不回滚。
6. 应用后可选“撤销本次应用”：在结果弹窗内保留原始字段快照，成功后显示一次“撤销”文字按钮；撤销时把原字段写回。离开弹窗后不再提供。批量模式不提供整体撤销，避免与后续编辑冲突。

### 4.6 数据与业务逻辑

#### 4.6.1 数据源抽象

新增 `lib/base/services/metadata_scraper.dart`，定义 provider 接口（设计级）：

```
MetadataQuery {
  String? title, artist, album;
  int? track, year;
  String filename;      // 用于解析
  String? directory;    // 用于从父目录解析 artist/album
  Set<String> excludeIds;
}

ScrapedCandidate {
  String source;        // provider id
  String sourceId;
  String? title, artist, album, albumArtist;
  int? year, track;
  Uint8List? coverBytes;
  String? lyrics;
  double score;
  Map<String, double> scoreParts;
}
```

provider 负责 `search(query)` 和 `fetchDetail(sourceId)`；`metadata_scraper.dart` 负责关键词构建、评分、排序、跨源回退、并发和取消。

#### 4.6.2 关键词构建（对齐 Tune Tree）

优先级从高到低：

1. 用户在弹窗中输入的 title/artist/album/track/year。
2. 当前歌曲标签（`song.title/artist/album/track/year`）。
3. 文件名 `artist - title` 解析（仅当前两者都没有 title/artist 时）。
4. 父目录：取文件所在目录的上一级为 artist、当前级为 album（仅当前两者都没有时）。
5. 音轨号：用户输入 > 标签 > 文件名开头 `^\d{1,3}[.\-_ ]`。
6. 年份：用户输入 > 标签。

搜索关键词字符串：`title|artist|album`，跳过空值。与 Tune Tree 的 `keyword` 一致。

#### 4.6.3 评分

沿用 Tune Tree 的权重与加减分：

| 字段 | 精确 | 包含 | 不匹配 |
| --- | --- | --- | --- |
| title | +10 | +5 | -8 |
| artist | +8 | +4 | -6.4 |
| album | +6 | +3 | -4.8 |
| track | +5 | - | -4 |
| year | +4 | - | -3 |
| 排除列表 | - | - | -1000 |

文本比较先做 NFKC、去首尾空格、小写。与 Tune Tree 的 `normalize_str` 一致；`NFKC` 对全角/半角、假名兼容字符有用。

结果按分数降序；同分按来源顺序和原始顺序稳定排序。默认每源取前 5，排除列表存在时抓 20 条再取前 5。

#### 4.6.4 搜索顺序与并发

- 单首“自动”模式：先源 A，0 条再源 B，前两者 0 条再源 C；一旦某源有结果就不再请求后面的源。这是 Tune Tree 的策略，能减少风控。
- 用户点某个来源的“换一批”：只请求该源，不受上面的回退限制。
- 每个候选的详情并发抓取，最大 12 个并发（Tune Tree 的共享线程池）；Dart 侧用 `Pool(12)` 或 `Future.wait` 分批。
- 每个请求带 10 秒超时；单源失败只影响该源，不阻断其他源。
- 风控/限额：provider 抛出 `RateLimitException` 时，停止该源并提示；不自动重试。
- 取消：批量模式维护 `CancelToken`/bool，用户停止后不再发起新请求，已发出的请求结果丢弃。

#### 4.6.5 写回标签

写回复用 `audio_tags_lofty` 的 `writeMetadata`（`EditMetadata` 已用）：

```
writeMetadata(
  path: song.path!,
  title: 最终标题,
  artist: 最终艺术家,
  album: 最终专辑,
  albumArtist: 最终专辑艺术家,
  genre: song.genre ?? '',
  year: 最终年份,
  track: 最终音轨,
  disc: song.disc,
  lyrics: 最终歌词,
  pictureBytes: 最终封面 bytes（未选新封面时传 null）,
)
```

关键点：

- `writeMetadata` 的字段是整套写入；未修改的字段必须传当前值，不能传空，否则会把标签清空。
- `overwrite == false` 时，候选字段只在当前值为空时采用；`overwrite == true` 时采用候选的非空字段，候选为空则保留当前值（不清空）。
- 封面：只有用户勾选“同时写入封面”且候选有 bytes 时传 `pictureBytes`；否则传 `null`，保留原封面。
- 歌词：只有用户勾选且候选有歌词时写；否则传当前歌词（保持原样）。
- 写入前校验封面：JPEG/PNG、≤ 5MB、解码尺寸 ≤ 6000x6000（与项目既有的封面校验思路一致）；不合法则跳过封面并提示，不阻断标签写入。

写后处理（必须与 `EditMetadata._tryWriteMetadata` 保持一致）：

- `song.modified = DateTime.now()`
- 若 `song.cacheExist`，删除 `song.cachePath`（本地通常为 false）
- 赋值 title/artist/album/albumArtist/genre/lyrics/year/track/disc
- `song.parsedLyrics = null`，`await setParsedLyrics(song)`
- `await library.updateMetadata(song)`
- 封面变更时：`invalidateCoverFile(song.picture)`（删除 `pictures/local/md5(id)` 旧文件），而不是只 `picture.reset()`；清 `PaintingBinding.instance.imageCache`
- `await computeColor(song.picture)`；若该歌是当前歌曲，更新 `currentCoverArtColor`、`contrastColorTheme`、`colorManager.updateLyricsPageColors()`
- `artistAlbumManager.updateArtistAlbum()`
- `song.updateNotifier.value++`、`song.picture.changeNotifier.value++`
- `layersManager.updateBackground()`
- 若当前歌曲，`audioHandler.updateLyricsNotifier.value++`（歌词变更时）

`EditMetadata` 目前只调用 `song.picture.reset()`，没有删除封面缓存文件；而 `_loadPicture` 是磁盘优先，会继续读旧文件。功能二应修正为 `invalidateCoverFile`，并在实现时把这段逻辑抽成共享 helper，避免编辑弹窗和刮削各写一份。

#### 4.6.6 数据库缺口

`lib/base/data/library.dart` 的 `updateMetadata`：

```dart
MetadataItemsCompanion(
  title: Value(song.title),
  artist: Value(song.artist),
  album: Value(song.album),
  genre: Value(song.genre),
  lyrics: Value(song.lyrics),
  year: Value(song.year),
  track: Value(song.track),
  disc: Value(song.disc),
)
```

没有 `albumArtist`。`EditMetadata` 会把 `song.albumArtist` 改在内存里，但重启后从数据库加载会丢失。功能二既然要写 album_artist，必须先把 `albumArtist: Value(song.albumArtist)` 补进 `updateMetadata`；否则刮削结果在本次会话可见、重启后消失。

另外 `updateMetadata` 也不写 `size`/`modified`，本功能不需要改。

#### 4.6.7 与现有功能的关系

- 专辑/艺术家分组：`albumKeyOf` 对本地用 `name:{album}`，改专辑标签会把歌曲移到另一张专辑；这是预期行为，但用户需要知道“应用新专辑名会改变分组”。`artistAlbumManager.updateArtistAlbum()` 必须调用。
- 本地专辑收藏按名称保存；改专辑名后原收藏不会自动跟过去。与现有 `EditMetadata` 行为一致，不额外处理。
- 添加时间：`song.created` 不变，数据库无该列；功能四的时间轴不受标签修改影响。
- 歌单/文件夹：按 id（路径）保存，标签修改不改 id，不受影响。
- 播放统计：`stats.dart` 键为 `title|artist`，改标签会导致之后的播放计入新的键；历史统计不会迁移。这是既有行为。
- 当前播放：如果修改的是当前歌曲，封面/歌词/标题需要刷新；`currentSongNotifier` 对象是同一引用，赋值后 `updateNotifier` 触发 UI。
- 扫描：写入期间 `Loader.busy == true` 时禁止应用；写入后不需要重扫，内存和数据库都已更新。
- 封面缓存：必须删除旧缓存文件，否则新旧封面不一致（见 4.6.5）。
- 数据库版本：不新增列，`schemaVersion` 不变；但 `updateMetadata` 的行为修正属于代码修复，不需要迁移。

迁移与回滚：

- 没有数据库结构迁移；`updateMetadata` 补 `albumArtist` 是行为修复，不影响已有行。
- 应用标签前不修改文件；用户确认后才写。弹窗内保留原始字段快照，可在同一弹窗内“撤销本次应用”。
- 关闭弹窗后不保留跨会话历史；回滚只能再次编辑标签或重新刮削。批量模式仅按单首撤销，不提供整体回滚，避免与之后的编辑冲突。

#### 4.6.8 风险与性能

风险：

1. 数据源稳定性与合规：Tune Tree 使用非官方 Web API（网易云、QQ、酷狗），可能随时失效、限流或涉及服务条款。必须在开工前由用户确定数据源（见待决策问题）。
2. 覆盖标签：默认“只填空”降低误覆盖；打开“覆盖已有标签”时必须在差异预览中明确列出。
3. 封面缓存：不删除旧缓存会表现为“保存成功但封面没变”。
4. albumArtist 丢失：`updateMetadata` 缺列，必须先修。
5. 并发：批量写入与用户手动编辑同一首歌会互相覆盖；批量页应标记正在处理的歌曲，写入期间禁止该行再次打开。
6. 网络超时：单首 10 秒，批量 20 首最多约 200 秒；需要进度和停止。
7. 内存：封面 bytes 每首一张，20 首约几十 MB；批量模式应只保留当前页/选中项的 bytes，应用后释放。
8. 文件名解析误判：`artist - title` 对含连字符的歌名可能拆错；用户输入优先级最高，结果页显示解析来源，允许修正。

性能：

- 单首：1 次搜索 + 最多 5 次详情；并发抓取，通常 1-3 秒。
- 批量：逐首或 2-3 首并发；不要一次 20 首全并发，避免风控。
- 列表：`ListView.builder`；候选封面用 `Image.memory` 并限制解码尺寸。
- 写回：一次标签写入 + 一次 DB update；封面解码在主 isolate 之外？`writeMetadata` 是平台调用，按现有 `EditMetadata` 的方式即可。

### 4.7 验收点

1. 非本地音源：设置页无“元数据补全”，编辑元数据不可达，歌曲菜单无“搜索标签”。
2. 本地歌曲打开编辑元数据，点“标签搜索”能打开结果弹窗；查询字段预填正确。
3. 结果按来源分组，显示封面、标题、艺术家、专辑、音轨、年份；“换一批”不重复当前结果。
4. 选择结果后显示差异；`覆盖已有标签` 关闭时只填空字段，打开时覆盖非空字段。
5. 应用后：文件标签更新；重启应用后 title/artist/album/albumArtist/year/track 仍在（验证 `updateMetadata` 已补 albumArtist）。
6. 应用后封面立即更新，无需重启；旧 `pictures/local/md5(id)` 已被删除。
7. 歌词开关关闭时不覆盖原歌词；打开时写入并能在播放页显示。
8. 网络失败/0 结果：显示空状态或错误提示，不写任何标签。
9. 批量页只列本地候选；勾选、进度、停止、逐首应用、失败保留均符合描述。
10. 应用期间 `Loader.busy` 时按钮不可用（或应用前提示“正在同步，稍后再试”）。
11. 应用新专辑名后，专辑列表出现新专辑，歌曲进入新专辑；收藏不自动迁移但无崩溃。
12. 当前播放歌曲应用新封面后，迷你栏/播放页封面同步更新。

---

## 5. 功能三：歌词时间轴快捷编辑器（LRC 时间戳）

### 5.1 参考实现

Tune Tree 的 LRC 解析与序列化在 `python/static/js/modules/lrc-parser.js`：

```js
TAG_REGEX: /^\[([a-z]+):(.*)\]$/i,
TIME_REGEX: /^\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)$/,
```

同一时间戳的两行被合并为一个 group 的主行和附行：

```js
if (current.timestamp !== null && next && next.timestamp !== null &&
    Math.abs(current.timestamp - next.timestamp) < 0.001) {
  groups.push({
    timestamp: current.timestamp,
    primary: { text: current.text, role: 'primary' },
    secondary: { text: next.text, role: 'secondary' }
  });
```

编辑器在 `python/static/js/modules/lyrics-editor.js`：

- 打开时解析当前歌词，加载缓存（`localStorage`，键 `tt-lyrics-edit-<trackId>`）。
- 音频播放条：快退 5 秒、播放/暂停、快进 5 秒、打轴按钮。
- 打轴：

```js
const currentTime = audio.currentTime;
const group = data.groups[lyricsState.activeGroupIndex];
group.timestamp = currentTime;
group.timestampStr = LrcParser.formatTime(currentTime);
...
if (lyricsState.activeGroupIndex < data.groups.length - 1) {
  setActiveGroup(lyricsState.activeGroupIndex + 1);
  _scrollToActiveGroup();
}
```

- 快捷键：`Shift+Enter` 打轴、`Shift+Space` 播放/暂停、`Shift+←/→` 快退/快进、`↑/↓` 切换行。
- 行操作：添加附行（同时间戳）、在下方添加行、删除整行、删除主行/附行。
- 导出 LRC：可浏览器下载，或保存到歌曲目录（`/tracks/<id>/export-lrc`）。
- “移除逐字轴”用 `stripWordTimestamps` 去掉 `<mm:ss.xx>` 词级时间戳。

编辑器弹窗的完整结构在 `python/static/index.html:402-523` 的 `#lyrics-editor-modal`：歌曲信息、播放条（audio、播放/暂停、±5 秒、打轴、进度、音量）、工具栏（搜索歌词/导入/重置/复制/导出 LRC/移除逐字轴）、快捷键提示、搜索面板、导入面板（粘贴/上传）、元数据文本域、行列表、底部取消/确认。Flutter 页面应保留这些能力，但不要复制它的 CSS 外观。

参考结论：本功能是“行级时间戳编辑器”，不是逐字卡拉 OK 编辑器；核心是播放、打轴、自动跳下一行、快捷键和 LRC 往返保真。

### 5.2 入口

主入口：

- 编辑元数据弹窗（`EditMetadata`）→ 歌词卡片 → “歌词时间轴”。
- 该弹窗已经是本地限定；因此入口天然只在本地出现。

次级入口：

- 歌曲行三点菜单 → “编辑歌词时间轴”（`isLocalLibrary` 时构建）。
- 批量选择页不提供歌词编辑（逐首编辑，不做批量）。

图标与标签：

| 位置 | 图标 | 标签 |
| --- | --- | --- |
| 编辑元数据歌词卡片 | `Icons.timer_outlined` | 歌词时间轴 |
| 歌曲菜单 | `Icons.timer_outlined` | 编辑歌词时间轴 |

隐藏规则：

- 非本地音源：编辑元数据不可达；歌曲菜单不构建该项。
- 本地但歌词为空：入口仍存在，页面显示空行状态，可直接添加行或从剪贴板导入。
- 本地但歌词是 TTML：入口存在，但页面显示“此歌词为 TTML，暂不支持逐行时间轴编辑”，不显示可编辑行；不提供“保存”误导用户。是否把入口改为不显示，列入待决策问题。

### 5.3 页面 / 弹窗结构

使用全屏设置子页，而不是弹窗：需要在有限高度里放播放器和可滚动的几十上百行歌词，弹窗会导致双层滚动和键盘遮挡。

```
opaqueSettingsPage(title: "歌词时间轴")
├─ myScaffold actions:
│   ├─ TextButton("重置")
│   └─ TextButton("保存")
└─ Column
   ├─ 歌曲信息行（普通 Padding + Text）
   │   ├─ 歌名（15px，textColor）
   │   └─ 艺术家 - 专辑（12px，alpha 150）
   ├─ AppleFormSection(title: "播放", divided: false)
   │   ├─ appleFormRow("进度", 时间文本 / 总时长)
   │   ├─ Slider（4 个按钮：-5s、播放/暂停、+5s、打轴）
   │   └─ 音量（可选；默认 0.8）
   ├─ 偏移提示行（仅 lyricsTimeOffset != 0 时）
   │   └─ appleFormRow("播放偏移", Text("+0.30s") + TextButton("写入时间轴并归零"))
   ├─ 快捷键说明（仅非移动端；12px alpha 150）
   ├─ 逐字轴提示（仅检测到逐字时间戳时）
   │   └─ appleFormRow("逐字时间戳", TextButton("移除逐字轴"))
   ├─ Expanded
   │   └─ ListView.builder
   │       └─ 每行 _LyricLineRow
   └─ 底部留白 100
```

`_LyricLineRow` 结构：

```
Row
├─ SizedBox(width: 86)
│   └─ TextField（时间戳，mm:ss.xx，右对齐，`FontFeature.tabularFigures()`）
├─ Expanded
│   └─ Column
│       ├─ Row: TextField（主行，左对齐，多行按需）
│       └─ Row: TextField（附行，仅 secondary 存在时）
└─ 行尾
    ├─ IconButton(Icons.schedule_rounded)  打轴
    ├─ IconButton(Icons.add_rounded)       添加附行
    ├─ IconButton(Icons.arrow_downward_rounded) 在下方添加行
    └─ IconButton(Icons.close_rounded)     删除整行
```

为了不显得拥挤，移动端可以把“添加附行/在下方添加行/删除”收进行尾的 `PopupMenuButton`，桌面端保留四个小图标。两种形态都使用现有 `IconButton` 和主题图标色。

行选中：

- 选中行背景 `textColor.withAlpha(38)`（与 `appleSegmented` 选中一致），左侧时间戳文字色不变。
- 不画竖线、不做发光、不做卡片阴影。
- 点击行任意位置选中；点击时间戳输入框不取消选中。

空状态：

- 没有行：居中“暂无歌词行”，下面一个 `appleFilledButton("添加一行")`。
- 歌词为 TTML：居中说明文字，不显示可编辑行。
- 加载失败/文件不存在：居中说明 + “返回”。

### 5.4 样式与主题

- 页面外壳：`opaqueSettingsPage`，不使用自定义背景。
- 分组：播放器信息和提示用 `AppleFormSection`；歌词行本身是列表行，不套卡片，避免每行一个卡片造成视觉噪音。
- 字体：时间戳使用 `FontFeature.tabularFigures()` 与 13px；正文 15px；说明 12px `textColor.withAlpha(150)`。不指定自定义字体族，跟随应用字体设置。
- 颜色：选中背景、播放器按钮、进度条都用 `textColor`/`iconColor.value`/`buttonColor.value`；破坏性操作（删除行）使用 `Colors.red`，与现有确认弹窗一致。
- 不使用 Tune Tree 的 CSS 变量和彩色角色徽标；主行/附行的区分靠缩进和 12px 的“翻译”文字，而不是彩色圆点。
- 文案无表情符号。

### 5.5 交互流程

1. 打开页面：
   - 若有 `lyricsTimeOffset != 0`，在顶部显示偏移提示。
   - 解析歌词为 LRC 文档；保留头部元数据原文。
   - 暂停主播放器（避免两路音频同时响），创建页面内独立播放器。
   - 若当前歌曲不是目标歌曲，不改变主播放队列；页面播放器只播放本地文件。
2. 选择行：点击行或时间戳；选中行高亮。
3. 打轴：
   - 点击行尾的时钟按钮，或按 `Shift+Enter`。
   - 把选中行的 `start` 设置为播放器当前位置；时间戳输入框同步。
   - 自动选中下一行并滚动到可见区域；最后一行则停留在最后一行。
   - 若没有选中行，提示“先选择一行”。
4. 编辑时间戳：
   - 点击时间戳输入框，全选文本。
   - 输入 `mm:ss`、`mm:ss.x`、`mm:ss.xx`、`mm:ss.xxx`；提交时解析。
   - 非法输入：恢复原值并 `showCenterMessage("时间格式无效")`。
5. 编辑文本：直接修改主行/附行；同一时间戳的两行在保存时保持相邻。
6. 添加/删除：
   - “添加附行”：为当前行创建 secondary，时间戳与主行相同；保存时输出两行同时间戳。
   - “在下方添加行”：新行时间戳为当前行 +0.1 秒（若当前行有时间戳），否则为空。
   - “删除整行”：删除主行和附行；删除主行但保留附行时，附行升为主行（与 Tune Tree 的 `removeLineFromGroup` 行为一致）。
7. 播放器：
   - 播放/暂停、±5 秒；拖动进度条跳转。
   - 跳转后自动选中离当前位置最近的有时间戳的行（Tune Tree 的 `_moveCursorToNearestTimestamp`）。
8. 偏移：
   - “写入时间轴并归零”把所有行的 `start` 减去当前 `lyricsTimeOffset`，然后把 `song.lyricsTimeOffset` 置 0 并 `library.updateLyricsTimeOffset(song)`。
   - 说明：播放时判断的是 `position + offset` 与行开始时间；因此正偏移意味着歌词提前出现。写入时间轴时要减去 offset，才能保持同样的听感。
9. 逐字轴：
   - 若解析发现一行内有多个 `<mm:ss.xx>` 词级时间戳，显示提示和“移除逐字轴”。
   - 移除后行变成普通行级时间戳；此操作不可逆，需确认。
10. 保存：
    - `returnOnly == true`（从 EditMetadata 进入）：序列化 LRC 文本，`Navigator.pop(context, text)`；EditMetadata 把文本放进 `_lyricsTextController`，用户仍需点编辑元数据的“确认”才会写文件。
    - `returnOnly == false`（从歌曲菜单进入）：调用共享的 `saveLyrics(song, text)` 直接写标签/侧车并更新数据库，显示“保存成功”，留在页面或返回由产品决定；建议保存后返回。
11. 重置：
    - 恢复到打开时的原始文本并重新解析；有改动时先确认。
12. 关闭：
    - 有未保存改动时 `showConfirmDialog("放弃修改")`。
    - 释放页面播放器、音频焦点；不自动恢复主播放器播放。

键盘行为（桌面/外接键盘）：

| 快捷键 | 动作 |
| --- | --- |
| `Shift+Enter` | 打轴 |
| `Shift+Space` | 播放/暂停 |
| `Shift+←` | 快退 5 秒 |
| `Shift+→` | 快进 5 秒 |
| `↑` | 上一行 |
| `↓` | 下一行 |

输入框内 `↑/↓`：只有光标在文本开头（上）或结尾（下）时才切换行，否则保留给文本导航（与 Tune Tree 一致）。移动端不显示快捷键说明，只保留按钮。

### 5.6 数据与业务逻辑

#### 5.6.1 LRC 文档模型

新增 `lib/base/data/lrc_document.dart`：

```
LrcMetaLine { String raw; }               // 头部原样保留
LrcLineGroup {
  String localId;                         // 列表 key，稳定
  Duration? start;
  String primary;
  String? secondary;
}
LrcDocument {
  List<String> headerLines;               // [ti:]、[ar:]、[al:]、[by:]、未定时行
  List<LrcLineGroup> groups;
  bool hasWordTimestamps;
}
```

解析规则（对齐 Tune Tree）：

- 行级时间：`^\[(\d{2}):(\d{2})[.:](\d{1,3})\](.*)$`；1-3 位毫秒，2 位按 ×10 处理（`05` → 50ms）。
- 标签行：`^\[([a-zA-Z]+):(.*)\]$`，且不以 `\d{2}:\d{2}` 开头；归入 `headerLines`，不参与行列表。
- 无时间戳的普通行：如果文档中至少有一行带时间戳，则归入头部/未定时区，保留原文；如果整篇没有时间戳，则作为无时间行显示（不可打轴，打轴时先赋时间）。
- 连续两行时间差 < 1ms 视为同一组：第一行为 primary，第二行为 secondary。
- 序列化：先输出 `headerLines` 原样，再按 groups 输出 `[mm:ss.xx]主行`，有附行则再输出一行同样的时间戳。
- 时间格式：`mm:ss.xx`（两位毫秒）用于输入和显示；保存时用两位，兼容现有解析器（`lyric.dart` 的 `parseTime` 会 `padRight(3,'0')`，两位 `05` 变成 `050` 毫秒，即 50ms，正确）。
- 空行、多余空白：解析时丢弃纯空行；保存时每个 group 一行，不保留原始空行位置。头部原文保留。

#### 5.6.2 与现有歌词解析的关系

`lib/base/services/lyric.dart` 的 `applyLrcParsing` 已经支持行级和逐字时间戳、翻译行、TTML。编辑器只处理 LRC；保存后：

- `song.lyrics = text`
- `song.parsedLyrics = null`
- `await setParsedLyrics(song)`
- 若该歌是当前歌曲，`audioHandler.updateLyricsNotifier.value++`
- `song.updateNotifier.value++`

不修改 `lyricsTimeOffset`，除非用户点了“写入时间轴并归零”。

#### 5.6.3 写回目标

两条路径：

1. 从 `EditMetadata` 进入：只返回文本，由 `EditMetadata` 的“确认”统一写。写入走 `writeMetadata(lyrics: ...)`，同时 `library.updateMetadata(song)`。这与现有编辑元数据一致。
2. 从歌曲菜单进入：直接保存。写回策略：
   - 始终写内嵌歌词标签（`writeMetadata(lyrics:)`）。
   - 如果歌曲同目录存在同名 `.lrc` 侧车文件，则同时更新该文件；否则不新建侧车，避免产生用户没要求的文件。
   - 若原歌词只来自侧车（`song.lyrics` 为空，`setParsedLyrics` 读侧车），保存后内嵌标签生效，侧车也更新，二者一致。
   - `.ttml`/`.xml` 侧车不写，页面在检测到 TTML 时应阻止编辑。

#### 5.6.4 播放器

- 使用项目已依赖的 `media_kit` 的 `Player`，只播放本地文件 `song.path`。
- 打开页面时 `audioHandler.pause()`；不修改主播放队列，不写播放历史，不触发 scrobble。
- 页面销毁时 `player.dispose()`；不自动恢复主播放器。
- 音量默认 0.8；不做持久化。
- 进度用 `StreamBuilder<Duration>` 监听 `player.stream.position` / `player.stream.duration`；拖动时先暂停位置回写，松手再 seek，避免抖动。

#### 5.6.5 与现有功能的关系

- `lyricsTimeOffset`：既有字段，播放页用它做全局偏移。编辑器必须显式处理，否则用户会看到“编辑后的时间和播放对不上”。
- 逐字歌词：现有 `ParsedLyrics.isKaraoke` 支持逐字；编辑器只做行级。检测到逐字时提示移除，避免保存后逐字信息被静默丢失。
- TTML：现有解析支持 TTML；编辑器无 TTML 序列化，必须检测并阻止，不能把 TTML 当普通文本改写。
- 侧车歌词：`setParsedLyrics` 在 `song.lyrics` 为空时读 `.lrc`/`.ttml`/`.xml`；保存内嵌后 `song.lyrics` 非空，后续优先内嵌。更新侧车是为了其他播放器也看到新时间轴。
- 缓存：本地歌曲无歌词缓存文件；`parsedLyrics` 是内存缓存，保存后置空重解析。
- 播放页：保存后如果当前歌曲正在播放，`updateLyricsNotifier` 触发高亮行重新计算；不需要重启页面。
- 封面/元数据：互不影响。

迁移与回滚：

- 没有数据库结构迁移；`lyricsTimeOffset` 是既有列。
- 写回是覆盖式。页面内“重置”恢复到打开时文本；从 `EditMetadata` 进入时，编辑元数据弹窗的“取消”可以整体放弃；从歌曲菜单直接保存时，旧歌词只保留在页面状态，离开页面后不可自动撤销，因此保存前必须确认。
- 侧车 `.lrc` 只在已存在时同步更新；不会新建用户未要求的文件。

#### 5.6.6 风险与性能

风险：

1. 保存覆盖原歌词且无自动历史；必须在关闭时确认放弃，并在页面提供“重置到打开时”。
2. 偏移处理错误会导致整篇时间轴错位；按 5.5 第 8 条的方向计算，并写单元测试。
3. TTML/逐字歌词被错误降级；检测后阻止或确认。
4. 两路播放器同时出声：进入页面先暂停主播放器。
5. 大量行的重建：每次输入都重建整个 `ListView` 会丢焦点；每个 group 固定 `localId`，输入只更新数据模型，不触发整页重建；仅在添加/删除/打轴/跳转时 `setState`。
6. 时间戳解析宽松：`01:2.3`、`1:02.3` 等非标准输入应拒绝，避免保存出解析器读不懂的 LRC。
7. 键盘快捷键与输入框冲突：按 Tune Tree 的“光标在首/尾才切换行”规则处理。
8. 侧车文件写失败：标签已写成功、侧车失败时提示“标签已保存，侧车更新失败”，不回滚标签。
9. iOS 文件提供器路径写标签可能失败：与现有 `EditMetadata` 一样弹出失败提示；不做特殊绕过。
10. 草稿缓存：Tune Tree 用 `localStorage` 保存编辑进度；本设计默认不写草稿，依赖页面内状态和关闭确认。若需要崩溃恢复，再增加按 `song.id` 的 appSupport 草稿文件，并在打开时提示恢复；不要直接照搬 `localStorage` 键。

性能：

- 解析 O(行数)，1000 行毫秒级。
- 列表 `ListView.builder`，只构建可见行。
- 每行一个 `TextEditingController` 会在 1000 行时占用内存；可用 `TextFormField(initialValue:)` + `onChanged` 或按可见行懒创建控制器。设计推荐：每个 group 一个 controller，数量与歌词行数同阶（通常 < 200），可接受；若担心长歌词，使用 `TextFormField` 的 `initialValue` 并在 `onChanged` 写回模型。

### 5.7 验收点

1. 非本地音源：编辑元数据不可达，歌曲菜单无“编辑歌词时间轴”。
2. 本地歌曲从编辑元数据进入，页面显示现有歌词行、头部 `[ti:]`/`[ar:]` 等原样保留。
3. 播放后点“打轴”，选中行时间戳等于播放位置（±0.1 秒），自动跳到下一行并滚动到可见。
4. `Shift+Enter`、`Shift+Space`、`Shift+←/→`、`↑/↓` 在桌面端生效；输入框内方向键行为符合第 5.5 条。
5. 同一时间戳添加附行后保存，输出两行同时间戳；删除主行后附行升为主行。
6. 非法时间输入被拒绝并提示，不写坏数据。
7. 保存后返回编辑元数据，歌词输入框内容为新文本；点“确认”写标签，播放页时间轴正确。
8. 从歌曲菜单直接保存，重启后歌词仍在；若存在 `.lrc` 侧车，侧车内容同步更新。
9. TTML 歌词显示说明，不出现可编辑行；逐字歌词显示“移除逐字轴”，确认后行级时间戳保留。
10. `lyricsTimeOffset != 0` 时显示提示；点“写入时间轴并归零”后，所有时间戳按方向调整，offset 变为 0，播放听感不变。
11. 有未保存改动关闭页面时弹确认；确认放弃后再次打开是原始歌词。
12. 页面打开时主播放器暂停；关闭后页面播放器释放，主播放队列未被修改，播放历史未新增记录。

---

## 6. 功能四：统计页的专辑时间轴

### 6.1 参考实现

Tune Tree 的专辑统计页在 `python/static/js/modules/album-stats.js`，入口是统计概览的“专辑”卡片（`python/static/js/modules/stats.js:66` 的 `openAlbumStats()`）：

```js
<div class="stat-card" onclick="openAlbumStats()">
  <div class="stat-label">专辑</div>
  <div class="stat-value">${s.total_albums}</div>
  ...
</div>
```

专辑统计页的“时间轴”区块：

```js
<div class="as-section" data-section="timeline">
  <div class="as-section-title">时间轴</div>
  ${_renderTimelineControls()}
  <div id="abs-timeline-container">
    ${_renderTimeline(stats.recent_tracks, _absTimelineRange)}
  </div>
</div>
```

时间范围只有“一个月内 / 三个月内”两个按钮（`_renderTimelineControls`）。

聚合算法（`_renderTimeline`）：

```js
const now = Date.now() / 1000;
const rangeDays = { month: 30, quarter: 91 };
const cutoff = now - (rangeDays[range] || 30) * 86400;
const filtered = tracks.filter(t => t.ctime && t.ctime >= cutoff);

const dayGroups = {};
filtered.forEach(t => {
  const d = new Date(t.ctime * 1000);
  const key = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
  if (!dayGroups[key]) dayGroups[key] = [];
  dayGroups[key].push(t);
});
...
dayTracks.forEach(t => {
  const aid = t.album_id || 0;
  if (!albumMap[aid]) albumMap[aid] = { ... tracks: [] };
  albumMap[aid].tracks.push(t);
});
```

后端数据来自 `python/repository/album_repository.py` 的 `recent_tracks`：

```sql
SELECT t.id AS track_id, t.title AS track_title, t.ext, t.duration, t.size,
       t.ctime, t.track_num,
       al.id AS album_id, al.title AS album_title, al.cover_path, al.year,
       al.artist_id, ar.name AS artist_name
FROM tracks t
LEFT JOIN albums al ON al.id = t.album_id
LEFT JOIN artists ar ON ar.id = al.artist_id
WHERE t.ctime IS NOT NULL
ORDER BY t.ctime DESC
LIMIT 500
```

悬停卡片（`_absShowHover`）显示专辑封面、标题、艺术家、年份、曲目数、总大小和曲目列表；左右交替布局是 Tune Tree 的 Web 视觉，不照搬到 Flutter。

参考结论：核心是“按添加时间（ctime）筛选最近一段时间 → 按天分组 → 天内按专辑聚合 → 展示专辑卡片”。Tune Tree 的左右分叉时间轴和悬停浮层属于 Web 自定义视觉，不应复制；在 Lain 里应使用按日期分组的 `AppleFormSection` 列表。

### 6.2 入口

主入口：

- 设置 → 听歌报告 → `StatsPage` → 在“热门专辑”之后新增“专辑时间轴”区块。
- 区块显示最近 3 张专辑的预览；点专辑行或“查看全部”进入 `AlbumTimelinePage`，卡片本身不做整块点击（避免与行点击冲突，也不需要额外的 InkWell 外观）。

次级入口：

- 设置 → 音乐源 → 本地音乐工具 → “专辑时间轴”（快捷入口）。

图标与标签：

| 位置 | 图标 | 标签 |
| --- | --- | --- |
| 统计页区块标题 | 无图标（与 `_sectionTitle` 一致） | 专辑时间轴 |
| 统计页卡片 | `Icons.timeline_rounded` | 最近新增 |
| 工具页 | `Icons.timeline_rounded` | 专辑时间轴 |

隐藏规则：

- 非本地音源：`StatsPage` 不构建“专辑时间轴”区块；工具页不存在；`AlbumTimelinePage` 无入口。
- 本地：即使没有任何带 `created` 时间的专辑，区块仍显示空状态“暂无添加时间数据”，不显示“查看全部”。

### 6.3 页面 / 弹窗结构

#### 6.3.1 `StatsPage` 内区块

```
_sectionTitle(l10n.albumTimeline)
_card(
  Column(
    ├─ 最近 3 张专辑行（CoverArtWidget 40x40 + 标题 + 日期 + 曲目数）
    ├─ Divider（MyDivider 0.5）
    └─ 右对齐 TextButton("查看全部")
  )
)
```

- 位置：放在 `popularAlbums` 之后，作为本地库的“最近新增”补充；不插入听歌统计的排名逻辑中。
- 数据：`artistAlbumManager.albumList` 中 `createdAt != null` 的专辑，按 `createdAt` 降序取前 3。
- 用 `ValueListenableBuilder` 监听 `artistAlbumManager.updateNotifier`，库刷新后自动更新。
- 空状态：`_empty(l10n)` 复用 StatsPage 的“无数据”样式。

#### 6.3.2 `AlbumTimelinePage`

```
opaqueSettingsPage(title: "专辑时间轴")
└─ Column
   ├─ AppleFormSection(divided: false)
   │   └─ appleSegmented<TimelineRange>(
   │        values: [month, quarter, all],
   │        labelOf: "一个月内" / "三个月内" / "全部",
   │        selected: range,
   │        onChanged: ...
   │      )
   └─ Expanded
       └─ ListView.builder（按日期分组）
           ├─ 日期头：Padding(20, 18, 20, 8) + Text("2026.11.15")
           │   右侧或同一行显示 "+12 首"（12px alpha 150）
           └─ AppleFormSection
               └─ 每张专辑一行 ListTile
                   ├─ leading: CoverArtWidget(size: 44, borderRadius: 6)
                   ├─ title: 专辑名（15px）
                   ├─ subtitle: 艺术家 · 年份（12px alpha 150）
                   ├─ trailing: "N 首"（12px alpha 180）
                   └─ onTap: goToAlbum(album.songList.first)
```

- 日期头不使用 `appleSectionTitle` 的 15px alpha 160？可以复用，但需要在右侧显示 `+N 首`。设计：日期头用与 `appleSectionTitle` 相同的 15px/alpha 160，外加一个 `+N` 文本；不新建样式体系。
- 时间轴不画竖线、节点、连线、左右分叉；这是明确的“不做自定义视觉”要求。
- 专辑行使用 `ListTile`，与设置页一致；不在行上加深色卡片或阴影。
- 加载：数据来自内存，无需 loading；若首次进入时 `artistAlbumManager.done == false`（库仍在分类），显示 `CircularProgressIndicator`，并监听 `updateNotifier` 重试。
- 空状态：当前范围无数据时，显示 `Center(Text("该时间段内没有新增专辑", 14px, alpha 150))`。
- 底部脚注：如果有 `createdAt == null` 的专辑，在列表末尾加一行 12px alpha 150 的说明“另有 N 张专辑缺少添加时间，未显示”。

### 6.4 样式与主题

- 页面外壳：`opaqueSettingsPage`。
- 分组：`AppleFormSection` + `appleSegmented`；日期头复用 StatsPage 的 `_sectionTitle` 字号/颜色约定。
- 卡片：不手写背景；`AppleFormSection` 自带 `textColor.withAlpha(20)`。
- 封面：`CoverArtWidget`。
- 行文字：标题 15px `textColor`；副标题 12px `withAlpha(150)`；数量 12px `withAlpha(180)`。
- 不使用 Tune Tree 的 `--accent` 圆点、深色浮层、左右分叉线。
- 文案无表情符号。

### 6.5 交互流程

1. 打开听歌报告，向下滚动到“专辑时间轴”区块；区块显示最近 3 张专辑。
2. 点“查看全部”或区块内的专辑行 → `AlbumTimelinePage`，默认范围“一个月内”。
3. 切换分段：
   - 一个月内：最近 30 天。
   - 三个月内：最近 91 天。
   - 全部：所有有 `createdAt` 的专辑，按日期降序。
4. 列表按日期分组，同一天内按 `createdAt` 降序，再按专辑名排序。
5. 点专辑行 → 复用 `goToAlbum(album.songList.first)` 打开现有专辑页；返回后仍停留在时间轴。
6. 库同步/编辑标签后，`artistAlbumManager.updateNotifier` 触发列表重建；滚动位置保持不变（用 `PageStorageKey` 或稳定 key）。
7. 不做下拉刷新；数据是内存聚合，刷新由库更新驱动。

### 6.6 数据与业务逻辑

#### 6.6.1 数据来源

- 专辑集合：`artistAlbumManager.albumList`（本地库加载后已分类）。
- 专辑添加时间：`Album.createdAt`，定义在 `lib/base/data/artist_album.dart`：

```dart
DateTime? get createdAt {
  DateTime? earliest;
  for (final song in songList) {
    final created = song.created;
    if (created != null && (earliest == null || created.isBefore(earliest))) {
      earliest = created;
    }
  }
  return earliest;
}
```

即“专辑中最早上传/创建的那首歌的时间”。

- `song.created` 的来源：
  - 本地扫描：`Folder.setFileAndModified` 调 `fileCreationTimes.resolve(paths)`；Android 通过平台通道取真实 birth time，其他平台用 `FileStat.changed`（Windows 为创建时间）。
  - `Library._restoreCreatedTimes` 在启动时从 `file_created.json` 恢复，未知的异步解析。注意：该异步解析完成时当前实现不会通知 UI，时间轴页可能先显示较少专辑后不再更新；本功能需要在解析回调里补一次 `library.changeNotifier.value++`，或给页面一个“创建时间已就绪”的通知。
- 不使用听歌统计 `stats.dart` 的播放数据；这是“库新增时间轴”，不是“收听时间轴”。

#### 6.6.2 聚合算法

```
range: month(30d) | quarter(91d) | all
cutoff = now - rangeDays
albums = albumList.where(createdAt != null && (all || createdAt >= cutoff))
groups = groupBy(localDate(createdAt))   // yyyy-MM-dd，本地时区
for each day desc:
  albumsInDay = albums where localDate == day, sorted by createdAt desc, then name
  songCount = sum(album.songList.length)
```

与 Tune Tree 的差异：

- Tune Tree 以“曲目”为单位，同一张专辑如果分两天入库，会在两天的分叉里各出现一部分。
- 本设计以“专辑”为单位，按 `createdAt`（最早歌曲）归入一天。理由：功能名是“专辑时间轴”，用户期望一张专辑只出现一次；同时避免同专辑重复。
- 因此“+N 首”表示当天新增专辑包含的曲目总数，而不是当天实际新增的曲目数。日期头文案建议“+N 首”，脚注说明“按专辑最早上传时间归档”。

#### 6.6.3 范围与日期

- 30 天 / 91 天按自然时间差计算，与 Tune Tree 一致（86400 秒/天）。
- 使用设备本地时区生成日期键，避免 UTC 跨日。
- “全部”可能包含很多专辑；按日期分组后 `ListView.builder` 懒构建。
- 未来时间的 `createdAt`（系统时间错误）归入“未来”组？设计：按日期降序自然排在最前，并在日期头标注；不特殊处理。

#### 6.6.4 与现有功能的关系

- 统计页 `StatsPage` 目前只展示听歌数据，且对全部音源开放。新增区块是本地库数据，必须单独门控；不要把它混进 `StatsData` 的年度聚合。
- `StatsPage._content` 的 `ListView` 是同步构建；新增区块的数据聚合要缓存，避免每次 `setState`（例如清空统计）都重新遍历全部专辑。
- `Album.createdAt` 依赖 `file_created.json`；重命名功能一必须迁移该文件，否则时间轴漂移（见 3.6.4 第 5 步）。
- 编辑标签会改变 `albumKeyOf` 和专辑分组；时间轴随 `updateArtistAlbum` 重建，符合预期。
- 歌单/收藏/统计不受影响（不按 id 聚合）。
- 大数据：`albumList` 可能上万；每次范围切换做一次 O(n) 过滤和分组，不要在每个 `build` 里做。

迁移与回滚：

- 只读功能，不写文件、不写数据库、无迁移；不需要回滚。
- 页面的范围选择只存在内存，离开页面即恢复默认“一个月内”。

#### 6.6.5 风险与性能

风险：

1. 缺少 `created`（Linux 某些文件系统没有 birth time）→ 专辑不显示；必须给出“缺少添加时间”的脚注，避免用户以为丢专辑。
2. 用户用 `cp -p`/同步工具带入旧创建时间 → 新加的专辑显示为很久以前；这是文件系统事实，界面文案应说明“按文件创建时间”。
3. 一张专辑的最早歌曲被删除后，`createdAt` 变成下一首的时间，专辑位置会移动；这是 `createdAt` 定义的结果，可接受。
4. 时区/夏令时：日期键用本地时间，跨时区旅行可能让某天移动；不额外处理。
5. 统计页在远程音源下必须完全不构建该区块；否则会把本地库数据混入在线报告，违反约束。
6. 大量封面加载：`CoverArtWidget` 自带懒加载调度，列表只构建可见行。
7. “全部”范围可能几千行；使用 `ListView.builder` + 分组扁平化，避免一次性 Column。

性能：

- 聚合一次 O(n)，结果缓存到页面 state；范围切换或 `updateNotifier` 变化时重算。
- 预览只取前 3 张，O(n) 一次或维护一个小顶堆；简单实现取前 3 也足够。
- 日期分组用 `Map<String, List<Album>>`，再排序日期键；稳定且无额外依赖。

### 6.7 验收点

1. 本地音源：听歌报告“热门专辑”之后出现“专辑时间轴”区块，显示最近 3 张专辑；点“查看全部”进入时间轴页。
2. Navidrome/Emby/飞牛/WebDAV：区块完全不存在，不是空状态或置灰；工具页入口也不存在。
3. 默认“一个月内”只显示 30 天内 `createdAt` 的专辑；切“三个月内”显示 91 天内；切“全部”显示所有有时间的专辑。
4. 同一张专辑只出现一次，归入其最早歌曲的日期。
5. 日期降序；同一天内按 `createdAt` 降序，再按名称排序。
6. 点专辑行打开现有专辑页，返回后滚动位置大致保持。
7. 没有 `createdAt` 的专辑不显示，列表末尾出现“另有 N 张专辑缺少添加时间”的说明。
8. 执行一次本地扫描新增一张专辑后，区块与时间轴页自动更新，无需重启。
9. 用功能一重命名歌曲后，专辑的日期不变（`file_created.json` 已迁移）。
10. 1000 张以上专辑切换范围不卡顿；列表只构建可见行。

---

## 7. 建议的文件划分（仅设计，不创建）

| 文件 | 作用 |
| --- | --- |
| `lib/base/data/library_naming.dart` | 命名模板模型、占位符、默认值、持久化通知器 |
| `lib/base/services/library_organizer.dart` | 预览算法、净名、根解析、执行、journal、撤销 |
| `lib/base/widgets/library_naming_page.dart` | 命名格式设置页 |
| `lib/base/widgets/library_organize_page.dart` | 整理预览/执行页 |
| `lib/base/widgets/local_library_tools_page.dart` | 本地音乐工具入口页 |
| `lib/base/services/metadata_scraper.dart` | provider 接口、关键词、评分、搜索回退、并发 |
| `lib/base/widgets/metadata_completion_page.dart` | 元数据补全列表页 |
| `lib/base/widgets/metadata_scrape_dialog.dart` | 单首搜索结果/应用弹窗 |
| `lib/base/widgets/metadata_batch_review_page.dart` | 批量搜索结果的逐首复核/应用页 |
| `lib/base/data/lrc_document.dart` | LRC 解析/序列化模型 |
| `lib/base/widgets/lyric_timeline_page.dart` | 歌词时间轴编辑页 |
| `lib/base/widgets/album_timeline_page.dart` | 专辑时间轴页 |
| `lib/base/services/metadata_write.dart` | 抽出 `EditMetadata` 的写后处理，供编辑与刮削共用 |

需要改动但不新建的现有文件：

- `lib/base/data/settings_category.dart`：不需要新增分类；如果决定把“本地音乐工具”做成一级分类，才需要加枚举（本设计不推荐，避免一级菜单膨胀）。
- `lib/base/widgets/settings_list.dart`：`musicSource` 分类增加本地限定条目。
- `lib/base/services/interaction.dart`：`showSongOptions` 增加本地限定项；`EditMetadata` 的调用条件若放宽也在这里。
- `lib/portrait_view/pages/song_list_page.dart`、`lib/landscape_view/panels/song_list_panel.dart`：`includeEdit` 条件、菜单项。
- `lib/base/widgets/selectable_song_list_page.dart`：顶部“操作”按钮与底部动作 sheet。
- `lib/base/widgets/song_list.dart`：当前列表 `moreSheet` 可选的“整理本列表”。
- `lib/base/widgets/edit_metadata.dart`：加“标签搜索”和“歌词时间轴”两个动作；写后逻辑抽成共享 helper；封面缓存改用 `invalidateCoverFile`。
- `lib/base/data/library.dart`：`updateMetadata` 补 `albumArtist`；新增 `applyRenames` 事务；`updateLyricsTimeOffset` 已有。
- `lib/base/data/folder.dart`：新增 id 替换/重写歌曲 id 列表的方法。
- `lib/base/data/playlist.dart`：新增 id 替换/重写 `_storedIds` 的方法。
- `lib/base/services/file_time.dart`：新增 `moveEntry(oldPath, newPath, millis)`。
- `lib/base/widgets/stats_page.dart`：新增本地限定区块。
- `lib/l10n/app_zh.arb`、`lib/l10n/app_en.arb`：新增文案键；运行 `flutter gen-l10n`。

### 7.1 新增文案键建议（中英同步）

| 键 | 中文 | 英文 |
| --- | --- | --- |
| `localLibraryTools` | 本地音乐工具 | Local Library Tools |
| `namingFormat` | 文件命名格式 | Naming Format |
| `directoryTemplate` | 目录模板 | Folder Template |
| `filenameTemplate` | 文件名模板 | File Name Template |
| `keepFeat` | 保留 feat. 信息 | Keep feat. Credit |
| `restoreDefaultFormat` | 恢复默认格式 | Restore Defaults |
| `organizeFiles` | 整理文件结构 | Organize Files |
| `organizeSelected` | 整理选中 | Organize Selected |
| `directoryPreview` | 目录预览 | Folder Preview |
| `changeList` | 变更列表 | Changes |
| `startOrganizing` | 开始整理 | Start Organizing |
| `organizeNormal` | 正常 | Normal |
| `organizeSkip` | 跳过 | Skip |
| `organizeConflict` | 冲突 | Conflict |
| `organizeBlocked` | 不允许 | Not Allowed |
| `undoOrganize` | 撤销本次整理 | Undo This Organize |
| `metadataCompletion` | 元数据补全 | Metadata Completion |
| `searchTags` | 搜索标签 | Search Tags |
| `overwriteTags` | 覆盖已有标签 | Overwrite Existing Tags |
| `writeCoverToo` | 同时写入封面 | Write Cover Too |
| `writeLyricsToo` | 同时写入歌词 | Write Lyrics Too |
| `nextBatch` | 换一批 | Next Batch |
| `applySelected` | 应用选中 | Apply Selected |
| `lyricTimeline` | 歌词时间轴 | Lyric Timeline |
| `stampTimestamp` | 打轴 | Stamp |
| `addSecondaryLine` | 添加附行 | Add Secondary Line |
| `addLineBelow` | 在下方添加行 | Add Line Below |
| `stripWordTimestamps` | 移除逐字轴 | Remove Word Timestamps |
| `bakeOffset` | 写入时间轴并归零 | Apply Offset and Reset |
| `albumTimeline` | 专辑时间轴 | Album Timeline |
| `lastMonth` | 一个月内 | Last Month |
| `lastQuarter` | 三个月内 | Last 3 Months |
| `allTime` | 全部 | All |
| `noAlbumsInRange` | 该时间段内没有新增专辑 | No albums added in this period |
| `albumsMissingCreated` | 另有 {count} 张专辑缺少添加时间 | {count} albums have no added time |

英文键只用于 `app_en.arb`；不要写死中文到代码里，也不要使用表情符号。

---

## 8. 实施顺序建议

1. 先做数据层修复与共享能力：
   - `library.updateMetadata` 补 `albumArtist`。
   - 抽出 `metadata_write.dart`，修正封面缓存失效逻辑。
   - `Folder`/`Playlist` 的 id 替换方法。
   - `file_time.dart` 的路径迁移方法。
2. 功能三（歌词时间轴）：入口在既有 `EditMetadata` 内，数据写入路径最短，可作为共享写回 helper 的第一个使用方。
3. 功能四（专辑时间轴）：只读，依赖 `createdAt`，风险最低；先验证 `file_created.json` 在本地库的完整性。
4. 功能二（元数据刮削）：在数据源确定后接入；先做单首，再做批量。
5. 功能一（命名/整理）：身份迁移面最大，放在最后，依赖前面已修好的 id 替换和写后刷新能力。

---

## 9. 待用户决策的问题

1. 元数据数据源（必须先定）
   - 方案 A：对齐 Tune Tree，使用网易云、QQ 音乐、酷狗的 Web API。优点：中文曲库匹配好、与参考实现一致；缺点：非官方接口、可能风控/失效、涉及服务条款。
   - 方案 B：使用 MusicBrainz + Cover Art Archive + LRCLIB 等公开接口。优点：接口稳定、条款清晰；缺点：中文/日文曲库覆盖和匹配质量弱于 A。
   - 方案 C：只做本地标签编辑，不联网刮削。与“刮削”需求不符，但最稳。
   - 方案 D：由用户自建/自填服务端接口，应用只做客户端。
   - 建议：如果以“复刻 Tune Tree 体验”为第一目标，选 A；如果以长期稳定和合规为第一目标，选 B 或 D。本文的评分/写回设计对 A/B/D 都适用。

2. 命名格式是否移动文件、是否跨根
   - 本文设计为“是，会移动文件”，并且只在歌曲当前所在的已配置根目录内移动，不跨根。
   - 备选：只重命名文件名，不创建/移动艺术家/专辑目录。若用户只想要“文件名格式”，应关闭目录模板或改成“仅文件名”模式。
   - 需确认：多音乐根目录是否允许跨根合并到第一个根。本文不建议。

3. 元数据编辑入口是否放宽
   - 现状：`EditMetadata` 只在“所有歌曲”列表、且本地时出现。
   - 本文建议：放宽到所有本地歌曲列表（艺术家/专辑/文件夹/歌单），否则“本地歌曲都能更新元数据”只能靠“元数据补全”页，单曲编辑体验割裂。
   - 需确认是否接受这个行为变化。

4. 专辑时间轴的时间语义
   - 本文定义为“专辑最早歌曲的文件创建时间”，不是听歌时间，也不是服务器 `created`。
   - 需确认用户是否接受“用同步工具带入旧创建时间的专辑会显示为很久以前”。

5. 歌词写回目标
   - 本文建议：内嵌标签始终写；同目录已有 `.lrc` 侧车时同步更新；不新建侧车。
   - 备选：始终新建/覆盖 `.lrc` 侧车，不改内嵌标签（更接近 Tune Tree 的“保存到歌曲目录”）。
   - 需确认。

6. iOS 外部文件夹
   - iOS 文件提供器/安全作用域路径的改名和写标签可能失败。本文建议标记 blocked，不做半成功。
   - 需确认是否接受“iOS 上部分外部文件夹不可整理/不可写标签”。

7. 撤销范围
   - 本文建议：整理提供单步撤销（页面生命周期内）+ journal 启动恢复；刮削提供单次应用撤销；歌词不提供自动撤销（靠取消/重置）。
   - 需确认是否要持久化多步历史（会增加状态文件和复杂度）。

8. 刮削默认覆盖策略
   - 本文建议默认“只填空字段”，用户显式打开“覆盖已有标签”才覆盖。
   - 需确认是否希望默认覆盖（更接近 Tune Tree 的“应用即写”）。

9. TTML 歌词的入口
   - 本文建议入口存在但页面显示“暂不支持”的说明；也可以选择入口不出现。
   - 需确认。
