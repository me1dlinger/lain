import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @lain.
  ///
  /// In en, this message translates to:
  /// **'Lain'**
  String get lain;

  /// No description provided for @title.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get title;

  /// No description provided for @artist.
  ///
  /// In en, this message translates to:
  /// **'Artist'**
  String get artist;

  /// No description provided for @album.
  ///
  /// In en, this message translates to:
  /// **'Album'**
  String get album;

  /// No description provided for @albumArtist.
  ///
  /// In en, this message translates to:
  /// **'Album Artist'**
  String get albumArtist;

  /// No description provided for @genre.
  ///
  /// In en, this message translates to:
  /// **'Genre'**
  String get genre;

  /// No description provided for @year.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get year;

  /// No description provided for @track.
  ///
  /// In en, this message translates to:
  /// **'Track'**
  String get track;

  /// No description provided for @disc.
  ///
  /// In en, this message translates to:
  /// **'Disc'**
  String get disc;

  /// No description provided for @lyrics.
  ///
  /// In en, this message translates to:
  /// **'Lyrics'**
  String get lyrics;

  /// No description provided for @folder.
  ///
  /// In en, this message translates to:
  /// **'Folder'**
  String get folder;

  /// No description provided for @frequently.
  ///
  /// In en, this message translates to:
  /// **'Most Played'**
  String get frequently;

  /// No description provided for @recently.
  ///
  /// In en, this message translates to:
  /// **'Recently Played'**
  String get recently;

  /// No description provided for @artists.
  ///
  /// In en, this message translates to:
  /// **'Artists'**
  String get artists;

  /// No description provided for @albums.
  ///
  /// In en, this message translates to:
  /// **'Albums'**
  String get albums;

  /// No description provided for @folders.
  ///
  /// In en, this message translates to:
  /// **'Folders'**
  String get folders;

  /// No description provided for @songs.
  ///
  /// In en, this message translates to:
  /// **'Songs'**
  String get songs;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @playlists.
  ///
  /// In en, this message translates to:
  /// **'Playlists'**
  String get playlists;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @playQueue.
  ///
  /// In en, this message translates to:
  /// **'Play Queue'**
  String get playQueue;

  /// No description provided for @followSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow System'**
  String get followSystem;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @settingsMusicSource.
  ///
  /// In en, this message translates to:
  /// **'Music Sources'**
  String get settingsMusicSource;

  /// No description provided for @localMusicSource.
  ///
  /// In en, this message translates to:
  /// **'Local Music Source'**
  String get localMusicSource;

  /// No description provided for @longPressToConfigure.
  ///
  /// In en, this message translates to:
  /// **'Long press to configure'**
  String get longPressToConfigure;

  /// No description provided for @customFolders.
  ///
  /// In en, this message translates to:
  /// **'Custom Folders'**
  String get customFolders;

  /// No description provided for @addCustomFolder.
  ///
  /// In en, this message translates to:
  /// **'Add Custom Folder'**
  String get addCustomFolder;

  /// No description provided for @startScan.
  ///
  /// In en, this message translates to:
  /// **'Start Scan'**
  String get startScan;

  /// No description provided for @scanSubdirectories.
  ///
  /// In en, this message translates to:
  /// **'Scan Subdirectories'**
  String get scanSubdirectories;

  /// No description provided for @blockedFolders.
  ///
  /// In en, this message translates to:
  /// **'Blocked Folders'**
  String get blockedFolders;

  /// No description provided for @addBlockedFolder.
  ///
  /// In en, this message translates to:
  /// **'Add Blocked Folder'**
  String get addBlockedFolder;

  /// No description provided for @noBlockedFolders.
  ///
  /// In en, this message translates to:
  /// **'No blocked folders'**
  String get noBlockedFolders;

  /// No description provided for @skipShortAudio.
  ///
  /// In en, this message translates to:
  /// **'Skip audio under {seconds} seconds'**
  String skipShortAudio(int seconds);

  /// No description provided for @minimumAudioLength.
  ///
  /// In en, this message translates to:
  /// **'Minimum Audio Length'**
  String get minimumAudioLength;

  /// No description provided for @manageStoragePermission.
  ///
  /// In en, this message translates to:
  /// **'Manage External Storage Permission'**
  String get manageStoragePermission;

  /// No description provided for @settingsUserInterface.
  ///
  /// In en, this message translates to:
  /// **'User Interface'**
  String get settingsUserInterface;

  /// No description provided for @settingsPlaybackLyrics.
  ///
  /// In en, this message translates to:
  /// **'Playback & Lyrics'**
  String get settingsPlaybackLyrics;

  /// No description provided for @settingsNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsNotifications;

  /// No description provided for @settingsStartupBackground.
  ///
  /// In en, this message translates to:
  /// **'Startup & Background'**
  String get settingsStartupBackground;

  /// No description provided for @settingsCacheDownloads.
  ///
  /// In en, this message translates to:
  /// **'Cache & Downloads'**
  String get settingsCacheDownloads;

  /// No description provided for @settingsHelpFeedback.
  ///
  /// In en, this message translates to:
  /// **'Help & Feedback'**
  String get settingsHelpFeedback;

  /// No description provided for @feedback.
  ///
  /// In en, this message translates to:
  /// **'Feedback'**
  String get feedback;

  /// No description provided for @customizeSettingsOrder.
  ///
  /// In en, this message translates to:
  /// **'Customize Menu Order'**
  String get customizeSettingsOrder;

  /// No description provided for @offlineMode.
  ///
  /// In en, this message translates to:
  /// **'Offline Mode'**
  String get offlineMode;

  /// No description provided for @offlineModeDescription.
  ///
  /// In en, this message translates to:
  /// **'Local music only; online sources are locked'**
  String get offlineModeDescription;

  /// No description provided for @offlineModeBlocked.
  ///
  /// In en, this message translates to:
  /// **'Offline mode is on; online music sources are locked'**
  String get offlineModeBlocked;

  /// No description provided for @lanDirect.
  ///
  /// In en, this message translates to:
  /// **'LAN direct'**
  String get lanDirect;

  /// No description provided for @lanDirectDescription.
  ///
  /// In en, this message translates to:
  /// **'Direct to the server on the LAN: no transcode, no cache'**
  String get lanDirectDescription;

  /// No description provided for @reload.
  ///
  /// In en, this message translates to:
  /// **'Reload'**
  String get reload;

  /// No description provided for @manageMusicFolder.
  ///
  /// In en, this message translates to:
  /// **'Manage Music Folders'**
  String get manageMusicFolder;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @openSourceLicense.
  ///
  /// In en, this message translates to:
  /// **'Open Source License'**
  String get openSourceLicense;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @sleepTimer.
  ///
  /// In en, this message translates to:
  /// **'Sleep Timer'**
  String get sleepTimer;

  /// No description provided for @pauseAfterCurrentTrack.
  ///
  /// In en, this message translates to:
  /// **'Pause After Current Track'**
  String get pauseAfterCurrentTrack;

  /// No description provided for @vibration.
  ///
  /// In en, this message translates to:
  /// **'Vibration'**
  String get vibration;

  /// No description provided for @library.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get library;

  /// No description provided for @select.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get select;

  /// No description provided for @sortSongs.
  ///
  /// In en, this message translates to:
  /// **'Sort Songs'**
  String get sortSongs;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @createPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Create Playlist'**
  String get createPlaylist;

  /// No description provided for @order.
  ///
  /// In en, this message translates to:
  /// **'Order'**
  String get order;

  /// No description provided for @reorder.
  ///
  /// In en, this message translates to:
  /// **'Reorder'**
  String get reorder;

  /// No description provided for @songCount.
  ///
  /// In en, this message translates to:
  /// **'{count} songs'**
  String songCount(int count);

  /// No description provided for @artistCount.
  ///
  /// In en, this message translates to:
  /// **'{count} in total'**
  String artistCount(int count);

  /// No description provided for @albumCount.
  ///
  /// In en, this message translates to:
  /// **'{count} in total'**
  String albumCount(int count);

  /// No description provided for @playlistCount.
  ///
  /// In en, this message translates to:
  /// **'{count} in total'**
  String playlistCount(int count);

  /// No description provided for @folderCount.
  ///
  /// In en, this message translates to:
  /// **'{count} in total'**
  String folderCount(int count);

  /// No description provided for @settingCount.
  ///
  /// In en, this message translates to:
  /// **'{count} in total'**
  String settingCount(int count);

  /// No description provided for @fontCount.
  ///
  /// In en, this message translates to:
  /// **'{count} in total'**
  String fontCount(int count);

  /// No description provided for @searchSongs.
  ///
  /// In en, this message translates to:
  /// **'Search Songs'**
  String get searchSongs;

  /// No description provided for @searchArtists.
  ///
  /// In en, this message translates to:
  /// **'Search Artists'**
  String get searchArtists;

  /// No description provided for @searchAlbums.
  ///
  /// In en, this message translates to:
  /// **'Search Albums'**
  String get searchAlbums;

  /// No description provided for @searchPlaylists.
  ///
  /// In en, this message translates to:
  /// **'Search Playlists'**
  String get searchPlaylists;

  /// No description provided for @searchLicenses.
  ///
  /// In en, this message translates to:
  /// **'Search Licenses'**
  String get searchLicenses;

  /// No description provided for @searchHome.
  ///
  /// In en, this message translates to:
  /// **'albums/songs/playlists'**
  String get searchHome;

  /// No description provided for @ascending.
  ///
  /// In en, this message translates to:
  /// **'Ascending'**
  String get ascending;

  /// No description provided for @descending.
  ///
  /// In en, this message translates to:
  /// **'Descending'**
  String get descending;

  /// No description provided for @pictureSize.
  ///
  /// In en, this message translates to:
  /// **'Picture Size'**
  String get pictureSize;

  /// No description provided for @large.
  ///
  /// In en, this message translates to:
  /// **'Large'**
  String get large;

  /// No description provided for @small.
  ///
  /// In en, this message translates to:
  /// **'Small'**
  String get small;

  /// No description provided for @view.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get view;

  /// No description provided for @list.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get list;

  /// No description provided for @grid.
  ///
  /// In en, this message translates to:
  /// **'Grid'**
  String get grid;

  /// No description provided for @favorited.
  ///
  /// In en, this message translates to:
  /// **'Favorited'**
  String get favorited;

  /// No description provided for @favorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favorites;

  /// No description provided for @duration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get duration;

  /// No description provided for @times.
  ///
  /// In en, this message translates to:
  /// **'Times'**
  String get times;

  /// No description provided for @loop.
  ///
  /// In en, this message translates to:
  /// **'Loop'**
  String get loop;

  /// No description provided for @shuffle.
  ///
  /// In en, this message translates to:
  /// **'Shuffle'**
  String get shuffle;

  /// No description provided for @repeat.
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get repeat;

  /// No description provided for @holdForRepeatOne.
  ///
  /// In en, this message translates to:
  /// **'Hold: repeat one'**
  String get holdForRepeatOne;

  /// No description provided for @playAll.
  ///
  /// In en, this message translates to:
  /// **'Play All'**
  String get playAll;

  /// No description provided for @move2Top.
  ///
  /// In en, this message translates to:
  /// **'Move to Top'**
  String get move2Top;

  /// No description provided for @playNow.
  ///
  /// In en, this message translates to:
  /// **'Play Now'**
  String get playNow;

  /// No description provided for @playNext.
  ///
  /// In en, this message translates to:
  /// **'Play Next'**
  String get playNext;

  /// No description provided for @add2Queue.
  ///
  /// In en, this message translates to:
  /// **'Add to Queue'**
  String get add2Queue;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @editMetadata.
  ///
  /// In en, this message translates to:
  /// **'Edit Metadata'**
  String get editMetadata;

  /// No description provided for @add2Playlist.
  ///
  /// In en, this message translates to:
  /// **'Add to Playlist'**
  String get add2Playlist;

  /// No description provided for @added2Playlist.
  ///
  /// In en, this message translates to:
  /// **'Added to playlist'**
  String get added2Playlist;

  /// No description provided for @selectAll.
  ///
  /// In en, this message translates to:
  /// **'Select All'**
  String get selectAll;

  /// No description provided for @complete.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get complete;

  /// No description provided for @continueMsg.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to continue?'**
  String get continueMsg;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @addFolder.
  ///
  /// In en, this message translates to:
  /// **'Add Folder'**
  String get addFolder;

  /// No description provided for @addRecursiveFolder.
  ///
  /// In en, this message translates to:
  /// **'Add Folder and All Subfolders'**
  String get addRecursiveFolder;

  /// No description provided for @replacePicture.
  ///
  /// In en, this message translates to:
  /// **'Replace Picture'**
  String get replacePicture;

  /// No description provided for @unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// No description provided for @updateMedata.
  ///
  /// In en, this message translates to:
  /// **'Update Metadata'**
  String get updateMedata;

  /// No description provided for @defaultText.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get defaultText;

  /// No description provided for @titleAscending.
  ///
  /// In en, this message translates to:
  /// **'Title Ascending'**
  String get titleAscending;

  /// No description provided for @titleDescending.
  ///
  /// In en, this message translates to:
  /// **'Title Descending'**
  String get titleDescending;

  /// No description provided for @artistAscending.
  ///
  /// In en, this message translates to:
  /// **'Artist Ascending'**
  String get artistAscending;

  /// No description provided for @artistDescending.
  ///
  /// In en, this message translates to:
  /// **'Artist Descending'**
  String get artistDescending;

  /// No description provided for @albumAscending.
  ///
  /// In en, this message translates to:
  /// **'Album Ascending'**
  String get albumAscending;

  /// No description provided for @albumDescending.
  ///
  /// In en, this message translates to:
  /// **'Album Descending'**
  String get albumDescending;

  /// No description provided for @durationAscending.
  ///
  /// In en, this message translates to:
  /// **'Duration Ascending'**
  String get durationAscending;

  /// No description provided for @durationDescending.
  ///
  /// In en, this message translates to:
  /// **'Duration Descending'**
  String get durationDescending;

  /// No description provided for @selectSortingType.
  ///
  /// In en, this message translates to:
  /// **'Select sorting type'**
  String get selectSortingType;

  /// No description provided for @loadingFolder.
  ///
  /// In en, this message translates to:
  /// **'Loading Folder'**
  String get loadingFolder;

  /// No description provided for @loadedSongs.
  ///
  /// In en, this message translates to:
  /// **'Loaded Songs'**
  String get loadedSongs;

  /// No description provided for @loadingNavidrome.
  ///
  /// In en, this message translates to:
  /// **'Loading Navidrome'**
  String get loadingNavidrome;

  /// No description provided for @canNotUpdate.
  ///
  /// In en, this message translates to:
  /// **'Can not update the song that is playing'**
  String get canNotUpdate;

  /// No description provided for @updateSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Update Successfully'**
  String get updateSuccessfully;

  /// No description provided for @updateFailed.
  ///
  /// In en, this message translates to:
  /// **'Update failed'**
  String get updateFailed;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @desktopLyrics.
  ///
  /// In en, this message translates to:
  /// **'Desktop Lyrics'**
  String get desktopLyrics;

  /// No description provided for @horizontal.
  ///
  /// In en, this message translates to:
  /// **'Horizontal'**
  String get horizontal;

  /// No description provided for @vertical.
  ///
  /// In en, this message translates to:
  /// **'Vertical'**
  String get vertical;

  /// No description provided for @lock.
  ///
  /// In en, this message translates to:
  /// **'Lock'**
  String get lock;

  /// No description provided for @unlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get unlock;

  /// No description provided for @closeAction.
  ///
  /// In en, this message translates to:
  /// **'Close Action'**
  String get closeAction;

  /// No description provided for @exit.
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get exit;

  /// No description provided for @hide.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get hide;

  /// No description provided for @checkUpdate.
  ///
  /// In en, this message translates to:
  /// **'Check Update'**
  String get checkUpdate;

  /// No description provided for @go2Download.
  ///
  /// In en, this message translates to:
  /// **'Go to Download'**
  String get go2Download;

  /// No description provided for @alreadyLatest.
  ///
  /// In en, this message translates to:
  /// **'Already on the latest version'**
  String get alreadyLatest;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @mainPageTheme.
  ///
  /// In en, this message translates to:
  /// **'Main Page Theme'**
  String get mainPageTheme;

  /// No description provided for @lyricsPageTheme.
  ///
  /// In en, this message translates to:
  /// **'Lyrics Page Theme'**
  String get lyricsPageTheme;

  /// No description provided for @vividMode.
  ///
  /// In en, this message translates to:
  /// **'Vivid Mode'**
  String get vividMode;

  /// No description provided for @lightMode.
  ///
  /// In en, this message translates to:
  /// **'Light Mode'**
  String get lightMode;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get darkMode;

  /// No description provided for @customMode.
  ///
  /// In en, this message translates to:
  /// **'Custom Mode'**
  String get customMode;

  /// No description provided for @local.
  ///
  /// In en, this message translates to:
  /// **'Local'**
  String get local;

  /// No description provided for @switchSource.
  ///
  /// In en, this message translates to:
  /// **'Switch Source'**
  String get switchSource;

  /// No description provided for @manageServers.
  ///
  /// In en, this message translates to:
  /// **'Manage Servers'**
  String get manageServers;

  /// No description provided for @username.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @exportLog.
  ///
  /// In en, this message translates to:
  /// **'Export Log'**
  String get exportLog;

  /// No description provided for @showApp.
  ///
  /// In en, this message translates to:
  /// **'Show App'**
  String get showApp;

  /// No description provided for @skip2Previous.
  ///
  /// In en, this message translates to:
  /// **'Skip to Previous'**
  String get skip2Previous;

  /// No description provided for @skip2Next.
  ///
  /// In en, this message translates to:
  /// **'Skip to Next'**
  String get skip2Next;

  /// No description provided for @playOrPause.
  ///
  /// In en, this message translates to:
  /// **'Play/Pause'**
  String get playOrPause;

  /// No description provided for @unlockDeskLrc.
  ///
  /// In en, this message translates to:
  /// **'Unlock Desktop Lyrics'**
  String get unlockDeskLrc;

  /// No description provided for @autoPlayOnStartup.
  ///
  /// In en, this message translates to:
  /// **'Auto-Play on Startup'**
  String get autoPlayOnStartup;

  /// No description provided for @return2Previous.
  ///
  /// In en, this message translates to:
  /// **'Return to Previous'**
  String get return2Previous;

  /// No description provided for @addedFolders.
  ///
  /// In en, this message translates to:
  /// **'Added Folders'**
  String get addedFolders;

  /// No description provided for @recursiveScan.
  ///
  /// In en, this message translates to:
  /// **'Scan Subfolders'**
  String get recursiveScan;

  /// No description provided for @songInfo.
  ///
  /// In en, this message translates to:
  /// **'Song Info'**
  String get songInfo;

  /// No description provided for @cached.
  ///
  /// In en, this message translates to:
  /// **'Cached'**
  String get cached;

  /// No description provided for @format.
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get format;

  /// No description provided for @bitrate.
  ///
  /// In en, this message translates to:
  /// **'Bitrate'**
  String get bitrate;

  /// No description provided for @samplerate.
  ///
  /// In en, this message translates to:
  /// **'Sample Rate'**
  String get samplerate;

  /// No description provided for @filePath.
  ///
  /// In en, this message translates to:
  /// **'File Path'**
  String get filePath;

  /// No description provided for @path.
  ///
  /// In en, this message translates to:
  /// **'Path'**
  String get path;

  /// No description provided for @go2Artist.
  ///
  /// In en, this message translates to:
  /// **'Go to Artist'**
  String get go2Artist;

  /// No description provided for @go2Album.
  ///
  /// In en, this message translates to:
  /// **'Go to Album'**
  String get go2Album;

  /// No description provided for @equalizer.
  ///
  /// In en, this message translates to:
  /// **'Equalizer'**
  String get equalizer;

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// No description provided for @randomize.
  ///
  /// In en, this message translates to:
  /// **'Randomize'**
  String get randomize;

  /// No description provided for @normal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get normal;

  /// No description provided for @randomizeTemp.
  ///
  /// In en, this message translates to:
  /// **'Randomize(Temporary)'**
  String get randomizeTemp;

  /// No description provided for @randomizePermanent.
  ///
  /// In en, this message translates to:
  /// **'Randomize(Permanent)'**
  String get randomizePermanent;

  /// No description provided for @modifiedTimeAscending.
  ///
  /// In en, this message translates to:
  /// **'Modified Time Ascending'**
  String get modifiedTimeAscending;

  /// No description provided for @modifiedTimedescending.
  ///
  /// In en, this message translates to:
  /// **'Modified Time Descending'**
  String get modifiedTimedescending;

  /// No description provided for @addedTimeAscending.
  ///
  /// In en, this message translates to:
  /// **'Added Time Ascending'**
  String get addedTimeAscending;

  /// No description provided for @streamQuality.
  ///
  /// In en, this message translates to:
  /// **'Streaming Quality'**
  String get streamQuality;

  /// No description provided for @streamQualityStandard.
  ///
  /// In en, this message translates to:
  /// **'Standard (up to 128kbps)'**
  String get streamQualityStandard;

  /// No description provided for @streamQualityHigh.
  ///
  /// In en, this message translates to:
  /// **'High (up to 192kbps)'**
  String get streamQualityHigh;

  /// No description provided for @streamQualityHq.
  ///
  /// In en, this message translates to:
  /// **'HQ (256kbps)'**
  String get streamQualityHq;

  /// No description provided for @streamQualitySq.
  ///
  /// In en, this message translates to:
  /// **'SQ (320kbps)'**
  String get streamQualitySq;

  /// No description provided for @streamQualityOriginal.
  ///
  /// In en, this message translates to:
  /// **'Original (no transcoding)'**
  String get streamQualityOriginal;

  /// No description provided for @streamFormat.
  ///
  /// In en, this message translates to:
  /// **'Transcode Format'**
  String get streamFormat;

  /// No description provided for @mobileDataWarning.
  ///
  /// In en, this message translates to:
  /// **'Cellular Data Warning'**
  String get mobileDataWarning;

  /// No description provided for @mobileDataNotice.
  ///
  /// In en, this message translates to:
  /// **'Streaming online music over mobile data'**
  String get mobileDataNotice;

  /// No description provided for @serverScheme.
  ///
  /// In en, this message translates to:
  /// **'Scheme'**
  String get serverScheme;

  /// No description provided for @serverHost.
  ///
  /// In en, this message translates to:
  /// **'Host'**
  String get serverHost;

  /// No description provided for @serverPort.
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get serverPort;

  /// No description provided for @serverPath.
  ///
  /// In en, this message translates to:
  /// **'Path'**
  String get serverPath;

  /// No description provided for @noData.
  ///
  /// In en, this message translates to:
  /// **'No data'**
  String get noData;

  /// No description provided for @popularSongs.
  ///
  /// In en, this message translates to:
  /// **'Top Songs'**
  String get popularSongs;

  /// No description provided for @popularAlbums.
  ///
  /// In en, this message translates to:
  /// **'Top Albums'**
  String get popularAlbums;

  /// No description provided for @timesUnit.
  ///
  /// In en, this message translates to:
  /// **'times'**
  String get timesUnit;

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @exportPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Export playlist'**
  String get exportPlaylist;

  /// No description provided for @exported.
  ///
  /// In en, this message translates to:
  /// **'Exported to'**
  String get exported;

  /// No description provided for @exportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed'**
  String get exportFailed;

  /// No description provided for @download.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

  /// No description provided for @downloads.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get downloads;

  /// No description provided for @downloadWaitingForWifi.
  ///
  /// In en, this message translates to:
  /// **'Queued; it will start on Wi-Fi'**
  String get downloadWaitingForWifi;

  /// No description provided for @downloadResumedOnWifi.
  ///
  /// In en, this message translates to:
  /// **'On Wi-Fi now, continuing {count} downloads'**
  String downloadResumedOnWifi(int count);

  /// No description provided for @downloadOnMobileData.
  ///
  /// In en, this message translates to:
  /// **'Download over mobile data'**
  String get downloadOnMobileData;

  /// No description provided for @downloadQuality.
  ///
  /// In en, this message translates to:
  /// **'Download quality'**
  String get downloadQuality;

  /// No description provided for @downloadTasks.
  ///
  /// In en, this message translates to:
  /// **'Download queue'**
  String get downloadTasks;

  /// No description provided for @downloadStateWaitingWifi.
  ///
  /// In en, this message translates to:
  /// **'Waiting for Wi-Fi'**
  String get downloadStateWaitingWifi;

  /// No description provided for @downloadStateDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading'**
  String get downloadStateDownloading;

  /// No description provided for @downloadStatePaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get downloadStatePaused;

  /// No description provided for @downloadStateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get downloadStateFailed;

  /// No description provided for @continueDownload.
  ///
  /// In en, this message translates to:
  /// **'Continue downloads'**
  String get continueDownload;

  /// No description provided for @pauseDownload.
  ///
  /// In en, this message translates to:
  /// **'Pause downloads'**
  String get pauseDownload;

  /// No description provided for @deleteAllDownloads.
  ///
  /// In en, this message translates to:
  /// **'Delete all'**
  String get deleteAllDownloads;

  /// No description provided for @downloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading…'**
  String get downloading;

  /// No description provided for @downloaded.
  ///
  /// In en, this message translates to:
  /// **'Downloaded'**
  String get downloaded;

  /// No description provided for @downloadAdded.
  ///
  /// In en, this message translates to:
  /// **'Added to downloads'**
  String get downloadAdded;

  /// No description provided for @allCached.
  ///
  /// In en, this message translates to:
  /// **'Everything is cached'**
  String get allCached;

  /// No description provided for @downloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Download failed'**
  String get downloadFailed;

  /// No description provided for @playFailed.
  ///
  /// In en, this message translates to:
  /// **'Playback failed'**
  String get playFailed;

  /// No description provided for @noDownloads.
  ///
  /// In en, this message translates to:
  /// **'Nothing downloaded yet'**
  String get noDownloads;

  /// No description provided for @importPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Import playlist'**
  String get importPlaylist;

  /// No description provided for @enterPath.
  ///
  /// In en, this message translates to:
  /// **'Enter a path'**
  String get enterPath;

  /// No description provided for @importedSongs.
  ///
  /// In en, this message translates to:
  /// **'Imported songs:'**
  String get importedSongs;

  /// No description provided for @noMatchingSongs.
  ///
  /// In en, this message translates to:
  /// **'No song in the library matches the file'**
  String get noMatchingSongs;

  /// No description provided for @fileNotFound.
  ///
  /// In en, this message translates to:
  /// **'File not found'**
  String get fileNotFound;

  /// No description provided for @mostPlayed.
  ///
  /// In en, this message translates to:
  /// **'Most played'**
  String get mostPlayed;

  /// No description provided for @cacheLists.
  ///
  /// In en, this message translates to:
  /// **'List cache'**
  String get cacheLists;

  /// No description provided for @viewCache.
  ///
  /// In en, this message translates to:
  /// **'View Cache'**
  String get viewCache;

  /// No description provided for @cacheTagAudio.
  ///
  /// In en, this message translates to:
  /// **'Song'**
  String get cacheTagAudio;

  /// No description provided for @cacheTagCover.
  ///
  /// In en, this message translates to:
  /// **'Cover'**
  String get cacheTagCover;

  /// No description provided for @cacheTagLyric.
  ///
  /// In en, this message translates to:
  /// **'Lyrics'**
  String get cacheTagLyric;

  /// No description provided for @precacheAll.
  ///
  /// In en, this message translates to:
  /// **'Cache Every Song\'s Info'**
  String get precacheAll;

  /// No description provided for @cacheTaskTitle.
  ///
  /// In en, this message translates to:
  /// **'Caching songs'**
  String get cacheTaskTitle;

  /// No description provided for @cacheBackground.
  ///
  /// In en, this message translates to:
  /// **'Run in Background'**
  String get cacheBackground;

  /// No description provided for @cacheMovedToBackground.
  ///
  /// In en, this message translates to:
  /// **'Caching continues in the background'**
  String get cacheMovedToBackground;

  /// No description provided for @cacheTaskDone.
  ///
  /// In en, this message translates to:
  /// **'Caching finished'**
  String get cacheTaskDone;

  /// No description provided for @cacheTaskCanceled.
  ///
  /// In en, this message translates to:
  /// **'Caching canceled'**
  String get cacheTaskCanceled;

  /// No description provided for @cacheTaskBusy.
  ///
  /// In en, this message translates to:
  /// **'A caching task is already running'**
  String get cacheTaskBusy;

  /// No description provided for @cacheTaskQueued.
  ///
  /// In en, this message translates to:
  /// **'Added to the caching queue'**
  String get cacheTaskQueued;

  /// No description provided for @cacheFailedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} failed'**
  String cacheFailedCount(int count);

  /// No description provided for @cacheBackPrompt.
  ///
  /// In en, this message translates to:
  /// **'Caching is still running. Cancel it or run it in the background?'**
  String get cacheBackPrompt;

  /// No description provided for @cacheKeepRunning.
  ///
  /// In en, this message translates to:
  /// **'Keep Waiting'**
  String get cacheKeepRunning;

  /// No description provided for @added2Next.
  ///
  /// In en, this message translates to:
  /// **'Playing next'**
  String get added2Next;

  /// No description provided for @homeLayout.
  ///
  /// In en, this message translates to:
  /// **'Home layout'**
  String get homeLayout;

  /// No description provided for @homeTopButtons.
  ///
  /// In en, this message translates to:
  /// **'Top buttons'**
  String get homeTopButtons;

  /// No description provided for @homeSections.
  ///
  /// In en, this message translates to:
  /// **'Home sections'**
  String get homeSections;

  /// No description provided for @ignoreCert.
  ///
  /// In en, this message translates to:
  /// **'Ignore certificate'**
  String get ignoreCert;

  /// No description provided for @recentlyAdded.
  ///
  /// In en, this message translates to:
  /// **'Recently Added'**
  String get recentlyAdded;

  /// No description provided for @connectSuccess.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get connectSuccess;

  /// No description provided for @connectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection failed'**
  String get connectionFailed;

  /// No description provided for @trackAscending.
  ///
  /// In en, this message translates to:
  /// **'Track Ascending'**
  String get trackAscending;

  /// No description provided for @trackDescending.
  ///
  /// In en, this message translates to:
  /// **'Track Descending'**
  String get trackDescending;

  /// No description provided for @servers.
  ///
  /// In en, this message translates to:
  /// **'Servers'**
  String get servers;

  /// No description provided for @addServer.
  ///
  /// In en, this message translates to:
  /// **'Add server'**
  String get addServer;

  /// No description provided for @serverName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get serverName;

  /// No description provided for @serverType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get serverType;

  /// No description provided for @publicAddress.
  ///
  /// In en, this message translates to:
  /// **'Public address'**
  String get publicAddress;

  /// No description provided for @lanAddress.
  ///
  /// In en, this message translates to:
  /// **'LAN address'**
  String get lanAddress;

  /// No description provided for @testAndSave.
  ///
  /// In en, this message translates to:
  /// **'Test and save'**
  String get testAndSave;

  /// No description provided for @recheck.
  ///
  /// In en, this message translates to:
  /// **'Check again'**
  String get recheck;

  /// No description provided for @unreachable.
  ///
  /// In en, this message translates to:
  /// **'Unreachable'**
  String get unreachable;

  /// No description provided for @inUse.
  ///
  /// In en, this message translates to:
  /// **'In use'**
  String get inUse;

  /// No description provided for @localMusic.
  ///
  /// In en, this message translates to:
  /// **'Local music'**
  String get localMusic;

  /// No description provided for @serverAddress.
  ///
  /// In en, this message translates to:
  /// **'Server Address'**
  String get serverAddress;

  /// No description provided for @cacheDetails.
  ///
  /// In en, this message translates to:
  /// **'Cache Details'**
  String get cacheDetails;

  /// No description provided for @cacheSongs.
  ///
  /// In en, this message translates to:
  /// **'Cached Songs'**
  String get cacheSongs;

  /// No description provided for @cacheTasks.
  ///
  /// In en, this message translates to:
  /// **'Cache tasks'**
  String get cacheTasks;

  /// No description provided for @cacheWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get cacheWaiting;

  /// No description provided for @noCacheTasks.
  ///
  /// In en, this message translates to:
  /// **'No cache tasks'**
  String get noCacheTasks;

  /// No description provided for @cacheGroup.
  ///
  /// In en, this message translates to:
  /// **'Playlist and artist cache'**
  String get cacheGroup;

  /// No description provided for @autoCacheSongs.
  ///
  /// In en, this message translates to:
  /// **'Auto-cache songs'**
  String get autoCacheSongs;

  /// No description provided for @autoCachePlaylists.
  ///
  /// In en, this message translates to:
  /// **'Auto-cache playlists'**
  String get autoCachePlaylists;

  /// No description provided for @autoCacheArtists.
  ///
  /// In en, this message translates to:
  /// **'Auto-cache artists'**
  String get autoCacheArtists;

  /// No description provided for @cacheDirectory.
  ///
  /// In en, this message translates to:
  /// **'Cache directory'**
  String get cacheDirectory;

  /// No description provided for @downloadDirectory.
  ///
  /// In en, this message translates to:
  /// **'Download directory'**
  String get downloadDirectory;

  /// No description provided for @cacheLimit.
  ///
  /// In en, this message translates to:
  /// **'Cache limit'**
  String get cacheLimit;

  /// No description provided for @cacheLimitUnlimited.
  ///
  /// In en, this message translates to:
  /// **'Unlimited'**
  String get cacheLimitUnlimited;

  /// No description provided for @cacheLimitGb.
  ///
  /// In en, this message translates to:
  /// **'{gb} GB'**
  String cacheLimitGb(int gb);

  /// No description provided for @moveCacheToNewDirectory.
  ///
  /// In en, this message translates to:
  /// **'Move the existing cache to the new folder?'**
  String get moveCacheToNewDirectory;

  /// No description provided for @moveDownloadsToNewDirectory.
  ///
  /// In en, this message translates to:
  /// **'Move the downloaded songs to the new folder?'**
  String get moveDownloadsToNewDirectory;

  /// No description provided for @cacheDirectoryChanged.
  ///
  /// In en, this message translates to:
  /// **'Cache directory updated'**
  String get cacheDirectoryChanged;

  /// No description provided for @storagePermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Storage permission is required for that folder'**
  String get storagePermissionDenied;

  /// No description provided for @downloadDirectoryChanged.
  ///
  /// In en, this message translates to:
  /// **'Download directory updated'**
  String get downloadDirectoryChanged;

  /// No description provided for @cacheCovers.
  ///
  /// In en, this message translates to:
  /// **'Covers'**
  String get cacheCovers;

  /// No description provided for @cacheLyrics.
  ///
  /// In en, this message translates to:
  /// **'Lyrics'**
  String get cacheLyrics;

  /// No description provided for @cacheTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get cacheTotal;

  /// No description provided for @cacheEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing cached yet'**
  String get cacheEmpty;

  /// No description provided for @removeCache.
  ///
  /// In en, this message translates to:
  /// **'Remove from cache'**
  String get removeCache;

  /// No description provided for @listeningReport.
  ///
  /// In en, this message translates to:
  /// **'Listening Report'**
  String get listeningReport;

  /// No description provided for @yearlyActivity.
  ///
  /// In en, this message translates to:
  /// **'Yearly Activity'**
  String get yearlyActivity;

  /// No description provided for @playRanking.
  ///
  /// In en, this message translates to:
  /// **'Most Played'**
  String get playRanking;

  /// No description provided for @yearlyStats.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get yearlyStats;

  /// No description provided for @topArtists.
  ///
  /// In en, this message translates to:
  /// **'Top Artists'**
  String get topArtists;

  /// No description provided for @listeningTime.
  ///
  /// In en, this message translates to:
  /// **'Listening Time'**
  String get listeningTime;

  /// No description provided for @playTimes.
  ///
  /// In en, this message translates to:
  /// **'Plays'**
  String get playTimes;

  /// No description provided for @listeningDays.
  ///
  /// In en, this message translates to:
  /// **'Active Days'**
  String get listeningDays;

  /// No description provided for @songsTotal.
  ///
  /// In en, this message translates to:
  /// **'Songs'**
  String get songsTotal;

  /// No description provided for @albumsTotal.
  ///
  /// In en, this message translates to:
  /// **'Albums'**
  String get albumsTotal;

  /// No description provided for @heatLess.
  ///
  /// In en, this message translates to:
  /// **'Less'**
  String get heatLess;

  /// No description provided for @heatMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get heatMore;

  /// No description provided for @allSources.
  ///
  /// In en, this message translates to:
  /// **'All Sources'**
  String get allSources;

  /// No description provided for @addedTimeDescending.
  ///
  /// In en, this message translates to:
  /// **'Added Time Descending'**
  String get addedTimeDescending;

  /// No description provided for @cannotBeUndone.
  ///
  /// In en, this message translates to:
  /// **'Cannot be Undone'**
  String get cannotBeUndone;

  /// No description provided for @clearCache.
  ///
  /// In en, this message translates to:
  /// **'Clear Cache'**
  String get clearCache;

  /// No description provided for @clearCacheConfirm.
  ///
  /// In en, this message translates to:
  /// **'Clear all cached songs?'**
  String get clearCacheConfirm;

  /// No description provided for @clearCacheConfirmAgain.
  ///
  /// In en, this message translates to:
  /// **'Confirm again: cleared songs cannot be restored'**
  String get clearCacheConfirmAgain;

  /// No description provided for @tapAgain.
  ///
  /// In en, this message translates to:
  /// **'Tap Again to Exit'**
  String get tapAgain;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @fonts.
  ///
  /// In en, this message translates to:
  /// **'Fonts'**
  String get fonts;

  /// No description provided for @searchFonts.
  ///
  /// In en, this message translates to:
  /// **'Search Fonts'**
  String get searchFonts;

  /// No description provided for @setFontName.
  ///
  /// In en, this message translates to:
  /// **'Set Font Name'**
  String get setFontName;

  /// No description provided for @setFont.
  ///
  /// In en, this message translates to:
  /// **'Set Font'**
  String get setFont;

  /// No description provided for @restoreDefault.
  ///
  /// In en, this message translates to:
  /// **'Restore Default'**
  String get restoreDefault;

  /// No description provided for @addFont.
  ///
  /// In en, this message translates to:
  /// **'Add Font'**
  String get addFont;

  /// No description provided for @deleteFont.
  ///
  /// In en, this message translates to:
  /// **'Delete Font'**
  String get deleteFont;

  /// No description provided for @currentFont.
  ///
  /// In en, this message translates to:
  /// **'Current Font'**
  String get currentFont;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @syncLibrary.
  ///
  /// In en, this message translates to:
  /// **'Synchronize Library'**
  String get syncLibrary;

  /// No description provided for @syncingTryLater.
  ///
  /// In en, this message translates to:
  /// **'Syncing library, try again later'**
  String get syncingTryLater;

  /// No description provided for @syncDone.
  ///
  /// In en, this message translates to:
  /// **'Library synced'**
  String get syncDone;

  /// No description provided for @syncFailed.
  ///
  /// In en, this message translates to:
  /// **'Sync failed'**
  String get syncFailed;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @folderExist.
  ///
  /// In en, this message translates to:
  /// **'The folder already exist'**
  String get folderExist;

  /// No description provided for @folderNotSupportedYet.
  ///
  /// In en, this message translates to:
  /// **'The folder is not supported yet'**
  String get folderNotSupportedYet;

  /// No description provided for @getPermissionFailed.
  ///
  /// In en, this message translates to:
  /// **'Get permission failed'**
  String get getPermissionFailed;

  /// No description provided for @premiumFeatures.
  ///
  /// In en, this message translates to:
  /// **'Premium Features'**
  String get premiumFeatures;

  /// No description provided for @premiumDescription.
  ///
  /// In en, this message translates to:
  /// **'Enjoy the full experience and support ongoing development'**
  String get premiumDescription;

  /// No description provided for @unlockPremium.
  ///
  /// In en, this message translates to:
  /// **'Unlock Premium Features'**
  String get unlockPremium;

  /// No description provided for @restorePurchase.
  ///
  /// In en, this message translates to:
  /// **'Restore Purchases'**
  String get restorePurchase;

  /// No description provided for @whatPremiumContains.
  ///
  /// In en, this message translates to:
  /// **'What\'s Included'**
  String get whatPremiumContains;

  /// No description provided for @themeDescription.
  ///
  /// In en, this message translates to:
  /// **'Unlock Vivid Mode for the Main Page'**
  String get themeDescription;

  /// No description provided for @fontDescription.
  ///
  /// In en, this message translates to:
  /// **'Use custom fonts'**
  String get fontDescription;

  /// No description provided for @equalizerDescription.
  ///
  /// In en, this message translates to:
  /// **'Adjust audio levels across different frequencies'**
  String get equalizerDescription;

  /// No description provided for @widgets.
  ///
  /// In en, this message translates to:
  /// **'Home Screen Widgets'**
  String get widgets;

  /// No description provided for @widgetsDescription.
  ///
  /// In en, this message translates to:
  /// **'Show Now Playing and your playlists on the Home Screen'**
  String get widgetsDescription;

  /// No description provided for @futurePremium.
  ///
  /// In en, this message translates to:
  /// **'Future Premium Features'**
  String get futurePremium;

  /// No description provided for @futurePremiumDescription.
  ///
  /// In en, this message translates to:
  /// **'All future premium features will be unlocked automatically'**
  String get futurePremiumDescription;

  /// No description provided for @premiumRequiredMessage.
  ///
  /// In en, this message translates to:
  /// **'This feature requires Premium Features to be unlocked before it can be used'**
  String get premiumRequiredMessage;

  /// No description provided for @premiumUnlockHint.
  ///
  /// In en, this message translates to:
  /// **'Go to Settings > Premium Features to unlock it'**
  String get premiumUnlockHint;

  /// No description provided for @alreadyPremium.
  ///
  /// In en, this message translates to:
  /// **'Premium features are already unlocked'**
  String get alreadyPremium;

  /// No description provided for @pendingPurchase.
  ///
  /// In en, this message translates to:
  /// **'Processing your purchase...'**
  String get pendingPurchase;

  /// No description provided for @purchaseNotFound.
  ///
  /// In en, this message translates to:
  /// **'No purchase records found'**
  String get purchaseNotFound;

  /// No description provided for @productNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Unable to load product information. Please check your internet connection and try again'**
  String get productNotAvailable;

  /// No description provided for @iapNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'In-App Purchases are not available. Please try again later'**
  String get iapNotAvailable;

  /// No description provided for @connectingToAppStore.
  ///
  /// In en, this message translates to:
  /// **'Connecting to the App Store...'**
  String get connectingToAppStore;

  /// No description provided for @checkingPurchase.
  ///
  /// In en, this message translates to:
  /// **'Checking purchase history...'**
  String get checkingPurchase;

  /// No description provided for @noLyrics.
  ///
  /// In en, this message translates to:
  /// **'There are no lyrics'**
  String get noLyrics;

  /// No description provided for @lyricsParseFailed.
  ///
  /// In en, this message translates to:
  /// **'Lyrics parsing failed'**
  String get lyricsParseFailed;

  /// No description provided for @switchMode.
  ///
  /// In en, this message translates to:
  /// **'Switch Mode'**
  String get switchMode;

  /// No description provided for @viewLog.
  ///
  /// In en, this message translates to:
  /// **'View Log'**
  String get viewLog;

  /// No description provided for @premiumTrialActive.
  ///
  /// In en, this message translates to:
  /// **'Premium Trial Active'**
  String get premiumTrialActive;

  /// No description provided for @trialRemainingStatus.
  ///
  /// In en, this message translates to:
  /// **'You have {count} min of Premium access remaining\nPurchase Premium to continue after your trial ends'**
  String trialRemainingStatus(int count);

  /// No description provided for @gotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get gotIt;

  /// No description provided for @trialRemaining.
  ///
  /// In en, this message translates to:
  /// **'Trial Remaining'**
  String get trialRemaining;

  /// No description provided for @bigPictureMode.
  ///
  /// In en, this message translates to:
  /// **'Big Picture Mode'**
  String get bigPictureMode;

  /// No description provided for @bigPictureModeDescription.
  ///
  /// In en, this message translates to:
  /// **'Unlock Big Picture Mode'**
  String get bigPictureModeDescription;

  /// No description provided for @adjustLyrics.
  ///
  /// In en, this message translates to:
  /// **'Adjust Lyrics'**
  String get adjustLyrics;

  /// No description provided for @drivingMode.
  ///
  /// In en, this message translates to:
  /// **'Driving Mode'**
  String get drivingMode;

  /// No description provided for @fontSize.
  ///
  /// In en, this message translates to:
  /// **'Font Size'**
  String get fontSize;

  /// No description provided for @fontWeight.
  ///
  /// In en, this message translates to:
  /// **'Font Weight'**
  String get fontWeight;

  /// No description provided for @offset.
  ///
  /// In en, this message translates to:
  /// **'Offset'**
  String get offset;

  /// No description provided for @getStart.
  ///
  /// In en, this message translates to:
  /// **'Get Start'**
  String get getStart;

  /// No description provided for @immersiveWideLayout.
  ///
  /// In en, this message translates to:
  /// **'Immersive for Wide Layout'**
  String get immersiveWideLayout;

  /// No description provided for @wideShowTopSystemBar.
  ///
  /// In en, this message translates to:
  /// **'Show Top System Bar in Wide Layout'**
  String get wideShowTopSystemBar;

  /// No description provided for @wideShowBottomSystemBar.
  ///
  /// In en, this message translates to:
  /// **'Show Bottom System Bar in Wide Layout'**
  String get wideShowBottomSystemBar;

  /// No description provided for @menuOnRight.
  ///
  /// In en, this message translates to:
  /// **'Open Menu from Right'**
  String get menuOnRight;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @chooseMusicSource.
  ///
  /// In en, this message translates to:
  /// **'Choose a Music Source'**
  String get chooseMusicSource;

  /// No description provided for @feiniuMusic.
  ///
  /// In en, this message translates to:
  /// **'Feiniu Music'**
  String get feiniuMusic;

  /// No description provided for @feiniuConnectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to connect to Feiniu Music. Check the server URL and your music app username and password.'**
  String get feiniuConnectionFailed;

  /// No description provided for @savedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Saved successfully'**
  String get savedSuccessfully;

  /// No description provided for @controlCenterLyrics.
  ///
  /// In en, this message translates to:
  /// **'Control Center Lyrics'**
  String get controlCenterLyrics;

  /// No description provided for @coverBroadcast.
  ///
  /// In en, this message translates to:
  /// **'Cover broadcast'**
  String get coverBroadcast;

  /// No description provided for @songQualityBadge.
  ///
  /// In en, this message translates to:
  /// **'Song quality'**
  String get songQualityBadge;

  /// No description provided for @coverBroadcastBitmap.
  ///
  /// In en, this message translates to:
  /// **'Bitmap only'**
  String get coverBroadcastBitmap;

  /// No description provided for @coverBroadcastServer.
  ///
  /// In en, this message translates to:
  /// **'Server cover URL'**
  String get coverBroadcastServer;

  /// No description provided for @coverBroadcastRelay.
  ///
  /// In en, this message translates to:
  /// **'Local relay URL'**
  String get coverBroadcastRelay;

  /// No description provided for @coverBroadcastContent.
  ///
  /// In en, this message translates to:
  /// **'Content provider URI'**
  String get coverBroadcastContent;

  /// No description provided for @coverBroadcastAuto.
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get coverBroadcastAuto;

  /// No description provided for @coverBroadcastRelayOriginal.
  ///
  /// In en, this message translates to:
  /// **'Local relay (original)'**
  String get coverBroadcastRelayOriginal;

  /// No description provided for @relayAddress.
  ///
  /// In en, this message translates to:
  /// **'Relay address'**
  String get relayAddress;

  /// No description provided for @relayAddressAuto.
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get relayAddressAuto;

  /// No description provided for @broadcastLyrics.
  ///
  /// In en, this message translates to:
  /// **'Broadcast lyrics'**
  String get broadcastLyrics;

  /// No description provided for @connect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connect;

  /// No description provided for @notConnected.
  ///
  /// In en, this message translates to:
  /// **'is Not Connected'**
  String get notConnected;

  /// No description provided for @sortType.
  ///
  /// In en, this message translates to:
  /// **'Sort By'**
  String get sortType;

  /// No description provided for @sortByName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get sortByName;

  /// No description provided for @sortByAddedTime.
  ///
  /// In en, this message translates to:
  /// **'Added Time'**
  String get sortByAddedTime;

  /// No description provided for @sortByPlayCount.
  ///
  /// In en, this message translates to:
  /// **'Play Count'**
  String get sortByPlayCount;

  /// No description provided for @sortBySize.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get sortBySize;

  /// No description provided for @sortByYear.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get sortByYear;

  /// No description provided for @sortByAlbumCount.
  ///
  /// In en, this message translates to:
  /// **'Album Count'**
  String get sortByAlbumCount;

  /// No description provided for @sortBySongCount.
  ///
  /// In en, this message translates to:
  /// **'Song Count'**
  String get sortBySongCount;

  /// No description provided for @sortByFavorite.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get sortByFavorite;

  /// No description provided for @randomSort.
  ///
  /// In en, this message translates to:
  /// **'Shuffle'**
  String get randomSort;

  /// No description provided for @favoriteFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not update favorites'**
  String get favoriteFailed;

  /// No description provided for @totalDuration.
  ///
  /// In en, this message translates to:
  /// **'Total Duration'**
  String get totalDuration;

  /// No description provided for @albumInfo.
  ///
  /// In en, this message translates to:
  /// **'Album Info'**
  String get albumInfo;

  /// No description provided for @artistInfo.
  ///
  /// In en, this message translates to:
  /// **'Artist Info'**
  String get artistInfo;

  /// No description provided for @biography.
  ///
  /// In en, this message translates to:
  /// **'Biography'**
  String get biography;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @songUnit.
  ///
  /// In en, this message translates to:
  /// **'Songs'**
  String get songUnit;

  /// No description provided for @contributingArtists.
  ///
  /// In en, this message translates to:
  /// **'Contributing Artists'**
  String get contributingArtists;

  /// No description provided for @noResults.
  ///
  /// In en, this message translates to:
  /// **'No results'**
  String get noResults;

  /// No description provided for @clearArtistsCache.
  ///
  /// In en, this message translates to:
  /// **'Clear artist cache'**
  String get clearArtistsCache;

  /// No description provided for @artistCacheRefreshed.
  ///
  /// In en, this message translates to:
  /// **'Artist cache refreshed'**
  String get artistCacheRefreshed;

  /// No description provided for @artistCacheNoImage.
  ///
  /// In en, this message translates to:
  /// **'Refreshed - no artist image yet, using the album cover'**
  String get artistCacheNoImage;

  /// No description provided for @addedTime.
  ///
  /// In en, this message translates to:
  /// **'Added Time'**
  String get addedTime;

  /// No description provided for @modifiedTime.
  ///
  /// In en, this message translates to:
  /// **'Modified Time'**
  String get modifiedTime;

  /// No description provided for @playCountLabel.
  ///
  /// In en, this message translates to:
  /// **'Play Count'**
  String get playCountLabel;

  /// No description provided for @clearSuccess.
  ///
  /// In en, this message translates to:
  /// **'Cleared'**
  String get clearSuccess;

  /// No description provided for @addToFavorites.
  ///
  /// In en, this message translates to:
  /// **'Add to Favorites'**
  String get addToFavorites;

  /// No description provided for @removeFromFavorites.
  ///
  /// In en, this message translates to:
  /// **'Remove from Favorites'**
  String get removeFromFavorites;

  /// No description provided for @playbackMode.
  ///
  /// In en, this message translates to:
  /// **'Playback Mode'**
  String get playbackMode;

  /// No description provided for @playbackModeExclusive.
  ///
  /// In en, this message translates to:
  /// **'Exclusive'**
  String get playbackModeExclusive;

  /// No description provided for @playbackModeDuck.
  ///
  /// In en, this message translates to:
  /// **'Smart Ducking'**
  String get playbackModeDuck;

  /// No description provided for @playbackModeMix.
  ///
  /// In en, this message translates to:
  /// **'Mixed'**
  String get playbackModeMix;

  /// No description provided for @playbackModeExclusiveDesc.
  ///
  /// In en, this message translates to:
  /// **'Lain takes the audio output and pauses when another app plays; it does not resume on its own afterwards.'**
  String get playbackModeExclusiveDesc;

  /// No description provided for @playbackModeDuckDesc.
  ///
  /// In en, this message translates to:
  /// **'Lain lowers its volume while other apps play audio and restores it when they stop.'**
  String get playbackModeDuckDesc;

  /// No description provided for @playbackModeMixDesc.
  ///
  /// In en, this message translates to:
  /// **'Lain\'s audio is mixed with other apps\' audio.'**
  String get playbackModeMixDesc;

  /// No description provided for @playbackModeNotice.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get playbackModeNotice;

  /// No description provided for @playbackModeScenarios.
  ///
  /// In en, this message translates to:
  /// **'Use Cases'**
  String get playbackModeScenarios;

  /// No description provided for @playbackModeNoticeInCar.
  ///
  /// In en, this message translates to:
  /// **'Smart Ducking is recommended in car mode.'**
  String get playbackModeNoticeInCar;

  /// No description provided for @playbackModeNoticeNavigation.
  ///
  /// In en, this message translates to:
  /// **'Music volume is lowered automatically during navigation voice prompts.'**
  String get playbackModeNoticeNavigation;

  /// No description provided for @playbackModeNoticeDesktop.
  ///
  /// In en, this message translates to:
  /// **'The desktop version uses Mixed by default.'**
  String get playbackModeNoticeDesktop;

  /// No description provided for @scenarioDailyListening.
  ///
  /// In en, this message translates to:
  /// **'Everyday listening'**
  String get scenarioDailyListening;

  /// No description provided for @scenarioDailyListeningMode.
  ///
  /// In en, this message translates to:
  /// **'Exclusive'**
  String get scenarioDailyListeningMode;

  /// No description provided for @scenarioNavigation.
  ///
  /// In en, this message translates to:
  /// **'Driving with navigation'**
  String get scenarioNavigation;

  /// No description provided for @scenarioNavigationMode.
  ///
  /// In en, this message translates to:
  /// **'Smart Ducking'**
  String get scenarioNavigationMode;

  /// No description provided for @scenarioGaming.
  ///
  /// In en, this message translates to:
  /// **'Game background music'**
  String get scenarioGaming;

  /// No description provided for @scenarioGamingMode.
  ///
  /// In en, this message translates to:
  /// **'Mixed'**
  String get scenarioGamingMode;

  /// No description provided for @scenarioArrow.
  ///
  /// In en, this message translates to:
  /// **'→'**
  String get scenarioArrow;

  /// No description provided for @playbackModeDesktopNote.
  ///
  /// In en, this message translates to:
  /// **'Exclusive playback is not supported on desktop; the selection is treated as Mixed.'**
  String get playbackModeDesktopNote;

  /// No description provided for @comment.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get comment;

  /// No description provided for @comments.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get comments;

  /// No description provided for @commentSettings.
  ///
  /// In en, this message translates to:
  /// **'Comment settings'**
  String get commentSettings;

  /// No description provided for @commentSwitch.
  ///
  /// In en, this message translates to:
  /// **'Comment display'**
  String get commentSwitch;

  /// No description provided for @commentSwitchDesc.
  ///
  /// In en, this message translates to:
  /// **'Shows a comment entry on the now-playing bar once a comment server is configured.'**
  String get commentSwitchDesc;

  /// No description provided for @commentServer.
  ///
  /// In en, this message translates to:
  /// **'Comment server'**
  String get commentServer;

  /// No description provided for @commentServers.
  ///
  /// In en, this message translates to:
  /// **'Comment servers'**
  String get commentServers;

  /// No description provided for @addCommentServer.
  ///
  /// In en, this message translates to:
  /// **'Add comment server'**
  String get addCommentServer;

  /// No description provided for @commentServerName.
  ///
  /// In en, this message translates to:
  /// **'Server name'**
  String get commentServerName;

  /// No description provided for @protocol.
  ///
  /// In en, this message translates to:
  /// **'Protocol'**
  String get protocol;

  /// No description provided for @commentTokenHint.
  ///
  /// In en, this message translates to:
  /// **'Optional; needed only when the server has a username or password'**
  String get commentTokenHint;

  /// No description provided for @commentNoServer.
  ///
  /// In en, this message translates to:
  /// **'No comment server configured'**
  String get commentNoServer;

  /// No description provided for @commentNoServerHint.
  ///
  /// In en, this message translates to:
  /// **'Add a comment server in the settings to read comments'**
  String get commentNoServerHint;

  /// No description provided for @commentEmpty.
  ///
  /// In en, this message translates to:
  /// **'No comments yet'**
  String get commentEmpty;

  /// No description provided for @commentLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load comments'**
  String get commentLoadFailed;

  /// No description provided for @commentRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commentRetry;

  /// No description provided for @commentReplies.
  ///
  /// In en, this message translates to:
  /// **'replies'**
  String get commentReplies;

  /// No description provided for @commentShowReplies.
  ///
  /// In en, this message translates to:
  /// **'Show {count} replies'**
  String commentShowReplies(int count);

  /// No description provided for @commentHideReplies.
  ///
  /// In en, this message translates to:
  /// **'Hide replies'**
  String get commentHideReplies;

  /// No description provided for @commentPagePrevious.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get commentPagePrevious;

  /// No description provided for @commentPageNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get commentPageNext;

  /// No description provided for @commentPageIndicator.
  ///
  /// In en, this message translates to:
  /// **'Page {page}'**
  String commentPageIndicator(int page);

  /// No description provided for @commentUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Cannot reach the comment server; check the address or the network'**
  String get commentUnreachable;

  /// No description provided for @commentForbidden.
  ///
  /// In en, this message translates to:
  /// **'The server refused the request; check the username and password'**
  String get commentForbidden;

  /// No description provided for @commentServerError.
  ///
  /// In en, this message translates to:
  /// **'The server returned something unexpected'**
  String get commentServerError;

  /// No description provided for @commentServerSwitched.
  ///
  /// In en, this message translates to:
  /// **'Switched to {name}'**
  String commentServerSwitched(String name);

  /// No description provided for @commentAtLeastOneAddress.
  ///
  /// In en, this message translates to:
  /// **'Fill in at least one of the LAN and public addresses'**
  String get commentAtLeastOneAddress;

  /// No description provided for @settingsComments.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get settingsComments;

  /// No description provided for @commentOn.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get commentOn;

  /// No description provided for @commentOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get commentOff;

  /// Status of the song comment feature in the settings list, with the name of the comment server it asks.
  ///
  /// In en, this message translates to:
  /// **'On · {server}'**
  String commentOnWithServer(String server);

  /// No description provided for @commentSortRecommended.
  ///
  /// In en, this message translates to:
  /// **'Recommended'**
  String get commentSortRecommended;

  /// No description provided for @commentSortHot.
  ///
  /// In en, this message translates to:
  /// **'Hot'**
  String get commentSortHot;

  /// No description provided for @commentSortTime.
  ///
  /// In en, this message translates to:
  /// **'Latest'**
  String get commentSortTime;

  /// The song the comment server matched, shown under the local song header.
  ///
  /// In en, this message translates to:
  /// **'Comments of “{name}”'**
  String commentMatchedSong(String name);

  /// No description provided for @commentChangeSong.
  ///
  /// In en, this message translates to:
  /// **'Change song'**
  String get commentChangeSong;

  /// No description provided for @commentMismatchTitle.
  ///
  /// In en, this message translates to:
  /// **'These comments belong to another song'**
  String get commentMismatchTitle;

  /// No description provided for @commentMismatchDetail.
  ///
  /// In en, this message translates to:
  /// **'The server matched this track with “{name}”, which does not look right. Pick the matching song to read its comments.'**
  String commentMismatchDetail(String name);

  /// No description provided for @commentPickSong.
  ///
  /// In en, this message translates to:
  /// **'Pick a song'**
  String get commentPickSong;

  /// No description provided for @commentSearchTitle.
  ///
  /// In en, this message translates to:
  /// **'Search songs'**
  String get commentSearchTitle;

  /// No description provided for @commentSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Song name / artist'**
  String get commentSearchHint;

  /// No description provided for @commentSearchEmpty.
  ///
  /// In en, this message translates to:
  /// **'No songs found'**
  String get commentSearchEmpty;

  /// No description provided for @commentSongNotFound.
  ///
  /// In en, this message translates to:
  /// **'The comment server did not find this song'**
  String get commentSongNotFound;

  /// No description provided for @commentTotalCount.
  ///
  /// In en, this message translates to:
  /// **'{count} comments'**
  String commentTotalCount(int count);

  /// No description provided for @commentPageOf.
  ///
  /// In en, this message translates to:
  /// **'Page {page} of {pageCount}'**
  String commentPageOf(int page, int pageCount);

  /// No description provided for @commentShowMoreReplies.
  ///
  /// In en, this message translates to:
  /// **'Show more replies'**
  String get commentShowMoreReplies;

  /// No description provided for @statsCard.
  ///
  /// In en, this message translates to:
  /// **'Stats'**
  String get statsCard;

  /// No description provided for @serverStatus.
  ///
  /// In en, this message translates to:
  /// **'Server status'**
  String get serverStatus;

  /// No description provided for @serverInfo.
  ///
  /// In en, this message translates to:
  /// **'Server info'**
  String get serverInfo;

  /// No description provided for @mediaStats.
  ///
  /// In en, this message translates to:
  /// **'Media library'**
  String get mediaStats;

  /// No description provided for @statsSongs.
  ///
  /// In en, this message translates to:
  /// **'Songs'**
  String get statsSongs;

  /// No description provided for @totalSize.
  ///
  /// In en, this message translates to:
  /// **'Total size'**
  String get totalSize;

  /// No description provided for @serverVersion.
  ///
  /// In en, this message translates to:
  /// **'Server version'**
  String get serverVersion;

  /// No description provided for @subsonicApiVersion.
  ///
  /// In en, this message translates to:
  /// **'Subsonic API'**
  String get subsonicApiVersion;

  /// No description provided for @openSubsonic.
  ///
  /// In en, this message translates to:
  /// **'Open Subsonic'**
  String get openSubsonic;

  /// No description provided for @supported.
  ///
  /// In en, this message translates to:
  /// **'Supported'**
  String get supported;

  /// No description provided for @notSupported.
  ///
  /// In en, this message translates to:
  /// **'Not supported'**
  String get notSupported;

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @latencyMs.
  ///
  /// In en, this message translates to:
  /// **'Latency {ms} ms'**
  String latencyMs(int ms);

  /// No description provided for @latencyValue.
  ///
  /// In en, this message translates to:
  /// **'{ms} ms'**
  String latencyValue(int ms);

  /// No description provided for @customDomain.
  ///
  /// In en, this message translates to:
  /// **'Custom domain'**
  String get customDomain;

  /// No description provided for @showAddress.
  ///
  /// In en, this message translates to:
  /// **'Show full address'**
  String get showAddress;

  /// No description provided for @hideAddress.
  ///
  /// In en, this message translates to:
  /// **'Hide address'**
  String get hideAddress;

  /// No description provided for @speedFirst.
  ///
  /// In en, this message translates to:
  /// **'Speed first'**
  String get speedFirst;

  /// No description provided for @speedFirstDescription.
  ///
  /// In en, this message translates to:
  /// **'When on, the app picks the reachable route with the lowest latency; when off, the manual priority order is kept.'**
  String get speedFirstDescription;

  /// No description provided for @scanStatus.
  ///
  /// In en, this message translates to:
  /// **'Scan status'**
  String get scanStatus;

  /// No description provided for @lastScanTime.
  ///
  /// In en, this message translates to:
  /// **'Last scan'**
  String get lastScanTime;

  /// No description provided for @scanning.
  ///
  /// In en, this message translates to:
  /// **'Scanning'**
  String get scanning;

  /// No description provided for @scanCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get scanCompleted;

  /// No description provided for @activeStreams.
  ///
  /// In en, this message translates to:
  /// **'Active streams'**
  String get activeStreams;

  /// No description provided for @transcoding.
  ///
  /// In en, this message translates to:
  /// **'Transcoding'**
  String get transcoding;

  /// No description provided for @serverOs.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get serverOs;

  /// No description provided for @systemUpdate.
  ///
  /// In en, this message translates to:
  /// **'System update'**
  String get systemUpdate;

  /// No description provided for @updateAvailable.
  ///
  /// In en, this message translates to:
  /// **'Update available'**
  String get updateAvailable;

  /// No description provided for @upToDate.
  ///
  /// In en, this message translates to:
  /// **'Up to date'**
  String get upToDate;

  /// No description provided for @hoursUnit.
  ///
  /// In en, this message translates to:
  /// **'h'**
  String get hoursUnit;

  /// No description provided for @daysUnit.
  ///
  /// In en, this message translates to:
  /// **'d'**
  String get daysUnit;

  /// No description provided for @librarySizeGB.
  ///
  /// In en, this message translates to:
  /// **'{size} GB'**
  String librarySizeGB(String size);

  /// No description provided for @libraryDurationHours.
  ///
  /// In en, this message translates to:
  /// **'{hours} {unit}'**
  String libraryDurationHours(String hours, String unit);

  /// No description provided for @localLibraryTools.
  ///
  /// In en, this message translates to:
  /// **'Local Library Tools'**
  String get localLibraryTools;

  /// No description provided for @localLibraryToolsHint.
  ///
  /// In en, this message translates to:
  /// **'Name, organize and complete tags'**
  String get localLibraryToolsHint;

  /// No description provided for @organizeSection.
  ///
  /// In en, this message translates to:
  /// **'Organize'**
  String get organizeSection;

  /// No description provided for @browseSection.
  ///
  /// In en, this message translates to:
  /// **'Browse'**
  String get browseSection;

  /// No description provided for @namingFormat.
  ///
  /// In en, this message translates to:
  /// **'Naming Format'**
  String get namingFormat;

  /// No description provided for @directorySection.
  ///
  /// In en, this message translates to:
  /// **'Folder'**
  String get directorySection;

  /// No description provided for @filenameSection.
  ///
  /// In en, this message translates to:
  /// **'File Name'**
  String get filenameSection;

  /// No description provided for @previewSection.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get previewSection;

  /// No description provided for @directoryTemplate.
  ///
  /// In en, this message translates to:
  /// **'Folder Template'**
  String get directoryTemplate;

  /// No description provided for @filenameTemplate.
  ///
  /// In en, this message translates to:
  /// **'File Name Template'**
  String get filenameTemplate;

  /// No description provided for @keepFeat.
  ///
  /// In en, this message translates to:
  /// **'Keep feat. Credit'**
  String get keepFeat;

  /// No description provided for @namingPlaceholders.
  ///
  /// In en, this message translates to:
  /// **'Available placeholders: {placeholders}'**
  String namingPlaceholders(String placeholders);

  /// No description provided for @namingSlashHelp.
  ///
  /// In en, this message translates to:
  /// **'A / in the template creates a folder level; a / inside a tag value is replaced with an underscore. The file name template must contain the title placeholder.'**
  String get namingSlashHelp;

  /// No description provided for @templateEmpty.
  ///
  /// In en, this message translates to:
  /// **'The template cannot be empty'**
  String get templateEmpty;

  /// No description provided for @templateNeedsTitle.
  ///
  /// In en, this message translates to:
  /// **'The file name template must contain the title placeholder'**
  String get templateNeedsTitle;

  /// No description provided for @templateAbsolute.
  ///
  /// In en, this message translates to:
  /// **'Absolute paths are not allowed'**
  String get templateAbsolute;

  /// No description provided for @templateParentSegment.
  ///
  /// In en, this message translates to:
  /// **'A \'..\' path segment is not allowed'**
  String get templateParentSegment;

  /// No description provided for @templateUnknownPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'The template contains an unknown placeholder'**
  String get templateUnknownPlaceholder;

  /// No description provided for @invalidTemplate.
  ///
  /// In en, this message translates to:
  /// **'Invalid template'**
  String get invalidTemplate;

  /// No description provided for @restoreDefaultFormat.
  ///
  /// In en, this message translates to:
  /// **'Restore Defaults'**
  String get restoreDefaultFormat;

  /// No description provided for @exampleSong.
  ///
  /// In en, this message translates to:
  /// **'Example song'**
  String get exampleSong;

  /// No description provided for @currentPath.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get currentPath;

  /// No description provided for @organizedPath.
  ///
  /// In en, this message translates to:
  /// **'Organized'**
  String get organizedPath;

  /// No description provided for @organizeFiles.
  ///
  /// In en, this message translates to:
  /// **'Organize Files'**
  String get organizeFiles;

  /// No description provided for @organizeFilesHint.
  ///
  /// In en, this message translates to:
  /// **'Preview, then move files'**
  String get organizeFilesHint;

  /// No description provided for @organizeFile.
  ///
  /// In en, this message translates to:
  /// **'Organize File'**
  String get organizeFile;

  /// No description provided for @organizeSelected.
  ///
  /// In en, this message translates to:
  /// **'Organize Selected'**
  String get organizeSelected;

  /// No description provided for @startOrganizing.
  ///
  /// In en, this message translates to:
  /// **'Start Organizing'**
  String get startOrganizing;

  /// No description provided for @overview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get overview;

  /// No description provided for @directoryPreview.
  ///
  /// In en, this message translates to:
  /// **'Folder Preview'**
  String get directoryPreview;

  /// No description provided for @changeList.
  ///
  /// In en, this message translates to:
  /// **'Changes'**
  String get changeList;

  /// No description provided for @organizeNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get organizeNormal;

  /// No description provided for @organizeSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get organizeSkip;

  /// No description provided for @organizeConflict.
  ///
  /// In en, this message translates to:
  /// **'Conflict'**
  String get organizeConflict;

  /// No description provided for @organizeBlocked.
  ///
  /// In en, this message translates to:
  /// **'Not Allowed'**
  String get organizeBlocked;

  /// No description provided for @organizeReasonUnchanged.
  ///
  /// In en, this message translates to:
  /// **'Already correct'**
  String get organizeReasonUnchanged;

  /// No description provided for @organizeReasonTargetExists.
  ///
  /// In en, this message translates to:
  /// **'Target exists'**
  String get organizeReasonTargetExists;

  /// No description provided for @organizeReasonMissingFile.
  ///
  /// In en, this message translates to:
  /// **'File missing'**
  String get organizeReasonMissingFile;

  /// No description provided for @organizeReasonMissingPath.
  ///
  /// In en, this message translates to:
  /// **'No path'**
  String get organizeReasonMissingPath;

  /// No description provided for @organizeReasonOutsideLibrary.
  ///
  /// In en, this message translates to:
  /// **'Outside the configured folders'**
  String get organizeReasonOutsideLibrary;

  /// No description provided for @organizeReasonFileProvider.
  ///
  /// In en, this message translates to:
  /// **'File-provider paths cannot be moved'**
  String get organizeReasonFileProvider;

  /// No description provided for @organizeReasonPathTooLong.
  ///
  /// In en, this message translates to:
  /// **'Path too long'**
  String get organizeReasonPathTooLong;

  /// No description provided for @organizeReasonTargetIsFolder.
  ///
  /// In en, this message translates to:
  /// **'Target is a folder'**
  String get organizeReasonTargetIsFolder;

  /// No description provided for @organizeReasonInvalidTemplate.
  ///
  /// In en, this message translates to:
  /// **'Invalid naming template'**
  String get organizeReasonInvalidTemplate;

  /// No description provided for @organizeResultMessage.
  ///
  /// In en, this message translates to:
  /// **'Moved {moved}, skipped {skipped}, failed {failed}'**
  String organizeResultMessage(int moved, int skipped, int failed);

  /// No description provided for @organizeStopped.
  ///
  /// In en, this message translates to:
  /// **'Stopped after {moved} files'**
  String organizeStopped(int moved);

  /// No description provided for @organizing.
  ///
  /// In en, this message translates to:
  /// **'Organizing'**
  String get organizing;

  /// No description provided for @undoOrganize.
  ///
  /// In en, this message translates to:
  /// **'Undo This Organize'**
  String get undoOrganize;

  /// No description provided for @undoSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Undone'**
  String get undoSuccessfully;

  /// No description provided for @undoFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not undo'**
  String get undoFailed;

  /// No description provided for @metadataCompletion.
  ///
  /// In en, this message translates to:
  /// **'Metadata Completion'**
  String get metadataCompletion;

  /// No description provided for @songsMissingTags.
  ///
  /// In en, this message translates to:
  /// **'{count} songs are missing tags'**
  String songsMissingTags(int count);

  /// No description provided for @batchSearchSelected.
  ///
  /// In en, this message translates to:
  /// **'Search Selected'**
  String get batchSearchSelected;

  /// No description provided for @batchSearchTags.
  ///
  /// In en, this message translates to:
  /// **'Search Tags in Batch'**
  String get batchSearchTags;

  /// No description provided for @batchSearching.
  ///
  /// In en, this message translates to:
  /// **'Searching {done} / {total}'**
  String batchSearching(int done, int total);

  /// No description provided for @filterMissingTags.
  ///
  /// In en, this message translates to:
  /// **'Missing Tags'**
  String get filterMissingTags;

  /// No description provided for @filterMissingTagsOrCover.
  ///
  /// In en, this message translates to:
  /// **'Tags or Cover'**
  String get filterMissingTagsOrCover;

  /// No description provided for @filterAllIncomplete.
  ///
  /// In en, this message translates to:
  /// **'All Incomplete'**
  String get filterAllIncomplete;

  /// No description provided for @allMetadataComplete.
  ///
  /// In en, this message translates to:
  /// **'Every song\'s metadata is complete'**
  String get allMetadataComplete;

  /// No description provided for @selectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String selectedCount(int count);

  /// No description provided for @missingTitle.
  ///
  /// In en, this message translates to:
  /// **'No title'**
  String get missingTitle;

  /// No description provided for @missingArtist.
  ///
  /// In en, this message translates to:
  /// **'No artist'**
  String get missingArtist;

  /// No description provided for @missingAlbum.
  ///
  /// In en, this message translates to:
  /// **'No album'**
  String get missingAlbum;

  /// No description provided for @missingCover.
  ///
  /// In en, this message translates to:
  /// **'No cover'**
  String get missingCover;

  /// No description provided for @missingLyrics.
  ///
  /// In en, this message translates to:
  /// **'No lyrics'**
  String get missingLyrics;

  /// No description provided for @searchTags.
  ///
  /// In en, this message translates to:
  /// **'Search Tags'**
  String get searchTags;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @scrapeFillEmpty.
  ///
  /// In en, this message translates to:
  /// **'Fill Empty Only'**
  String get scrapeFillEmpty;

  /// No description provided for @overwriteTags.
  ///
  /// In en, this message translates to:
  /// **'Overwrite Existing Tags'**
  String get overwriteTags;

  /// No description provided for @writeCoverToo.
  ///
  /// In en, this message translates to:
  /// **'Write Cover Too'**
  String get writeCoverToo;

  /// No description provided for @writeLyricsToo.
  ///
  /// In en, this message translates to:
  /// **'Write Lyrics Too'**
  String get writeLyricsToo;

  /// No description provided for @nextBatch.
  ///
  /// In en, this message translates to:
  /// **'Next Batch'**
  String get nextBatch;

  /// No description provided for @noMoreResults.
  ///
  /// In en, this message translates to:
  /// **'No more results from this source'**
  String get noMoreResults;

  /// No description provided for @noSearchResults.
  ///
  /// In en, this message translates to:
  /// **'No results'**
  String get noSearchResults;

  /// No description provided for @coverSkipped.
  ///
  /// In en, this message translates to:
  /// **'The cover format is not supported and was skipped'**
  String get coverSkipped;

  /// No description provided for @matchScore.
  ///
  /// In en, this message translates to:
  /// **'Match'**
  String get matchScore;

  /// No description provided for @changes.
  ///
  /// In en, this message translates to:
  /// **'Changes'**
  String get changes;

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided for @applySelected.
  ///
  /// In en, this message translates to:
  /// **'Apply Selected'**
  String get applySelected;

  /// No description provided for @batchReview.
  ///
  /// In en, this message translates to:
  /// **'Batch Results'**
  String get batchReview;

  /// No description provided for @batchApplied.
  ///
  /// In en, this message translates to:
  /// **'Applied to {count} songs'**
  String batchApplied(int count);

  /// No description provided for @nextCandidate.
  ///
  /// In en, this message translates to:
  /// **'Another'**
  String get nextCandidate;

  /// No description provided for @syncingWait.
  ///
  /// In en, this message translates to:
  /// **'Syncing; please try again shortly'**
  String get syncingWait;

  /// No description provided for @lyricTimeline.
  ///
  /// In en, this message translates to:
  /// **'Edit Lyrics'**
  String get lyricTimeline;

  /// No description provided for @lyricTimelineHint.
  ///
  /// In en, this message translates to:
  /// **'Adjust LRC timestamps line by line'**
  String get lyricTimelineHint;

  /// No description provided for @progress.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get progress;

  /// No description provided for @stamp.
  ///
  /// In en, this message translates to:
  /// **'Stamp'**
  String get stamp;

  /// No description provided for @playbackOffset.
  ///
  /// In en, this message translates to:
  /// **'Playback Offset'**
  String get playbackOffset;

  /// No description provided for @bakeOffset.
  ///
  /// In en, this message translates to:
  /// **'Apply Offset and Reset'**
  String get bakeOffset;

  /// No description provided for @wordTimestamps.
  ///
  /// In en, this message translates to:
  /// **'Word Timestamps'**
  String get wordTimestamps;

  /// No description provided for @stripWordTimestamps.
  ///
  /// In en, this message translates to:
  /// **'Remove Word Timestamps'**
  String get stripWordTimestamps;

  /// No description provided for @ttmlNotEditable.
  ///
  /// In en, this message translates to:
  /// **'This lyric is TTML; line-level timeline editing is not supported'**
  String get ttmlNotEditable;

  /// No description provided for @noLyricLines.
  ///
  /// In en, this message translates to:
  /// **'No lyric lines yet'**
  String get noLyricLines;

  /// No description provided for @addLine.
  ///
  /// In en, this message translates to:
  /// **'Add a Line'**
  String get addLine;

  /// No description provided for @addSecondaryLine.
  ///
  /// In en, this message translates to:
  /// **'Add Secondary Line'**
  String get addSecondaryLine;

  /// No description provided for @addLineBelow.
  ///
  /// In en, this message translates to:
  /// **'Add Line Below'**
  String get addLineBelow;

  /// No description provided for @discardChanges.
  ///
  /// In en, this message translates to:
  /// **'Discard Changes'**
  String get discardChanges;

  /// No description provided for @invalidTimeFormat.
  ///
  /// In en, this message translates to:
  /// **'Invalid time format'**
  String get invalidTimeFormat;

  /// No description provided for @saveSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get saveSuccessfully;

  /// No description provided for @saveFailed.
  ///
  /// In en, this message translates to:
  /// **'Save failed'**
  String get saveFailed;

  /// No description provided for @sidecarUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Tags saved; the sidecar could not be updated'**
  String get sidecarUpdateFailed;

  /// No description provided for @editLyricTimeline.
  ///
  /// In en, this message translates to:
  /// **'Edit Lyrics'**
  String get editLyricTimeline;

  /// No description provided for @albumTimeline.
  ///
  /// In en, this message translates to:
  /// **'Album Timeline'**
  String get albumTimeline;

  /// No description provided for @albumTimelineHint.
  ///
  /// In en, this message translates to:
  /// **'Browse albums by added time'**
  String get albumTimelineHint;

  /// No description provided for @lastMonth.
  ///
  /// In en, this message translates to:
  /// **'Last Month'**
  String get lastMonth;

  /// No description provided for @lastQuarter.
  ///
  /// In en, this message translates to:
  /// **'Last 3 Months'**
  String get lastQuarter;

  /// No description provided for @allTime.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get allTime;

  /// No description provided for @noAlbumsInRange.
  ///
  /// In en, this message translates to:
  /// **'No albums added in this period'**
  String get noAlbumsInRange;

  /// No description provided for @albumsMissingCreated.
  ///
  /// In en, this message translates to:
  /// **'{count} albums have no added time'**
  String albumsMissingCreated(int count);

  /// No description provided for @albumTimelineAddedCount.
  ///
  /// In en, this message translates to:
  /// **'+{count} songs'**
  String albumTimelineAddedCount(int count);

  /// No description provided for @albumTimelineSongCount.
  ///
  /// In en, this message translates to:
  /// **'{count} songs'**
  String albumTimelineSongCount(int count);

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get viewAll;

  /// No description provided for @stop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stop;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @actions.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get actions;

  /// No description provided for @organizeFolder.
  ///
  /// In en, this message translates to:
  /// **'Organize Folder'**
  String get organizeFolder;

  /// No description provided for @organizeDone.
  ///
  /// In en, this message translates to:
  /// **'Organized'**
  String get organizeDone;

  /// No description provided for @organizeComplete.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get organizeComplete;

  /// No description provided for @organizePending.
  ///
  /// In en, this message translates to:
  /// **'Not processed'**
  String get organizePending;

  /// No description provided for @undoApply.
  ///
  /// In en, this message translates to:
  /// **'Undo This Apply'**
  String get undoApply;

  /// No description provided for @previousCard.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get previousCard;

  /// No description provided for @nextCard.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get nextCard;

  /// No description provided for @scrapeLongPressHint.
  ///
  /// In en, this message translates to:
  /// **'Long-press a card to apply it directly'**
  String get scrapeLongPressHint;

  /// No description provided for @organizeFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get organizeFailed;

  /// No description provided for @applyCurrent.
  ///
  /// In en, this message translates to:
  /// **'Apply This'**
  String get applyCurrent;

  /// No description provided for @applyAllBest.
  ///
  /// In en, this message translates to:
  /// **'Apply All Best'**
  String get applyAllBest;

  /// No description provided for @songPosition.
  ///
  /// In en, this message translates to:
  /// **'Song {index} of {total}'**
  String songPosition(int index, int total);

  /// No description provided for @jumpToSong.
  ///
  /// In en, this message translates to:
  /// **'Choose a Song'**
  String get jumpToSong;

  /// No description provided for @previousSong.
  ///
  /// In en, this message translates to:
  /// **'Previous Song'**
  String get previousSong;

  /// No description provided for @nextSong.
  ///
  /// In en, this message translates to:
  /// **'Next Song'**
  String get nextSong;

  /// No description provided for @resultsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} results'**
  String resultsCount(int count);

  /// No description provided for @searchLyrics.
  ///
  /// In en, this message translates to:
  /// **'Search Lyrics'**
  String get searchLyrics;

  /// No description provided for @restoreLyrics.
  ///
  /// In en, this message translates to:
  /// **'Restore Lyrics'**
  String get restoreLyrics;

  /// No description provided for @lyricsPreview.
  ///
  /// In en, this message translates to:
  /// **'Lyrics Preview'**
  String get lyricsPreview;

  /// No description provided for @copyText.
  ///
  /// In en, this message translates to:
  /// **'Copy Text'**
  String get copyText;

  /// No description provided for @fileName.
  ///
  /// In en, this message translates to:
  /// **'File Name'**
  String get fileName;

  /// No description provided for @copied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get copied;

  /// No description provided for @replayGain.
  ///
  /// In en, this message translates to:
  /// **'Replay gain'**
  String get replayGain;

  /// No description provided for @replayGainOff.
  ///
  /// In en, this message translates to:
  /// **'Off (file level)'**
  String get replayGainOff;

  /// No description provided for @replayGainTrack.
  ///
  /// In en, this message translates to:
  /// **'Per track'**
  String get replayGainTrack;

  /// No description provided for @replayGainAlbum.
  ///
  /// In en, this message translates to:
  /// **'Per album'**
  String get replayGainAlbum;

  /// No description provided for @replayGainDescription.
  ///
  /// In en, this message translates to:
  /// **'Use the loudness tags in the files so tracks from different albums do not jump in volume.'**
  String get replayGainDescription;

  /// No description provided for @playbackSpeed.
  ///
  /// In en, this message translates to:
  /// **'Playback speed'**
  String get playbackSpeed;

  /// No description provided for @audioFade.
  ///
  /// In en, this message translates to:
  /// **'Fade in and out'**
  String get audioFade;

  /// No description provided for @audioFadeDescription.
  ///
  /// In en, this message translates to:
  /// **'Ramp the volume in when playback starts and out when it pauses or the track changes.'**
  String get audioFadeDescription;

  /// No description provided for @queueCleared.
  ///
  /// In en, this message translates to:
  /// **'Queue cleared'**
  String get queueCleared;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @scanNow.
  ///
  /// In en, this message translates to:
  /// **'Scan library now'**
  String get scanNow;

  /// No description provided for @scanNowConfirm.
  ///
  /// In en, this message translates to:
  /// **'Ask the server to scan its music folders now?'**
  String get scanNowConfirm;

  /// No description provided for @scanStarted.
  ///
  /// In en, this message translates to:
  /// **'Scan started'**
  String get scanStarted;

  /// No description provided for @operationFailed.
  ///
  /// In en, this message translates to:
  /// **'Operation failed'**
  String get operationFailed;

  /// No description provided for @autoScanLibrary.
  ///
  /// In en, this message translates to:
  /// **'Auto scan library'**
  String get autoScanLibrary;

  /// No description provided for @autoScanDescription.
  ///
  /// In en, this message translates to:
  /// **'Check the folders after launch and on a timer. Only files whose modified time changed are read again.'**
  String get autoScanDescription;

  /// No description provided for @scanInterval.
  ///
  /// In en, this message translates to:
  /// **'Scan interval'**
  String get scanInterval;

  /// No description provided for @scanIntervalMinutes.
  ///
  /// In en, this message translates to:
  /// **'Every {minutes} min'**
  String scanIntervalMinutes(int minutes);

  /// No description provided for @scanIntervalHours.
  ///
  /// In en, this message translates to:
  /// **'Every {hours} h'**
  String scanIntervalHours(int hours);

  /// No description provided for @offlineLibrarySource.
  ///
  /// In en, this message translates to:
  /// **'Offline library'**
  String get offlineLibrarySource;

  /// No description provided for @offlineLibraryLocal.
  ///
  /// In en, this message translates to:
  /// **'Local music library'**
  String get offlineLibraryLocal;

  /// No description provided for @offlineLibraryCached.
  ///
  /// In en, this message translates to:
  /// **'Cached songs of the server'**
  String get offlineLibraryCached;

  /// No description provided for @offlineLibraryCachedDetail.
  ///
  /// In en, this message translates to:
  /// **'{count} songs already on disk'**
  String offlineLibraryCachedDetail(int count);

  /// No description provided for @offlineChooseLibrary.
  ///
  /// In en, this message translates to:
  /// **'Which library should offline mode use?'**
  String get offlineChooseLibrary;

  /// No description provided for @noServerForOffline.
  ///
  /// In en, this message translates to:
  /// **'No server available for the cached library'**
  String get noServerForOffline;

  /// No description provided for @libraryHealth.
  ///
  /// In en, this message translates to:
  /// **'Library checkup'**
  String get libraryHealth;

  /// No description provided for @healthMissingTags.
  ///
  /// In en, this message translates to:
  /// **'Missing tags'**
  String get healthMissingTags;

  /// No description provided for @healthMissingCover.
  ///
  /// In en, this message translates to:
  /// **'No cover'**
  String get healthMissingCover;

  /// No description provided for @healthMissingLyrics.
  ///
  /// In en, this message translates to:
  /// **'No lyrics'**
  String get healthMissingLyrics;

  /// No description provided for @healthDuplicates.
  ///
  /// In en, this message translates to:
  /// **'Duplicates'**
  String get healthDuplicates;

  /// No description provided for @healthTotal.
  ///
  /// In en, this message translates to:
  /// **'{count} local songs'**
  String healthTotal(int count);

  /// No description provided for @healthClean.
  ///
  /// In en, this message translates to:
  /// **'Nothing to fix'**
  String get healthClean;

  /// No description provided for @healthNoMissingTags.
  ///
  /// In en, this message translates to:
  /// **'Every song has a title, artist and album'**
  String get healthNoMissingTags;

  /// No description provided for @healthNoMissingCover.
  ///
  /// In en, this message translates to:
  /// **'Every song has a cover'**
  String get healthNoMissingCover;

  /// No description provided for @healthNoMissingLyrics.
  ///
  /// In en, this message translates to:
  /// **'Every song has lyrics'**
  String get healthNoMissingLyrics;

  /// No description provided for @healthNoDuplicates.
  ///
  /// In en, this message translates to:
  /// **'No duplicate songs found'**
  String get healthNoDuplicates;

  /// No description provided for @healthFileCount.
  ///
  /// In en, this message translates to:
  /// **'{count} files'**
  String healthFileCount(int count);

  /// No description provided for @playbackSettings.
  ///
  /// In en, this message translates to:
  /// **'Playback settings'**
  String get playbackSettings;

  /// No description provided for @searchTagsHint.
  ///
  /// In en, this message translates to:
  /// **'Search NetEase and QQ Music, then apply a match'**
  String get searchTagsHint;

  /// No description provided for @tagInformation.
  ///
  /// In en, this message translates to:
  /// **'Tag information'**
  String get tagInformation;

  /// No description provided for @audioInformation.
  ///
  /// In en, this message translates to:
  /// **'Audio information'**
  String get audioInformation;

  /// No description provided for @playbackReport.
  ///
  /// In en, this message translates to:
  /// **'Report playback progress'**
  String get playbackReport;

  /// No description provided for @playbackReportDescription.
  ///
  /// In en, this message translates to:
  /// **'Keep the server’s now-playing entry and position up to date; turn off to stop the periodic reports.'**
  String get playbackReportDescription;

  /// No description provided for @randomSongs.
  ///
  /// In en, this message translates to:
  /// **'Random songs'**
  String get randomSongs;

  /// No description provided for @randomSongsHint.
  ///
  /// In en, this message translates to:
  /// **'A fresh set of 100 songs each time it is refreshed'**
  String get randomSongsHint;

  /// No description provided for @useServerRandom.
  ///
  /// In en, this message translates to:
  /// **'Use server random list'**
  String get useServerRandom;

  /// No description provided for @useServerRandomDescription.
  ///
  /// In en, this message translates to:
  /// **'On: ask the server for a random selection. Off: draw from the songs already saved on this device. Falls back to the local list when the server cannot answer.'**
  String get useServerRandomDescription;

  /// No description provided for @viewComments.
  ///
  /// In en, this message translates to:
  /// **'View comments'**
  String get viewComments;

  /// No description provided for @lyricsCoverMotion.
  ///
  /// In en, this message translates to:
  /// **'Lyrics cover motion'**
  String get lyricsCoverMotion;

  /// No description provided for @playerCoverStyle.
  ///
  /// In en, this message translates to:
  /// **'Player cover style'**
  String get playerCoverStyle;

  /// No description provided for @coverStyleSquare.
  ///
  /// In en, this message translates to:
  /// **'Square cover'**
  String get coverStyleSquare;

  /// No description provided for @coverStyleVinyl.
  ///
  /// In en, this message translates to:
  /// **'Vinyl record'**
  String get coverStyleVinyl;

  /// No description provided for @lyricShareCard.
  ///
  /// In en, this message translates to:
  /// **'Share lyric card'**
  String get lyricShareCard;

  /// No description provided for @annualReport.
  ///
  /// In en, this message translates to:
  /// **'Year in review'**
  String get annualReport;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @savedTo.
  ///
  /// In en, this message translates to:
  /// **'Saved to {path}'**
  String savedTo(String path);

  /// No description provided for @annualDaysMusic.
  ///
  /// In en, this message translates to:
  /// **'days with music'**
  String get annualDaysMusic;

  /// No description provided for @annualTopArtist.
  ///
  /// In en, this message translates to:
  /// **'Artist of the year'**
  String get annualTopArtist;

  /// No description provided for @annualTopAlbum.
  ///
  /// In en, this message translates to:
  /// **'Album of the year'**
  String get annualTopAlbum;

  /// No description provided for @annualTopSong.
  ///
  /// In en, this message translates to:
  /// **'Song of the year'**
  String get annualTopSong;

  /// No description provided for @annualMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly rhythm'**
  String get annualMonthly;

  /// No description provided for @annualBestMonth.
  ///
  /// In en, this message translates to:
  /// **'Most played month'**
  String get annualBestMonth;

  /// No description provided for @annualStreak.
  ///
  /// In en, this message translates to:
  /// **'Longest streak: {days} days in a row'**
  String annualStreak(int days);

  /// No description provided for @annualNoData.
  ///
  /// In en, this message translates to:
  /// **'Not enough listening data for this year yet'**
  String get annualNoData;

  /// No description provided for @shareCardSettings.
  ///
  /// In en, this message translates to:
  /// **'Share card'**
  String get shareCardSettings;

  /// No description provided for @shareCardTopText.
  ///
  /// In en, this message translates to:
  /// **'Top text'**
  String get shareCardTopText;

  /// No description provided for @shareCardBackground.
  ///
  /// In en, this message translates to:
  /// **'Background'**
  String get shareCardBackground;

  /// No description provided for @shareCardTextSize.
  ///
  /// In en, this message translates to:
  /// **'Lyric text size'**
  String get shareCardTextSize;

  /// No description provided for @shareCardCoverSize.
  ///
  /// In en, this message translates to:
  /// **'Cover size'**
  String get shareCardCoverSize;

  /// No description provided for @shareCardShowTranslation.
  ///
  /// In en, this message translates to:
  /// **'Show translation'**
  String get shareCardShowTranslation;

  /// No description provided for @shareCardBlur.
  ///
  /// In en, this message translates to:
  /// **'Soft blur'**
  String get shareCardBlur;

  /// No description provided for @shareCardCrop.
  ///
  /// In en, this message translates to:
  /// **'Cover crop'**
  String get shareCardCrop;

  /// No description provided for @shareCardAurora.
  ///
  /// In en, this message translates to:
  /// **'Aurora'**
  String get shareCardAurora;

  /// No description provided for @shareCardPixelate.
  ///
  /// In en, this message translates to:
  /// **'Mosaic'**
  String get shareCardPixelate;

  /// No description provided for @shareCardHalftone.
  ///
  /// In en, this message translates to:
  /// **'Halftone'**
  String get shareCardHalftone;

  /// No description provided for @similarArtists.
  ///
  /// In en, this message translates to:
  /// **'Similar artists'**
  String get similarArtists;

  /// No description provided for @moreFromArtist.
  ///
  /// In en, this message translates to:
  /// **'More from this artist'**
  String get moreFromArtist;

  /// No description provided for @audioQualityStats.
  ///
  /// In en, this message translates to:
  /// **'Audio quality'**
  String get audioQualityStats;

  /// No description provided for @cacheStorageStats.
  ///
  /// In en, this message translates to:
  /// **'Cache storage'**
  String get cacheStorageStats;

  /// No description provided for @qualityDistribution.
  ///
  /// In en, this message translates to:
  /// **'Quality mix'**
  String get qualityDistribution;

  /// No description provided for @formatDistribution.
  ///
  /// In en, this message translates to:
  /// **'Format mix'**
  String get formatDistribution;

  /// No description provided for @losslessRatio.
  ///
  /// In en, this message translates to:
  /// **'Lossless share'**
  String get losslessRatio;

  /// No description provided for @averageBitrate.
  ///
  /// In en, this message translates to:
  /// **'Average bitrate'**
  String get averageBitrate;

  /// No description provided for @unknownQuality.
  ///
  /// In en, this message translates to:
  /// **'Unclassified'**
  String get unknownQuality;

  /// No description provided for @hires.
  ///
  /// In en, this message translates to:
  /// **'High-res'**
  String get hires;

  /// No description provided for @lossless.
  ///
  /// In en, this message translates to:
  /// **'Lossless'**
  String get lossless;

  /// No description provided for @lossy.
  ///
  /// In en, this message translates to:
  /// **'Lossy'**
  String get lossy;

  /// No description provided for @highestQualitySongs.
  ///
  /// In en, this message translates to:
  /// **'Highest quality'**
  String get highestQualitySongs;

  /// No description provided for @storageBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Storage mix'**
  String get storageBreakdown;

  /// No description provided for @cacheUsage.
  ///
  /// In en, this message translates to:
  /// **'Cache usage'**
  String get cacheUsage;

  /// No description provided for @activeTasks.
  ///
  /// In en, this message translates to:
  /// **'Active tasks'**
  String get activeTasks;

  /// No description provided for @cacheAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get cacheAudio;

  /// No description provided for @cacheOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get cacheOther;

  /// No description provided for @largestCached.
  ///
  /// In en, this message translates to:
  /// **'Largest cached songs'**
  String get largestCached;

  /// No description provided for @storageLocation.
  ///
  /// In en, this message translates to:
  /// **'Storage locations'**
  String get storageLocation;

  /// No description provided for @downloadedFiles.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get downloadedFiles;

  /// No description provided for @carDisplay.
  ///
  /// In en, this message translates to:
  /// **'Song broadcast'**
  String get carDisplay;

  /// No description provided for @carDisplayLines.
  ///
  /// In en, this message translates to:
  /// **'Lines'**
  String get carDisplayLines;

  /// No description provided for @carLinesTwo.
  ///
  /// In en, this message translates to:
  /// **'Two lines'**
  String get carLinesTwo;

  /// No description provided for @carLinesThree.
  ///
  /// In en, this message translates to:
  /// **'Three lines'**
  String get carLinesThree;

  /// No description provided for @carLine1.
  ///
  /// In en, this message translates to:
  /// **'First line'**
  String get carLine1;

  /// No description provided for @carLine2.
  ///
  /// In en, this message translates to:
  /// **'Second line'**
  String get carLine2;

  /// No description provided for @carLine3.
  ///
  /// In en, this message translates to:
  /// **'Third line'**
  String get carLine3;

  /// No description provided for @carTokenLyricOriginal.
  ///
  /// In en, this message translates to:
  /// **'Original lyric'**
  String get carTokenLyricOriginal;

  /// No description provided for @carTokenLyricTranslation.
  ///
  /// In en, this message translates to:
  /// **'Translation'**
  String get carTokenLyricTranslation;

  /// No description provided for @carTokenTitle.
  ///
  /// In en, this message translates to:
  /// **'Song title'**
  String get carTokenTitle;

  /// No description provided for @carTokenArtist.
  ///
  /// In en, this message translates to:
  /// **'Artist'**
  String get carTokenArtist;

  /// No description provided for @carTokenAlbum.
  ///
  /// In en, this message translates to:
  /// **'Album'**
  String get carTokenAlbum;

  /// No description provided for @carAddField.
  ///
  /// In en, this message translates to:
  /// **'Add field'**
  String get carAddField;

  /// No description provided for @carSeparator.
  ///
  /// In en, this message translates to:
  /// **'Separator'**
  String get carSeparator;

  /// No description provided for @carSeparatorSpace.
  ///
  /// In en, this message translates to:
  /// **'Space'**
  String get carSeparatorSpace;

  /// No description provided for @carPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get carPreview;

  /// No description provided for @carReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get carReset;

  /// No description provided for @classicCoverMode.
  ///
  /// In en, this message translates to:
  /// **'Classic Bluetooth cover'**
  String get classicCoverMode;

  /// No description provided for @classicCoverBitmap.
  ///
  /// In en, this message translates to:
  /// **'Bitmap'**
  String get classicCoverBitmap;

  /// No description provided for @classicCoverBitmapUri.
  ///
  /// In en, this message translates to:
  /// **'Bitmap + URI'**
  String get classicCoverBitmapUri;

  /// No description provided for @classicCoverLarge.
  ///
  /// In en, this message translates to:
  /// **'Original large image'**
  String get classicCoverLarge;

  /// No description provided for @classicCoverRelay.
  ///
  /// In en, this message translates to:
  /// **'Bitmap + relay/server URI'**
  String get classicCoverRelay;

  /// No description provided for @carTabLayout.
  ///
  /// In en, this message translates to:
  /// **'Layout'**
  String get carTabLayout;

  /// No description provided for @carTabCover.
  ///
  /// In en, this message translates to:
  /// **'Cover'**
  String get carTabCover;

  /// No description provided for @carTabLyrics.
  ///
  /// In en, this message translates to:
  /// **'Lyrics'**
  String get carTabLyrics;

  /// No description provided for @carPreviewBuiltin.
  ///
  /// In en, this message translates to:
  /// **'Built-in'**
  String get carPreviewBuiltin;

  /// No description provided for @carPreviewLive.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get carPreviewLive;

  /// No description provided for @carNoSong.
  ///
  /// In en, this message translates to:
  /// **'Nothing is playing'**
  String get carNoSong;

  /// No description provided for @pcInspector.
  ///
  /// In en, this message translates to:
  /// **'PC inspector'**
  String get pcInspector;

  /// No description provided for @debug.
  ///
  /// In en, this message translates to:
  /// **'Debug'**
  String get debug;

  /// No description provided for @currentBroadcast.
  ///
  /// In en, this message translates to:
  /// **'Current broadcast'**
  String get currentBroadcast;

  /// No description provided for @rediscovery.
  ///
  /// In en, this message translates to:
  /// **'Long time no see'**
  String get rediscovery;

  /// No description provided for @searchAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get searchAll;

  /// No description provided for @searchTopResult.
  ///
  /// In en, this message translates to:
  /// **'Top result'**
  String get searchTopResult;

  /// No description provided for @searchRecent.
  ///
  /// In en, this message translates to:
  /// **'Recent searches'**
  String get searchRecent;

  /// No description provided for @searchClearRecent.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get searchClearRecent;

  /// No description provided for @searchTrySearching.
  ///
  /// In en, this message translates to:
  /// **'Try searching for'**
  String get searchTrySearching;

  /// No description provided for @searchBrowse.
  ///
  /// In en, this message translates to:
  /// **'Browse'**
  String get searchBrowse;

  /// No description provided for @searchIdleHint.
  ///
  /// In en, this message translates to:
  /// **'Songs, albums, artists and playlists - all in one place'**
  String get searchIdleHint;

  /// No description provided for @searchShowAll.
  ///
  /// In en, this message translates to:
  /// **'Show all'**
  String get searchShowAll;

  /// No description provided for @searchCountSongs.
  ///
  /// In en, this message translates to:
  /// **'{count} songs'**
  String searchCountSongs(int count);

  /// No description provided for @prefetchNextSong.
  ///
  /// In en, this message translates to:
  /// **'Pre-cache the next song'**
  String get prefetchNextSong;

  /// No description provided for @settingsDataBackup.
  ///
  /// In en, this message translates to:
  /// **'Data and backup'**
  String get settingsDataBackup;

  /// No description provided for @backupData.
  ///
  /// In en, this message translates to:
  /// **'Backup'**
  String get backupData;

  /// No description provided for @backupExport.
  ///
  /// In en, this message translates to:
  /// **'Export backup'**
  String get backupExport;

  /// No description provided for @backupImport.
  ///
  /// In en, this message translates to:
  /// **'Restore from a file'**
  String get backupImport;

  /// No description provided for @backupSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get backupSettings;

  /// No description provided for @backupServers.
  ///
  /// In en, this message translates to:
  /// **'Servers and accounts'**
  String get backupServers;

  /// No description provided for @backupPlaylists.
  ///
  /// In en, this message translates to:
  /// **'Playlists and favorites'**
  String get backupPlaylists;

  /// No description provided for @backupStatistics.
  ///
  /// In en, this message translates to:
  /// **'Listening statistics'**
  String get backupStatistics;

  /// No description provided for @backupPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Server passwords are not included; enter them again after restoring.'**
  String get backupPrivacy;

  /// No description provided for @backupSaved.
  ///
  /// In en, this message translates to:
  /// **'Backup saved'**
  String get backupSaved;

  /// No description provided for @backupRestoreConfirm.
  ///
  /// In en, this message translates to:
  /// **'Restore this backup? Settings, servers, playlists and statistics will be replaced.'**
  String get backupRestoreConfirm;

  /// No description provided for @backupRestoreDone.
  ///
  /// In en, this message translates to:
  /// **'Restored. Restart Lain to apply everything.'**
  String get backupRestoreDone;

  /// No description provided for @backupInvalid.
  ///
  /// In en, this message translates to:
  /// **'This is not a Lain backup file'**
  String get backupInvalid;

  /// No description provided for @backupRollback.
  ///
  /// In en, this message translates to:
  /// **'The previous data was copied to a rollback file'**
  String get backupRollback;

  /// No description provided for @settingsGroupGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get settingsGroupGeneral;

  /// No description provided for @settingsGroupPlayback.
  ///
  /// In en, this message translates to:
  /// **'Playback'**
  String get settingsGroupPlayback;

  /// No description provided for @settingsGroupLibrary.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get settingsGroupLibrary;

  /// No description provided for @settingsGroupMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get settingsGroupMore;

  /// No description provided for @settingsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search settings'**
  String get settingsSearchHint;

  /// No description provided for @settingsNoResults.
  ///
  /// In en, this message translates to:
  /// **'No matching settings'**
  String get settingsNoResults;

  /// No description provided for @showInFolder.
  ///
  /// In en, this message translates to:
  /// **'Show in folder'**
  String get showInFolder;

  /// No description provided for @removeFromLibrary.
  ///
  /// In en, this message translates to:
  /// **'Remove from library'**
  String get removeFromLibrary;

  /// No description provided for @removeFromLibraryConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove this song from the library? The audio file is not deleted.'**
  String get removeFromLibraryConfirm;

  /// No description provided for @removedFromLibrary.
  ///
  /// In en, this message translates to:
  /// **'Removed from the library'**
  String get removedFromLibrary;

  /// No description provided for @deleteFile.
  ///
  /// In en, this message translates to:
  /// **'Delete file'**
  String get deleteFile;

  /// No description provided for @deleteFileConfirm.
  ///
  /// In en, this message translates to:
  /// **'Permanently delete this audio file? This cannot be undone.'**
  String get deleteFileConfirm;

  /// No description provided for @fileDeleted.
  ///
  /// In en, this message translates to:
  /// **'File deleted'**
  String get fileDeleted;

  /// No description provided for @noFileManager.
  ///
  /// In en, this message translates to:
  /// **'No file manager could open the folder'**
  String get noFileManager;

  /// No description provided for @showInFolderFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the folder'**
  String get showInFolderFailed;

  /// No description provided for @audioOutput.
  ///
  /// In en, this message translates to:
  /// **'Audio output'**
  String get audioOutput;

  /// No description provided for @audioRoute.
  ///
  /// In en, this message translates to:
  /// **'Current route'**
  String get audioRoute;

  /// No description provided for @audioRouteBluetooth.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth'**
  String get audioRouteBluetooth;

  /// No description provided for @audioRouteUsb.
  ///
  /// In en, this message translates to:
  /// **'USB audio'**
  String get audioRouteUsb;

  /// No description provided for @audioRouteWired.
  ///
  /// In en, this message translates to:
  /// **'Wired headphones'**
  String get audioRouteWired;

  /// No description provided for @audioRouteSpeaker.
  ///
  /// In en, this message translates to:
  /// **'Speaker'**
  String get audioRouteSpeaker;

  /// No description provided for @audioRouteEarpiece.
  ///
  /// In en, this message translates to:
  /// **'Earpiece'**
  String get audioRouteEarpiece;

  /// No description provided for @audioRouteHdmi.
  ///
  /// In en, this message translates to:
  /// **'HDMI'**
  String get audioRouteHdmi;

  /// No description provided for @audioRouteDock.
  ///
  /// In en, this message translates to:
  /// **'Dock'**
  String get audioRouteDock;

  /// No description provided for @audioRouteHearingAid.
  ///
  /// In en, this message translates to:
  /// **'Hearing aid'**
  String get audioRouteHearingAid;

  /// No description provided for @audioRouteLine.
  ///
  /// In en, this message translates to:
  /// **'Line output'**
  String get audioRouteLine;

  /// No description provided for @audioRouteOther.
  ///
  /// In en, this message translates to:
  /// **'Audio device'**
  String get audioRouteOther;

  /// No description provided for @audioOutputSampleRate.
  ///
  /// In en, this message translates to:
  /// **'Output sample rate'**
  String get audioOutputSampleRate;

  /// No description provided for @audioOutputBuffer.
  ///
  /// In en, this message translates to:
  /// **'Output buffer'**
  String get audioOutputBuffer;

  /// No description provided for @audioOutputLatency.
  ///
  /// In en, this message translates to:
  /// **'Buffer latency'**
  String get audioOutputLatency;

  /// No description provided for @audioSourceFormat.
  ///
  /// In en, this message translates to:
  /// **'Source format'**
  String get audioSourceFormat;

  /// No description provided for @audioSourceSampleRate.
  ///
  /// In en, this message translates to:
  /// **'Source sample rate'**
  String get audioSourceSampleRate;

  /// No description provided for @audioOutputDevices.
  ///
  /// In en, this message translates to:
  /// **'Connected output devices'**
  String get audioOutputDevices;

  /// No description provided for @audioOutputNote.
  ///
  /// In en, this message translates to:
  /// **'Android reports the output rate and buffer. The Bluetooth codec itself is negotiated by the system and is not exposed to apps.'**
  String get audioOutputNote;

  /// No description provided for @audioOutputUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This platform does not report output details'**
  String get audioOutputUnavailable;

  /// No description provided for @audioNoSongPlaying.
  ///
  /// In en, this message translates to:
  /// **'Nothing is playing'**
  String get audioNoSongPlaying;

  /// No description provided for @serverCapabilities.
  ///
  /// In en, this message translates to:
  /// **'Server capabilities'**
  String get serverCapabilities;

  /// No description provided for @capLyrics.
  ///
  /// In en, this message translates to:
  /// **'Lyrics by song id'**
  String get capLyrics;

  /// No description provided for @capSimilarSongs.
  ///
  /// In en, this message translates to:
  /// **'Sonic similarity'**
  String get capSimilarSongs;

  /// No description provided for @capTranscodeOffset.
  ///
  /// In en, this message translates to:
  /// **'Transcode offset'**
  String get capTranscodeOffset;

  /// No description provided for @capFormPost.
  ///
  /// In en, this message translates to:
  /// **'Form post'**
  String get capFormPost;

  /// No description provided for @capApiKey.
  ///
  /// In en, this message translates to:
  /// **'API key auth'**
  String get capApiKey;

  /// No description provided for @capPlaybackReport.
  ///
  /// In en, this message translates to:
  /// **'Playback reporting'**
  String get capPlaybackReport;

  /// No description provided for @capSimilarArtists.
  ///
  /// In en, this message translates to:
  /// **'Similar artists'**
  String get capSimilarArtists;

  /// No description provided for @capFavorites.
  ///
  /// In en, this message translates to:
  /// **'Album and artist favorites'**
  String get capFavorites;

  /// No description provided for @capLibraryScan.
  ///
  /// In en, this message translates to:
  /// **'Library scan'**
  String get capLibraryScan;

  /// No description provided for @capPlaylists.
  ///
  /// In en, this message translates to:
  /// **'Server playlists'**
  String get capPlaylists;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
