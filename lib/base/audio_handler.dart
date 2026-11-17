import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:media_kit/media_kit.dart';
import 'package:lain/base/data/config.dart';
import 'package:lain/base/data/car_display.dart';
import 'package:lain/base/data/cover_broadcast_mode.dart';
import 'package:lain/base/data/cache_download_settings.dart';
import 'package:lain/base/data/lan_direct_setting.dart';
import 'package:lain/base/data/loader.dart';
import 'package:lain/base/data/playlist.dart';
import 'package:lain/base/services/background_task_service.dart';
import 'package:lain/base/services/broadcast_inspector.dart';
import 'package:lain/base/services/home_widget_service.dart';
import 'package:lain/base/services/interaction.dart';
import 'package:lain/base/services/mobile_data_notice.dart';
import 'package:lain/base/services/my_window_listener.dart';
import 'package:lain/base/services/picture_service.dart';
import 'package:lain/base/services/play_queue_logic.dart';
import 'package:lain/base/services/stream_relay.dart';
import 'package:lain/base/services/stream_client.dart';
import 'package:lain/base/services/taskbar_service.dart';
import 'package:lain/base/services/webdav_client.dart';
import 'package:lain/base/services/color_manager.dart';
import 'package:lain/base/app.dart';
import 'package:lain/base/services/logger.dart';
import 'package:lain/base/services/lyric.dart';
import 'package:lain/base/services/media_session_item.dart';
import 'package:lain/base/services/media_art.dart';
import 'package:lain/base/services/media_broadcast.dart';
import 'package:lain/base/services/audio_focus.dart';
import 'package:lain/base/data/playback_mode.dart';
import 'package:lain/base/data/playback_effect_settings.dart';
import 'package:lain/base/utils/dynamic_lyrics_page_route.dart';
import 'package:lain/base/utils/common_utils.dart';
import 'package:lain/base/utils/path.dart';
import 'package:lain/base/widgets/equalizer.dart';
import 'package:lain/base/widgets/lyric_list_view.dart';
import 'package:lain/base/data/history.dart';
import 'package:lain/base/data/stats.dart';
import 'package:lain/layer/layers_manager.dart';
import 'package:lain/base/utils/contrast_color_generator.dart';
import 'package:lain/base/data/library.dart';
import 'package:lain/base/my_audio_metadata.dart';
import 'package:lain/base/utils/metadata_utils.dart';
import 'package:lain/layer/lyrics_page_layer.dart';
import 'dart:async';

import 'package:lain/portrait_view/sleep_timer.dart';

late AudioSession _session;

late MyAudioHandler audioHandler;

List<MyAudioMetadata> playQueue = [];
String? playQueueForStreamId;

final ValueNotifier<MyAudioMetadata?> currentSongNotifier = ValueNotifier(null);
final isPlayingNotifier = ValueNotifier(false);
final playModeNotifier = ValueNotifier(0);
final volumeNotifier = ValueNotifier(0.3);

final autoPlayOnStartupNotifier = ValueNotifier(false);

final currentLyricsIndexNotifier = ValueNotifier(-1);

/// Whether lyric lines are broadcast to a car head unit (the settings tile
/// "broadcast lyrics"). Named for Core's control centre when this was a
/// notification feature; the stored key is kept so an existing setting carries
/// over.
///
/// On: the primary line is the current lyric line and the secondary one is
/// `artist - title`. Off: plain track metadata, and no metadata update
/// per lyric line at all - each one is a full AVRCP/`MediaSession` read on the
/// head unit.
final controlCenterLyricsNotifier = ValueNotifier(false);

bool loadingSong = false;

Future<void> initAudioService() async {
  MediaKit.ensureInitialized();
  audioHandler = await AudioService.init(
    builder: () => MyAudioHandler(),

    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.meidlinger.lain',
      androidNotificationChannelName: 'Lain',
      androidNotificationOngoing: true,
    ),
  );
  _session = await AudioSession.instance;
  // Configure for the playback mode in effect (the handler re-reads the
  // setting from disk when it starts, so this is the persisted choice).
  adopt(_session, playbackModeNotifier.value);

  await _session.setActive(true);

  // Start the LAN cover relay now, so the first track can be published with a
  // car-fetchable artwork URI straight away instead of a beat later.
  unawaited(streamRelay.warmUp());
  unawaited(broadcastInspector.start());

  _session.becomingNoisyEventStream.listen((_) {
    audioHandler.pause();
  });

  // Interruptions are handled per playback mode: exclusive pauses and resumes,
  // duck lowers the volume instead of pausing, mix ignores them. The events are
  // only listened to once the handler exists, since keeping them queued would
  // act on an interruption that is already over.
  unawaited(
    audioHandler.whenReady.then((_) => audioHandler.startPlaybackModeHandling()),
  );

  if (isMobile) {
    const channel = MethodChannel('com.meidlinger.lain.audio_control');

    channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'toggleFavorite':
          if (currentSongNotifier.value != null) {
            // iOS only: hold background runtime so the command is not cut off
            // when the widget tap woke the app in the background.
            await audioHandler.beginWidgetCommandGrace();
            toggleFavoriteState(currentSongNotifier.value!);
          }
        case 'skipToPrevious':
          audioHandler.skipToPrevious();
        case 'togglePlay':
          await audioHandler.beginWidgetCommandGrace();
          audioHandler.togglePlay();
        case 'skipToNext':
          audioHandler.skipToNext();
        default:
      }
    });
  }
}

/// What the player was doing before the lyric timeline borrowed it.
class LyricPreviewBookmark {
  final List<MyAudioMetadata> queue;
  final List<MyAudioMetadata> queueTmp;
  final int index;
  final Duration position;
  final bool wasPlaying;
  final int playMode;

  const LyricPreviewBookmark({
    required this.queue,
    required this.queueTmp,
    required this.index,
    required this.position,
    required this.wasPlaying,
    required this.playMode,
  });
}

class MyAudioHandler extends BaseAudioHandler {
  final _player = Player();
  bool _started = false;
  int currentIndex = -1;
  List<MyAudioMetadata> _playQueueTmp = [];
  int _tmpPlayMode = 0;

  /// What the last clear removed, so it can be put back from the undo bar.
  List<MyAudioMetadata>? _clearedQueue;
  List<MyAudioMetadata>? _clearedQueueTmp;
  int _clearedIndex = -1;
  Duration _clearedPosition = Duration.zero;
  DateTime? _playLastSyncTime;
  Duration _playedDuration = Duration.zero;

  /// The next track whose audio is being fetched for the queue's upcoming
  /// switch, and the token that lets a later queue change stop it.
  String? _nextCacheSongId;
  CancelToken? _nextCacheToken;

  /// Bumped whenever a track load starts the cache chain. A chain that finds a
  /// newer generation has been superseded and must not prefetch anything.
  int _cacheFlowGeneration = 0;

  File? _playQueueState;
  late File _playState;
  late File _equalizerState;
  late File _positionState;

  Timer? _positionTimer;

  /// A volume ramp in progress, and the command that owns it. A newer
  /// play/pause/duck cancels the ramp so two of them never fight over the
  /// player's level.
  Timer? _fadeTimer;
  int _fadeToken = 0;
  int _transportGeneration = 0;

  /// The last position reported to the server's now-playing entry, and the
  /// song it belonged to. Reports are throttled so a stream does not get one
  /// request per second.
  DateTime? _lastProgressReportAt;
  String? _progressReportSongId;

  /// The player volume a ramp returns to. On a phone the player runs at its
  /// own full level and the system mixer does the rest, so it must not be tied
  /// to the in-app 0..1 slider default.
  double _volumeTarget = 100;

  // Last lyric line pushed to the system media session, so the notification is
  // only refreshed when the displayed line actually changes.
  String? _publishedLyric;

  // Artwork announced for the song currently in the media session. Kept per
  // song so a lyric-line update never drops the artwork again (that is what made
  // a cover appear and then vanish), and so a track that is switched back to
  // needs no work.
  String? _pubSongId;
  String? _pubFileArtUri;
  String? _pubCoverPath;
  String? _pubSmallArtPath;

  /// A URI a head unit can fetch itself, when the selected mode asks for one.
  String? _pubFetchArtUri;

  static const _mediaChannel = MethodChannel('com.meidlinger.lain.media');
  final Map<String, String> _contentUriCache = {};
  final Set<String> _contentUriInFlight = {};

  // The broadcast gate for the system media session: one generation per
  // announced track (an async cover result from an older one is dropped
  // instead of overwriting the current track) and one coalesced publish, so a
  // burst of switches reaches the head unit as a single item instead of a
  // queue of every track it skipped through.
  final _broadcast = MediaBroadcaster();

  /// Whether a track switch is in flight: from the moment [load] starts until
  /// the player has it open. Only read by the completion handler, to tell an
  /// end-of-track report from the tail of the file that was just replaced.
  bool _hasSwitchInFlight() {
    final started = _lastSwitchAt;
    return started != null &&
        DateTime.now().difference(started) < const Duration(seconds: 3);
  }

  /// Whether the load [generation] is the one that should still reach the
  /// session.
  bool _isCurrentLoad(int generation) => generation == _loadGeneration;

  /// The artwork announced for the current song, and the version the snapshot's
  /// item id carries. [MediaBroadcaster.publish] only re-sends an item whose
  /// key changed, and a consumer (audio_service's bitmap cache, a head unit)
  /// keys artwork by item id - so a cover that arrived after the first publish
  /// must change the id, or it is never read.

  /// The load generation the track switch that is opening was started for.
  /// Everything a load does after its first await checks it, so a switch that
  /// was superseded by a later one cannot publish its track or reset the
  /// session's playback position over the newer one.
  int _loadGeneration = 0;

  // Set when a load aborted before it opened anything (nothing to show yet).
  // The next play() retries the load instead of resuming a player that was
  // never opened, which would otherwise leave the button dead.
  bool _needsReload = false;

  // Guards the single automatic retry of a failed stream open after switching
  // between the home and away addresses.
  bool _retriedAfterAddressSwitch = false;

  // How many times the current track has been *restarted from the beginning*
  // because a stream reported the end of a buffered segment as the end of the
  // song. mpv can report more than one for the same stall.
  int _fakeCompleteResumes = 0;

  // How many tracks this session has advanced from automatically, and how many
  // of those were "the song ended" rather than a user pressing next. Used by
  // the end-of-track diagnostics; see [_hasAdvancedRecently].
  int _autoAdvanceCount = 0;
  int _completedAdvanceCount = 0;

  // Identity of the last "the song ended" that was acted on, so the same
  // end-of-track cannot advance the queue twice.
  String? _lastCompletionKey;

  // Timestamp floor for "did the queue advance just now": a completion that
  // arrives right after a track switch is the previous track's tail.
  DateTime? _lastSwitchAt;

  // A load in progress, and the index it is opening.
  bool _loading = false;
  int _loadingIndex = -1;

  // Work already started for a song, so a burst of publishes does not queue the
  // same download or URI resolution twice.
  final Set<String> _coverLoadInFlight = {};
  final Map<String, Future<void>> _smallArtWork = {};

  DateTime? _songSwitchedAt;

  // iOS background-execution grace for the current load (see _beginLoadGrace).
  StreamSubscription<bool>? _loadGraceSub;
  int? _loadGraceToken;
  bool _loadGraceSawBuffering = false;

  // iOS background-execution grace for widget-button commands.
  int? _widgetCommandToken;
  Timer? _widgetCommandTimer;
  StreamSubscription<Duration>? _widgetCommandSub;

  // iOS background-execution grace held while mpv is buffering, including
  // mid-song stalls on weak network.
  int? _stallGraceToken;
  bool _stallGraceArming = false;

