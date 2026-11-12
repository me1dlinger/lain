import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:home_widget/home_widget.dart';
import 'package:lain/base/app.dart';
import 'package:lain/base/data/music_server.dart';
import 'package:lain/base/data/offline_setting.dart';
import 'package:lain/base/services/cert_policy.dart';
import 'package:lain/base/services/emby_client.dart';
import 'package:lain/base/services/feiniu_client.dart';
import 'package:lain/base/services/logger.dart';
import 'package:lain/base/services/navidrome_client.dart';
import 'package:lain/base/services/stream_client.dart';
import 'package:lain/base/services/webdav_client.dart';
import 'package:lain/layer/premium_layer.dart';

final config = Config();

class Config {
  late final File file;

  /// Every configured server, in the order they were added.
  final List<MusicServer> servers = [];

  /// The server the app is currently using, if any (a local library has none).
  String? activeServerId;

  MusicServer? get activeServer {
    for (final server in servers) {
      if (server.id == activeServerId) {
        return server;
      }
    }
    return null;
  }

  List<MusicServer> serversOf(SourceType type) => [
    for (final server in servers)
      if (server.type == type) server,
  ];

  static const _secureStorage = FlutterSecureStorage(
    mOptions: MacOsOptions(usesDataProtectionKeychain: false),
  );

  Future<void> load() async {
    if (kReleaseMode && Platform.isIOS) {
      final isPremiumTmp = await _trySecureRead('isPremium');
      if (isPremiumTmp != 'true') {
        isPremiumNotifier.value = false;
        final now = DateTime.now();
        try {
          final trialBeginMs = await _secureStorage.read(key: 'trialBeginMs');
          if (trialBeginMs == null) {
            if (await _trySecureWrite(
              'trialBeginMs',
              now.millisecondsSinceEpoch.toString(),
            )) {
              trialRemainingMinNotifier.value = 4320; // 3 days
            }
          } else {
            final trialBeginTime = DateTime.fromMillisecondsSinceEpoch(
              int.tryParse(trialBeginMs) ?? 0,
            );
            final diff = now.difference(trialBeginTime);
            if (diff.inMinutes < 4320) {
              trialRemainingMinNotifier.value = 4320 - diff.inMinutes;
            }
          }
          if (trialRemainingMinNotifier.value > 0) {
            isPremiumNotifier.value = true;
            Timer.periodic(Duration(minutes: 1), (timer) {
              if (trialRemainingMinNotifier.value <= 0) {
                timer.cancel();
                return;
              }
              trialRemainingMinNotifier.value--;
            });
          }
        } catch (e) {
          logger.output(e.toString());
        }
      }

      if (!isPremiumNotifier.value) {
        viewModeNotifier.value = .normal;
      }
      await syncWidgetPremium();
    }

    file = File("${appSupportDir.path}/config.json");
    if (!(file.existsSync())) {
      return;
    }

    final content = await file.readAsString();

    final Map<String, dynamic> map =
        jsonDecode(content) as Map<String, dynamic>;

    await _loadServers(map);

    final tmpSourceType = map['sourceType'] as String?;
    if (tmpSourceType != null) {
      sourceType = SourceType.values.asNameMap()[tmpSourceType] ?? sourceType;
    }

    activeServerId = map['activeServerId'] as String?;
    final active = activeServer;
    if (active != null) {
      // The chosen server decides the source; the legacy field only survives for
      // a local library, which has no server.
      sourceType = active.type;
    } else if (sourceType != .local && servers.isNotEmpty) {
      final picked = servers.firstWhere(
        (server) => server.type == sourceType,
        orElse: () => servers.first,
      );
      activeServerId = picked.id;
      sourceType = picked.type;
    }

    isStreamSource =
        sourceType == .navidrome ||
        sourceType == .emby ||
        sourceType == .feiniu;
    isNotStreamSource = !isStreamSource;

    ignoreServerCert = active?.ignoresCert ?? false;

    if (active != null && active.isUsable) {
      // Connect without probing, so a launch stays fast; a failing request
      // switches to the other address instead. The address that was good last
      // time is reused - leaving home or coming back to it is normal, and
      // overriding it with the LAN address would undo that every launch. The
      // LAN address is only the default when nothing was remembered yet.
      final lan = active.lanUrl.trim();
      if ((active.lastGoodUrl?.trim() ?? '').isEmpty && lan.isNotEmpty) {
        active.lastGoodUrl = lan;
      }
      _openClient(active, active.currentUrl);
    }

    if (_hasPlainTextPassword(map)) {
      await save();
    }
  }

