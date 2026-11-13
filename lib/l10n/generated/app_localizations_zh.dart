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
  String get cached => '已缓存到本机';

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
  String get randomizeTemp => '随机(暂时)';

  @override
  String get randomizePermanent => '随机(永久)';

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
  String get downloading => '正在下载…';

  @override
  String get downloaded => '已下载';

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
  String get cacheCovers => '已缓存封面';

  @override
  String get cacheLyrics => '已缓存歌词';

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
  String get playbackModeExclusiveDesc => '临音独占音频输出，其他应用没有声音。';

  @override
  String get playbackModeDuckDesc => '其他应用播放音频时，自动降低临音的音量。';

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
}