  MyAudioHandler() {
    // avoid reading .lrc files
    (_player.platform as NativePlayer).setProperty('sub-auto', 'no');
    // A speed change must not transpose the music: mpv's scaletempo filter
    // keeps the pitch while it changes the tempo. Set explicitly because the
    // bundled libmpv builds do not all ship the same default.
    (_player.platform as NativePlayer).setProperty(
      'audio-pitch-correction',
      'yes',
    );
    if (_player.state.volume > 0) {
      _volumeTarget = _player.state.volume;
    }
    _applyReplayGain();
    _applyPlaybackSpeed();
    replayGainModeNotifier.addListener(_applyReplayGain);
    playbackSpeedNotifier.addListener(_applyPlaybackSpeed);

    if (Platform.isIOS) {
      (_player.platform as NativePlayer).setProperty('audio-exclusive', 'yes');
    }

    _player.stream.error.listen((onData) {
      logger.output("player error:$onData");
    });

    // Reported positions the ear can notice: the opening of a track and the
    // close of one. A position this close to either means the completion is
    // about the song, not about a buffered segment.
    const edgeWindow = Duration(seconds: 5);

    _player.stream.completed.listen((completed) async {
      if (!completed) {
        return;
      }
      final song = currentSongNotifier.value;
      final position = _player.state.position;
      final duration = _player.state.duration;

      _completionLog(
        'completed id=${song?.id ?? '-'} pos=${_fmtDuration(position)} '
        'dur=${_fmtDuration(duration)} '
        'idle=${_player.state.buffering} loading=$loadingSong '
        'paused=${!isPlayingNotifier.value} mode=${playModeNotifier.value} '
        'resumes=$_fakeCompleteResumes${_sinceSwitch()}',
      );

      // A completion that arrives while this track is still opening belongs to
      // whatever mpv was playing before - the track the user just skipped past,
      // or the one before it. Advancing on it skipped a track unasked, and on a
      // car it looked like the session jumping through the queue on its own.
      // Opening a track resets the completed flag, so the new track still
      // reports its own end.
      final loadGenerationAtEntry = _loadGeneration;
      if (_hasSwitchInFlight()) {
        _completionLog(
          'completion while a track is still opening, ignored '
          '(belongs to the previous file)',
        );
        return;
      }

      if (Loader.busy) {
        _completionLog('load in progress, pausing instead of advancing');
        await pause();
        return;
      }

      // The same end-of-track can be delivered more than once (a renderer
      // flush around a seek, or a player reset). Acting on it twice is what
      // played a song twice and then jumped: the second delivery resumed the
      // song that had just been opened, from its beginning.
      final key =
          '${song?.id ?? '-'}@${duration.inMilliseconds}/'
          '${(position.inMilliseconds / 1000).round()}';
      if (_lastCompletionKey == key) {
        _completionLog('duplicate of a completion already acted on, ignored');
        return;
      }

      // A streamed song can report completion at the end of a buffered
      // segment while it is not over. Only stream sources can: a local file
      // has nowhere to stall, and a player reset can report a position near
      // zero right after opening - which is why "resumed already" was not
      // enough (the first bogus report consumed the allowance, the second one
      // moved on). A completion that arrives right after a switch is the
      // previous track's tail.
      //
      // The old test let one dangerous case through: a report arriving far
      // from both ends (a seek flush, a demuxer hiccup, a key frame
      // adjustment) was read as "the song ended" and the player moved on.
      // With a head unit attached that is exactly the runaway skipping the
      // user reports, since every such report advanced the queue. A report
      // that is neither near the start nor near the end is therefore treated
      // as bogus as well.
      final nearStart = position <= edgeWindow;
      final nearEnd = duration > Duration.zero
          ? (duration - position) <= edgeWindow
          : true;
      final atEnd = duration > Duration.zero && position >= duration;
      final justSwitched =
          _lastSwitchAt != null &&
          DateTime.now().difference(_lastSwitchAt!) <
              const Duration(milliseconds: 1500);
      final midTrack = !nearStart && !nearEnd && !atEnd;
      final couldBeSegmentEnd =
          isStreamSource && !atEnd && (nearStart || midTrack) && !justSwitched;

      if (couldBeSegmentEnd) {
        _fakeCompleteResumes++;
        _completionLog(
          'end of a buffered segment, resuming id=${song?.id ?? '-'} '
          'from ${_fmtDuration(position)} (attempt $_fakeCompleteResumes)',
        );
        if (_fakeCompleteResumes <= 3) {
          // Resume from where the track stopped - never from the beginning.
          // A real end of file can sit well short of the duration mpv
          // estimated (a VBR header that disagrees with the frames that
          // follow), and restarting from zero on it is what played a handful
          // of tracks twice, every single time, regardless of network, cache
          // or how they were started.
          final before = _player.state.position;
          await _player.play();
          updatePlaybackState();

          // Give the resumed stream a moment to move. A stalled segment
          // continues and its position advances; the end of a file does not,
          // and neither does it buffer. Telling the two apart is what keeps a
          // short-of-duration track from being replayed while still resuming
          // a genuine mid-track stall.
          var waited = 0;
          while (waited < 5000) {
            await Future<void>.delayed(const Duration(milliseconds: 250));
            waited += 250;
            if (loadGenerationAtEntry != _loadGeneration) {
              return;
            }
            if (_player.state.position > before) {
              _completionLog(
                'resumed from ${_fmtDuration(before)}, position advancing',
              );
              return;
            }
            if (!_player.state.buffering) {
              break;
            }
          }
          _completionLog(
            'resume did not advance, reading it as the end of the track '
            '(reported duration ${_fmtDuration(duration)} '
            'ended at ${_fmtDuration(position)})',
          );
          // Fall through: this was the track's real end, not a segment.
        } else {
          // Giving up on that theory: let it move on rather than loop forever.
          _completionLog('too many segment-end reports, advancing anyway');
        }
      }

      _lastCompletionKey = key;

      // The awaits above can have let a later switch start; the end of the
      // track that was playing then is not the current track's to act on.
      if (loadGenerationAtEntry != _loadGeneration) {
        _completionLog('completion superseded by a newer track switch, ignored');
        return;
      }

      if (playModeNotifier.value == 2) {
        // Repeat one: the same track from the beginning, the queue untouched.
        // A load flag left behind by an earlier superseded load must not
        // swallow the replay (the generation check above already ruled out a
        // newer switch being in flight).
        _completionLog(
          'repeat one, restarting id=${song?.id ?? '-'}',
        );
        _loading = false;
        await load();
      } else {
        _completedAdvanceCount++;
        _completionLog(
          'song ended, advancing to the next track '
          '(automatic=$_autoAdvanceCount fromEnd=$_completedAdvanceCount)',
        );
        _autoAdvanceCount++;
        await skipToNext(); // automatically go to next song
      }
    });

    currentSongNotifier.addListener(() {
      if (viewModeNotifier.value == .bigPicture) {
        if (useCurrentSongForBg) {
          colorManager.updateBigPictureRelatedColors(
            currentSongNotifier.value?.picture,
          );
        }
        return;
      }
      layersManager.updateBackground();
    });

    _player.stream.position.listen(_updateCurrentLyricIndex);

    // iOS: hold a background task for the whole buffering phase (including
    // mid-song stalls on weak network) so the process is not suspended before
    // buffering completes. core-idle also reports true on stop/pause, so only
    // arm while a song is actually playing or loading.
    _player.stream.buffering.listen((buffering) {
      if (buffering) {
        _beginStallGrace();
      } else {
        _endStallGrace();
      }
    });
  }

  void _updateCurrentLyricIndex(Duration position) {
    final currentSong = currentSongNotifier.value;
    if (currentSong == null ||
        loadingSong ||
        position < Duration.zero ||
        currentSongNotifier.value!.parsedLyrics == null) {
      return;
    }
    int tmp = currentLyricsIndexNotifier.value;
    final lines = currentSong.parsedLyrics!.lines;

    position += Duration(milliseconds: currentSong.lyricsTimeOffset);

    if (tmp >= 0 &&
        tmp + 1 < lines.length &&
        position >= lines[tmp].start &&
        position <= lines[tmp + 1].start) {
      return;
    }

    int current = -1;
    if (position >= lines.last.start) {
      current = lines.length - 1;
    } else {
      for (int i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (position < line.start) {
          break;
        }
        if (current == -1 || line.start > lines[current].start) {
          current = i;
        }
      }
    }

    if (current != currentLyricsIndexNotifier.value) {
      currentLyricsIndexNotifier.value = current;

      // Publish the current lyric line to the system media session, but only
      // when the user asked for lyrics to be broadcast: every metadata update
      // costs the head unit a full AVRCP read, and one per lyric line with the
      // feature off is pure noise. The playback state is not re-sent either -
      // the line changed, the playback did not, and a playback update on every
      // line made the unit re-read the item again.
      final lineText = (current >= 0 && current < lines.length)
          ? lines[current].text
          : null;
      if (controlCenterLyricsNotifier.value && lineText != _publishedLyric) {
        updateServiceMediaItem(
          currentSong,
          lyric: lineText,
          kind: MediaUpdateKind.lyric,
        );
      }

      if (isMobile) {
        HomeWidgetService.updateLyricsIndex();
      }
    }
  }

  Future<void> updateIsPlaying(bool isPlaying) async {
    if (isPlaying) {
      _playLastSyncTime = DateTime.now();
    } else if (_playLastSyncTime != null) {
      _playedDuration += DateTime.now().difference(_playLastSyncTime!);
      _playLastSyncTime = null;
    }
    needPause = false;
    isPlayingNotifier.value = isPlaying;
    if (Platform.isWindows) {
      if (!windowIsClosed) {
        setupTaskbar();
      }
    } else if (isMobile) {
      await HomeWidgetService.updateIsPlaying();
    }
  }

