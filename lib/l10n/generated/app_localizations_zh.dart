// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get lain => '临音';

  @override
  String get title => '标题';

  @override
  String get artist => '艺术家';

  @override
  String get album => '专辑';

  @override
  String get albumArtist => '专辑艺术家';

  @override
  String get genre => '流派';

  @override
  String get year => '年份';

  @override
  String get track => '音轨编号';

  @override
  String get disc => '碟号';

  @override
  String get lyrics => '歌词';

  @override
  String get folder => '文件夹';

  @override
  String get frequently => '最多播放';

  @override
  String get recently => '最近播放';

  @override
  String get artists => '艺术家';

  @override
  String get albums => '专辑';

  @override
  String get folders => '文件夹';

  @override
  String get songs => '所有歌曲';

  @override
  String get home => '主页';

  @override
  String get playlists => '歌单';

  @override
  String get language => '语言';

  @override
  String get playQueue => '播放列表';

  @override
  String get followSystem => '跟随系统';

  @override
  String get settings => '设置';

  @override
  String get settingsMusicSource => '音乐源';

  @override
  String get localMusicSource => '本地音乐源';

  @override
  String get longPressToConfigure => '长按进入配置';

  @override
  String get customFolders => '自定义文件夹';

  @override
  String get addCustomFolder => '添加自定义文件夹';

  @override
  String get startScan => '开始扫描';

  @override
  String get scanSubdirectories => '扫描子目录';

  @override
  String get blockedFolders => '被屏蔽的文件夹';

  @override
  String get addBlockedFolder => '添加屏蔽文件夹';

  @override
  String get noBlockedFolders => '没有被屏蔽的文件夹';

  @override
  String skipShortAudio(int seconds) {
    return '不扫描 $seconds 秒以下音频';
  }

  @override
  String get minimumAudioLength => '最短音频时长';

  @override
  String get manageStoragePermission => '管理外部存储权限';

  @override
  String get settingsUserInterface => '用户界面';

  @override
  String get settingsPlaybackLyrics => '播放和歌词';

  @override
  String get settingsNotifications => '通知';

  @override
  String get settingsStartupBackground => '启动和后台';

  @override
  String get settingsCacheDownloads => '缓存和下载';

  @override
  String get settingsHelpFeedback => '帮助和反馈';

  @override
  String get feedback => '反馈';

  @override
  String get customizeSettingsOrder => '自定义菜单顺序';

  @override
  String get offlineMode => '离线模式';

  @override
  String get offlineModeDescription => '只使用本地音乐，在线音源入口将被锁定';

  @override
  String get offlineModeBlocked => '离线模式已开启，在线音乐源已锁定';

  @override
  String get lanDirect => '局域网直连';

  @override
  String get lanDirectDescription => '局域网内直连服务器，不转码、不读缓存';

  @override
  String get reload => '重新加载';

  @override
  String get manageMusicFolder => '管理音乐文件夹';

  @override
  String get about => '关于';

  @override
  String get openSourceLicense => '开源许可证';

  @override
  String get privacyPolicy => '隐私政策';

  @override
  String get sleepTimer => '定时关闭';

  @override
  String get pauseAfterCurrentTrack => '播完整首歌再关闭';

  @override
  String get vibration => '振动';

  @override
  String get library => '音乐库';

  @override
  String get select => '批量选择';

  @override
  String get sortSongs => '歌曲排序';

  @override
  String get delete => '删除';

  @override
  String get remove => '移除';

  @override
  String get createPlaylist => '创建歌单';

  @override
  String get order => '顺序';

  @override
  String get reorder => '调整顺序';

  @override
  String songCount(int count) {
    return '$count 首';
  }

  @override
  String artistCount(int count) {
    return '$count 人';
  }

  @override
  String albumCount(int count) {
    return '$count 张';
  }

  @override
  String playlistCount(int count) {
    return '$count 个';
  }

  @override
  String folderCount(int count) {
    return '$count 个';
  }

  @override
  String settingCount(int count) {
    return '$count 项';
  }

  @override
  String fontCount(int count) {
    return '$count 种';
  }

  @override
  String get searchSongs => '搜索歌曲';

  @override
  String get searchArtists => '搜索艺术家';

  @override
  String get searchAlbums => '搜索专辑';

  @override
  String get searchPlaylists => '搜索歌单';

  @override
  String get searchLicenses => '搜索许可证';

  @override
  String get searchHome => '搜索专辑/歌曲/歌单';

  @override
  String get ascending => '升序';

  @override
  String get descending => '降序';

  @override
  String get pictureSize => '图片大小';

  @override
  String get large => '大';

  @override
  String get small => '小';

  @override
  String get view => '视图';

  @override
  String get list => '列表';

  @override
  String get grid => '网格';

  @override
  String get favorited => '喜欢';

  @override
  String get favorites => '我喜欢的';

  @override
  String get duration => '时长';

  @override
  String get times => '次数';

  @override
  String get loop => '列表循环';

  @override
  String get shuffle => '随机播放';

  @override
  String get repeat => '单曲循环';

  @override
  String get holdForRepeatOne => '长按：单曲循环';

  @override
  String get playAll => '播放全部';

  @override
  String get move2Top => '移至顶部';

  @override
  String get playNow => '现在播放';

  @override
  String get playNext => '下一首播放';

  @override
  String get add2Queue => '添加到播放列表';

  @override
  String get edit => '编辑';

  @override
  String get editMetadata => '编辑元数据';

  @override
  String get add2Playlist => '添加到歌单';

  @override
  String get added2Playlist => '已添加到歌单';

  @override
  String get selectAll => '全选';

  @override
  String get complete => '完成';

  @override
  String get continueMsg => '确认要继续吗?';

  @override
  String get cancel => '取消';

  @override
  String get confirm => '确认';

  @override
  String get addFolder => '添加文件夹';

  @override
  String get addRecursiveFolder => '添加文件夹及所有子文件夹';

  @override
  String get replacePicture => '替换图片';

  @override
  String get unknown => '未知';

  @override
  String get updateMedata => '更新元数据';

  @override
  String get defaultText => '默认';

  @override
  String get titleAscending => '标题升序';

  @override
  String get titleDescending => '标题降序';

  @override
  String get artistAscending => '艺术家升序';

  @override
  String get artistDescending => '艺术家降序';

  @override
  String get albumAscending => '专辑升序';

  @override
  String get albumDescending => '专辑降序';

  @override
  String get durationAscending => '时长升序';

  @override
  String get durationDescending => '时长降序';

  @override
  String get selectSortingType => '选择排序类型';

  @override
  String get loadingFolder => '正在加载的文件夹';

  @override
  String get loadedSongs => '已加载歌曲';

  @override
  String get loadingNavidrome => '正在加载Navidrome';

  @override
  String get canNotUpdate => '无法修改正在播放的歌曲';

  @override
  String get updateSuccessfully => '更新成功';

  @override
  String get updateFailed => '更新失败';

  @override
  String get clear => '清空';

  @override
  String get reset => '重置';

  @override
  String get desktopLyrics => '桌面歌词';

  @override
  String get horizontal => '水平';

  @override
  String get vertical => '竖直';

  @override
  String get lock => '锁定';

  @override
  String get unlock => '解锁';

  @override
  String get closeAction => '关闭动作';

  @override
  String get exit => '退出';

  @override
  String get hide => '隐藏';

  @override
  String get checkUpdate => '检查更新';

  @override
  String get go2Download => '前往下载';

  @override
  String get alreadyLatest => '已经是最新版本';

  @override
  String get theme => '主题';

  @override
  String get mainPageTheme => '主页面主题';

  @override
  String get lyricsPageTheme => '歌词页面主题';

  @override
  String get vividMode => '生动模式';

  @override
  String get lightMode => '浅色模式';

  @override
  String get darkMode => '深色模式';

  @override
  String get customMode => '自定义模式';

  @override
  String get local => '本地';

  @override
  String get switchSource => '切换音乐来源';

  @override
  String get manageServers => '管理服务器';

  @override
  String get username => '账号';

  @override
  String get password => '密码';

  @override
  String get exportLog => '导出日志';

  @override
  String get showApp => '显示应用';

  @override
  String get skip2Previous => '上一首';

  @override
  String get skip2Next => '下一首';

  @override
  String get playOrPause => '播放/暂停';

  @override
  String get unlockDeskLrc => '解锁桌面歌词';

  @override
  String get autoPlayOnStartup => '启动后自动播放';

  @override
  String get return2Previous => '返回上一级';

  @override
  String get addedFolders => '已添加的目录';

  @override
  String get recursiveScan => '扫描子目录';

  @override
  String get songInfo => '歌曲信息';

  @override
  String get cached => '已缓存';

  @override
  String get format => '格式';

  @override
  String get bitrate => '比特率';

  @override
  String get samplerate => '采样率';

  @override
  String get filePath => '文件路径';

  @override
  String get path => '路径';

  @override
  String get go2Artist => '查看艺术家';

  @override
  String get go2Album => '查看专辑';

  @override
  String get equalizer => '均衡器';

  @override
  String get more => '更多';

  @override
  String get randomize => '随机';

  @override
  String get normal => '正常';

  @override
  String get modifiedTimeAscending => '修改时间升序';

  @override
  String get modifiedTimedescending => '修改时间降序';

  @override
  String get addedTimeAscending => '添加时间升序';

  @override
  String get streamQuality => '在线音质';

  @override
  String get streamQualityStandard => '标准品质（最高 128kbps）';

  @override
  String get streamQualityHigh => '高品质（最高 192kbps）';

  @override
  String get streamQualityHq => 'HQ 高品质（256kbps）';

  @override
  String get streamQualitySq => 'SQ 品质（320kbps）';

  @override
  String get streamQualityOriginal => '原品质（不转换）';

  @override
  String get streamFormat => '转码格式';

  @override
  String get mobileDataWarning => '移动流量提醒';

  @override
  String get mobileDataNotice => '正在使用移动流量播放在线音乐';

  @override
  String get serverScheme => '协议';

  @override
  String get serverHost => '主机';

  @override
  String get serverPort => '端口';

  @override
  String get serverPath => '路径';

  @override
  String get noData => '无数据';

  @override
  String get popularSongs => '热门歌曲';

  @override
  String get popularAlbums => '热门专辑';

  @override
  String get timesUnit => '次';

  @override
  String get rename => '重命名';

  @override
  String get exportPlaylist => '导出歌单';

  @override
  String get exported => '已导出到';

  @override
  String get exportFailed => '导出失败';

  @override
  String get download => '下载';

  @override
  String get downloads => '下载记录';

  @override
  String get downloadWaitingForWifi => '已加入下载队列，连接 Wi-Fi 后自动开始';

  @override
  String downloadResumedOnWifi(int count) {
    return '已连接 Wi-Fi，继续下载 $count 个任务';
  }

  @override
  String get downloadOnMobileData => '移动网络下载';

  @override
  String get downloadQuality => '下载码率';

  @override
  String get downloadTasks => '下载任务';

  @override
  String get downloadStateWaitingWifi => '等待 Wi-Fi';

  @override
  String get downloadStateDownloading => '下载中';

  @override
  String get downloadStatePaused => '已暂停';

  @override
  String get downloadStateFailed => '失败';

  @override
  String get continueDownload => '继续下载';

  @override
  String get pauseDownload => '暂停下载';

  @override
  String get deleteAllDownloads => '全部删除';

  @override
  String get downloading => '正在下载…';

  @override
  String get downloaded => '已下载';

  @override
  String get downloadAdded => '已添加到下载列表';

  @override
  String get allCached => '已全部缓存';

  @override
  String get downloadFailed => '下载失败';

  @override
  String get playFailed => '播放失败';

  @override
  String get noDownloads => '还没有下载记录';

  @override
  String get importPlaylist => '导入歌单';

  @override
  String get enterPath => '手动输入路径';

  @override
  String get importedSongs => '已导入歌曲数：';

  @override
  String get noMatchingSongs => '文件里没有匹配到曲库中的歌曲';

  @override
  String get fileNotFound => '找不到该文件';

  @override
  String get mostPlayed => '播放次数倒序';

  @override
  String get cacheLists => '列表缓存';

  @override
  String get viewCache => '查看缓存';

  @override
  String get cacheTagAudio => '歌曲';

  @override
  String get cacheTagCover => '封面';

  @override
  String get cacheTagLyric => '歌词';

  @override
  String get precacheAll => '缓存全部歌曲信息';

  @override
  String get cacheTaskTitle => '缓存歌曲';

  @override
  String get cacheBackground => '后台运行';

  @override
  String get cacheMovedToBackground => '已转入后台继续缓存';

  @override
  String get cacheTaskDone => '缓存完成';

  @override
  String get cacheTaskCanceled => '已取消缓存';

  @override
  String get cacheTaskBusy => '已有缓存任务在进行';

  @override
  String get cacheTaskQueued => '已加入缓存队列';

  @override
  String cacheFailedCount(int count) {
    return '$count 首失败';
  }

  @override
  String get cacheBackPrompt => '缓存仍在进行，要取消还是放到后台？';

  @override
  String get cacheKeepRunning => '继续等待';

  @override
  String get added2Next => '已添加到下一首播放';

  @override
  String get homeLayout => '主页设置';

  @override
  String get homeTopButtons => '最顶部的按钮';

  @override
  String get homeSections => '主页内容';

  @override
  String get ignoreCert => '忽略证书校验';

  @override
  String get recentlyAdded => '最近添加';

  @override
  String get connectSuccess => '连接成功';

  @override
  String get connectionFailed => '连接失败';

  @override
  String get trackAscending => '音轨号升序';

  @override
  String get trackDescending => '音轨号降序';

  @override
  String get servers => '服务器';

  @override
  String get addServer => '添加服务器';

  @override
  String get serverName => '名称';

  @override
  String get serverType => '类型';

  @override
  String get publicAddress => '公网地址';

  @override
  String get lanAddress => '局域网地址';

  @override
  String get testAndSave => '测试并保存';

  @override
  String get recheck => '重新检测';

  @override
  String get unreachable => '不可用';

  @override
  String get inUse => '使用中';

  @override
  String get localMusic => '本地音乐';

  @override
  String get serverAddress => '服务器地址';

  @override
  String get cacheDetails => '缓存详情';

  @override
  String get cacheSongs => '已缓存歌曲';

  @override
  String get cacheTasks => '缓存任务';

  @override
  String get cacheWaiting => '等待缓存';

  @override
  String get noCacheTasks => '暂无缓存任务';

  @override
  String get cacheGroup => '歌单与艺术家缓存';

  @override
  String get autoCacheSongs => '自动缓存歌曲';

  @override
  String get autoCachePlaylists => '自动缓存歌单';

  @override
  String get autoCacheArtists => '自动缓存艺术家';

  @override
  String get cacheDirectory => '缓存目录';

  @override
  String get downloadDirectory => '下载目录';

  @override
  String get cacheLimit => '缓存上限';

  @override
  String get cacheLimitUnlimited => '不限制';

  @override
  String cacheLimitGb(int gb) {
    return '$gb GB';
  }

  @override
  String get moveCacheToNewDirectory => '把已有缓存移动到新目录吗？';

  @override
  String get moveDownloadsToNewDirectory => '把已下载的歌曲移动到新目录吗？';

  @override
  String get cacheDirectoryChanged => '缓存目录已更新';

  @override
  String get storagePermissionDenied => '需要存储权限才能使用这个目录';

  @override
  String get downloadDirectoryChanged => '下载目录已更新';

  @override
  String get cacheCovers => '封面';

  @override
  String get cacheLyrics => '歌词';

  @override
  String get cacheTotal => '合计';

  @override
  String get cacheEmpty => '暂无缓存';

  @override
  String get removeCache => '删除缓存';

  @override
  String get listeningReport => '听歌报告';

  @override
  String get yearlyActivity => '年度热力图';

  @override
  String get playRanking => '播放排行';

  @override
  String get yearlyStats => '年度统计';

  @override
  String get topArtists => '热门艺术家';

  @override
  String get listeningTime => '听歌时长';

  @override
  String get playTimes => '听歌次数';

  @override
  String get listeningDays => '听歌天数';

  @override
  String get songsTotal => '歌曲数';

  @override
  String get albumsTotal => '专辑数';

  @override
  String get heatLess => '少';

  @override
  String get heatMore => '多';

  @override
  String get allSources => '全部音源';

  @override
  String get addedTimeDescending => '添加时间降序';

  @override
  String get cannotBeUndone => '不可撤销';

  @override
  String get clearCache => '清除缓存';

  @override
  String get clearCacheConfirm => '清空全部缓存歌曲？';

  @override
  String get clearCacheConfirmAgain => '再次确认：清空后无法恢复';

  @override
  String get tapAgain => '再按一次退出';

  @override
  String get close => '关闭';

  @override
  String get fonts => '字体';

  @override
  String get searchFonts => '搜索字体';

  @override
  String get setFontName => '设置字体名称';

  @override
  String get setFont => '设置字体';

  @override
  String get restoreDefault => '恢复默认';

  @override
  String get addFont => '添加字体';

  @override
  String get deleteFont => '删除字体';

  @override
  String get currentFont => '当前字体';

  @override
  String get refresh => '刷新';

  @override
  String get syncLibrary => '同步资料库';

  @override
  String get syncingTryLater => '正在同步，请稍后再试';

  @override
  String get syncDone => '资料库同步完成';

  @override
  String get syncFailed => '同步失败';

  @override
  String get all => '全部';

  @override
  String get folderExist => '该文件夹已存在';

  @override
  String get folderNotSupportedYet => '暂不支持该文件夹';

  @override
  String get getPermissionFailed => '获取权限失败';

  @override
  String get premiumFeatures => '高级功能';

  @override
  String get premiumDescription => '获得更完整的使用体验并支持应用持续开发';

  @override
  String get unlockPremium => '解锁高级功能';

  @override
  String get restorePurchase => '恢复购买';

  @override
  String get whatPremiumContains => '高级功能包含';

  @override
  String get themeDescription => '支持开启主页面生动模式';

  @override
  String get fontDescription => '可使用自定义字体';

  @override
  String get equalizerDescription => '可调节不同频段的音量';

  @override
  String get widgets => '桌面小组件';

  @override
  String get widgetsDescription => '在主屏幕展示正在播放与你的歌单';

  @override
  String get futurePremium => '未来高级功能';

  @override
  String get futurePremiumDescription => '后续新增的高级功能自动解锁';

  @override
  String get premiumRequiredMessage => '当前功能需要解锁高级功能后才能使用';

  @override
  String get premiumUnlockHint => '请前往「设置 > 高级功能」进行解锁';

  @override
  String get alreadyPremium => '已解锁高级功能';

  @override
  String get pendingPurchase => '正在处理中...';

  @override
  String get purchaseNotFound => '未发现购买记录';

  @override
  String get productNotAvailable => '无法获取商品信息，请检查网络连接后重试';

  @override
  String get iapNotAvailable => '应用内购买功能暂不可用, 请稍后再试';

  @override
  String get connectingToAppStore => '正在连接 App Store...';

  @override
  String get checkingPurchase => '正在检查购买记录...';

  @override
  String get noLyrics => '暂无歌词';

  @override
  String get lyricsParseFailed => '歌词解析失败';

  @override
  String get switchMode => '切换模式';

  @override
  String get viewLog => '查看日志';

  @override
  String get premiumTrialActive => '高级功能试用已开启';

  @override
  String trialRemainingStatus(int count) {
    return '剩余试用时间：$count 分钟\n试用结束后, 购买高级功能即可继续使用';
  }

  @override
  String get gotIt => '好的';

  @override
  String get trialRemaining => '剩余试用时间';

  @override
  String get bigPictureMode => '大图模式';

  @override
  String get bigPictureModeDescription => '解锁大图模式';

  @override
  String get adjustLyrics => '调整歌词';

  @override
  String get drivingMode => '驾驶模式';

  @override
  String get fontSize => '字体大小';

  @override
  String get fontWeight => '字体粗细';

  @override
  String get offset => '偏移';

  @override
  String get getStart => '开始使用';

  @override
  String get immersiveWideLayout => '宽布局启用沉浸模式';

  @override
  String get wideShowTopSystemBar => '宽布局显示顶部系统条';

  @override
  String get wideShowBottomSystemBar => '宽布局显示底部系统条';

  @override
  String get menuOnRight => '从右侧弹出菜单';

  @override
  String get save => '保存';

  @override
  String get chooseMusicSource => '选择音乐来源';

  @override
  String get feiniuMusic => '飞牛音乐';

  @override
  String get feiniuConnectionFailed => '无法连接飞牛音乐，请检查服务器地址及音乐应用账号密码';

  @override
  String get savedSuccessfully => '保存成功';

  @override
  String get controlCenterLyrics => '控制中心歌词';

  @override
  String get coverBroadcast => '封面广播方式';

  @override
  String get songQualityBadge => '歌曲品质';

  @override
  String get coverBroadcastBitmap => '仅位图';

  @override
  String get coverBroadcastServer => '服务器封面地址';

  @override
  String get coverBroadcastRelay => '本机中继地址';

  @override
  String get coverBroadcastContent => '内容提供器 URI';

  @override
  String get coverBroadcastAuto => '自动';

  @override
  String get coverBroadcastRelayOriginal => '本机中继（原图）';

  @override
  String get relayAddress => '中继地址';

  @override
  String get relayAddressAuto => '自动';

  @override
  String get broadcastLyrics => '广播歌词';

  @override
  String get connect => '连接';

  @override
  String get notConnected => '未连接';

  @override
  String get sortType => '排序方式';

  @override
  String get sortByName => '名称';

  @override
  String get sortByAddedTime => '添加时间';

  @override
  String get sortByPlayCount => '播放次数';

  @override
  String get sortBySize => '文件大小';

  @override
  String get sortByYear => '年份';

  @override
  String get sortByAlbumCount => '专辑数量';

  @override
  String get sortBySongCount => '歌曲数量';

  @override
  String get sortByFavorite => '喜爱';

  @override
  String get randomSort => '随机';

  @override
  String get favoriteFailed => '无法更新收藏';

  @override
  String get totalDuration => '总时长';

  @override
  String get albumInfo => '专辑信息';

  @override
  String get artistInfo => '艺术家信息';

  @override
  String get biography => '艺术家简介';

  @override
  String get description => '简介';

  @override
  String get songUnit => '歌曲';

  @override
  String get contributingArtists => '参与创作的艺术家';

  @override
  String get noResults => '没有找到结果';

  @override
  String get clearArtistsCache => '清空艺术家缓存';

  @override
  String get artistCacheRefreshed => '艺术家缓存已刷新';

  @override
  String get artistCacheNoImage => '已刷新，服务器暂无艺术家头像（使用专辑封面）';

  @override
  String get addedTime => '添加时间';

  @override
  String get modifiedTime => '修改时间';

  @override
  String get playCountLabel => '播放次数';

  @override
  String get clearSuccess => '清除成功';

  @override
  String get addToFavorites => '添加到我喜欢的';

  @override
  String get removeFromFavorites => '取消喜欢';

  @override
  String get playbackMode => '播放模式';

  @override
  String get playbackModeExclusive => '独占播放';

  @override
  String get playbackModeDuck => '智能避让';

  @override
  String get playbackModeMix => '混合播放';

  @override
  String get playbackModeExclusiveDesc =>
      '临音独占音频输出；其他应用播放时临音自动暂停，其他应用结束后不会自动继续播放。';

  @override
  String get playbackModeDuckDesc => '其他应用播放音频时，自动降低临音的音量；其他应用结束后恢复原音量。';

  @override
  String get playbackModeMixDesc => '临音与其他应用的音频混合输出。';

  @override
  String get playbackModeNotice => '注意事项';

  @override
  String get playbackModeScenarios => '使用场景';

  @override
  String get playbackModeNoticeInCar => '车载模式下推荐使用「智能避让」模式。';

  @override
  String get playbackModeNoticeNavigation => '导航语音播报时自动降低音乐音量。';

  @override
  String get playbackModeNoticeDesktop => '桌面版默认使用混合播放。';

  @override
  String get scenarioDailyListening => '日常听歌';

  @override
  String get scenarioDailyListeningMode => '独占播放';

  @override
  String get scenarioNavigation => '开车导航';

  @override
  String get scenarioNavigationMode => '智能避让';

  @override
  String get scenarioGaming => '游戏背景音乐';

  @override
  String get scenarioGamingMode => '混合播放';

  @override
  String get scenarioArrow => '→';

  @override
  String get playbackModeDesktopNote => '桌面端不支持独占播放，选择将按混合播放处理。';

  @override
  String get comment => '评论';

  @override
  String get comments => '评论';

  @override
  String get commentSettings => '评论设置';

  @override
  String get commentSwitch => '评论展示';

  @override
  String get commentSwitchDesc => '配置评论服务器后，在播放栏显示评论入口。';

  @override
  String get commentServer => '评论服务器';

  @override
  String get commentServers => '评论服务器';

  @override
  String get addCommentServer => '添加评论服务器';

  @override
  String get commentServerName => '服务器名称';

  @override
  String get protocol => '协议';

  @override
  String get commentTokenHint => '服务器设置了账号或密码时填写，可留空';

  @override
  String get commentNoServer => '尚未配置评论服务器';

  @override
  String get commentNoServerHint => '在设置中添加一个评论服务器后即可查看评论';

  @override
  String get commentEmpty => '暂无评论';

  @override
  String get commentLoadFailed => '评论加载失败';

  @override
  String get commentRetry => '重试';

  @override
  String get commentReplies => '条回复';

  @override
  String commentShowReplies(int count) {
    return '查看 $count 条回复';
  }

  @override
  String get commentHideReplies => '收起回复';

  @override
  String get commentPagePrevious => '上一页';

  @override
  String get commentPageNext => '下一页';

  @override
  String commentPageIndicator(int page) {
    return '第 $page 页';
  }

  @override
  String get commentUnreachable => '无法连接到评论服务器，请检查地址或网络';

  @override
  String get commentForbidden => '服务器拒绝访问，请检查账号和密码';

  @override
  String get commentServerError => '服务器返回了异常内容';

  @override
  String commentServerSwitched(String name) {
    return '已切换到 $name';
  }

  @override
  String get commentAtLeastOneAddress => '局域网与公网地址至少填写一个';

  @override
  String get settingsComments => '评论';

  @override
  String get commentOn => '已开启';

  @override
  String get commentOff => '已关闭';

  @override
  String commentOnWithServer(String server) {
    return '已开启 · $server';
  }

  @override
  String get commentSortRecommended => '推荐';

  @override
  String get commentSortHot => '最热';

  @override
  String get commentSortTime => '最新';

  @override
  String commentMatchedSong(String name) {
    return '来自「$name」的评论';
  }

  @override
  String get commentChangeSong => '换一首';

  @override
  String get commentMismatchTitle => '这些评论对应的不是当前歌曲';

  @override
  String commentMismatchDetail(String name) {
    return '服务器把这首歌匹配成了「$name」，看起来对不上号。请选择正确的歌曲后再查看评论。';
  }

  @override
  String get commentPickSong => '选择歌曲';

  @override
  String get commentSearchTitle => '搜索歌曲';

  @override
  String get commentSearchHint => '歌名 / 歌手';

  @override
  String get commentSearchEmpty => '没有找到相关歌曲';

  @override
  String get commentSongNotFound => '服务器上没有找到这首歌';

  @override
  String commentTotalCount(int count) {
    return '共 $count 条评论';
  }

  @override
  String commentPageOf(int page, int pageCount) {
    return '第 $page / $pageCount 页';
  }

  @override
  String get commentShowMoreReplies => '查看更多回复';

  @override
  String get statsCard => '统计';

  @override
  String get serverStatus => '服务器状态';

  @override
  String get serverInfo => '服务器信息';

  @override
  String get mediaStats => '媒体统计';

  @override
  String get statsSongs => '歌曲';

  @override
  String get totalSize => '总大小';

  @override
  String get serverVersion => '服务端版本';

  @override
  String get subsonicApiVersion => 'Subsonic API';

  @override
  String get openSubsonic => 'Open Subsonic';

  @override
  String get supported => '支持';

  @override
  String get notSupported => '不支持';

  @override
  String get status => '状态';

  @override
  String latencyMs(int ms) {
    return '延迟 $ms ms';
  }

  @override
  String latencyValue(int ms) {
    return '$ms ms';
  }

  @override
  String get customDomain => '自定义域名';

  @override
  String get showAddress => '显示完整地址';

  @override
  String get hideAddress => '隐藏地址';

  @override
  String get speedFirst => '速度优先';

  @override
  String get speedFirstDescription => '开启后自动选择延迟最低的可用链路，关闭后按手动优先级选择';

  @override
  String get scanStatus => '扫描状态';

  @override
  String get lastScanTime => '最后扫描时间';

  @override
  String get scanning => '扫描中';

  @override
  String get scanCompleted => '已完成';

  @override
  String get activeStreams => '正在播放';

  @override
  String get transcoding => '转码';

  @override
  String get serverOs => '运行系统';

  @override
  String get systemUpdate => '系统更新';

  @override
  String get updateAvailable => '有可用更新';

  @override
  String get upToDate => '已是最新';

  @override
  String get hoursUnit => '小时';

  @override
  String get daysUnit => '天';

  @override
  String librarySizeGB(String size) {
    return '$size GB';
  }

  @override
  String libraryDurationHours(String hours, String unit) {
    return '$hours $unit';
  }

  @override
  String get localLibraryTools => '本地音乐工具';

  @override
  String get localLibraryToolsHint => '命名、整理、补全标签';

  @override
  String get organizeSection => '整理';

  @override
  String get browseSection => '浏览';

  @override
  String get namingFormat => '文件命名格式';

  @override
  String get directorySection => '目录';

  @override
  String get filenameSection => '文件名';

  @override
  String get previewSection => '预览';

  @override
  String get directoryTemplate => '目录模板';

  @override
  String get filenameTemplate => '文件名模板';

  @override
  String get keepFeat => '保留 feat. 信息';

  @override
  String namingPlaceholders(String placeholders) {
    return '可用占位符：$placeholders';
  }

  @override
  String get namingSlashHelp =>
      '模板中的 / 表示目录层级；标签值里的 / 会被替换为下划线。文件名模板必须包含标题占位符。';

  @override
  String get templateEmpty => '模板不能为空';

  @override
  String get templateNeedsTitle => '文件名模板必须包含标题占位符';

  @override
  String get templateAbsolute => '不能使用绝对路径';

  @override
  String get templateParentSegment => '不能包含 .. 路径段';

  @override
  String get templateUnknownPlaceholder => '模板包含未知占位符';

  @override
  String get invalidTemplate => '模板无效';

  @override
  String get restoreDefaultFormat => '恢复默认格式';

  @override
  String get exampleSong => '示例歌曲';

  @override
  String get currentPath => '当前';

  @override
  String get organizedPath => '整理后';

  @override
  String get organizeFiles => '整理文件结构';

  @override
  String get organizeFilesHint => '预览后移动文件';

  @override
  String get organizeFile => '整理文件';

  @override
  String get organizeSelected => '整理选中';

  @override
  String get startOrganizing => '开始整理';

  @override
  String get overview => '概览';

  @override
  String get directoryPreview => '目录预览';

  @override
  String get changeList => '变更列表';

  @override
  String get organizeNormal => '正常';

  @override
  String get organizeSkip => '跳过';

  @override
  String get organizeConflict => '冲突';

  @override
  String get organizeBlocked => '不允许';

  @override
  String get organizeReasonUnchanged => '无需改动';

  @override
  String get organizeReasonTargetExists => '目标已存在';

  @override
  String get organizeReasonMissingFile => '文件不存在';

  @override
  String get organizeReasonMissingPath => '缺少路径';

  @override
  String get organizeReasonOutsideLibrary => '不在已配置目录内';

  @override
  String get organizeReasonFileProvider => '文件提供器路径暂不支持移动';

  @override
  String get organizeReasonPathTooLong => '路径过长';

  @override
  String get organizeReasonTargetIsFolder => '目标是目录';

  @override
  String get organizeReasonInvalidTemplate => '命名模板无效';

  @override
  String organizeResultMessage(int moved, int skipped, int failed) {
    return '已整理 $moved 个文件，跳过 $skipped 个，失败 $failed 个';
  }

  @override
  String organizeStopped(int moved) {
    return '已停止，处理了 $moved 个文件';
  }

  @override
  String get organizing => '正在整理';

  @override
  String get undoOrganize => '撤销本次整理';

  @override
  String get undoSuccessfully => '已撤销';

  @override
  String get undoFailed => '无法撤销';

  @override
  String get metadataCompletion => '元数据补全';

  @override
  String songsMissingTags(int count) {
    return '$count 首歌曲缺少标签';
  }

  @override
  String get batchSearchSelected => '批量搜索选中';

  @override
  String get batchSearchTags => '批量搜索标签';

  @override
  String batchSearching(int done, int total) {
    return '正在搜索 $done / $total';
  }

  @override
  String get filterMissingTags => '仅缺标签';

  @override
  String get filterMissingTagsOrCover => '缺标签或封面';

  @override
  String get filterAllIncomplete => '全部不完整';

  @override
  String get allMetadataComplete => '全部歌曲元数据完整';

  @override
  String selectedCount(int count) {
    return '已选 $count 首';
  }

  @override
  String get missingTitle => '缺歌名';

  @override
  String get missingArtist => '缺艺术家';

  @override
  String get missingAlbum => '缺专辑';

  @override
  String get missingCover => '缺封面';

  @override
  String get missingLyrics => '缺歌词';

  @override
  String get searchTags => '搜索标签';

  @override
  String get search => '搜索';

  @override
  String get scrapeFillEmpty => '只填空字段';

  @override
  String get overwriteTags => '覆盖已有标签';

  @override
  String get writeCoverToo => '同时写入封面';

  @override
  String get writeLyricsToo => '同时写入歌词';

  @override
  String get nextBatch => '换一批';

  @override
  String get noMoreResults => '该来源没有更多结果';

  @override
  String get noSearchResults => '没有找到结果';

  @override
  String get coverSkipped => '封面格式不支持，已跳过';

  @override
  String get matchScore => '匹配';

  @override
  String get changes => '变更';

  @override
  String get apply => '应用';

  @override
  String get applySelected => '应用选中';

  @override
  String get batchReview => '批量结果';

  @override
  String batchApplied(int count) {
    return '已应用 $count 首';
  }

  @override
  String get nextCandidate => '换一个';

  @override
  String get syncingWait => '正在同步，稍后再试';

  @override
  String get lyricTimeline => '编辑歌词';

  @override
  String get lyricTimelineHint => '逐行调整 LRC 时间戳';

  @override
  String get progress => '进度';

  @override
  String get stamp => '打轴';

  @override
  String get playbackOffset => '播放偏移';

  @override
  String get bakeOffset => '写入时间轴并归零';

  @override
  String get wordTimestamps => '逐字时间戳';

  @override
  String get stripWordTimestamps => '移除逐字轴';

  @override
  String get ttmlNotEditable => '此歌词为 TTML，暂不支持逐行时间轴编辑';

  @override
  String get noLyricLines => '暂无歌词行';

  @override
  String get addLine => '添加一行';

  @override
  String get addSecondaryLine => '添加附行';

  @override
  String get addLineBelow => '在下方添加行';

  @override
  String get discardChanges => '放弃修改';

  @override
  String get invalidTimeFormat => '时间格式无效';

  @override
  String get saveSuccessfully => '保存成功';

  @override
  String get saveFailed => '保存失败';

  @override
  String get sidecarUpdateFailed => '标签已保存，侧车更新失败';

  @override
  String get editLyricTimeline => '编辑歌词';

  @override
  String get albumTimeline => '专辑时间轴';

  @override
  String get albumTimelineHint => '按添加时间浏览专辑';

  @override
  String get lastMonth => '一个月内';

  @override
  String get lastQuarter => '三个月内';

  @override
  String get allTime => '全部';

  @override
  String get noAlbumsInRange => '该时间段内没有新增专辑';

  @override
  String albumsMissingCreated(int count) {
    return '另有 $count 张专辑缺少添加时间';
  }

  @override
  String albumTimelineAddedCount(int count) {
    return '+$count 首';
  }

  @override
  String albumTimelineSongCount(int count) {
    return '$count 首';
  }

  @override
  String get viewAll => '查看全部';

  @override
  String get stop => '停止';

  @override
  String get retry => '重试';

  @override
  String get actions => '操作';

  @override
  String get organizeFolder => '整理文件夹';

  @override
  String get organizeDone => '已整理';

  @override
  String get organizeComplete => '完成';

  @override
  String get organizePending => '未处理';

  @override
  String get undoApply => '撤销本次应用';

  @override
  String get previousCard => '上一张';

  @override
  String get nextCard => '下一张';

  @override
  String get scrapeLongPressHint => '长按卡片可直接应用';

  @override
  String get organizeFailed => '失败';

  @override
  String get applyCurrent => '应用当前';

  @override
  String get applyAllBest => '应用全部最佳';

  @override
  String songPosition(int index, int total) {
    return '第 $index / $total 首';
  }

  @override
  String get jumpToSong => '选择歌曲';

  @override
  String get previousSong => '上一首';

  @override
  String get nextSong => '下一首';

  @override
  String resultsCount(int count) {
    return '$count 个结果';
  }

  @override
  String get searchLyrics => '搜索歌词';

  @override
  String get restoreLyrics => '还原歌词';

  @override
  String get lyricsPreview => '歌词预览';

  @override
  String get copyText => '复制文本';

  @override
  String get fileName => '文件名';

  @override
  String get copied => '已复制';

  @override
  String get replayGain => '音量归一化';

  @override
  String get replayGainOff => '关闭（原始音量）';

  @override
  String get replayGainTrack => '按单曲';

  @override
  String get replayGainAlbum => '按专辑';

  @override
  String get replayGainDescription => '读取文件中的响度标签，避免不同专辑的歌曲忽大忽小。';

  @override
  String get playbackSpeed => '播放速度';

  @override
  String get audioFade => '淡入淡出';

  @override
  String get audioFadeDescription => '开始播放时音量渐入，暂停或切歌时音量渐出。';

  @override
  String get queueCleared => '播放队列已清空';

  @override
  String get undo => '撤销';

  @override
  String get scanNow => '立即扫描曲库';

  @override
  String get scanNowConfirm => '现在让服务器扫描音乐文件夹？';

  @override
  String get scanStarted => '已开始扫描';

  @override
  String get operationFailed => '操作失败';

  @override
  String get autoScanLibrary => '自动扫描曲库';

  @override
  String get autoScanDescription => '启动后和定时检查文件夹，只重新读取有改动的文件。';

  @override
  String get scanInterval => '扫描间隔';

  @override
  String scanIntervalMinutes(int minutes) {
    return '每 $minutes 分钟';
  }

  @override
  String scanIntervalHours(int hours) {
    return '每 $hours 小时';
  }

  @override
  String get offlineLibrarySource => '离线曲库';

  @override
  String get offlineLibraryLocal => '本地音乐库';

  @override
  String get offlineLibraryCached => '服务器缓存歌曲';

  @override
  String offlineLibraryCachedDetail(int count) {
    return '已有 $count 首在本地';
  }

  @override
  String get offlineChooseLibrary => '离线时使用哪个曲库？';

  @override
  String get noServerForOffline => '没有可用于缓存曲库的服务器';

  @override
  String get libraryHealth => '曲库体检';

  @override
  String get healthMissingTags => '缺标签';

  @override
  String get healthMissingCover => '缺封面';

  @override
  String get healthMissingLyrics => '缺歌词';

  @override
  String get healthDuplicates => '重复歌曲';

  @override
  String healthTotal(int count) {
    return '共 $count 首本地歌曲';
  }

  @override
  String get healthClean => '未发现问题';

  @override
  String get healthNoMissingTags => '所有歌曲都有标题、艺术家和专辑';

  @override
  String get healthNoMissingCover => '所有歌曲都有封面';

  @override
  String get healthNoMissingLyrics => '所有歌曲都有歌词';

  @override
  String get healthNoDuplicates => '没有发现重复歌曲';

  @override
  String healthFileCount(int count) {
    return '$count 个文件';
  }

  @override
  String get playbackSettings => '播放设置';

  @override
  String get searchTagsHint => '从网易云与 QQ 音乐搜索并应用匹配结果';

  @override
  String get tagInformation => '标签信息';

  @override
  String get audioInformation => '音频信息';

  @override
  String get playbackReport => '上报播放进度';

  @override
  String get playbackReportDescription => '持续更新服务器端的“正在播放”与播放位置；关闭后不再定时上报。';

  @override
  String get randomSongs => '随机播放';

  @override
  String get randomSongsHint => '每次刷新重新抽取 100 首歌曲';

  @override
  String get useServerRandom => '使用服务器随机列表';

  @override
  String get useServerRandomDescription =>
      '开启后向服务器请求随机歌曲；关闭后从本机已保存的歌曲中抽取。服务器不可用时自动回退到本地列表。';

  @override
  String get viewComments => '查看评论';

  @override
  String get lyricsCoverMotion => '歌词页封面动效';

  @override
  String get playerCoverStyle => '播放器封面样式';

  @override
  String get coverStyleSquare => '方形封面';

  @override
  String get coverStyleVinyl => '黑胶唱片';

  @override
  String get lyricShareCard => '分享歌词卡片';

  @override
  String get annualReport => '年度回顾';

  @override
  String get share => '分享';

  @override
  String savedTo(String path) {
    return '已保存到 $path';
  }

  @override
  String get annualDaysMusic => '天有音乐';

  @override
  String get annualTopArtist => '年度歌手';

  @override
  String get annualTopAlbum => '年度专辑';

  @override
  String get annualTopSong => '年度歌曲';

  @override
  String get annualMonthly => '月度节奏';

  @override
  String get annualBestMonth => '听得最多的月份';

  @override
  String annualStreak(int days) {
    return '最长连续听歌 $days 天';
  }

  @override
  String get annualNoData => '这一年还没有足够的听歌数据';

  @override
  String get shareCardSettings => '分享卡片';

  @override
  String get shareCardTopText => '顶部文字';

  @override
  String get shareCardBackground => '背景效果';

  @override
  String get shareCardTextSize => '歌词字号';

  @override
  String get shareCardCoverSize => '封面大小';

  @override
  String get shareCardShowTranslation => '显示翻译';

  @override
  String get shareCardBlur => '柔和虚化';

  @override
  String get shareCardCrop => '封面裁切';

  @override
  String get shareCardAurora => '流光';

  @override
  String get shareCardPixelate => '马赛克';

  @override
  String get shareCardHalftone => '点阵';

  @override
  String get similarArtists => '相似艺人';

  @override
  String get moreFromArtist => '更多来自这位艺术家';

  @override
  String get audioQualityStats => '音质统计';

  @override
  String get cacheStorageStats => '缓存存储';

  @override
  String get qualityDistribution => '音质分布';

  @override
  String get formatDistribution => '格式分布';

  @override
  String get losslessRatio => '无损占比';

  @override
  String get averageBitrate => '平均码率';

  @override
  String get unknownQuality => '未知';

  @override
  String get hires => '高解析';

  @override
  String get lossless => '无损';

  @override
  String get lossy => '有损';

  @override
  String get highestQualitySongs => '最高音质';

  @override
  String get storageBreakdown => '存储构成';

  @override
  String get cacheUsage => '缓存占用';

  @override
  String get activeTasks => '进行中的任务';

  @override
  String get cacheAudio => '音频';

  @override
  String get cacheOther => '其他';

  @override
  String get largestCached => '占用最大的缓存歌曲';

  @override
  String get storageLocation => '存储位置';

  @override
  String get downloadedFiles => '下载';

  @override
  String get carDisplay => '歌曲广播';

  @override
  String get classicBluetoothBroadcast => '经典蓝牙广播';

  @override
  String get classicBluetoothBroadcastDesc =>
      '打开后始终使用经典蓝牙（AVRCP）的发布方式；关闭后根据当前音频输出自动选择。';

  @override
  String get classicBluetoothRouteClassic => '当前输出：经典蓝牙';

  @override
  String get classicBluetoothRouteOther => '当前输出：非经典蓝牙';

  @override
  String get carDisplayLines => '显示行数';

  @override
  String get carLinesTwo => '两行';

  @override
  String get carLinesThree => '三行';

  @override
  String get carLine1 => '第一行';

  @override
  String get carLine2 => '第二行';

  @override
  String get carLine3 => '第三行';

  @override
  String get carTokenLyricOriginal => '原词';

  @override
  String get carTokenLyricTranslation => '翻译';

  @override
  String get carTokenTitle => '歌名';

  @override
  String get carTokenArtist => '艺术家';

  @override
  String get carTokenAlbum => '专辑';

  @override
  String get carAddField => '添加字段';

  @override
  String get carSeparator => '连接符';

  @override
  String get carSeparatorSpace => '空格';

  @override
  String get carPreview => '预览';

  @override
  String get carReset => '恢复默认';

  @override
  String get classicCoverMode => '经典蓝牙封面';

  @override
  String get classicCoverFull => '完整方案（文件 + 可获取 URI + 位图）';

  @override
  String get classicCoverBitmap => '位图';

  @override
  String get classicCoverBitmapUri => '位图 + URI';

  @override
  String get classicCoverLarge => '原始大图';

  @override
  String get classicCoverRelay => '位图 + 中继/服务器 URI';

  @override
  String get carTabLayout => '布局';

  @override
  String get carTabCover => '封面';

  @override
  String get carTabLyrics => '歌词';

  @override
  String get carPreviewBuiltin => '内置';

  @override
  String get carPreviewLive => '实时';

  @override
  String get carNoSong => '当前没有播放歌曲';

  @override
  String get pcInspector => 'PC 检查服务';

  @override
  String get debug => '调试';

  @override
  String get currentBroadcast => '当前广播';

  @override
  String get rediscovery => '久别重逢';

  @override
  String get searchAll => '全部';

  @override
  String get searchTopResult => '最佳结果';

  @override
  String get searchRecent => '最近搜索';

  @override
  String get searchClearRecent => '清除';

  @override
  String get searchTrySearching => '试试搜索';

  @override
  String get searchBrowse => '快速浏览';

  @override
  String get searchIdleHint => '歌曲、专辑、艺术家、歌单，一次搜遍';

  @override
  String get searchShowAll => '查看全部';

  @override
  String searchCountSongs(int count) {
    return '$count 首';
  }

  @override
  String get prefetchNextSong => '预缓存下一首';

  @override
  String get settingsDataBackup => '数据与备份';

  @override
  String get backupData => '备份';

  @override
  String get backupExport => '导出备份';

  @override
  String get backupImport => '从文件恢复';

  @override
  String get backupSettings => '设置';

  @override
  String get backupServers => '服务器与账号';

  @override
  String get backupPlaylists => '歌单与收藏';

  @override
  String get backupStatistics => '听歌统计';

  @override
  String get backupPrivacy => '备份不包含服务器密码，恢复后需要重新输入';

  @override
  String get backupSaved => '备份已保存';

  @override
  String get backupRestoreConfirm => '恢复这个备份？设置、服务器、歌单和统计都会被替换。';

  @override
  String get backupRestoreDone => '恢复完成，重启临音后全部生效';

  @override
  String get backupInvalid => '这不是有效的临音备份文件';

  @override
  String get backupRollback => '恢复前的数据已另存为回滚文件';

  @override
  String get settingsGroupGeneral => '通用';

  @override
  String get settingsGroupPlayback => '播放';

  @override
  String get settingsGroupLibrary => '音乐库';

  @override
  String get settingsGroupMore => '更多';

  @override
  String get settingsSearchHint => '搜索设置';

  @override
  String get settingsNoResults => '没有匹配的设置';

  @override
  String get showInFolder => '在文件夹中显示';

  @override
  String get removeFromLibrary => '移出曲库';

  @override
  String get removeFromLibraryConfirm => '从曲库移除这首歌？音频文件不会被删除。';

  @override
  String get removedFromLibrary => '已移出曲库';

  @override
  String get deleteFile => '删除文件';

  @override
  String get deleteFileConfirm => '永久删除这个音频文件？此操作无法撤销。';

  @override
  String get fileDeleted => '文件已删除';

  @override
  String get noFileManager => '没有可用的文件管理器';

  @override
  String get showInFolderFailed => '无法打开文件夹';

  @override
  String get audioOutput => '音频输出';

  @override
  String get audioRoute => '当前输出';

  @override
  String get audioRouteBluetooth => '蓝牙';

  @override
  String get audioRouteUsb => 'USB 音频';

  @override
  String get audioRouteWired => '有线耳机';

  @override
  String get audioRouteSpeaker => '扬声器';

  @override
  String get audioRouteEarpiece => '听筒';

  @override
  String get audioRouteHdmi => 'HDMI';

  @override
  String get audioRouteDock => '底座';

  @override
  String get audioRouteHearingAid => '助听器';

  @override
  String get audioRouteLine => '线路输出';

  @override
  String get audioRouteOther => '音频设备';

  @override
  String get audioOutputSampleRate => '输出采样率';

  @override
  String get audioOutputBuffer => '输出缓冲';

  @override
  String get audioOutputLatency => '缓冲延迟';

  @override
  String get audioSourceFormat => '源格式';

  @override
  String get audioSourceSampleRate => '源采样率';

  @override
  String get audioOutputDevices => '已连接的输出设备';

  @override
  String get audioOutputNote => '输出采样率与缓冲由 Android 提供；蓝牙编码本身由系统协商，应用无法读取。';

  @override
  String get audioOutputUnavailable => '当前平台不提供输出信息';

  @override
  String get audioNoSongPlaying => '暂无播放';

  @override
  String get serverCapabilities => '服务器能力';

  @override
  String get capLyrics => '按歌曲 ID 获取歌词';

  @override
  String get capSimilarSongs => '音色相似推荐';

  @override
  String get capTranscodeOffset => '转码定位';

  @override
  String get capFormPost => '表单提交';

  @override
  String get capApiKey => 'API Key 登录';

  @override
  String get capPlaybackReport => '播放进度上报';

  @override
  String get capSimilarArtists => '相似艺术家';

  @override
  String get capFavorites => '专辑与艺术家收藏';

  @override
  String get capLibraryScan => '音乐库扫描';

  @override
  String get capPlaylists => '服务器歌单';

  @override
  String get broadcastCover => '广播封面';

  @override
  String get abLoop => 'A–B 循环';

  @override
  String get abSetA => 'A 设为当前';

  @override
  String get abSetB => 'B 设为当前';

  @override
  String get abClear => '清除循环';

  @override
  String get abNeedBoth => '先设置 A 和 B';

  @override
  String get gaplessPlayback => '无缝播放';

  @override
  String get trackTransition => '歌曲切换过渡';

  @override
  String get transitionOff => '关闭';

  @override
  String get transitionFixed => '固定淡入淡出';

  @override
  String get transitionAdaptive => '智能自适应';

  @override
  String get transitionSeconds => '过渡总时长';

  @override
  String get downloadSelected => '下载所选';

  @override
  String get showAllSongs => '显示全部歌曲';

  @override
  String get showMissingOnly => '只显示缺少标签';

  @override
  String get dailyMix => '每日推荐';

  @override
  String get dailyMixToday => '今天';

  @override
  String get dailyMixHistory => '历史回顾';

  @override
  String get dailyMixCalendar => '推荐日历';

  @override
  String get dailyMixBackToday => '回到今天';

  @override
  String get dailyMixRefreshConfirm => '重新生成今天的推荐？';

  @override
  String get dailyMixMissing => '不可用';

  @override
  String get dailyMixEmpty => '曲库中还没有可推荐的歌曲';

  @override
  String get sessionDiary => '音乐记忆';

  @override
  String get sessionTodayMemories => '今日回忆';

  @override
  String get sessionResumeQueue => '恢复这段队列';

  @override
  String get sessionNoSessions => '还没有播放记录';

  @override
  String get sessionCompleted => '听完';

  @override
  String get sessionSkipped => '跳过';

  @override
  String get scrobbleQueue => '播放上报队列';

  @override
  String get scrobblePending => '待上报';

  @override
  String get scrobbleDead => '失败记录';

  @override
  String get scrobbleRetry => '重试';

  @override
  String get scrobbleClearDead => '清除失败记录';

  @override
  String get scrobbleNoPending => '没有待发送的记录';

  @override
  String get sourceHealth => '源健康';

  @override
  String get sourceHealthy => '可连接';

  @override
  String get sourceUnreachable => '不可达';

  @override
  String get sourceLastCheck => '最近检查';

  @override
  String get sourcePendingReports => '待上报记录';

  @override
  String get sourceNoServers => '还没有配置服务器';

  @override
  String get sourceTestAll => '测试全部来源';

  @override
  String get syncPreview => '同步预览';

  @override
  String get syncPreviewAdded => '新增歌曲';

  @override
  String get syncPreviewRemoved => '将被移除';

  @override
  String get syncPreviewChanged => '元数据变化';

  @override
  String get syncPreviewUnchanged => '未变化';

  @override
  String get syncPreviewCacheImpact => '受影响缓存';

  @override
  String get syncPreviewPlaylistImpact => '受影响歌单引用';

  @override
  String get syncPreviewApply => '开始同步';

  @override
  String get syncPreviewSafe => '没有需要变更的内容';

  @override
  String get syncPreviewWarn => '移除只会从曲库消失，不会删除文件。';

  @override
  String scrobbleAttempts(int count) {
    return '$count 次尝试';
  }

  @override
  String sessionTracks(int count) {
    return '$count 首';
  }
}