  /// Reads the server list, migrating the single-server layout the app used
  /// before multiple servers existed.
  Future<void> _loadServers(Map<String, dynamic> map) async {
    servers.clear();

    final rawServers = map['servers'];
    if (rawServers is List && rawServers.isNotEmpty) {
      for (final raw in rawServers) {
        final server = MusicServer.fromJson(raw);
        if (server == null) {
          continue;
        }
        var password = await _trySecureRead('password_${server.id}');
        if (password == null || password.isEmpty) {
          password = raw is Map ? '${raw['password'] ?? ''}' : '';
        }
        server.password = password;
        servers.add(server);
      }
      return;
    }

    Future<void> migrate(
      SourceType type,
      Object? legacy,
      String secureKey,
    ) async {
      final raw = legacy is Map ? legacy : const {};
      final baseUrl = '${raw['baseUrl'] ?? ''}'.trim();
      if (baseUrl.isEmpty) {
        return;
      }
      var password = await _trySecureRead(secureKey) ?? '';
      if (password.isEmpty) {
        password = '${raw['password'] ?? ''}';
      }
      servers.add(
        MusicServer(
          id: MusicServer.newId(),
          type: type,
          name: type.name,
          publicUrl: baseUrl,
          username: '${raw['username'] ?? ''}',
          password: password,
        ),
      );
    }

    await migrate(.webdav, map['webdav'], 'webdav_password');
    await migrate(.navidrome, map['navidrome'], 'navidrome_password');
    await migrate(.emby, map['emby'], 'emby_password');
    await migrate(.feiniu, map['feiniu'], 'feiniu_password');
  }

  Future<bool> _probe(MusicServer server, String address) async {
    try {
      if (server.type == .webdav) {
        final client = WebDavClient(
          baseUrl: address,
          username: server.username,
          password: server.password,
        );
        return await client.ping().timeout(const Duration(seconds: 5));
      }
      return await _buildStreamClient(
        server,
        address,
      ).ping().timeout(const Duration(seconds: 5));
    } catch (error) {
      logger.output('[servers] ${server.name} $address: $error');
      return false;
    }
  }

  StreamClient _buildStreamClient(MusicServer server, String address) {
    switch (server.type) {
      case .emby:
        return EmbyClient(
          baseUrl: address,
          username: server.username,
          password: server.password,
        );
      case .feiniu:
        return FeiniuClient(
          baseUrl: address,
          username: server.username,
          password: server.password,
        );
      default:
        return NavidromeClient(
          baseUrl: address,
          username: server.username,
          password: server.password,
        );
    }
  }

  /// Builds the runtime client for [server] at [address] and points the app at
  /// it; the other address becomes the fallback tried when a request fails.
  void _openClient(MusicServer server, String address) {
    final alternative = server.addresses.firstWhere(
      (url) => url != address,
      orElse: () => '',
    );

    if (server.type == .webdav) {
      final client = WebDavClient(
        baseUrl: address,
        username: server.username,
        password: server.password,
      );
      client.alternativeBaseUrl = alternative;
      webdavClient = client;
      streamClient = null;
      return;
    }

    final client = _buildStreamClient(server, address);
    client.alternativeBaseUrl = alternative;
    // An in-flight failover moves the live client; keep the server record (and
    // the settings page) naming the address that is really being used.
    client.onAddressChanged = (url) {
      server.lastGoodUrl = url;
      unawaited(save());
    };
    streamClient = client;
    webdavClient = null;
  }

  /// Re-probes the active server's other addresses and moves the app to one that
  /// answers, returning true when the address actually changed.
  ///
  /// A launch reuses [MusicServer.lastGoodUrl] so it is not held up by two
  /// timeouts - but that is the address that was good *last time*. Leaving the
  /// house with a LAN address remembered, or coming home with a public one, is
  /// perfectly normal, and every request then keeps failing until the user goes
  /// to the settings and connects again by hand.
  Future<bool> reProbeActiveServer() async {
    final server = activeServer;
    if (server == null) {
      return false;
    }

    final current = streamClient?.baseUrl ?? webdavClient?.baseUrl;

    // Leave a working address alone. Checking the current one first is what
    // stops the app from hopping to another address - the LAN one - merely
    // because a single request timed out on a public network that is fine.
    if (current != null && current.isNotEmpty) {
      if (await _probe(server, current)) {
        return false;
      }
    }

    for (final address in server.addresses) {
      if (address == current) {
        continue;
      }
      if (await _probe(server, address)) {
        logger.output('[servers] ${server.name} switched to $address');
        server.lastGoodUrl = address;
        _openClient(server, address);
        await save();
        return true;
      }
    }

    return false;
  }