  void updatePlaybackState({Duration? postion, bool stop = false}) {
    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          isPlayingNotifier.value ? MediaControl.pause : MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: {MediaAction.seek},
        playing: isPlayingNotifier.value,
        processingState: stop ? .idle : .ready,
        speed: _player.state.rate,
        updatePosition: postion ?? _player.state.position,
        queueIndex: _serviceQueueIndex,
      ),
    );
  }

  /// Where the published queue window starts in [playQueue], and the index
  /// inside that window. Android MediaSession queue ids are positions in the
  /// published list, so both a car's queue and its "skip to item" call are
  /// mapped through these.
  int _queueWindowStart = 0;
  int? _serviceQueueIndex;
  String? _queueWindowSignature;

  /// Publishes a window of the queue around the current song.
  ///
  /// A MediaSession queue is what a head unit browses and what gives it the
  /// "7 of 1286" position; a whole 1000+ song queue as one Binder payload is
  /// more than the link can carry, so only 200 items either side of the
  /// current one are sent. The track number/count extras still describe the
  /// full queue, so the unit reports the real position rather than the window.
  void _publishQueueWindow() {
    if (playQueue.isEmpty) {
      if (_queueWindowSignature != null) {
        _queueWindowSignature = null;
        _serviceQueueIndex = null;
        queue.add(const <MediaItem>[]);
      }
      return;
    }
    if (currentIndex < 0 || currentIndex >= playQueue.length) {
      return;
    }
    const window = 200;
    var start = currentIndex - window ~/ 2;
    var end = start + window;
    if (start < 0) {
      start = 0;
      end = math.min(window, playQueue.length);
    }
    if (end > playQueue.length) {
      end = playQueue.length;
      start = math.max(0, playQueue.length - window);
    }
    final current = playQueue[currentIndex];
    final signature =
        '${playQueue.length}|$start|$end|$currentIndex|${current.id}|'
        '${playQueue.first.id}|${playQueue.last.id}|'
        '${playQueue[start].id}|${playQueue[end - 1].id}';
    _serviceQueueIndex = currentIndex - start;
    if (signature == _queueWindowSignature) {
      return;
    }
    _queueWindowSignature = signature;
    _queueWindowStart = start;

    final items = <MediaItem>[];
    for (var i = start; i < end; i++) {
      final song = playQueue[i];
      items.add(
        buildServiceMediaItem(
          id: song.id,
          songTitle: getTitle(song),
          artist: getArtist(song),
          album: getAlbum(song),
          duration: song.duration,
          trackNumber: i + 1,
          trackCount: playQueue.length,
        ),
      );
    }
    queue.add(items);
    updatePlaybackState();
  }

  void _prepare() {
    _playQueueState = File(
      "${appSupportDir.path}/${sourceType.name}/play_queue_state.json",
    );
    if (!(_playQueueState!.existsSync())) {
      _playQueueState!.createSync(recursive: true);
      _savePlayQueueState();
    }

    _playState = File(
      "${appSupportDir.path}/${sourceType.name}/play_state.json",
    );
    if (!(_playState.existsSync())) {
      _playState.createSync(recursive: true);
      savePlayState();
    }
    _equalizerState = File("${appSupportDir.path}/equalizer_state.json");
    if (!(_equalizerState.existsSync())) {
      saveEqualizerState();
    }

    _positionState = File(
      "${appSupportDir.path}/${sourceType.name}/position_state.json",
    );
    if (!(_positionState.existsSync())) {
      _positionState.createSync(recursive: true);
      _positionState.writeAsString(Duration.zero.inMilliseconds.toString());
    }
  }

  List<MyAudioMetadata> _restoreQueue(List<dynamic>? rawList) {
    final result = <MyAudioMetadata>[];

    for (final id in rawList ?? []) {
      final song = library.id2Song[id];
      // Offline cached mode cannot play a song whose file is not on disk.
      if (song != null && (!library.cachedOnly || song.cacheExist)) {
        result.add(song);
      }
    }

    return result;
  }

  Future<void> loadStates() async {
    _prepare();
    _resolvedReady.complete();
    await _loadPlayState();
    await _loadPlayQueueState();
    await _loadEqualizerState();
    await _tryPlay();
  }

  Future<void> _loadPlayQueueState() async {
    final content = await _playQueueState!.readAsString();

    final json = jsonDecode(content) as Map<String, dynamic>;

    _playQueueTmp.addAll(_restoreQueue(json['playQueueTmp']));
    playQueue.addAll(_restoreQueue(json['playQueue']));
  }

  Future<void> _savePlayQueueState() async {
    _playQueueState!.writeAsStringSync(
      jsonEncode({
        'playQueueTmp': _playQueueTmp.map((e) => e.id).toList(),
        'playQueue': playQueue.map((e) => e.id).toList(),
      }),
    );
  }

  Future<void> _tryPlay() async {
    if (!_started && autoPlayOnStartupNotifier.value) {
      if (playQueue.isEmpty) {
        currentIndex = 0;
        playQueue = List.from(library.songList);
      }
      if (playQueue.isNotEmpty) {
        isPlayingNotifier.value = true;
      } else {
        currentIndex = -1;
      }
    }

    if (playQueue.isNotEmpty) {
      // reload may make some songs not in the library to be removed
      if (currentIndex == -1 || currentIndex >= playQueue.length) {
        currentIndex = 0;
      }

      final positionMs = await _positionState.readAsString();

      await load(start: Duration(milliseconds: int.tryParse(positionMs) ?? 0));

      if (isPlayingNotifier.value) {
        _startPositionTimer();
      }
    }

    if (!_started) {
      _started = true;
      if (autoPlayOnStartupNotifier.value) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (currentSongNotifier.value != null) {
            globalNavigatorKey.currentState?.push(
              DynamicLyricsPageRoute(
                pageBuilder: (_, _, _) => LyricsPageLayer(),
              ),
            );
          }
        });
      }
    }
  }

  Future<void> _loadPlayState() async {
    final content = await _playState.readAsString();
    final Map<String, dynamic> json =
        jsonDecode(content) as Map<String, dynamic>;

    currentIndex = json['currentIndex'] as int? ?? -1;
    playModeNotifier.value = json['playMode'] as int? ?? 0;
    _tmpPlayMode = json['tmpPlayMode'] as int? ?? 0;

    volumeNotifier.value = json['volume'] as double? ?? 0.3;

    if (!isMobile) {
      setVolume(volumeNotifier.value);
    }
  }

  void savePlayState() {
    _playState.writeAsStringSync(
      jsonEncode({
        'currentIndex': currentIndex,
        'playMode': playModeNotifier.value,
        'tmpPlayMode': _tmpPlayMode,
        'volume': volumeNotifier.value,
      }),
    );
  }

  Future<void> _loadEqualizerState() async {
    if (!isPremiumNotifier.value) {
      return;
    }
    final content = await _equalizerState.readAsString();
    gains = (jsonDecode(content) as List<dynamic>).cast();
    await applyEqualizer();
  }

  void saveEqualizerState() {
    _equalizerState.writeAsStringSync(jsonEncode(gains));
  }

  void saveAllStates() async {
    await audioHandler._savePlayQueueState();
    audioHandler.savePlayState();
  }

  bool insert2Next(MyAudioMetadata song) {
    final result = PlayQueueLogic.insert2Next(playQueue, currentIndex, song);
    if (result == null) {
      return false;
    }
    currentIndex = result.currentIndex;
    if (result.wasNewlyInserted &&
        (playModeNotifier.value == 1 ||
            (playModeNotifier.value == 2 && audioHandler._tmpPlayMode == 1))) {
      _playQueueTmp.add(song);
    }
    // The queue changed, so what is next/previous changed too.
    _prefetchNeighbours();
    return true;
  }

  bool add2Last(MyAudioMetadata song) {
    final result = PlayQueueLogic.add2Last(playQueue, currentIndex, song);
    if (result == null) {
      return false;
    }
    currentIndex = result.currentIndex;
    if (result.wasNewlyInserted &&
        (playModeNotifier.value == 1 ||
            (playModeNotifier.value == 2 && audioHandler._tmpPlayMode == 1))) {
      _playQueueTmp.add(song);
    }
    // Appending can change what modulo wraps to when this is the last index.
    final current = currentSongNotifier.value;
    if (current != null && current.cacheExist) {
      _cacheNextSong();
    }
    return true;
  }

  void singlePlay(MyAudioMetadata song) async {
    if (insert2Next(song)) {
      await skipToNext();
    }
    play();
  }

  Future<void> setPlayQueue(
    List<MyAudioMetadata> source,
    int playMode, {
    int? targetIndex,
  }) async {
    if (source.isEmpty) {
      return;
    }
    final tapped = targetIndex != null &&
            targetIndex >= 0 &&
            targetIndex < source.length
        ? source[targetIndex]
        : null;
    // A tap on a row keeps the mode the user is in; the page's play-all and
    // shuffle buttons choose one.
    final mode = tapped != null ? playModeNotifier.value : playMode;
    // A new queue replaces anything an undo could put back.
    _clearedQueue = null;
    _clearedQueueTmp = null;

    // The order this queue was created in. Every later mode change rebuilds
    // from it, so it must always describe the queue being installed now. The
    // old code left a snapshot from an earlier queue behind, and asking for
    // "list loop" later swapped that stale list in - or found no current song
    // at all when the page had rebuilt its objects (the favourites case).
    _playQueueTmp = List.from(source);

    if (mode == 1) {
      // Shuffle: the tapped song (if any) plays first, the rest random.
      final others = List.of(source)
        ..removeWhere((song) => song.id == tapped?.id)
        ..shuffle();
      playQueue = [?tapped, ...others];
      currentIndex = 0;
    } else {
      playQueue = List.from(source);
      currentIndex = tapped == null ? 0 : _indexOfId(playQueue, tapped.id);
      if (currentIndex < 0) {
        currentIndex = 0;
      }
    }

    if (mode != 2) {
      _tmpPlayMode = mode;
    }
    playModeNotifier.value = mode;

    await audioHandler.load();
    audioHandler.play();

    saveAllStates();
  }

  void reversePlayQueue() {
    if (playQueue.isEmpty) {
      return;
    }
    playQueue = playQueue.reversed.toList();
    if (_playQueueTmp.isNotEmpty) {
      _playQueueTmp = _playQueueTmp.reversed.toList();
    }
    currentIndex = _indexOfId(playQueue, currentSongNotifier.value?.id);
    if (currentIndex < 0) {
      currentIndex = 0;
    }
    _prefetchNeighbours();
    saveAllStates();
  }

  /// Puts the current song first and shuffles the rest of the *original* order.
  void shuffle() {
    if (playQueue.isEmpty) {
      return;
    }
    final current = currentSongNotifier.value ??
        playQueue[currentIndex.clamp(0, playQueue.length - 1)];
    if (_playQueueTmp.isEmpty) {
      _playQueueTmp = List.from(playQueue);
    }
    final others = List.of(_playQueueTmp)
      ..removeWhere((song) => song.id == current.id)
      ..shuffle();
    playQueue = [current, ...others];
    currentIndex = 0;
    _prefetchNeighbours();
  }

  void changePlayMode(int newPlayMode) async {
    if (newPlayMode == playModeNotifier.value) {
      return;
    }
    final previousMode = playModeNotifier.value;
    final current = currentSongNotifier.value ??
        (playQueue.isEmpty
            ? null
            : playQueue[currentIndex.clamp(0, playQueue.length - 1)]);

    switch (newPlayMode) {
      case 0:
        // List loop: the order the queue was created in, with the song that is
        // playing now still playing.
        playQueue = List.from(
          _playQueueTmp.isNotEmpty ? _playQueueTmp : playQueue,
        );
        currentIndex = _indexOfId(playQueue, current?.id);
        if (currentIndex < 0) {
          currentIndex = 0;
        }
        break;
      case 1:
        // Shuffle always rebuilds from the original order. The old code did
        // nothing when a snapshot existed, which is why the button looked dead
        // after a previous shuffle.
        final base =
            _playQueueTmp.isNotEmpty ? List.of(_playQueueTmp) : List.of(playQueue);
        final others = base
            .where((song) => song.id != current?.id)
            .toList()
          ..shuffle();
        playQueue = [?current, ...others];
        currentIndex = 0;
        break;
      default:
        // Repeat one keeps the queue exactly as it is, and remembers the mode
        // to return to when the user leaves it.
        if (previousMode != 2) {
          _tmpPlayMode = previousMode;
        }
        break;
    }

    playModeNotifier.value = newPlayMode;
    _showPlayModeMessage(newPlayMode);
    if (newPlayMode != 2) {
      await _savePlayQueueState();
    }
    _prefetchNeighbours();
    savePlayState();
  }

  /// Short press on the play-mode button: list loop <-> shuffle only. From
  /// repeat one it returns to the mode repeat one was entered from.
  void toggleListAndShuffle() {
    if (playQueue.isEmpty) {
      return;
    }
    final current = playModeNotifier.value;
    if (current == 2) {
      changePlayMode(_tmpPlayMode == 2 ? 0 : _tmpPlayMode);
      return;
    }
    changePlayMode(current == 0 ? 1 : 0);
  }

  /// Long press: repeat one, on the queue that is playing now - no detour
  /// through shuffle and no new queue. Pressing it again leaves repeat one.
  void setRepeatOne() {
    if (playQueue.isEmpty) {
      return;
    }
    if (playModeNotifier.value == 2) {
      changePlayMode(_tmpPlayMode == 2 ? 0 : _tmpPlayMode);
    } else {
      changePlayMode(2);
    }
  }

  void _showPlayModeMessage(int mode) {
    final l10n = getAppLocalizations();
    showCenterMessage(
      mode == 0
          ? l10n.loop
          : mode == 1
          ? l10n.shuffle
          : l10n.repeat,
    );
  }

  int _indexOfId(List<MyAudioMetadata> list, String? id) {
    if (id == null) {
      return -1;
    }
    for (var i = 0; i < list.length; i++) {
      if (list[i].id == id) {
        return i;
      }
    }
    return -1;
  }

  void delete(int index) {
    MyAudioMetadata tmp = playQueue[index];
    if (_playQueueTmp.isNotEmpty) {
      _playQueueTmp.removeWhere((song) => song.id == tmp.id);
    }
    playQueue.removeAt(index);
    _prefetchNeighbours();
  }

  Future<void> clear({bool notifyUndo = true}) async {
    final hadQueue = playQueue.isNotEmpty;
    if (hadQueue) {
      _clearedQueue = List.of(playQueue);
      _clearedQueueTmp = List.of(_playQueueTmp);
      _clearedIndex = currentIndex.clamp(0, playQueue.length - 1);
      _clearedPosition = getPosition();
    } else {
      _clearedQueue = null;
      _clearedQueueTmp = null;
      _clearedIndex = -1;
      _clearedPosition = Duration.zero;
    }
    await stop();
    playQueue = [];
    _playQueueTmp = [];
    currentIndex = -1;
    currentSongNotifier.value = null;
    currentCoverArtColor = Colors.grey;
    _queueWindowSignature = null;
    _serviceQueueIndex = null;
    queue.add(const <MediaItem>[]);
    saveAllStates();

    if (isMobile) {
      HomeWidgetService.updateNowPlayingWidget();
      HomeWidgetService.reloadPlaylistsWidget();
    }

    if (hadQueue && notifyUndo) {
      showUndoMessage(getAppLocalizations().queueCleared, () {
        unawaited(undoClearQueue());
      });
    }
  }

  /// Puts back the queue that [clear] removed and resumes where it was.
  Future<bool> undoClearQueue() async {
    final queue = _clearedQueue;
    if (queue == null || queue.isEmpty) {
      return false;
    }
    final tmp = _clearedQueueTmp;
    final start = _clearedPosition;
    final index = _clearedIndex;
    _clearedQueue = null;
    _clearedQueueTmp = null;
    _clearedIndex = -1;
    _clearedPosition = Duration.zero;

    playQueue = List.of(queue);
    _playQueueTmp = List.of(tmp ?? const []);
    currentIndex = index.clamp(0, playQueue.length - 1);
    await load(start: start > Duration.zero ? start : null);
    await play();
    saveAllStates();
    return true;
  }

  void justClear() {
    _clearedQueue = null;
    _clearedQueueTmp = null;
    _clearedIndex = -1;
    _clearedPosition = Duration.zero;
    _endLoadGrace();
    _endStallGrace();
    _player.stop();
    updateIsPlaying(false);
    updatePlaybackState(stop: true);
    _positionTimer?.cancel();
    _positionTimer = null;

    playQueue = [];
    _playQueueTmp = [];
    currentIndex = -1;
    currentSongNotifier.value = null;
    currentCoverArtColor = Colors.grey;

    if (isMobile) {
      HomeWidgetService.updateNowPlayingWidget();
      HomeWidgetService.reloadPlaylistsWidget();
    }
  }

  List<MyAudioMetadata> getNewQueue(List<MyAudioMetadata> oldQueue) {
    final List<MyAudioMetadata> newPlayQueue = [];
    for (final song in oldQueue) {
      final newSong = library.id2Song[song.id];
      if (newSong != null) {
        newPlayQueue.add(newSong);
      }
    }
    return newPlayQueue;
  }

  Future<void> sync() async {
    playQueue = getNewQueue(playQueue);
    _playQueueTmp = getNewQueue(_playQueueTmp);
    final currentSong = currentSongNotifier.value;
    if (currentSong != null) {
      final tmpCurrentSong = library.id2Song[currentSong.id];
      if (tmpCurrentSong != null) {
        await _setLyricsAndUpdateColors(tmpCurrentSong);
        currentSongNotifier.value = tmpCurrentSong;
        currentIndex = playQueue.indexOf(tmpCurrentSong);
        updateServiceMediaItem(tmpCurrentSong);
      } else {
        currentSongNotifier.value = null;
        currentIndex = -1;
        if (playQueue.isNotEmpty) {
          await skipToNext();
        } else {
          await stop();
        }
      }
    }
    saveAllStates();
  }

  Future<void> _setLyricsAndUpdateColors(MyAudioMetadata song) async {
    await setParsedLyrics(song);
    await _updateColorsFor(song);
  }

  /// The cover's colour, which drives the app's theme. Kept apart from the
  /// lyrics so the stream never waits for the artwork to be downloaded first:
  /// the colour is cosmetic and can land whenever it is ready.
  Future<void> _updateColorsFor(MyAudioMetadata song) async {
    final color = await computeColor(song.picture);
    if (currentSongNotifier.value?.id != song.id) {
      // The song moved on while the colour was being computed.
      return;
    }
    currentCoverArtColor = color;
    updateHoverFocusColor();
    contrastColorTheme = ContrastColorGenerator.generate(currentCoverArtColor);
    if (lyricsPageThemeNotifier.value == .vivid) {
      colorManager.updateLyricsPageColors();
    }

    if (viewModeNotifier.value == .mini) {
      colorManager.updateMiniViewColors();
    }
  }

  /// Warms the artwork (and, for the next/previous track, the lyrics) of the
  /// tracks around the current one, so a switch shows both at once instead of
  /// after a download.
  ///
  /// Two tracks each way: the second one is only reached by skipping twice, but
  /// a listener who skips through a queue does that often enough that its cover
  /// being ready is worth the one-time fetch. Only the immediate neighbours
  /// warm their lyrics as well - lyrics are a server call on most sources,
  /// while the cover is what a switch needs in the same instant.
  ///
  /// Only worth doing on a phone, where something other than this app displays
  /// them (a head unit); on a desktop it would just do work for nothing.
  void _prefetchNeighbours() {
    if (isMobile) {
      for (final delta in const [1, -1]) {
        final neighbour = currentIndex + delta;
        if (neighbour < 0 || neighbour >= playQueue.length) {
          continue;
        }
        unawaited(_prefetch(playQueue[neighbour]));
      }
      for (final delta in const [2, -2]) {
        final neighbour = currentIndex + delta;
        if (neighbour < 0 || neighbour >= playQueue.length) {
          continue;
        }
        unawaited(_prefetch(playQueue[neighbour], lyrics: false));
      }
    }
    // Queue changes can alter which track is next. The next track's audio only
    // starts once the current track is on disk; the cache chain does that.
    final current = currentSongNotifier.value;
    if (current != null && current.cacheExist) {
      _cacheNextSong();
    }
    _publishQueueWindow();
  }

  /// Resolves right after [_prepare] has run, so code that needs the handler's
  /// files (or that must act on a loaded state) can wait for it.
  final Completer<void> _resolvedReady = Completer<void>();
  late final Future<void> whenReady = _resolvedReady.future;

  /// Applies the selected playback mode to the audio session and keeps it in
  /// step with [playbackModeNotifier] while the handler lives.
  InterruptionController? _interruptions;
  AudioPlaybackMode _appliedPlaybackMode = playbackModeNotifier.value;
  bool _playbackVolumeDucked = false;

  /// Whether the player was already playing last time it was reported, so
  /// ducking never starts a paused player and unducking never resumes one the
  /// user paused meanwhile.
  bool _wasPlayingOnLastDuck = false;

  /// Starts the interruption handling and applies the current playback mode.
  /// Called by `initAudioService` once the handler exists.
  void startPlaybackModeHandling() {
    final session = _session;
    unawaited(_applyCurrentPlaybackMode());
    playbackModeNotifier.addListener(_applyCurrentPlaybackMode);

    _interruptions = InterruptionController(
      modeOf: () => playbackModeNotifier.value,
      pause: () => unawaited(pause()),
      duck: _duckVolume,
      unduck: _unduckVolume,
    );
    session.interruptionEventStream.listen((event) {
      _interruptions?.handle(event.begin);
    });

    // Let a live change of mode reach the audio output even when the page that
    // changed it did not write the settings file itself.
    playbackModeNotifier.addListener(() {
      if (playbackModeNotifier.value != _appliedPlaybackMode) {
        unawaited(_applyCurrentPlaybackMode());
        debugPrint('playbackMode -> ${playbackModeNotifier.value.name}');
      }
    });
  }

  /// Reconfigures the audio session for [playbackModeNotifier]'s value, and
  /// takes back the volume if the mode no longer ducks.
  Future<void> _applyCurrentPlaybackMode() async {
    if (!isMobile) {
      return;
    }
    final mode = playbackModeNotifier.value;
    if (mode == _appliedPlaybackMode && !_playbackVolumeDucked) {
      return;
    }
    _appliedPlaybackMode = mode;
    if (mode != AudioPlaybackMode.duck && _playbackVolumeDucked) {
      _unduckVolume();
    }
    unawaited(applyPlaybackMode(mode));
  }

  /// Lowers the volume for a duck without pausing. A paused player stays
  /// paused: its next play() sets the volume from the saved level again.
  void _duckVolume() {
    if (!isPlayingNotifier.value) {
      _wasPlayingOnLastDuck = false;
      return;
    }
    _wasPlayingOnLastDuck = true;
    _playbackVolumeDucked = true;
    _cancelFade();
    _player.setVolume(duckedVolumeScaled * 100);
  }

  /// Gives the volume back to the level the player was using before the duck.
  void _unduckVolume() {
    if (!_playbackVolumeDucked) {
      return;
    }
    _playbackVolumeDucked = false;
    if (!_wasPlayingOnLastDuck) {
      return;
    }
    _wasPlayingOnLastDuck = false;
    setVolume(volumeNotifier.value);
  }

  /// Starts downloading the queue's next track.
  ///
  /// The transition is the same one [skipToNext] and the automatic advance use,
  /// `(currentIndex + 1) % playQueue.length`, so the file is on disk by the time
  /// the switch happens. Only the latest prefetch is kept: quick skipping
  /// cancels the one that no longer matters instead of piling up downloads.
  void _cacheNextSong() {
    if (!prefetchNextSongNotifier.value) {
      _cancelNextCacheIfNotCurrent();
      return;
    }
    // LAN direct plays from the server and leaves the cache alone, so no
    // prefetch is started (and none already running is kept).
    if (isStreamSource && lanDirectActive) {
      _cancelNextCacheIfNotCurrent();
      return;
    }
    // Local files are already on disk; WebDAV caches like a stream source.
    if (sourceType == .local || playQueue.isEmpty || currentIndex < 0) {
      _cancelNextCacheIfNotCurrent();
      return;
    }
    // Repeat-one plays this track again: there is no next track to warm.
    if (playModeNotifier.value == 2) {
      _cancelNextCacheIfNotCurrent();
      return;
    }
    final next = playQueue[(currentIndex + 1) % playQueue.length];
    if (next.id == currentSongNotifier.value?.id || next.cacheExist) {
      _cancelNextCacheIfNotCurrent();
      return;
    }
    if (_nextCacheSongId == next.id) {
      return;
    }
    _cancelNextCacheIfNotCurrent();
    final token = CancelToken();
    _nextCacheSongId = next.id;
    _nextCacheToken = token;
    unawaited(() async {
      try {
        final cached = await library.tryAddCache(next, cancelToken: token);
        if (cached) {
          library.changeNotifier.value++;
        }
      } catch (_) {
        // Cancellation and network failures both end here; neither is a
        // reason to interrupt playback.
      } finally {
        if (identical(_nextCacheToken, token)) {
          _nextCacheToken = null;
          _nextCacheSongId = null;
        }
      }
    }());
  }

  /// Drops the pending prefetch unless the song being fetched just became the
  /// one playing: that download is wanted now, so it is left to finish.
  void _cancelNextCacheIfNotCurrent() {
    final token = _nextCacheToken;
    if (token == null) {
      return;
    }
    final id = _nextCacheSongId;
    _nextCacheToken = null;
    _nextCacheSongId = null;
    if (id != null && id == currentSongNotifier.value?.id) {
      return;
    }
    token.cancel('next-track prefetch superseded');
  }

  Future<void> _prefetch(MyAudioMetadata song, {bool lyrics = true}) async {
    try {
      // A cover already on disk is used as it is: asking the scheduler for it
      // would only re-check the same file. `smallFor` below does the same for
      // the broadcast-sized copy, so a prefetched track costs no request when
      // its cover was cached by an earlier play (or by the cache page).
      final picture = song.picture;
      final path = picture.path;
      final onDisk = path.isNotEmpty && File(path).existsSync();
      if (!onDisk && !picture.isLoaded) {
        await loadPictureSafe(picture);
      }
      // The broadcast-sized copy is what a switch announces, so make it now:
      // next/previous then reach the head unit with the cover in the first
      // item instead of publishing a second, cover-carrying one a moment later.
      if ((onDisk || picture.isExist) && isMobile) {
        unawaited(mediaArt.smallFor(path));
      }
      if (lyrics) {
        await setParsedLyrics(song);
      }
    } catch (e) {
      _mediaLog('prefetch failed for ${song.id}: $e');
    }
  }

  /// How long the artwork and lyrics are waited for before giving up on a song.
  static const _prepareTimeout = Duration(seconds: 8);

  /// Fetches what the media session needs - the artwork and the lyrics - so a
  /// track does not start before there is anything to show on the head unit.
  ///
  /// The neighbouring tracks were preheated, so this normally returns at once.
  /// A song that has neither artwork nor lyrics still counts as ready (the
  /// attempt finished); only a fetch that hangs past [_prepareTimeout] fails.
  Future<bool> _prepareForPlayback(MyAudioMetadata song) async {
    final started = DateTime.now();
    // The broadcast-sized copy is made in the background (the cover event
    // republishes when it lands), so it is no longer part of "ready": making
    // it here put a decode plus a file write in front of every track, which is
    // exactly what let a burst of next-presses queue up.
    try {
      await Future.wait([
        if (!song.picture.isLoaded)
          loadPictureSafe(song.picture, priority: true),
        setParsedLyrics(song),
      ]).timeout(_prepareTimeout);
    } on TimeoutException {
      _mediaLog(
        'artwork/lyrics not ready after ${_prepareTimeout.inSeconds}s '
        'for ${song.id}',
      );
      return false;
    } catch (e) {
      // A failure is not a reason to refuse to play.
      _mediaLog('artwork/lyrics failed for ${song.id}: $e');
      return true;
    }

    _mediaLog(
      'ready for ${song.id} in '
      '${DateTime.now().difference(started).inMilliseconds}ms',
    );
    return true;
  }

  // iOS: keeps the app running while a song loads in the background. The
  // grace ends when buffering settles after MPV_EVENT_START_FILE; the player
  // reset before that event also emits buffering=false, so only a false
  // following a true counts as loaded.
  Future<void> _beginLoadGrace() async {
    await _endLoadGrace();
    _loadGraceToken = await BackgroundTaskService.begin();
    if (_loadGraceToken == null) {
      return;
    }
    _loadGraceSawBuffering = false;
    _loadGraceSub = _player.stream.buffering.listen((buffering) async {
      if (buffering) {
        _loadGraceSawBuffering = true;
      } else if (_loadGraceSawBuffering) {
        if (needPause) {
          // ensure widget is updated
          await Future.delayed(Duration(milliseconds: 500));
          await pause();
        }
        _endLoadGrace();
      }
    });
  }

  Future<void> _endLoadGrace() async {
    _loadGraceSub?.cancel();
    _loadGraceSub = null;
    final token = _loadGraceToken;
    _loadGraceToken = null;
    await BackgroundTaskService.end(token);
  }

  // iOS: a widget tap wakes the app in the background with only a few seconds
  // of runtime, which can suspend it before playback becomes audible (Dart
  // ran, but no sound). Holds a background task until the first position tick
  // (audio flowing) or the timeout, whichever comes first.
  Future<void> beginWidgetCommandGrace() async {
    await endWidgetCommandGrace();
    _widgetCommandToken = await BackgroundTaskService.begin();
    if (_widgetCommandToken == null) {
      return;
    }

    _widgetCommandTimer = Timer(Duration(seconds: 15), endWidgetCommandGrace);
  }

  Future<void> endWidgetCommandGrace() async {
    _widgetCommandSub?.cancel();
    _widgetCommandSub = null;
    _widgetCommandTimer?.cancel();
    _widgetCommandTimer = null;
    final token = _widgetCommandToken;
    _widgetCommandToken = null;
    await BackgroundTaskService.end(token);
  }

  Future<void> _beginStallGrace() async {
    if (!Platform.isIOS || _stallGraceArming || _stallGraceToken != null) {
      return;
    }
    if (!loadingSong && !isPlayingNotifier.value) {
      return;
    }
    _stallGraceArming = true;
    _stallGraceToken = await BackgroundTaskService.begin();
    _stallGraceArming = false;
  }

  Future<void> _endStallGrace() async {
    final token = _stallGraceToken;
    _stallGraceToken = null;
    await BackgroundTaskService.end(token);
  }

  /// Fills the current track's cache, then warms the queue's next track.
  ///
  /// The two downloads are deliberately sequential: on a slow link they would
  /// otherwise compete, and the current track's own cache would be the one
  /// that suffered. A track already on disk skips the first step, so the next
  /// one starts immediately.
  Future<void> _cacheCurrentThenNext(MyAudioMetadata song) async {
    if (!autoCacheSongsNotifier.value) {
      return;
    }
    // LAN direct neither reads nor fills the cache.
    if (isStreamSource && lanDirectActive) {
      return;
    }
    final generation = ++_cacheFlowGeneration;
    if (sourceType == .local) {
      return;
    }

    if (!song.cacheExist) {
      await Future.delayed(const Duration(seconds: 3));
      if (generation != _cacheFlowGeneration ||
          currentSongNotifier.value != song) {
        return;
      }
      // The switch can be turned on during the delay.
      if (isStreamSource && lanDirectActive) {
        return;
      }
      try {
        final cached = await library.tryAddCache(song);
        if (cached) {
          library.changeNotifier.value++;
        }
      } catch (e) {
        logger.output('[cache] while-playing cache failed for ${song.id}: $e');
      }
    }

    // A newer track load owns the flow now; it will prefetch its own next.
    if (generation != _cacheFlowGeneration ||
        currentSongNotifier.value != song) {
      return;
    }
    _cacheNextSong();
  }

  Future<void> load({Duration? start}) async {
    // A queued switch can reach load() with the track it already opened: a
    // completion handler and a command must never open the same index twice,
    // which is what played a song a second time before moving on.
    if (_loading) {
      if (start == null && currentIndex == _loadingIndex) {
        _completionLog(
          'load already opening index=$currentIndex '
          'id=${playQueue.isNotEmpty ? playQueue[currentIndex].id : '-'}, '
          'ignored duplicate request',
        );
        return;
      }
      _completionLog(
        'load requested while index=$_loadingIndex is still opening',
      );
    }
    // Every track switch takes a generation of its own. A load that is still
    // waiting for artwork, lyrics or the player to open when the user presses
    // next again must not touch the session afterwards: that late work is what
    // published the previous track over the current one and reset the
    // position, which a head unit then walks through track by track.
    final loadGeneration = ++_loadGeneration;
    // A new broadcast generation too: artwork started for the track announced
    // before this one must never be written into this track's snapshot. The
    // generation was bumped by nobody after an earlier refactor, so a cover
    // that finished late was applied to whichever song was current by then -
    // exactly how a track could show the previous one's cover.
    _broadcast.nextGeneration();
    _loading = true;
    _loadingIndex = currentIndex;
    _fakeCompleteResumes = 0;
    _lastCompletionKey = null;
    _lastSwitchAt = DateTime.now();
    // iOS only: request background execution time for the lyrics fetch,
    // stream ping, player open and buffering below.
    await _beginLoadGrace();

    if (currentSongNotifier.value != null) {
      if (_playLastSyncTime != null) {
        _playedDuration += DateTime.now().difference(_playLastSyncTime!);
      }
      if (_player.state.duration.inSeconds > 0) {
        // The share listened to is measured in *played* time, not by how far
        // the progress bar moved: dragging it to the end adds nothing, and a
        // pause does not count either.
        double times =
            _playedDuration.inSeconds / _player.state.duration.inSeconds;
        if (times > 0.5 &&
            autoCacheSongsNotifier.value &&
            !(isStreamSource && lanDirectActive)) {
          library.tryAddCache(currentSongNotifier.value!);
        }
        // Past two thirds of the track it is a finished listen: the play count,
        // the server's scrobble and the listening report all take it from here,
        // without having to run to the very end.
        if (times > 0.67) {
          history.addSongTimes(currentSongNotifier.value!, times.round());
          // Local listening report: one entry per mostly-finished listen,
          // aggregated across every source (see ListeningStats).
          unawaited(
            stats.recordPlay(currentSongNotifier.value!, _playedDuration),
          );
        }
      }
    }
    _playLastSyncTime = null;
    _playedDuration = Duration.zero;

    // save currentIndex
    savePlayState();

    final currentSong = playQueue[currentIndex];

    loadingSong = true;
    _applyReplayGain();
    _applyPlaybackSpeed();

    // Announce the track before anything else. What a car shows comes from the
    // media session, so it has to switch in the same instant as the song - not
    // once the artwork has been fetched and the stream opened.
    //
    // Announce the track first, then let the relay re-confirm its LAN address
    // in the background. Announcing must never wait on the network: the media
    // session is updated through the main isolate's message loop, and holding
    // this up is exactly what leaves a head unit showing the previous track
    // while the phone has already moved on. Losing the cover for a moment is
    // far cheaper than losing the title, the artist and the lyric line.
    currentSongNotifier.value = currentSong;

    currentLyricsIndexNotifier.value = -1;
    _publishedLyric = null;
    // Only the load that is still opening the queue's track may announce it:
    // a load superseded a moment ago has nothing to say to the session.
    //
    // No artwork is waited for here. The old code held the publish for up to
    // half a second to have the cover ready, which was exactly the delay a
    // head unit showed on every local track; the small copy is now made from
    // the cover the list already has, and a cover that has to be fetched is
    // published once it lands instead of holding the title back.
    if (_isCurrentLoad(loadGeneration)) {
      if (isMobile) {
        // Give the broadcast-sized cover a short chance to be ready, so the
        // track is announced in a single item *with* its artwork. For a
        // prefetched neighbour this returns instantly; a cover that has to be
        // fetched does not hold the switch longer than this.
        final coverPath = currentSong.picture.path;
        final coverOnDisk =
            coverPath.isNotEmpty && File(coverPath).existsSync();
        await _prepareSmallArt(
          currentSong,
          _broadcast.generation,
          onDisk: coverOnDisk,
        ).timeout(
          const Duration(milliseconds: 300),
          onTimeout: () {},
        );
      }
      if (_isCurrentLoad(loadGeneration)) {
        updateServiceMediaItem(
          currentSong,
          kind: MediaUpdateKind.track,
        );
      }
    }

    // Lyrics and the artwork are what a head unit shows, so on a phone both are
    // fetched before the stream starts: a track that plays for fifteen seconds
    // with nothing on screen is worse than a short wait. The neighbouring tracks
    // were preheated, so this normally returns at once. On a desktop there is no
    // head unit to keep waiting for, so playback is not held back at all.
    //
    // Streamed sources are the exception on a phone too: their artwork and
    // lyrics arrive with the stream, and holding the stream back for them would
    // stall the first play of every track. They are parsed in parallel instead.
    //
    // A superseded load gives up here: preparing (or opening) a track the user
    // has already skipped past would only queue more work behind the one that
    // matters.
    final gatesPlayback = isMobile && isNotStreamSource;
    final prepared = gatesPlayback
        ? await _prepareForPlayback(currentSong)
        : true;
    if (!_isCurrentLoad(loadGeneration)) {
      _completionLog('load of index=$currentIndex superseded, abandoned');
      return;
    }
    if (!gatesPlayback) {
      unawaited(setParsedLyrics(currentSong));
    }

    // The artwork's colour is cosmetic, so it is computed on its own and never
    // holds the stream back.
    unawaited(_updateColorsFor(currentSong));

    if (isMobile) {
      await HomeWidgetService.updateNowPlayingWidget();
      await HomeWidgetService.reloadPlaylistsWidget();
    }

    // Warm the tracks either side, so next/previous are instant.
    _prefetchNeighbours();

    if (!prepared) {
      // Artwork/lyrics timed out. That used to stop here, which left the app
      // sitting on a track that never opened: an automatic advance (the song
      // before it finishing) could not be retried by itself, so the queue
      // looked stuck on repeat until the user pressed next. Playing now and
      // filling the artwork/lyrics in afterwards is what the stream sources
      // already do, and a track with a late cover beats a track that never
      // starts.
      unawaited(setParsedLyrics(currentSong));
      _mediaLog('playing ${currentSong.id} without waiting for artwork/lyrics');
    }

    // A switch starts silently and ramps up once the new file is open. Opening
    // at full level is what makes a track change click on a head unit.
    final fadeEnabled = audioFadeNotifier.value;
    if (fadeEnabled) {
      _cancelFade();
      _player.setVolume(0);
    } else {
      _restorePlayerVolume();
    }

    try {
      if (currentSong.cacheExist && !(isStreamSource && lanDirectActive)) {
        await _player.open(
          Media(currentSong.cachePath!, start: start),
          play: isPlayingNotifier.value,
        );
      } else {
        final source = await _resolvePlaybackUri(currentSong);

        // Stream diagnostics (see [_probeStream]): a song that reports the end
        // of a buffered segment as the end of the track is very hard to catch
        // live, so the response mpv is about to read is measured once per
        // source URI and written to the log with the values that decide it.
        if (source.isStream) {
          unawaited(_probeStream(currentSong, source));
        }

        await _player.open(
          Media(
            source.playbackUrl,
            httpHeaders: source.playbackHeaders,
            start: start,
          ),
          play: isPlayingNotifier.value,
        );
        // This track is not on disk, so it is being streamed: warn once when
        // that happens over a cellular connection.
        if (!isNotStreamSource) {
          unawaited(mobileDataNotice.maybeWarn(usesNetwork: true));
        }
      }

      // Cache the track that just started; when that finishes, the queue's
      // next track is fetched so the switch can open a local file.
      unawaited(_cacheCurrentThenNext(currentSong));

      if (fadeEnabled && isPlayingNotifier.value) {
        unawaited(_fadeTo(_volumeTarget, from: 0));
      } else if (!fadeEnabled) {
        _restorePlayerVolume();
      }

      if (isPlayingNotifier.value) {
        _playLastSyncTime = DateTime.now();
      }
    } catch (error) {
      logger.output('[media] ${currentSong.title} $error');
      // Leaving home or arriving back changes which of the server's addresses
      // answers; the one baked into the stream URL then fails. Re-probe the
      // server once and, if another address works, reload the same track
      // instead of stopping at an error the listener never asked for.
      if (!_retriedAfterAddressSwitch &&
          isStreamSource &&
          await config.reProbeActiveServer()) {
        _retriedAfterAddressSwitch = true;
        _mediaLog('address switched, reloading ${currentSong.id}');
        _onServerAddressChanged();
        _loading = false;
        await load(start: start);
        _retriedAfterAddressSwitch = false;
        return;
      }
      stop();
      _loading = false;
    }

    // A superseded load must not reset the session's position: a zero there
    // is what a head unit reads as the new track starting over.
    if (!_isCurrentLoad(loadGeneration)) {
      _completionLog('load of index=$currentIndex superseded, abandoned');
      return;
    }

    updatePlaybackState(postion: Duration.zero);
    _reportServerProgress(force: true);

    if (start == null) {
      _positionState.writeAsString(Duration.zero.inMilliseconds.toString());
    }

    loadingSong = false;
    _loading = false;

    // Publish the line the song opens on, instead of waiting for the first
    // position tick to notice it.
    _updateCurrentLyricIndex(getPosition());
    if (controlCenterLyricsNotifier.value) {
      updateServiceMediaItem(
        currentSong,
        lyric: _currentLyricText(),
        kind: MediaUpdateKind.lyric,
      );
    }
  }

  /// Turns the track into something the player can open: a cache file, a local
  /// path, or a server stream. A remote stream is re-served to mpv over plain
  /// localhost HTTP (libmpv's bundled ffmpeg does TLS with macOS Secure
  /// Transport, which cannot negotiate TLS 1.3, while Dart's HttpClient can
  /// and honours the system proxy), so the URL the player gets is the relay's.
  Future<_PlaybackSource> _resolvePlaybackUri(MyAudioMetadata song) async {
    String? resource;
    Map<String, String>? headers;

    switch (sourceType) {
      case .webdav:
        final tmpPath = await covertToRedirectPathIfNeed(song.path!);
        if (tmpPath == null) {
          headers = webdavClient?.headers;
          resource = WebDavClient.encodeRemoteUrl(song.path!);
        } else {
          resource = tmpPath;
        }
      case .navidrome:
      case .emby:
      case .feiniu:
        await streamClient?.ping();
        // A cached song has a local path too; without a server URL it is played
        // from the path below instead of being awaited into a stopped player.
        resource = streamClient?.getStreamUrl(song.id);
        headers = streamClient?.headers;
      default:
        break;
    }
    resource ??= song.path!;

    final uri = Uri.tryParse(resource);
    final isRemote =
        uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host != '127.0.0.1' &&
        uri.host != 'localhost' &&
        uri.host != '::1';

    final isStream = isStreamSource && streamClient != null;
    if (!isRemote) {
      return _PlaybackSource(
        sourceUrl: resource,
        playbackUrl: resource,
        playbackHeaders: headers,
        isStream: isStream,
      );
    }

    final relayUrl = await streamRelay.register(resource, headers);
    return _PlaybackSource(
      sourceUrl: resource,
      playbackUrl: relayUrl,
      playbackHeaders: null,
      relayed: true,
      isStream: isStream,
    );
  }

  /// One measurement per source URI, so a queue played end to end adds a line
  /// per new track rather than per replay.
  final Set<String> _probedStreams = {};

  /// Asks the stream source for the very same response mpv is opening, records
  /// how long the server takes to react and what the response says, and logs
  /// it. Nothing here plays anything.
  ///
  /// It is what tells the difference between the three ways a stream can look
  /// "finished" before it is: a refused or error response, a response without
  /// a length (mpv then reads until the connection closes, and a stalled
  /// transfer is indistinguishable from the end of the file), and a server
  /// that only starts streaming after a long wait.
  Future<void> _probeStream(
    MyAudioMetadata song,
    _PlaybackSource source,
  ) async {
    if (!_probedStreams.add(source.sourceUrl)) {
      return;
    }
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    final started = DateTime.now();
    try {
      final request = await client.getUrl(Uri.parse(source.sourceUrl));
      source.playbackHeaders?.forEach(request.headers.set);
      final response = await request.close();
      final length = response.contentLength;
      final type = response.headers.contentType?.mimeType ?? '-';
      final range = response.headers.value(HttpHeaders.contentRangeHeader);
      final ms = DateTime.now().difference(started).inMilliseconds;
      final status = response.statusCode;
      final verdict = status >= 400
          ? 'refused-by-server'
          : length < 0
          ? 'UNKNOWN-LENGTH (mpv reads until the connection closes; a stall '
                'then looks exactly like the end of the song)'
          : status >= 300
          ? 'status-only (mpv treats a 3xx/2xx without a body as the end)'
          : 'normal';
      _completionLog(
        'probe id=${song.id} status=$status '
        'type=$type length=${length < 0 ? 'unknown' : length} '
        'range=${range ?? '-'} ttfb=${ms}ms $verdict',
      );
      await response.drain<void>().catchError((_) {});
    } catch (e) {
      final ms = DateTime.now().difference(started).inMilliseconds;
      _completionLog(
        'probe id=${song.id} FAILED after ${ms}ms: $e '
        '(the player would report an immediate end of track)',
      );
    } finally {
      client.close(force: true);
    }
  }

  /// Current lyric line, or null when the song has no lyrics, the position is
  /// outside the lyrics timeline, or the line is the parser's placeholder.
  ///
  /// The parser stores a localised "no lyrics"/"parsing failed" note as a line
  /// of its own; that is not a lyric, and publishing it would replace the head
  /// unit's artist line with it.
  String? _currentLyricText() {
    final lines = currentSongNotifier.value?.parsedLyrics?.lines;
    final index = currentLyricsIndexNotifier.value;
    if (lines == null || index < 0 || index >= lines.length) {
      return null;
    }
    final line = lines[index].text;
    final l10n = getAppLocalizations();
    if (line == l10n.noLyrics || line == l10n.lyricsParseFailed) {
      return null;
    }
    return line;
  }

  ({String original, String translation}) _currentCarLyricPair() {
    final lines = currentSongNotifier.value?.parsedLyrics?.lines;
    final index = currentLyricsIndexNotifier.value;
    if (lines == null || index < 0 || index >= lines.length) {
      return (original: '', translation: '');
    }
    return carLyricPair(
      text: lines[index].text,
      translations: lines[index].translates,
      englishLocale: getAppLocalizations().localeName.startsWith('en'),
    );
  }

  /// Diagnostics for the media session. Written to the app's log (exportable
  /// from the settings) and to stdout, so `adb logcat` shows the same lines
  /// while the phone - rather than a car - is under test.
  void _mediaLog(String message) {
    logger.output('[media] $message');
    debugPrint('[media] $message');
  }

  /// End-of-track diagnostics. Kept apart from [_mediaLog] on purpose: the
  /// media-session log is read by hand after a head-unit complaint, while this
  /// one answers "did a song advance itself twice", which needs a few lines
  /// around every completion.
  void _completionLog(String message) {
    logger.output('[playback] $message');
    debugPrint('[playback] $message');
  }

  static String _fmtDuration(Duration value) {
    final negative = value.isNegative;
    final v = negative ? -value : value;
    final ms = v.inMilliseconds.remainder(1000).toString().padLeft(3, '0');
    final s = v.inSeconds.remainder(60).toString().padLeft(2, '0');
    final m = (v.inMinutes % 60).toString().padLeft(2, '0');
    final h = v.inHours > 0 ? '${v.inHours}:' : '';
    return '${negative ? '-' : ''}$h$m:$s.$ms';
  }

  /// Whether a user command has moved the queue in the last few seconds. When
  /// one has, a completion arriving just after it belongs to the previous
  /// track's tail and must not advance again.
  bool _hasAdvancedRecently() {
    final at = _lastSwitchAt;
    return at != null &&
        DateTime.now().difference(at) < const Duration(milliseconds: 1500);
  }

  /// Milliseconds since the song currently in the session was switched to.
  String _sinceSwitch() {
    final started = _songSwitchedAt;
    if (started == null) {
      return '';
    }
    return ' t=+${DateTime.now().difference(started).inMilliseconds}ms';
  }

  /// Loads the current cover ahead of the list thumbnails, so a track that has
  /// to fetch its artwork does not stay without one. The broadcast-sized copy
  /// is made from whatever lands on disk.
  Future<void> _whenCoverReady(MyAudioMetadata song) async {
    final started = DateTime.now();
    try {
      await loadPictureSafe(song.picture, priority: true);
    } catch (e) {
      _mediaLog('cover load failed for ${song.id}: $e');
      return;
    } finally {
      _coverLoadInFlight.remove(song.id);
    }

    final ms = DateTime.now().difference(started).inMilliseconds;
    if (currentSongNotifier.value?.id != song.id) {
      _mediaLog('cover ready for ${song.id} in ${ms}ms, song already left');
      return;
    }
    _mediaLog(
      'cover ready for ${song.id} in ${ms}ms'
      '${_sinceSwitch()} (on disk: ${song.picture.isExist})',
    );
    if (isMobile) {
      unawaited(HomeWidgetService.updateNowPlayingWidget());
    }
    // The cover is on disk now; the session still needs the broadcast-sized
    // copy of it. No item id is forced here: [_resolveSmallArt] versions the
    // artwork only when the image it publishes really changed.
    unawaited(_prepareSmallArt(song, _broadcast.generation, onDisk: true));
  }

  /// Refreshes the system media session with the current song and lyric line.
  void refreshServiceMediaItem() {
    final song = currentSongNotifier.value;
    if (song != null) {
      updateServiceMediaItem(
        song,
        lyric: controlCenterLyricsNotifier.value ? _currentLyricText() : null,
      );
    }
  }

  /// Re-publishes the MediaSession queue after the app reordered or removed a
  /// row. The audio itself did not change, so no metadata update is needed.
  void refreshQueueWindow() {
    _publishQueueWindow();
  }

  /// A different server address is in use now. The artwork files themselves are
  /// local, so the snapshot only has to be re-published.
  void _onServerAddressChanged() {
    _coverUriCache.clear();
    refreshServiceMediaItem();
  }

  /// The artwork to announce for [song].
  ///
  /// A phone gets the broadcast-sized JPEG in `artCacheFile` and nothing else:
  /// audio_service decodes that file into the session's bitmap, so the head
  /// unit receives the image inside the metadata instead of fetching a URL of
  /// its own. On a Bluetooth link that is the difference between a tiny
  /// thumbnail and a multi-megabyte cover, and it removes the whole
  /// "publish, then re-publish when the URL resolves" sequence. Desktop keeps a
  /// file URI, which is what its media integration reads.
  ({String? fileUri, String? coverPath, String? smallArtPath, String? fetchUri})
  _artworkFor(MyAudioMetadata song) {
    if (_pubSongId != song.id) {
      _pubSongId = song.id;
      _pubFileArtUri = null;
      _pubCoverPath = null;
      _pubSmallArtPath = null;
      _pubFetchArtUri = null;
      _songSwitchedAt = DateTime.now();
    }

    final path = song.picture.path;
    // Ask the file, not `picture.isExist`: that flag is only set once the
    // artwork has been loaded, and it stays false for a picture whose load
    // failed once even though the image is right there on disk.
    final onDisk = path.isNotEmpty && File(path).existsSync();

    // A copy made for an earlier play is ready without any work - also for a
    // streamed track whose large cover was never downloaded to the cache. The
    // file is checked, not just the in-memory map: the OS may have cleared the
    // cache directory since, and publishing a dead path leaves the unit without
    // artwork until the next track.
    if (path.isNotEmpty) {
      final ready = mediaArt.readyPath(path);
      if (ready != null && File(ready).existsSync()) {
        _pubSmallArtPath ??= ready;
      }
      final published = _pubSmallArtPath;
      if (published != null && !File(published).existsSync()) {
        _pubSmallArtPath = null;
      }
    }

    if (onDisk) {
      _pubCoverPath = path;
      if (!isMobile) {
        _pubFileArtUri ??= File(path).uri.toString();
      }
    }

    unawaited(_prepareSmallArt(song, _broadcast.generation, onDisk: onDisk));

    // A cover the app has not loaded yet: load it for the UI and for the copy
    // above. This never blocks the publish.
    if (!onDisk && _coverLoadInFlight.add(song.id)) {
      // Ask the file, not the flag: a picture object can say "loaded" after
      // its file was cleared from the cache, and that is a cover the head unit
      // would never get.
      unawaited(_whenCoverReady(song));
    }

    _announceCover(song, onDisk);

    return (
      fileUri: _pubFileArtUri,
      coverPath: _pubCoverPath,
      smallArtPath: _pubSmallArtPath,
      fetchUri: _pubFetchArtUri,
    );
  }

  /// The mode actually used for this source. [CoverBroadcastMode.auto] picks
  /// the server for a streamed source and the local relay for a local library,
  /// so switching sources switches the artwork route without touching the
  /// setting.
  CoverBroadcastMode get _effectiveCoverMode {
    final selected = coverBroadcastModeNotifier.value;
    if (selected != CoverBroadcastMode.auto) {
      return selected;
    }
    return isStreamSource
        ? CoverBroadcastMode.server
        : CoverBroadcastMode.relay;
  }

  /// Decides which URI (if any) the head unit may fetch itself, according to
  /// [coverBroadcastModeNotifier]. The bitmap is always published as well.
  void _announceCover(MyAudioMetadata song, bool onDisk) {
    final mode = _effectiveCoverMode;
    switch (mode) {
      case CoverBroadcastMode.auto:
        return;
      case CoverBroadcastMode.bitmap:
        _pubFetchArtUri = null;
        if (isMobile) {
          _pubFileArtUri = null;
        }
        return;
      case CoverBroadcastMode.server:
        final remote = streamClient?.getPictureUrl(song.picture.id);
        _pubFetchArtUri = (remote == null || remote.isEmpty)
            ? null
            : _coverUrlWithSize(remote, MediaArt.broadcastSide);
        if (_pubFetchArtUri == null && isMobile) {
          // A local library (or a server that has no URL) still has the relay.
          _announceRelay(song, onDisk, original: false);
        }
        return;
      case CoverBroadcastMode.relay:
        _announceRelay(song, onDisk, original: false);
        return;
      case CoverBroadcastMode.relayOriginal:
        _announceRelay(song, onDisk, original: true);
        return;
      case CoverBroadcastMode.content:
        _pubFetchArtUri = null;
        final small = _pubSmallArtPath;
        if (small == null) {
          return;
        }
        final cached = _contentUriCache[small];
        if (cached != null) {
          _pubFileArtUri = cached;
          return;
        }
        unawaited(_resolveContentUri(small, song));
        return;
    }
  }

  /// Points the session at this phone's relay for [song]'s cover.
  void _announceRelay(
    MyAudioMetadata song,
    bool onDisk, {
    required bool original,
  }) {
    final small = _pubSmallArtPath;
    final key = original
        ? (onDisk ? song.picture.path : small)
        : (small ?? (onDisk ? song.picture.path : null));
    if (key == null) {
      return;
    }
    final uri = streamRelay.coverUrlSync(filePath: key);
    _pubFetchArtUri = uri;
    if (uri == null) {
      // The LAN address may not be resolved yet (cold start, network change).
      // Publish once it is, without waiting here.
      unawaited(
        streamRelay.warmUp().then((_) {
          if (currentSongNotifier.value?.id != song.id) {
            return;
          }
          final mode = _effectiveCoverMode;
          if (mode != CoverBroadcastMode.relay &&
              mode != CoverBroadcastMode.relayOriginal) {
            return;
          }
          final resolved = streamRelay.coverUrlSync(filePath: key);
          if (resolved == null) {
            return;
          }
          _pubFetchArtUri = resolved;
          refreshServiceMediaItem();
        }),
      );
    }
  }

  /// The content URI for [path] if it is known, otherwise resolves it in the
  /// background and returns null. Classic Bluetooth modes use this to add a
  /// URI next to the bitmap, or to publish the URI instead of it.
  String? _contentUriFor(String? path, MyAudioMetadata song) {
    if (path == null || path.isEmpty) {
      return null;
    }
    final cached = _contentUriCache[path];
    if (cached != null) {
      return cached;
    }
    unawaited(_resolveContentUri(path, song));
    return null;
  }

  Future<void> _resolveContentUri(String path, MyAudioMetadata song) async {
    if (!_contentUriInFlight.add(path)) {
      return;
    }
    String? uri;
    try {
      uri = await _mediaChannel.invokeMethod<String>('getContentUri', {
        'path': path,
      });
    } catch (e) {
      _mediaLog('content URI failed: $e');
    } finally {
      _contentUriInFlight.remove(path);
    }
    if (uri == null || uri.isEmpty) {
      return;
    }
    _contentUriCache[path] = uri;
    final wantsContent =
        coverBroadcastModeNotifier.value == CoverBroadcastMode.content ||
        classicCoverModeNotifier.value == ClassicCoverMode.bitmapUri;
    if (wantsContent && currentSongNotifier.value?.id == song.id) {
      _pubFileArtUri = uri;
      refreshServiceMediaItem();
    }
  }

  /// A server cover sized for a head unit instead of the full original.
  String _coverUrlWithSize(String url, int size) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.queryParameters.containsKey('size')) {
      return url;
    }
    return uri
        .replace(
          queryParameters: {...uri.queryParameters, 'size': '$size'},
        )
        .toString();
  }

  /// Drops URIs that were resolved for a network that is no longer in use.
  final Map<String, String> _coverUriCache = {};

  /// Starts making the broadcast-sized copy of [song]'s cover, once per
  /// cover, and returns the work so a caller that wants to announce the track
  /// *with* its artwork can wait for it.
  ///
  /// Announcing a track without artwork and adding it a moment later is what
  /// makes a head unit show the previous cover (or none) for the first second
  /// and, on some units, lose the artwork for the rest of the session. One item
  /// with the artwork in it is the stable shape.
  Future<void> _prepareSmallArt(
    MyAudioMetadata song,
    int generation, {
    required bool onDisk,
  }) {
    if (_pubSmallArtPath != null) {
      return Future.value();
    }
    final path = song.picture.path;
    if (path.isEmpty) {
      return Future.value();
    }
    // A copy from an earlier play - this run or a previous one - needs no
    // request at all.
    final cached = mediaArt.readyPath(path);
    if (cached != null) {
      _pubSmallArtPath ??= cached;
      return Future.value();
    }
    final key = onDisk ? path : 'stream:${song.picture.id}';
    final existing = _smallArtWork[key];
    if (existing != null) {
      return existing;
    }
    if (!_broadcast.shouldAttemptCover(
      key,
      relayGeneration: streamRelay.lanBaseUrlGeneration,
      generation: generation,
    )) {
      return Future.value();
    }

    final work = _resolveSmallArt(song, generation, onDisk: onDisk);
    _smallArtWork[key] = work;
    unawaited(
      work.whenComplete(() {
        if (identical(_smallArtWork[key], work)) {
          _smallArtWork.remove(key);
        }
      }),
    );
    return work;
  }

  /// Makes (or reuses) the downscaled copy of the current cover, then
  /// re-publishes so the car gets the small one instead of the original.
  ///
  /// The result is only applied while the broadcast it was started for is
  /// still the current one: a copy finishing after the user skipped on must
  /// not be written into the next track's snapshot (that is how a cover ended
  /// up belonging to the wrong song).
  Future<void> _resolveSmallArt(
    MyAudioMetadata song,
    int generation, {
    required bool onDisk,
  }) async {
    final path = song.picture.path;
    final key = onDisk ? path : 'stream:${song.picture.id}';
    String? small;
    try {
      // Checked before the request, not after it: a thumbnail cached by an
      // earlier run is what keeps a streamed cover from being fetched again on
      // every launch.
      small = mediaArt.readyPath(path);
      if (small != null) {
        // Reuse it below.
      } else if (onDisk) {
        small = await mediaArt.smallFor(path);
      } else if (isStreamSource && song.picture.id.isNotEmpty) {
        // The server renders a cover at the asked-for size, so the phone never
        // downloads (and decodes) the original just to shrink it.
        final bytes = await streamClient?.getPictureBytes(
          song.picture.id,
          size: MediaArt.broadcastSide,
        );
        if (bytes != null && bytes.isNotEmpty) {
          small = await mediaArt.smallFromBytes(path, bytes);
        }
      } else {
        // A local cover is extracted from the file on first play; do that
        // first, then shrink it.
        await loadPictureSafe(song.picture, priority: true);
        if (song.picture.isExist && File(path).existsSync()) {
          small = await mediaArt.smallFor(path);
        }
      }
    } catch (e) {
      _mediaLog('art preparation failed for ${song.id}: $e');
    }

    if (!_broadcast.isCurrent(generation) ||
        currentSongNotifier.value?.id != song.id) {
      _mediaLog('art for ${song.id} arrived for an older broadcast');
      return;
    }
    // A copy that could not be made stays unpublished (and is retried by the
    // next publish) instead of being replaced by the original: the original is
    // several megabytes, exactly what the broadcast is trying to avoid.
    if (small == null) {
      final verdict = _broadcast.handleCoverOutcome(
        key,
        CoverOutcome(generation: generation, artPath: null),
      );
      _mediaLog(
        'art produced nothing for ${song.id} (retry=${verdict.retryable})',
      );
      return;
    }
    _broadcast.handleCoverOutcome(
      key,
      CoverOutcome(generation: generation, artPath: small),
    );
    _pubSmallArtPath = small;
    _mediaLog('small art${_sinceSwitch()}: $small');
    refreshServiceMediaItem();
  }

  /// Publishes the current track to the system media session.
  ///
  /// The Android media notification, Bluetooth/AVRCP and a car head unit all
  /// read the now-playing state from here; see [buildServiceMediaItem] for how
  /// the fields map. Called as soon as the song changes - before the stream is
  /// opened - so a head unit never keeps showing the previous track while the
  /// phone fetches artwork or lyrics. Anything not known yet is re-published as
  /// soon as it is (artwork when it lands on disk, the lyric line as playback
  /// passes it).
  void updateServiceMediaItem(
    MyAudioMetadata currentSong, {
    String? lyric,
    MediaUpdateKind kind = MediaUpdateKind.artwork,
  }) {
    final art = _artworkFor(currentSong);
    final line = (lyric != null && lyric.trim().isNotEmpty) ? lyric : null;
    _publishedLyric = line;

    var bitmapPath = art.smallArtPath;
    var fileUri = art.fileUri;
    var fetchUri = art.fetchUri;
    switch (classicCoverModeNotifier.value) {
      case ClassicCoverMode.bitmap:
        fileUri = null;
        fetchUri = null;
      case ClassicCoverMode.bitmapUri:
        final uri = _contentUriFor(art.smallArtPath, currentSong);
        fileUri = uri;
        fetchUri = uri;
      case ClassicCoverMode.largeBitmap:
        bitmapPath = art.coverPath ?? art.smallArtPath;
        fileUri = null;
        fetchUri = null;
      case ClassicCoverMode.relayUri:
        // Keep the server/relay URL selected by the cover broadcast mode.
        break;
    }

    final title = getTitle(currentSong);
    final artist = getArtist(currentSong);
    final album = getAlbum(currentSong);
    final lyricsOn = controlCenterLyricsNotifier.value;
    final carLyric = _currentCarLyricPair();
    final carLines = composeCarDisplayLines(
      carDisplayConfigNotifier.value,
      title: title,
      artist: artist,
      album: album,
      lyric: carLyric.original,
      translation: carLyric.translation,
      lyricsEnabled: lyricsOn,
    );
    // Versioned once there is artwork, so a cover that arrived late (or was
    // rebuilt after a failure) is published under an id a consumer has not
    // cached a bitmap for yet.
    final id = currentSong.id;
    final key = Object.hashAll([
      title,
      artist,
      album,
      line,
      lyricsOn,
      fileUri,
      bitmapPath,
      fetchUri,
      carLines,
    ]);

    // Publication goes through the broadcast gate. It coalesces a burst into
    // the last state, spaces updates the way the Bluetooth link needs, and
    // drops an item identical to what the session already holds - a repeated
    // metadata update makes AVRCP and Android Auto re-read the artwork, which
    // is the expensive part of every track change.
    //
    // A track switch is sent without the plain debounce: the head unit must
    // hear about it at once. It still waits for the gate's minimum gap, which
    // is what keeps a burst of next-presses from becoming a queue of items the
    // unit walks through one by one, long after the phone has moved on.
    _broadcast.publish(
      MediaSnapshot(
        id: id,
        key: key,
        hasArt: bitmapPath != null || fetchUri != null,
        deliver: (_) {
          mediaItem.add(
            buildServiceMediaItem(
              id: id,
              songTitle: title,
              artist: artist,
              album: album,
              duration: currentSong.duration,
              lyric: line,
              lyricInTitle: lyricsOn,
              fileArtUri: fileUri,
              artCacheFile: bitmapPath,
              fetchableArtUri: fetchUri,
              carLines: carLines,
              trackNumber: currentIndex >= 0 ? currentIndex + 1 : null,
              trackCount: playQueue.isEmpty ? null : playQueue.length,
            ),
          );

          // The relay URL of whatever image this item carries. It is only a
          // diagnostic for the PC inspector: it does not change what the car
          // receives, but it lets the inspector show the exact bytes behind
          // either a bitmap or a URI scheme.
          final debugUri = bitmapPath == null
              ? null
              : streamRelay.coverUrlSync(filePath: bitmapPath);
          broadcastInspector.update(
            title: title,
            artist: artist,
            album: album,
            lines: carLines,
            lyric: line,
            translation: carLyric.translation,
            coverPath: bitmapPath,
            fetchUri: fetchUri,
            debugUri: debugUri,
            mode: classicCoverModeNotifier.value.name,
            bitmap: bitmapPath != null,
          );
          _mediaLog(
            'publish id=$id kind=${kind.name}'
            ' art=${fileUri == null ? 'none' : 'uri'}'
            ' bitmap=${bitmapPath == null ? 'none' : 'yes'}'
            ' fetch=${fetchUri ?? '-'}'
            ' debug=${debugUri ?? '-'}'
            ' lyric=${line == null ? '-' : '"$line"'}'
            ' lines=${carLines.map((line) => '"$line"').join(' | ')}'
            '${_sinceSwitch()}',
          );
        },
      ),
      kind: kind,
      immediate: kind == MediaUpdateKind.track,
    );
    _publishQueueWindow();
  }

  @override
  Future<void> onTaskRemoved() async {
    // The app was swiped out of the recents list. Playback must not keep going
    // with no window to control it; pausing first keeps the saved position,
    // stopping releases the foreground service and the notification.
    _completionLog('task removed, stopping playback');
    try {
      await pause();
      await stop();
      // Reopening the app attaches to this same handler: the next play must
      // open the track again instead of resuming a stopped player.
      _needsReload = true;
    } catch (e) {
      _completionLog('stop on task removal failed: $e');
    }
  }

  /// Plays [song] on the main player for the lyric timeline editor.
  ///
  /// The editor needs the same sound and the same controls as the rest of the
  /// app, so it borrows the main player instead of opening a second one. The
  /// queue, song, position and playing state are remembered, and
  /// [stopLyricPreview] puts the listener back exactly where they were.
  Future<LyricPreviewBookmark> startLyricPreview(
    MyAudioMetadata song, {
    bool autoPlay = true,
    Duration start = Duration.zero,
  }) async {
    final bookmark = LyricPreviewBookmark(
      queue: List<MyAudioMetadata>.of(playQueue),
      queueTmp: List<MyAudioMetadata>.of(_playQueueTmp),
      index: currentIndex,
      position: getPosition(),
      wasPlaying: isPlayingNotifier.value,
      playMode: playModeNotifier.value,
    );
    await pause();
    _playQueueTmp = [song];
    playQueue = [song];
    currentIndex = 0;
    await load(start: start);
    if (autoPlay) {
      await play();
    }
    // The temporary queue is not written to disk: a launch after the app was
    // killed inside the editor must restore the listener's real queue, not the
    // single song the editor was previewing.
    return bookmark;
  }

  /// Leaves the editor's single-song preview and restores the queue and
  /// position that were active before it.
  Future<void> stopLyricPreview(LyricPreviewBookmark bookmark) async {
    await pause();
    _playQueueTmp = List<MyAudioMetadata>.of(bookmark.queueTmp);
    playQueue = List<MyAudioMetadata>.of(bookmark.queue);
    currentIndex = bookmark.index;
    playModeNotifier.value = bookmark.playMode;
    if (playQueue.isEmpty ||
        currentIndex < 0 ||
        currentIndex >= playQueue.length) {
      currentSongNotifier.value = null;
      saveAllStates();
      return;
    }
    await load(start: bookmark.position);
    if (bookmark.wasPlaying) {
      await play();
    }
    saveAllStates();
  }

  @override
  Future<void> play() async {
    if (playQueue.isEmpty) return;
    if (_needsReload) {
      _needsReload = false;
      await load();
      return;
    }
    final generation = ++_transportGeneration;

    final fadeEnabled = audioFadeNotifier.value;
    if (fadeEnabled) {
      _cancelFade();
      _player.setVolume(0);
    } else {
      _restorePlayerVolume();
    }
    _player.play();
    if (fadeEnabled) {
      unawaited(_fadeTo(_volumeTarget, from: 0));
    }

    // Publish "playing" before the widget bookkeeping below, which can throw on
    // a device where the home widget is not set up - the media session would
    // then keep showing paused while the song plays.
    isPlayingNotifier.value = true;
    _playLastSyncTime ??= DateTime.now();
    updatePlaybackState();
    _reportServerProgress(force: true);

    await updateIsPlaying(true);

    if (generation != _transportGeneration) {
      return;
    }
    _startPositionTimer();
  }

  /// Writes the resume position and keeps the media session's progress moving.
  /// A notification, a car and the OS lock screen read the position from the
  /// session; without a periodic update it only changes on play/pause/seek.
  void _startPositionTimer() {
    _positionTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      _positionState.writeAsString(getPosition().inMilliseconds.toString());
      if (isPlayingNotifier.value && !loadingSong) {
        updatePlaybackState();
        _reportServerProgress();
      }
    });
  }

  @override
  Future<void> pause() async {
    final generation = ++_transportGeneration;
    if (audioFadeNotifier.value && isPlayingNotifier.value) {
      await _fadeTo(0, duration: const Duration(milliseconds: 180));
    }
    // A play() that arrived while the volume ramped down owns the player now.
    if (generation != _transportGeneration) {
      return;
    }
    _player.pause();
    _restorePlayerVolume();
    await updateIsPlaying(false);
    updatePlaybackState();
    _reportServerProgress(force: true, paused: true);
    _positionTimer?.cancel();
    _positionTimer = null;
    _positionState.writeAsString(getPosition().inMilliseconds.toString());
  }

  @override
  Future<void> stop() async {
    _transportGeneration++;
    _cancelFade();
    _restorePlayerVolume();
    await _endLoadGrace();
    await _endStallGrace();
    _player.stop();
    await updateIsPlaying(false);
    updatePlaybackState(stop: true);
    _positionTimer?.cancel();
    _positionTimer = null;
    _positionState.writeAsString(Duration.zero.inMilliseconds.toString());
  }

  @override
  Future<void> seek(Duration position) async {
    updatePlaybackState(postion: position);
    await _player.seek(position);
    // ensure position is updated
    await Future.delayed(Duration(milliseconds: 50));
    updateLyricsNotifier.value++;
    _positionState.writeAsString(getPosition().inMilliseconds.toString());
    _reportServerProgress(force: true);
  }

  @override
  Future<void> skipToNext() async {
    if (playQueue.isEmpty) return;

    currentIndex = (currentIndex + 1) % playQueue.length;
    if (_hasAdvancedRecently()) {
      _completionLog(
        'next requested within a switch (another advance just happened)',
      );
    }
    await load();
  }

  @override
  Future<void> skipToPrevious() async {
    if (playQueue.isEmpty) return;

    currentIndex = (currentIndex + playQueue.length - 1) % playQueue.length;
    await load();
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    final target = _queueWindowStart + index;
    if (target < 0 || target >= playQueue.length) {
      return;
    }
    currentIndex = target;
    await load();
    if (!isPlayingNotifier.value) {
      play();
    }
  }

  void togglePlay() {
    if (playQueue.isEmpty) return;

    if (isPlayingNotifier.value) {
      pause();
    } else {
      play();
    }
  }

  Stream<Duration> getPositionStream() {
    return _player.stream.position;
  }

  Stream<Duration> getDurationStream() {
    return _player.stream.duration;
  }

  Duration getPosition() {
    return _player.state.position;
  }

  Duration getCurrentDuration() {
    return _player.state.duration;
  }

  void setVolume(double volume) {
    _cancelFade();
    _volumeTarget = _scaleVolume(volume);
    _player.setVolume(_volumeTarget);
  }

  /// The player's own 0..100 scale for the user's 0..1 volume setting. The log
  /// curve is kept, since that is what the volume slider has always used.
  double _scaleVolume(double volume) =>
      (math.log(volume * 9 + 1) / math.log(10)) * 100;

  void _cancelFade() {
    _fadeToken++;
    _fadeTimer?.cancel();
    _fadeTimer = null;
  }

  /// Puts the player back at the level it was playing at, e.g. after a
  /// fade-out left it at zero. Never changes the volume setting itself.
  void _restorePlayerVolume() {
    _cancelFade();
    _player.setVolume(_volumeTarget);
  }

  /// Ramps the player volume from where it is now to [target]. A newer ramp or
  /// transport command cancels this one, and the future still completes so a
  /// waiting caller cannot hang.
  Future<void> _fadeTo(
    double target, {
    Duration duration = const Duration(milliseconds: 220),
    double? from,
  }) {
    _fadeTimer?.cancel();
    final token = ++_fadeToken;
    // A fade-in starts from silence explicitly: the player's reported volume
    // can still be the old value right after setVolume(0), which made the
    // "ramp" a no-op.
    final start = from ?? _player.state.volume;
    if ((start - target).abs() < 0.5) {
      _player.setVolume(target);
      return Future.value();
    }

    final completer = Completer<void>();
    const tickMs = 16;
    final totalMs = duration.inMilliseconds <= 0 ? tickMs : duration.inMilliseconds;
    var elapsed = 0;
    _fadeTimer = Timer.periodic(const Duration(milliseconds: tickMs), (timer) {
      if (token != _fadeToken) {
        timer.cancel();
        if (!completer.isCompleted) {
          completer.complete();
        }
        return;
      }
      elapsed += tickMs;
      final progress = (elapsed / totalMs).clamp(0.0, 1.0);
      final eased = 1 - math.pow(1 - progress, 3).toDouble();
      _player.setVolume(start + (target - start) * eased);
      if (progress >= 1) {
        timer.cancel();
        _fadeTimer = null;
        _player.setVolume(target);
        if (!completer.isCompleted) {
          completer.complete();
        }
      }
    });
    return completer.future;
  }

  /// Replay gain is a decoder property, so it stays applied across tracks.
  void _applyReplayGain() {
    final platform = _player.platform;
    if (platform is! NativePlayer) {
      return;
    }
    platform.setProperty(
      'replaygain',
      switch (replayGainModeNotifier.value) {
        ReplayGainMode.off => 'no',
        ReplayGainMode.track => 'track',
        ReplayGainMode.album => 'album',
      },
    );
  }

  void _applyPlaybackSpeed() {
    unawaited(_player.setRate(playbackSpeedNotifier.value));
  }

  /// Sends the phone's position to the server's "now playing" entry. A local
  /// library has no server; the remaining sources decide whether they can use
  /// it.
  void _reportServerProgress({bool force = false, bool paused = false}) {
    if (!reportPlaybackProgressNotifier.value ||
        !isStreamSource ||
        streamClient == null) {
      return;
    }
    final song = currentSongNotifier.value;
    if (song == null) {
      return;
    }
    final now = DateTime.now();
    final sameSong = _progressReportSongId == song.id;
    if (!force &&
        sameSong &&
        _lastProgressReportAt != null &&
        now.difference(_lastProgressReportAt!) < const Duration(seconds: 10)) {
      return;
    }
    _progressReportSongId = song.id;
    _lastProgressReportAt = now;
    unawaited(
      streamClient!.reportPlaybackProgress(
        song.id,
        getPosition(),
        paused: paused,
        speed: playbackSpeedNotifier.value,
      ),
    );
  }

  Future<void> applyEqualizer() async {
    bool isAllZero = gains.every((g) => g.abs() < 0.01);
    String af = '';

    if (!isAllZero) {
      double g1 = gains[0]; // 31Hz
      double g2 = gains[1]; // 62Hz
      double g3 = gains[2]; // 125Hz
      double g4 = gains[3]; // 250Hz
      double g5 = gains[4]; // 500Hz
      double g6 = gains[5]; // 1kHz
      double g7 = gains[6]; // 2kHz
      double g8 = gains[7]; // 4kHz
      double g9 = gains[8]; // 8kHz
      double g10 = gains[9]; // 16kHz

      double b1 = g1; // 65Hz
      double b2 = 0.0;
      double b3 = g2; // 131Hz
      double b4 = g3; // 185Hz
      double b5 = 0.0; // 263Hz
      double b6 = g4; // 371Hz
      double b7 = g5; // 525Hz
      double b8 = 0.0; // 742Hz
      double b9 = g6; // 1050Hz
      double b10 = g7; // 1480Hz
      double b11 = 0.0; // 2090Hz
      double b12 = g8; // 2960Hz
      double b13 = 0.0;
      double b14 = g9; // 5920Hz
      double b15 = 0.0; // 8370Hz
      double b16 = g10; // 11800Hz
      double b17 = g10; // 16700Hz
      double b18 = g10; // 20000Hz

      List<double> bValues = [
        b1,
        b2,
        b3,
        b4,
        b5,
        b6,
        b7,
        b8,
        b9,
        b10,
        b11,
        b12,
        b13,
        b14,
        b15,
        b16,
        b17,
        b18,
      ];

      final List<String> activeParams = [];
      for (int i = 0; i < bValues.length; i++) {
        double multiplier = math.pow(10, bValues[i] / 20).toDouble();

        activeParams.add('${i + 1}b=${multiplier.toStringAsFixed(3)}');
      }
      af = 'superequalizer=${activeParams.join(":")}';
    }

    await (_player.platform as NativePlayer).setProperty('af', af);
    saveEqualizerState();
  }
}

/// What [MyAudioHandler._resolvePlaybackUri] produced: the URL the player opens
/// (the relay's, for a remote stream) and the original one, which the stream
/// diagnostics read from.
class _PlaybackSource {
  final String sourceUrl;
  final String playbackUrl;
  final Map<String, String>? playbackHeaders;
  final bool relayed;
  final bool isStream;

  const _PlaybackSource({
    required this.sourceUrl,
    required this.playbackUrl,
    this.playbackHeaders,
    this.relayed = false,
    this.isStream = false,
  });
}
