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
  /// **'Cached on this phone'**
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

  /// No description provided for @cacheCovers.
  ///
  /// In en, this message translates to:
  /// **'Cached Covers'**
  String get cacheCovers;

  /// No description provided for @cacheLyrics.
  ///
  /// In en, this message translates to:
  /// **'Cached Lyrics'**
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