  /// Switches the app to [server]: probes its addresses (LAN first) and only
  /// connects when one of them answers.
  Future<bool> activateServer(MusicServer server) async {
    // Offline mode is the single gate every activation path goes through,
    // including the first-launch source picker and the server editor.
    if (offlineModeNotifier.value) {
      return false;
    }
    // Set before probing, so the probe itself accepts the certificate too.
    ignoreServerCert = server.ignoresCert;

    String? reachable;
    for (final address in server.addresses) {
      if (await _probe(server, address)) {
        reachable = address;
        break;
      }
    }
    if (reachable == null) {
      return false;
    }

    server.lastGoodUrl = reachable;
    if (!servers.any((item) => item.id == server.id)) {
      servers.add(server);
    }
    activeServerId = server.id;
    sourceType = server.type;
    isStreamSource =
        sourceType == .navidrome ||
        sourceType == .emby ||
        sourceType == .feiniu;
    isNotStreamSource = !isStreamSource;
    _openClient(server, reachable);
    await save();
    return true;
  }

  /// Switches to a local library: no server, folders are scanned instead.
  Future<void> activateLocal() async {
    ignoreServerCert = false;
    activeServerId = null;
    sourceType = .local;
    isStreamSource = false;
    isNotStreamSource = true;
    streamClient = null;
    webdavClient = null;
    await save();
  }

  Future<void> upsertServer(MusicServer server) async {
    final index = servers.indexWhere((item) => item.id == server.id);
    if (index == -1) {
      servers.add(server);
    } else {
      servers[index] = server;
    }
    await save();
  }

  /// Removes [server], together with its stored password. Its cached songs,
  /// covers and offline library are only wiped when no other server of the same
  /// kind is left: that data lives in one directory per kind, shared by all of
  /// them.
  Future<void> deleteServer(MusicServer server) async {
    servers.removeWhere((item) => item.id == server.id);

    final sameKind = servers.any((item) => item.type == server.type);
    if (!sameKind) {
      final dir = Directory('${appSupportDir.path}/${server.type.name}');
      try {
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
      } catch (error) {
        logger.output('[servers] could not delete ${dir.path}: $error');
      }
    }

    await _trySecureDelete('password_${server.id}');

    if (activeServerId == server.id) {
      activeServerId = null;
      if (!sameKind && sourceType == server.type) {
        streamClient = null;
        webdavClient = null;
        ignoreServerCert = false;
        sourceType = .local;
        isStreamSource = false;
        isNotStreamSource = true;
      }
    }
    await save();
  }

  Future<void> savePremium() async {
    await _trySecureWrite('isPremium', 'true');
  }

  // Widget sizes beyond the free ones (NowPlaying above systemSmall,
  // Playlists above systemMedium) read this flag and dim themselves with an
  // unlock hint, so it must be pushed and re-rendered whenever it changes.
  Future<void> syncWidgetPremium() async {
    await HomeWidget.saveWidgetData('isPremium', isPremiumNotifier.value);
    await HomeWidget.updateWidget(iOSName: 'NowPlayingWidget');
    await HomeWidget.updateWidget(iOSName: 'PlaylistsWidget');
  }

  Future<void> save() async {
    // The password of every server lives in secure storage, keyed by the
    // server's id; when that write fails the plaintext stays in config.json for
    // that entry only, instead of losing the credential on the next load.
    final entries = <Map<String, Object?>>[];
    for (final server in servers) {
      final secured = await _trySecureWrite(
        'password_${server.id}',
        server.password,
      );
      final json = server.toJson();
      if (!secured) {
        json['password'] = server.password;
      }
      entries.add(json);
    }

    await file.writeAsString(
      jsonEncode({
        'sourceType': sourceType.name,
        'activeServerId': activeServerId,
        'servers': entries,
      }),
    );
  }

  Future<void> _trySecureDelete(String key) async {
    try {
      await _secureStorage.delete(key: key);
    } catch (e) {
      logger.output('Failed to delete "$key" from secure storage: $e');
    }
  }

  Future<String?> _trySecureRead(String key) async {
    try {
      return await _secureStorage.read(key: key);
    } catch (e) {
      logger.output('Failed to read "$key" from secure storage: $e');
      return null;
    }
  }

  Future<bool> _trySecureWrite(String key, String value) async {
    try {
      await _secureStorage.write(key: key, value: value);
      return true;
    } catch (e) {
      logger.output('Failed to write "$key" to secure storage: $e');
      return false;
    }
  }

  bool _hasPlainTextPassword(Map<String, dynamic> map) {
    for (var key in ['webdav', 'navidrome', 'emby', 'feiniu']) {
      if (map[key] != null && map[key]['password'] != null) {
        return true;
      }
    }
    return false;
  }
}
