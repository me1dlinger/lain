// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get lain => 'Lain';

  @override
  String get title => 'Title';

  @override
  String get artist => 'Artist';

  @override
  String get album => 'Album';

  @override
  String get albumArtist => 'Album Artist';

  @override
  String get genre => 'Genre';

  @override
  String get year => 'Year';

  @override
  String get track => 'Track';

  @override
  String get disc => 'Disc';

  @override
  String get lyrics => 'Lyrics';

  @override
  String get folder => 'Folder';

  @override
  String get frequently => 'Most Played';

  @override
  String get recently => 'Recently Played';

  @override
  String get artists => 'Artists';

  @override
  String get albums => 'Albums';

  @override
  String get folders => 'Folders';

  @override
  String get songs => 'Songs';

  @override
  String get home => 'Home';

  @override
  String get playlists => 'Playlists';

  @override
  String get language => 'Language';

  @override
  String get playQueue => 'Play Queue';

  @override
  String get followSystem => 'Follow System';

  @override
  String get settings => 'Settings';

  @override
  String get settingsMusicSource => 'Music Sources';

  @override
  String get localMusicSource => 'Local Music Source';

  @override
  String get longPressToConfigure => 'Long press to configure';

  @override
  String get customFolders => 'Custom Folders';

  @override
  String get addCustomFolder => 'Add Custom Folder';

  @override
  String get startScan => 'Start Scan';

  @override
  String get scanSubdirectories => 'Scan Subdirectories';

  @override
  String get blockedFolders => 'Blocked Folders';

  @override
  String get addBlockedFolder => 'Add Blocked Folder';

  @override
  String get noBlockedFolders => 'No blocked folders';

  @override
  String skipShortAudio(int seconds) {
    return 'Skip audio under $seconds seconds';
  }

  @override
  String get minimumAudioLength => 'Minimum Audio Length';

  @override
  String get manageStoragePermission => 'Manage External Storage Permission';

  @override
  String get settingsUserInterface => 'User Interface';

  @override
  String get settingsPlaybackLyrics => 'Playback & Lyrics';

  @override
  String get settingsNotifications => 'Notifications';

  @override
  String get settingsStartupBackground => 'Startup & Background';

  @override
  String get settingsCacheDownloads => 'Cache & Downloads';

  @override
  String get settingsHelpFeedback => 'Help & Feedback';

  @override
  String get feedback => 'Feedback';

  @override
  String get customizeSettingsOrder => 'Customize Menu Order';

  @override
  String get offlineMode => 'Offline Mode';

  @override
  String get offlineModeDescription =>
      'Local music only; online sources are locked';

  @override
  String get offlineModeBlocked =>
      'Offline mode is on; online music sources are locked';

  @override
  String get lanDirect => 'LAN direct';

  @override
  String get lanDirectDescription =>
      'Direct to the server on the LAN: no transcode, no cache';

  @override
  String get reload => 'Reload';

  @override
  String get manageMusicFolder => 'Manage Music Folders';

  @override
  String get about => 'About';

  @override
  String get openSourceLicense => 'Open Source License';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get sleepTimer => 'Sleep Timer';

  @override
  String get pauseAfterCurrentTrack => 'Pause After Current Track';

  @override
  String get vibration => 'Vibration';

  @override
  String get library => 'Library';

  @override
  String get select => 'Select';

  @override
  String get sortSongs => 'Sort Songs';

  @override
  String get delete => 'Delete';

  @override
  String get remove => 'Remove';

  @override
  String get createPlaylist => 'Create Playlist';

  @override
  String get order => 'Order';

  @override
  String get reorder => 'Reorder';

  @override
  String songCount(int count) {
    return '$count songs';
  }

  @override
  String artistCount(int count) {
    return '$count in total';
  }

  @override
  String albumCount(int count) {
    return '$count in total';
  }

  @override
  String playlistCount(int count) {
    return '$count in total';
  }

  @override
  String folderCount(int count) {
    return '$count in total';
  }

  @override
  String settingCount(int count) {
    return '$count in total';
  }

  @override
  String fontCount(int count) {
    return '$count in total';
  }

  @override
  String get searchSongs => 'Search Songs';

  @override
  String get searchArtists => 'Search Artists';

  @override
  String get searchAlbums => 'Search Albums';

  @override
  String get searchPlaylists => 'Search Playlists';

  @override
  String get searchLicenses => 'Search Licenses';

  @override
  String get searchHome => 'albums/songs/playlists';

  @override
  String get ascending => 'Ascending';

  @override
  String get descending => 'Descending';

  @override
  String get pictureSize => 'Picture Size';

  @override
  String get large => 'Large';

  @override
  String get small => 'Small';

  @override
  String get view => 'View';

  @override
  String get list => 'List';

  @override
  String get grid => 'Grid';

  @override
  String get favorited => 'Favorited';

  @override
  String get favorites => 'Favorites';

  @override
  String get duration => 'Duration';

  @override
  String get times => 'Times';

  @override
  String get loop => 'Loop';

  @override
  String get shuffle => 'Shuffle';

  @override
  String get repeat => 'Repeat';

  @override
  String get holdForRepeatOne => 'Hold: repeat one';

  @override
  String get playAll => 'Play All';

  @override
  String get move2Top => 'Move to Top';

  @override
  String get playNow => 'Play Now';

  @override
  String get playNext => 'Play Next';

  @override
  String get add2Queue => 'Add to Queue';

  @override
  String get edit => 'Edit';

  @override
  String get editMetadata => 'Edit Metadata';

  @override
  String get add2Playlist => 'Add to Playlist';

  @override
  String get added2Playlist => 'Added to playlist';

  @override
  String get selectAll => 'Select All';

  @override
  String get complete => 'Complete';

  @override
  String get continueMsg => 'Are you sure you want to continue?';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirm => 'Confirm';

  @override
  String get addFolder => 'Add Folder';

  @override
  String get addRecursiveFolder => 'Add Folder and All Subfolders';

  @override
  String get replacePicture => 'Replace Picture';

  @override
  String get unknown => 'Unknown';

  @override
  String get updateMedata => 'Update Metadata';

  @override
  String get defaultText => 'Default';

  @override
  String get titleAscending => 'Title Ascending';

  @override
  String get titleDescending => 'Title Descending';

  @override
  String get artistAscending => 'Artist Ascending';

  @override
  String get artistDescending => 'Artist Descending';

  @override
  String get albumAscending => 'Album Ascending';

  @override
  String get albumDescending => 'Album Descending';

  @override
  String get durationAscending => 'Duration Ascending';

  @override
  String get durationDescending => 'Duration Descending';

  @override
  String get selectSortingType => 'Select sorting type';

  @override
  String get loadingFolder => 'Loading Folder';

  @override
  String get loadedSongs => 'Loaded Songs';

  @override
  String get loadingNavidrome => 'Loading Navidrome';

  @override
  String get canNotUpdate => 'Can not update the song that is playing';

  @override
  String get updateSuccessfully => 'Update Successfully';

  @override
  String get updateFailed => 'Update failed';

  @override
  String get clear => 'Clear';

  @override
  String get reset => 'Reset';

  @override
  String get desktopLyrics => 'Desktop Lyrics';

  @override
  String get horizontal => 'Horizontal';

  @override
  String get vertical => 'Vertical';

  @override
  String get lock => 'Lock';

  @override
  String get unlock => 'Unlock';

  @override
  String get closeAction => 'Close Action';

  @override
  String get exit => 'Exit';

  @override
  String get hide => 'Hide';

  @override
  String get checkUpdate => 'Check Update';

  @override
  String get go2Download => 'Go to Download';

  @override
  String get alreadyLatest => 'Already on the latest version';

  @override
  String get theme => 'Theme';

  @override
  String get mainPageTheme => 'Main Page Theme';

  @override
  String get lyricsPageTheme => 'Lyrics Page Theme';

  @override
  String get vividMode => 'Vivid Mode';

  @override
  String get lightMode => 'Light Mode';

  @override
  String get darkMode => 'Dark Mode';

  @override
  String get customMode => 'Custom Mode';

  @override
  String get local => 'Local';

  @override
  String get switchSource => 'Switch Source';

  @override
  String get manageServers => 'Manage Servers';

  @override
  String get username => 'Username';

  @override
  String get password => 'Password';

  @override
  String get exportLog => 'Export Log';

  @override
  String get showApp => 'Show App';

  @override
  String get skip2Previous => 'Skip to Previous';

  @override
  String get skip2Next => 'Skip to Next';

  @override
  String get playOrPause => 'Play/Pause';

  @override
  String get unlockDeskLrc => 'Unlock Desktop Lyrics';

  @override
  String get autoPlayOnStartup => 'Auto-Play on Startup';

  @override
  String get return2Previous => 'Return to Previous';

  @override
  String get addedFolders => 'Added Folders';

  @override
  String get recursiveScan => 'Scan Subfolders';

  @override
  String get songInfo => 'Song Info';

  @override
  String get cached => 'Cached';

  @override
  String get format => 'Format';

  @override
  String get bitrate => 'Bitrate';

  @override
  String get samplerate => 'Sample Rate';

  @override
  String get filePath => 'File Path';

  @override
  String get path => 'Path';

  @override
  String get go2Artist => 'Go to Artist';

  @override
  String get go2Album => 'Go to Album';

  @override
  String get equalizer => 'Equalizer';

  @override
  String get more => 'More';

  @override
  String get randomize => 'Randomize';

  @override
  String get normal => 'Normal';

  @override
  String get randomizeTemp => 'Randomize(Temporary)';

  @override
  String get randomizePermanent => 'Randomize(Permanent)';

  @override
  String get modifiedTimeAscending => 'Modified Time Ascending';

  @override
  String get modifiedTimedescending => 'Modified Time Descending';

  @override
  String get addedTimeAscending => 'Added Time Ascending';

  @override
  String get streamQuality => 'Streaming Quality';

  @override
  String get streamQualityStandard => 'Standard (up to 128kbps)';

  @override
  String get streamQualityHigh => 'High (up to 192kbps)';

  @override
  String get streamQualityHq => 'HQ (256kbps)';

  @override
  String get streamQualitySq => 'SQ (320kbps)';

  @override
  String get streamQualityOriginal => 'Original (no transcoding)';

  @override
  String get streamFormat => 'Transcode Format';

  @override
  String get mobileDataWarning => 'Cellular Data Warning';

  @override
  String get mobileDataNotice => 'Streaming online music over mobile data';

  @override
  String get serverScheme => 'Scheme';

  @override
  String get serverHost => 'Host';

  @override
  String get serverPort => 'Port';

  @override
  String get serverPath => 'Path';

  @override
  String get noData => 'No data';

  @override
  String get popularSongs => 'Top Songs';

  @override
  String get popularAlbums => 'Top Albums';

  @override
  String get timesUnit => 'times';

  @override
  String get rename => 'Rename';

  @override
  String get exportPlaylist => 'Export playlist';

  @override
  String get exported => 'Exported to';

  @override
  String get exportFailed => 'Export failed';

  @override
  String get download => 'Download';

  @override
  String get downloads => 'Downloads';

  @override
  String get downloadWaitingForWifi => 'Queued; it will start on Wi-Fi';

  @override
  String downloadResumedOnWifi(int count) {
    return 'On Wi-Fi now, continuing $count downloads';
  }

  @override
  String get downloadOnMobileData => 'Download over mobile data';

  @override
  String get downloadQuality => 'Download quality';

  @override
  String get downloadTasks => 'Download queue';

  @override
  String get downloadStateWaitingWifi => 'Waiting for Wi-Fi';

  @override
  String get downloadStateDownloading => 'Downloading';

  @override
  String get downloadStatePaused => 'Paused';

  @override
  String get downloadStateFailed => 'Failed';

  @override
  String get continueDownload => 'Continue downloads';

  @override
  String get pauseDownload => 'Pause downloads';

  @override
  String get deleteAllDownloads => 'Delete all';

  @override
  String get downloading => 'Downloading…';

  @override
  String get downloaded => 'Downloaded';

  @override
  String get downloadAdded => 'Added to downloads';

  @override
  String get allCached => 'Everything is cached';

  @override
  String get downloadFailed => 'Download failed';

  @override
  String get playFailed => 'Playback failed';

  @override
  String get noDownloads => 'Nothing downloaded yet';

  @override
  String get importPlaylist => 'Import playlist';

  @override
  String get enterPath => 'Enter a path';

  @override
  String get importedSongs => 'Imported songs:';

  @override
  String get noMatchingSongs => 'No song in the library matches the file';

  @override
  String get fileNotFound => 'File not found';

  @override
  String get mostPlayed => 'Most played';

  @override
  String get cacheLists => 'List cache';

  @override
  String get viewCache => 'View Cache';

  @override
  String get cacheTagAudio => 'Song';

  @override
  String get cacheTagCover => 'Cover';

  @override
  String get cacheTagLyric => 'Lyrics';

  @override
  String get precacheAll => 'Cache Every Song\'s Info';

  @override
  String get cacheTaskTitle => 'Caching songs';

  @override
  String get cacheBackground => 'Run in Background';

  @override
  String get cacheMovedToBackground => 'Caching continues in the background';

  @override
  String get cacheTaskDone => 'Caching finished';

  @override
  String get cacheTaskCanceled => 'Caching canceled';

  @override
  String get cacheTaskBusy => 'A caching task is already running';

  @override
  String get cacheTaskQueued => 'Added to the caching queue';

  @override
  String cacheFailedCount(int count) {
    return '$count failed';
  }

  @override
  String get cacheBackPrompt =>
      'Caching is still running. Cancel it or run it in the background?';

  @override
  String get cacheKeepRunning => 'Keep Waiting';

  @override
  String get added2Next => 'Playing next';

  @override
  String get homeLayout => 'Home layout';

  @override
  String get homeTopButtons => 'Top buttons';

  @override
  String get homeSections => 'Home sections';

  @override
  String get ignoreCert => 'Ignore certificate';

  @override
  String get recentlyAdded => 'Recently Added';

  @override
  String get connectSuccess => 'Connected';

  @override
  String get connectionFailed => 'Connection failed';

  @override
  String get trackAscending => 'Track Ascending';

  @override
  String get trackDescending => 'Track Descending';

  @override
  String get servers => 'Servers';

  @override
  String get addServer => 'Add server';

  @override
  String get serverName => 'Name';

  @override
  String get serverType => 'Type';

  @override
  String get publicAddress => 'Public address';

  @override
  String get lanAddress => 'LAN address';

  @override
  String get testAndSave => 'Test and save';

  @override
  String get recheck => 'Check again';

  @override
  String get unreachable => 'Unreachable';

  @override
  String get inUse => 'In use';

  @override
  String get localMusic => 'Local music';

  @override
  String get serverAddress => 'Server Address';

  @override
  String get cacheDetails => 'Cache Details';

  @override
  String get cacheSongs => 'Cached Songs';

  @override
  String get cacheTasks => 'Cache tasks';

  @override
  String get cacheWaiting => 'Waiting';

  @override
  String get noCacheTasks => 'No cache tasks';

  @override
  String get cacheGroup => 'Playlist and artist cache';

  @override
  String get autoCacheSongs => 'Auto-cache songs';

  @override
  String get autoCachePlaylists => 'Auto-cache playlists';

  @override
  String get autoCacheArtists => 'Auto-cache artists';

  @override
  String get cacheDirectory => 'Cache directory';

  @override
  String get downloadDirectory => 'Download directory';

  @override
  String get cacheLimit => 'Cache limit';

  @override
  String get cacheLimitUnlimited => 'Unlimited';

  @override
  String cacheLimitGb(int gb) {
    return '$gb GB';
  }

  @override
  String get moveCacheToNewDirectory =>
      'Move the existing cache to the new folder?';

  @override
  String get moveDownloadsToNewDirectory =>
      'Move the downloaded songs to the new folder?';

  @override
  String get cacheDirectoryChanged => 'Cache directory updated';

  @override
  String get storagePermissionDenied =>
      'Storage permission is required for that folder';

  @override
  String get downloadDirectoryChanged => 'Download directory updated';

  @override
  String get cacheCovers => 'Covers';

  @override
  String get cacheLyrics => 'Lyrics';

  @override
  String get cacheTotal => 'Total';

  @override
  String get cacheEmpty => 'Nothing cached yet';

  @override
  String get removeCache => 'Remove from cache';

  @override
  String get listeningReport => 'Listening Report';

  @override
  String get yearlyActivity => 'Yearly Activity';

  @override
  String get playRanking => 'Most Played';

  @override
  String get yearlyStats => 'Statistics';

  @override
  String get topArtists => 'Top Artists';

  @override
  String get listeningTime => 'Listening Time';

  @override
  String get playTimes => 'Plays';

  @override
  String get listeningDays => 'Active Days';

  @override
  String get songsTotal => 'Songs';

  @override
  String get albumsTotal => 'Albums';

  @override
  String get heatLess => 'Less';

  @override
  String get heatMore => 'More';

  @override
  String get allSources => 'All Sources';

  @override
  String get addedTimeDescending => 'Added Time Descending';

  @override
  String get cannotBeUndone => 'Cannot be Undone';

  @override
  String get clearCache => 'Clear Cache';

  @override
  String get clearCacheConfirm => 'Clear all cached songs?';

  @override
  String get clearCacheConfirmAgain =>
      'Confirm again: cleared songs cannot be restored';

  @override
  String get tapAgain => 'Tap Again to Exit';

  @override
  String get close => 'Close';

  @override
  String get fonts => 'Fonts';

  @override
  String get searchFonts => 'Search Fonts';

  @override
  String get setFontName => 'Set Font Name';

  @override
  String get setFont => 'Set Font';

  @override
  String get restoreDefault => 'Restore Default';

  @override
  String get addFont => 'Add Font';

  @override
  String get deleteFont => 'Delete Font';

  @override
  String get currentFont => 'Current Font';

  @override
  String get refresh => 'Refresh';

  @override
  String get syncLibrary => 'Synchronize Library';

  @override
  String get syncingTryLater => 'Syncing library, try again later';

  @override
  String get syncDone => 'Library synced';

  @override
  String get syncFailed => 'Sync failed';

  @override
  String get all => 'All';

  @override
  String get folderExist => 'The folder already exist';

  @override
  String get folderNotSupportedYet => 'The folder is not supported yet';

  @override
  String get getPermissionFailed => 'Get permission failed';

  @override
  String get premiumFeatures => 'Premium Features';

  @override
  String get premiumDescription =>
      'Enjoy the full experience and support ongoing development';

  @override
  String get unlockPremium => 'Unlock Premium Features';

  @override
  String get restorePurchase => 'Restore Purchases';

  @override
  String get whatPremiumContains => 'What\'s Included';

  @override
  String get themeDescription => 'Unlock Vivid Mode for the Main Page';

  @override
  String get fontDescription => 'Use custom fonts';

  @override
  String get equalizerDescription =>
      'Adjust audio levels across different frequencies';

  @override
  String get widgets => 'Home Screen Widgets';

  @override
  String get widgetsDescription =>
      'Show Now Playing and your playlists on the Home Screen';

  @override
  String get futurePremium => 'Future Premium Features';

  @override
  String get futurePremiumDescription =>
      'All future premium features will be unlocked automatically';

  @override
  String get premiumRequiredMessage =>
      'This feature requires Premium Features to be unlocked before it can be used';

  @override
  String get premiumUnlockHint =>
      'Go to Settings > Premium Features to unlock it';

  @override
  String get alreadyPremium => 'Premium features are already unlocked';

  @override
  String get pendingPurchase => 'Processing your purchase...';

  @override
  String get purchaseNotFound => 'No purchase records found';

  @override
  String get productNotAvailable =>
      'Unable to load product information. Please check your internet connection and try again';

  @override
  String get iapNotAvailable =>
      'In-App Purchases are not available. Please try again later';

  @override
  String get connectingToAppStore => 'Connecting to the App Store...';

  @override
  String get checkingPurchase => 'Checking purchase history...';

  @override
  String get noLyrics => 'There are no lyrics';

  @override
  String get lyricsParseFailed => 'Lyrics parsing failed';

  @override
  String get switchMode => 'Switch Mode';

  @override
  String get viewLog => 'View Log';

  @override
  String get premiumTrialActive => 'Premium Trial Active';

  @override
  String trialRemainingStatus(int count) {
    return 'You have $count min of Premium access remaining\nPurchase Premium to continue after your trial ends';
  }

  @override
  String get gotIt => 'Got it';

  @override
  String get trialRemaining => 'Trial Remaining';

  @override
  String get bigPictureMode => 'Big Picture Mode';

  @override
  String get bigPictureModeDescription => 'Unlock Big Picture Mode';

  @override
  String get adjustLyrics => 'Adjust Lyrics';

  @override
  String get drivingMode => 'Driving Mode';

  @override
  String get fontSize => 'Font Size';

  @override
  String get fontWeight => 'Font Weight';

  @override
  String get offset => 'Offset';

  @override
  String get getStart => 'Get Start';

  @override
  String get immersiveWideLayout => 'Immersive for Wide Layout';

  @override
  String get wideShowTopSystemBar => 'Show Top System Bar in Wide Layout';

  @override
  String get wideShowBottomSystemBar => 'Show Bottom System Bar in Wide Layout';

  @override
  String get menuOnRight => 'Open Menu from Right';

  @override
  String get save => 'Save';

  @override
  String get chooseMusicSource => 'Choose a Music Source';

  @override
  String get feiniuMusic => 'Feiniu Music';

  @override
  String get feiniuConnectionFailed =>
      'Unable to connect to Feiniu Music. Check the server URL and your music app username and password.';

  @override
  String get savedSuccessfully => 'Saved successfully';

  @override
  String get controlCenterLyrics => 'Control Center Lyrics';

  @override
  String get coverBroadcast => 'Cover broadcast';

  @override
  String get songQualityBadge => 'Song quality';

  @override
  String get coverBroadcastBitmap => 'Bitmap only';

  @override
  String get coverBroadcastServer => 'Server cover URL';

  @override
  String get coverBroadcastRelay => 'Local relay URL';

  @override
  String get coverBroadcastContent => 'Content provider URI';

  @override
  String get coverBroadcastAuto => 'Automatic';

  @override
  String get coverBroadcastRelayOriginal => 'Local relay (original)';

  @override
  String get relayAddress => 'Relay address';

  @override
  String get relayAddressAuto => 'Automatic';

  @override
  String get broadcastLyrics => 'Broadcast lyrics';

  @override
  String get connect => 'Connect';

  @override
  String get notConnected => 'is Not Connected';

  @override
  String get sortType => 'Sort By';

  @override
  String get sortByName => 'Name';

  @override
  String get sortByAddedTime => 'Added Time';

  @override
  String get sortByPlayCount => 'Play Count';

  @override
  String get sortBySize => 'Size';

  @override
  String get sortByYear => 'Year';

  @override
  String get sortByAlbumCount => 'Album Count';

  @override
  String get sortBySongCount => 'Song Count';

  @override
  String get sortByFavorite => 'Favorites';

  @override
  String get randomSort => 'Shuffle';

  @override
  String get favoriteFailed => 'Could not update favorites';

  @override
  String get totalDuration => 'Total Duration';

  @override
  String get albumInfo => 'Album Info';

  @override
  String get artistInfo => 'Artist Info';

  @override
  String get biography => 'Biography';

  @override
  String get description => 'Description';

  @override
  String get songUnit => 'Songs';

  @override
  String get contributingArtists => 'Contributing Artists';

  @override
  String get noResults => 'No results';

  @override
  String get clearArtistsCache => 'Clear artist cache';

  @override
  String get artistCacheRefreshed => 'Artist cache refreshed';

  @override
  String get artistCacheNoImage =>
      'Refreshed - no artist image yet, using the album cover';

  @override
  String get addedTime => 'Added Time';

  @override
  String get modifiedTime => 'Modified Time';

  @override
  String get playCountLabel => 'Play Count';

  @override
  String get clearSuccess => 'Cleared';

  @override
  String get addToFavorites => 'Add to Favorites';

  @override
  String get removeFromFavorites => 'Remove from Favorites';

  @override
  String get playbackMode => 'Playback Mode';

  @override
  String get playbackModeExclusive => 'Exclusive';

  @override
  String get playbackModeDuck => 'Smart Ducking';

  @override
  String get playbackModeMix => 'Mixed';

  @override
  String get playbackModeExclusiveDesc =>
      'Lain takes the audio output and pauses when another app plays; it does not resume on its own afterwards.';

  @override
  String get playbackModeDuckDesc =>
      'Lain lowers its volume while other apps play audio and restores it when they stop.';

  @override
  String get playbackModeMixDesc =>
      'Lain\'s audio is mixed with other apps\' audio.';

  @override
  String get playbackModeNotice => 'Notes';

  @override
  String get playbackModeScenarios => 'Use Cases';

  @override
  String get playbackModeNoticeInCar =>
      'Smart Ducking is recommended in car mode.';

  @override
  String get playbackModeNoticeNavigation =>
      'Music volume is lowered automatically during navigation voice prompts.';

  @override
  String get playbackModeNoticeDesktop =>
      'The desktop version uses Mixed by default.';

  @override
  String get scenarioDailyListening => 'Everyday listening';

  @override
  String get scenarioDailyListeningMode => 'Exclusive';

  @override
  String get scenarioNavigation => 'Driving with navigation';

  @override
  String get scenarioNavigationMode => 'Smart Ducking';

  @override
  String get scenarioGaming => 'Game background music';

  @override
  String get scenarioGamingMode => 'Mixed';

  @override
  String get scenarioArrow => '→';

  @override
  String get playbackModeDesktopNote =>
      'Exclusive playback is not supported on desktop; the selection is treated as Mixed.';

  @override
  String get comment => 'Comments';

  @override
  String get comments => 'Comments';

  @override
  String get commentSettings => 'Comment settings';

  @override
  String get commentSwitch => 'Comment display';

  @override
  String get commentSwitchDesc =>
      'Shows a comment entry on the now-playing bar once a comment server is configured.';

  @override
  String get commentServer => 'Comment server';

  @override
  String get commentServers => 'Comment servers';

  @override
  String get addCommentServer => 'Add comment server';

  @override
  String get commentServerName => 'Server name';

  @override
  String get protocol => 'Protocol';

  @override
  String get commentTokenHint =>
      'Optional; needed only when the server has a username or password';

  @override
  String get commentNoServer => 'No comment server configured';

  @override
  String get commentNoServerHint =>
      'Add a comment server in the settings to read comments';

  @override
  String get commentEmpty => 'No comments yet';

  @override
  String get commentLoadFailed => 'Failed to load comments';

  @override
  String get commentRetry => 'Retry';

  @override
  String get commentReplies => 'replies';

  @override
  String commentShowReplies(int count) {
    return 'Show $count replies';
  }

  @override
  String get commentHideReplies => 'Hide replies';

  @override
  String get commentPagePrevious => 'Previous';

  @override
  String get commentPageNext => 'Next';

  @override
  String commentPageIndicator(int page) {
    return 'Page $page';
  }

  @override
  String get commentUnreachable =>
      'Cannot reach the comment server; check the address or the network';

  @override
  String get commentForbidden =>
      'The server refused the request; check the username and password';

  @override
  String get commentServerError => 'The server returned something unexpected';

  @override
  String commentServerSwitched(String name) {
    return 'Switched to $name';
  }

  @override
  String get commentAtLeastOneAddress =>
      'Fill in at least one of the LAN and public addresses';

  @override
  String get settingsComments => 'Comments';

  @override
  String get commentOn => 'On';

  @override
  String get commentOff => 'Off';

  @override
  String commentOnWithServer(String server) {
    return 'On · $server';
  }

  @override
  String get commentSortRecommended => 'Recommended';

  @override
  String get commentSortHot => 'Hot';

  @override
  String get commentSortTime => 'Latest';

  @override
  String commentMatchedSong(String name) {
    return 'Comments of “$name”';
  }

  @override
  String get commentChangeSong => 'Change song';

  @override
  String get commentMismatchTitle => 'These comments belong to another song';

  @override
  String commentMismatchDetail(String name) {
    return 'The server matched this track with “$name”, which does not look right. Pick the matching song to read its comments.';
  }

  @override
  String get commentPickSong => 'Pick a song';

  @override
  String get commentSearchTitle => 'Search songs';

  @override
  String get commentSearchHint => 'Song name / artist';

  @override
  String get commentSearchEmpty => 'No songs found';

  @override
  String get commentSongNotFound => 'The comment server did not find this song';

  @override
  String commentTotalCount(int count) {
    return '$count comments';
  }

  @override
  String commentPageOf(int page, int pageCount) {
    return 'Page $page of $pageCount';
  }

  @override
  String get commentShowMoreReplies => 'Show more replies';

  @override
  String get statsCard => 'Stats';

  @override
  String get serverStatus => 'Server status';

  @override
  String get serverInfo => 'Server info';

  @override
  String get mediaStats => 'Media library';

  @override
  String get statsSongs => 'Songs';

  @override
  String get totalSize => 'Total size';

  @override
  String get serverVersion => 'Server version';

  @override
  String get subsonicApiVersion => 'Subsonic API';

  @override
  String get openSubsonic => 'Open Subsonic';

  @override
  String get supported => 'Supported';

  @override
  String get notSupported => 'Not supported';

  @override
  String get status => 'Status';

  @override
  String latencyMs(int ms) {
    return 'Latency $ms ms';
  }

  @override
  String latencyValue(int ms) {
    return '$ms ms';
  }

  @override
  String get customDomain => 'Custom domain';

  @override
  String get showAddress => 'Show full address';

  @override
  String get hideAddress => 'Hide address';

  @override
  String get speedFirst => 'Speed first';

  @override
  String get speedFirstDescription =>
      'When on, the app picks the reachable route with the lowest latency; when off, the manual priority order is kept.';

  @override
  String get scanStatus => 'Scan status';

  @override
  String get lastScanTime => 'Last scan';

  @override
  String get scanning => 'Scanning';

  @override
  String get scanCompleted => 'Completed';

  @override
  String get activeStreams => 'Active streams';

  @override
  String get transcoding => 'Transcoding';

  @override
  String get serverOs => 'System';

  @override
  String get systemUpdate => 'System update';

  @override
  String get updateAvailable => 'Update available';

  @override
  String get upToDate => 'Up to date';

  @override
  String get hoursUnit => 'h';

  @override
  String get daysUnit => 'd';

  @override
  String librarySizeGB(String size) {
    return '$size GB';
  }

  @override
  String libraryDurationHours(String hours, String unit) {
    return '$hours $unit';
  }

  @override
  String get localLibraryTools => 'Local Library Tools';

  @override
  String get localLibraryToolsHint => 'Name, organize and complete tags';

  @override
  String get organizeSection => 'Organize';

  @override
  String get browseSection => 'Browse';

  @override
  String get namingFormat => 'Naming Format';

  @override
  String get directorySection => 'Folder';

  @override
  String get filenameSection => 'File Name';

  @override
  String get previewSection => 'Preview';

  @override
  String get directoryTemplate => 'Folder Template';

  @override
  String get filenameTemplate => 'File Name Template';

  @override
  String get keepFeat => 'Keep feat. Credit';

  @override
  String namingPlaceholders(String placeholders) {
    return 'Available placeholders: $placeholders';
  }

  @override
  String get namingSlashHelp =>
      'A / in the template creates a folder level; a / inside a tag value is replaced with an underscore. The file name template must contain the title placeholder.';

  @override
  String get templateEmpty => 'The template cannot be empty';

  @override
  String get templateNeedsTitle =>
      'The file name template must contain the title placeholder';

  @override
  String get templateAbsolute => 'Absolute paths are not allowed';

  @override
  String get templateParentSegment => 'A \'..\' path segment is not allowed';

  @override
  String get templateUnknownPlaceholder =>
      'The template contains an unknown placeholder';

  @override
  String get invalidTemplate => 'Invalid template';

  @override
  String get restoreDefaultFormat => 'Restore Defaults';

  @override
  String get exampleSong => 'Example song';

  @override
  String get currentPath => 'Current';

  @override
  String get organizedPath => 'Organized';

  @override
  String get organizeFiles => 'Organize Files';

  @override
  String get organizeFilesHint => 'Preview, then move files';

  @override
  String get organizeFile => 'Organize File';

  @override
  String get organizeSelected => 'Organize Selected';

  @override
  String get startOrganizing => 'Start Organizing';

  @override
  String get overview => 'Overview';

  @override
  String get directoryPreview => 'Folder Preview';

  @override
  String get changeList => 'Changes';

  @override
  String get organizeNormal => 'Normal';

  @override
  String get organizeSkip => 'Skip';

  @override
  String get organizeConflict => 'Conflict';

  @override
  String get organizeBlocked => 'Not Allowed';

  @override
  String get organizeReasonUnchanged => 'Already correct';

  @override
  String get organizeReasonTargetExists => 'Target exists';

  @override
  String get organizeReasonMissingFile => 'File missing';

  @override
  String get organizeReasonMissingPath => 'No path';

  @override
  String get organizeReasonOutsideLibrary => 'Outside the configured folders';

  @override
  String get organizeReasonFileProvider =>
      'File-provider paths cannot be moved';

  @override
  String get organizeReasonPathTooLong => 'Path too long';

  @override
  String get organizeReasonTargetIsFolder => 'Target is a folder';

  @override
  String get organizeReasonInvalidTemplate => 'Invalid naming template';

  @override
  String organizeResultMessage(int moved, int skipped, int failed) {
    return 'Moved $moved, skipped $skipped, failed $failed';
  }

  @override
  String organizeStopped(int moved) {
    return 'Stopped after $moved files';
  }

  @override
  String get organizing => 'Organizing';

  @override
  String get undoOrganize => 'Undo This Organize';

  @override
  String get undoSuccessfully => 'Undone';

  @override
  String get undoFailed => 'Could not undo';

  @override
  String get metadataCompletion => 'Metadata Completion';

  @override
  String songsMissingTags(int count) {
    return '$count songs are missing tags';
  }

  @override
  String get batchSearchSelected => 'Search Selected';

  @override
  String get batchSearchTags => 'Search Tags in Batch';

  @override
  String batchSearching(int done, int total) {
    return 'Searching $done / $total';
  }

  @override
  String get filterMissingTags => 'Missing Tags';

  @override
  String get filterMissingTagsOrCover => 'Tags or Cover';

  @override
  String get filterAllIncomplete => 'All Incomplete';

  @override
  String get allMetadataComplete => 'Every song\'s metadata is complete';

  @override
  String selectedCount(int count) {
    return '$count selected';
  }

  @override
  String get missingTitle => 'No title';

  @override
  String get missingArtist => 'No artist';

  @override
  String get missingAlbum => 'No album';

  @override
  String get missingCover => 'No cover';

  @override
  String get missingLyrics => 'No lyrics';

  @override
  String get searchTags => 'Search Tags';

  @override
  String get search => 'Search';

  @override
  String get scrapeFillEmpty => 'Fill Empty Only';

  @override
  String get overwriteTags => 'Overwrite Existing Tags';

  @override
  String get writeCoverToo => 'Write Cover Too';

  @override
  String get writeLyricsToo => 'Write Lyrics Too';

  @override
  String get nextBatch => 'Next Batch';

  @override
  String get noMoreResults => 'No more results from this source';

  @override
  String get noSearchResults => 'No results';

  @override
  String get coverSkipped =>
      'The cover format is not supported and was skipped';

  @override
  String get matchScore => 'Match';

  @override
  String get changes => 'Changes';

  @override
  String get apply => 'Apply';

  @override
  String get applySelected => 'Apply Selected';

  @override
  String get batchReview => 'Batch Results';

  @override
  String batchApplied(int count) {
    return 'Applied to $count songs';
  }

  @override
  String get nextCandidate => 'Another';

  @override
  String get syncingWait => 'Syncing; please try again shortly';

  @override
  String get lyricTimeline => 'Edit Lyrics';

  @override
  String get lyricTimelineHint => 'Adjust LRC timestamps line by line';

  @override
  String get progress => 'Progress';

  @override
  String get stamp => 'Stamp';

  @override
  String get playbackOffset => 'Playback Offset';

  @override
  String get bakeOffset => 'Apply Offset and Reset';

  @override
  String get wordTimestamps => 'Word Timestamps';

  @override
  String get stripWordTimestamps => 'Remove Word Timestamps';

  @override
  String get ttmlNotEditable =>
      'This lyric is TTML; line-level timeline editing is not supported';

  @override
  String get noLyricLines => 'No lyric lines yet';

  @override
  String get addLine => 'Add a Line';

  @override
  String get addSecondaryLine => 'Add Secondary Line';

  @override
  String get addLineBelow => 'Add Line Below';

  @override
  String get discardChanges => 'Discard Changes';

  @override
  String get invalidTimeFormat => 'Invalid time format';

  @override
  String get saveSuccessfully => 'Saved';

  @override
  String get saveFailed => 'Save failed';

  @override
  String get sidecarUpdateFailed =>
      'Tags saved; the sidecar could not be updated';

  @override
  String get editLyricTimeline => 'Edit Lyrics';

  @override
  String get albumTimeline => 'Album Timeline';

  @override
  String get albumTimelineHint => 'Browse albums by added time';

  @override
  String get lastMonth => 'Last Month';

  @override
  String get lastQuarter => 'Last 3 Months';

  @override
  String get allTime => 'All';

  @override
  String get noAlbumsInRange => 'No albums added in this period';

  @override
  String albumsMissingCreated(int count) {
    return '$count albums have no added time';
  }

  @override
  String albumTimelineAddedCount(int count) {
    return '+$count songs';
  }

  @override
  String albumTimelineSongCount(int count) {
    return '$count songs';
  }

  @override
  String get viewAll => 'View All';

  @override
  String get stop => 'Stop';

  @override
  String get retry => 'Retry';

  @override
  String get actions => 'Actions';

  @override
  String get organizeFolder => 'Organize Folder';

  @override
  String get organizeDone => 'Organized';

  @override
  String get organizeComplete => 'Complete';

  @override
  String get organizePending => 'Not processed';

  @override
  String get undoApply => 'Undo This Apply';

  @override
  String get previousCard => 'Previous';

  @override
  String get nextCard => 'Next';

  @override
  String get scrapeLongPressHint => 'Long-press a card to apply it directly';

  @override
  String get organizeFailed => 'Failed';

  @override
  String get applyCurrent => 'Apply This';

  @override
  String get applyAllBest => 'Apply All Best';

  @override
  String songPosition(int index, int total) {
    return 'Song $index of $total';
  }

  @override
  String get jumpToSong => 'Choose a Song';

  @override
  String get previousSong => 'Previous Song';

  @override
  String get nextSong => 'Next Song';

  @override
  String resultsCount(int count) {
    return '$count results';
  }

  @override
  String get searchLyrics => 'Search Lyrics';

  @override
  String get restoreLyrics => 'Restore Lyrics';

  @override
  String get lyricsPreview => 'Lyrics Preview';

  @override
  String get copyText => 'Copy Text';

  @override
  String get fileName => 'File Name';

  @override
  String get copied => 'Copied';

  @override
  String get replayGain => 'Replay gain';

  @override
  String get replayGainOff => 'Off (file level)';

  @override
  String get replayGainTrack => 'Per track';

  @override
  String get replayGainAlbum => 'Per album';

  @override
  String get replayGainDescription =>
      'Use the loudness tags in the files so tracks from different albums do not jump in volume.';

  @override
  String get playbackSpeed => 'Playback speed';

  @override
  String get audioFade => 'Fade in and out';

  @override
  String get audioFadeDescription =>
      'Ramp the volume in when playback starts and out when it pauses or the track changes.';

  @override
  String get queueCleared => 'Queue cleared';

  @override
  String get undo => 'Undo';

  @override
  String get scanNow => 'Scan library now';

  @override
  String get scanNowConfirm => 'Ask the server to scan its music folders now?';

  @override
  String get scanStarted => 'Scan started';

  @override
  String get operationFailed => 'Operation failed';

  @override
  String get autoScanLibrary => 'Auto scan library';

  @override
  String get autoScanDescription =>
      'Check the folders after launch and on a timer. Only files whose modified time changed are read again.';

  @override
  String get scanInterval => 'Scan interval';

  @override
  String scanIntervalMinutes(int minutes) {
    return 'Every $minutes min';
  }

  @override
  String scanIntervalHours(int hours) {
    return 'Every $hours h';
  }

  @override
  String get offlineLibrarySource => 'Offline library';

  @override
  String get offlineLibraryLocal => 'Local music library';

  @override
  String get offlineLibraryCached => 'Cached songs of the server';

  @override
  String offlineLibraryCachedDetail(int count) {
    return '$count songs already on disk';
  }

  @override
  String get offlineChooseLibrary => 'Which library should offline mode use?';

  @override
  String get noServerForOffline => 'No server available for the cached library';

  @override
  String get libraryHealth => 'Library checkup';

  @override
  String get healthMissingTags => 'Missing tags';

  @override
  String get healthMissingCover => 'No cover';

  @override
  String get healthMissingLyrics => 'No lyrics';

  @override
  String get healthDuplicates => 'Duplicates';

  @override
  String healthTotal(int count) {
    return '$count local songs';
  }

  @override
  String get healthClean => 'Nothing to fix';

  @override
  String get healthNoMissingTags => 'Every song has a title, artist and album';

  @override
  String get healthNoMissingCover => 'Every song has a cover';

  @override
  String get healthNoMissingLyrics => 'Every song has lyrics';

  @override
  String get healthNoDuplicates => 'No duplicate songs found';

  @override
  String healthFileCount(int count) {
    return '$count files';
  }

  @override
  String get playbackSettings => 'Playback settings';

  @override
  String get searchTagsHint =>
      'Search NetEase and QQ Music, then apply a match';

  @override
  String get tagInformation => 'Tag information';

  @override
  String get audioInformation => 'Audio information';

  @override
  String get playbackReport => 'Report playback progress';

  @override
  String get playbackReportDescription =>
      'Keep the server’s now-playing entry and position up to date; turn off to stop the periodic reports.';

  @override
  String get randomSongs => 'Random songs';

  @override
  String get randomSongsHint =>
      'A fresh set of 100 songs each time it is refreshed';

  @override
  String get useServerRandom => 'Use server random list';

  @override
  String get useServerRandomDescription =>
      'On: ask the server for a random selection. Off: draw from the songs already saved on this device. Falls back to the local list when the server cannot answer.';

  @override
  String get viewComments => 'View comments';

  @override
  String get lyricsCoverMotion => 'Lyrics cover motion';

  @override
  String get playerCoverStyle => 'Player cover style';

  @override
  String get coverStyleSquare => 'Square cover';

  @override
  String get coverStyleVinyl => 'Vinyl record';

  @override
  String get lyricShareCard => 'Share lyric card';

  @override
  String get annualReport => 'Year in review';

  @override
  String get share => 'Share';

  @override
  String savedTo(String path) {
    return 'Saved to $path';
  }

  @override
  String get annualDaysMusic => 'days with music';

  @override
  String get annualTopArtist => 'Artist of the year';

  @override
  String get annualTopAlbum => 'Album of the year';

  @override
  String get annualTopSong => 'Song of the year';

  @override
  String get annualMonthly => 'Monthly rhythm';

  @override
  String get annualBestMonth => 'Most played month';

  @override
  String annualStreak(int days) {
    return 'Longest streak: $days days in a row';
  }

  @override
  String get annualNoData => 'Not enough listening data for this year yet';

  @override
  String get shareCardSettings => 'Share card';

  @override
  String get shareCardTopText => 'Top text';

  @override
  String get shareCardBackground => 'Background';

  @override
  String get shareCardTextSize => 'Lyric text size';

  @override
  String get shareCardCoverSize => 'Cover size';

  @override
  String get shareCardShowTranslation => 'Show translation';

  @override
  String get shareCardBlur => 'Soft blur';

  @override
  String get shareCardCrop => 'Cover crop';

  @override
  String get shareCardAurora => 'Aurora';

  @override
  String get shareCardPixelate => 'Mosaic';

  @override
  String get shareCardHalftone => 'Halftone';

  @override
  String get similarArtists => 'Similar artists';

  @override
  String get moreFromArtist => 'More from this artist';

  @override
  String get audioQualityStats => 'Audio quality';

  @override
  String get cacheStorageStats => 'Cache storage';

  @override
  String get qualityDistribution => 'Quality mix';

  @override
  String get formatDistribution => 'Format mix';

  @override
  String get losslessRatio => 'Lossless share';

  @override
  String get averageBitrate => 'Average bitrate';

  @override
  String get unknownQuality => 'Unclassified';

  @override
  String get hires => 'High-res';

  @override
  String get lossless => 'Lossless';

  @override
  String get lossy => 'Lossy';

  @override
  String get highestQualitySongs => 'Highest quality';

  @override
  String get storageBreakdown => 'Storage mix';

  @override
  String get cacheUsage => 'Cache usage';

  @override
  String get activeTasks => 'Active tasks';

  @override
  String get cacheAudio => 'Audio';

  @override
  String get cacheOther => 'Other';

  @override
  String get largestCached => 'Largest cached songs';

  @override
  String get storageLocation => 'Storage locations';

  @override
  String get downloadedFiles => 'Downloads';

  @override
  String get carDisplay => 'Song broadcast';

  @override
  String get carDisplayLines => 'Lines';

  @override
  String get carLinesTwo => 'Two lines';

  @override
  String get carLinesThree => 'Three lines';

  @override
  String get carLine1 => 'First line';

  @override
  String get carLine2 => 'Second line';

  @override
  String get carLine3 => 'Third line';

  @override
  String get carTokenLyricOriginal => 'Original lyric';

  @override
  String get carTokenLyricTranslation => 'Translation';

  @override
  String get carTokenTitle => 'Song title';

  @override
  String get carTokenArtist => 'Artist';

  @override
  String get carTokenAlbum => 'Album';

  @override
  String get carAddField => 'Add field';

  @override
  String get carSeparator => 'Separator';

  @override
  String get carSeparatorSpace => 'Space';

  @override
  String get carPreview => 'Preview';

  @override
  String get carReset => 'Reset';

  @override
  String get classicCoverMode => 'Classic Bluetooth cover';

  @override
  String get classicCoverBitmap => 'Bitmap';

  @override
  String get classicCoverBitmapUri => 'Bitmap + URI';

  @override
  String get classicCoverLarge => 'Original large image';

  @override
  String get classicCoverRelay => 'Bitmap + relay/server URI';

  @override
  String get carTabLayout => 'Layout';

  @override
  String get carTabCover => 'Cover';

  @override
  String get carTabLyrics => 'Lyrics';

  @override
  String get carPreviewBuiltin => 'Built-in';

  @override
  String get carPreviewLive => 'Live';

  @override
  String get carNoSong => 'Nothing is playing';

  @override
  String get pcInspector => 'PC inspector';

  @override
  String get debug => 'Debug';

  @override
  String get currentBroadcast => 'Current broadcast';
}
