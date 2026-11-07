import 'dart:math';

import 'package:sylvakru/base/app.dart';

/// One configured music server.
///
/// A server may be reachable at two addresses - a public one used away from home
/// and a LAN one - and the app prefers the LAN address, falling back to the
/// public one (see `Config.activateServer` and
/// `StreamClient.switchToAlternative`). Several servers of the same kind can be
/// stored at once; the active one decides the current source.
class MusicServer {
  final String id;
  SourceType type;
  String name;
  String publicUrl;
  String lanUrl;
  String username;
  String password;

  /// Address that last answered a probe. Connecting reuses it without probing
  /// again, so a launch is not delayed by two timeouts.
  String? lastGoodUrl;

  /// Accept this server's certificate without validating it (a NAS on the LAN
  /// usually serves a self-signed one). Kept per address, since only one of
  /// them is usually reached over such a certificate.
  bool ignorePublicCert;

  bool ignoreLanCert;

  MusicServer({
    required this.id,
    required this.type,
    required this.name,
    this.publicUrl = '',
    this.lanUrl = '',
    this.username = '',
    this.password = '',
    this.lastGoodUrl,
    this.ignorePublicCert = false,
    this.ignoreLanCert = false,
  });

  /// Addresses to try, LAN first: it is the cheaper and faster route when both
  /// work, and the public address covers being away from home.
  List<String> get addresses {
    final result = <String>[];
    void add(String? url) {
      final value = url?.trim() ?? '';
      if (value.isNotEmpty && !result.contains(value)) {
        result.add(value);
      }
    }

    add(lanUrl);
    add(publicUrl);
    add(lastGoodUrl);
    return result;
  }

  /// Whether any of this server's addresses must have its certificate accepted
  /// without validation. Either address turns it on for the whole server, so
  /// that a failover to the other one keeps working.
  bool get ignoresCert => ignorePublicCert || ignoreLanCert;

  bool get hasLan => lanUrl.trim().isNotEmpty;

  bool get hasPublic => publicUrl.trim().isNotEmpty;

  bool get isUsable => addresses.isNotEmpty;

  /// Address in use right now, for the list's subtitle.
  String get currentUrl {
    final last = lastGoodUrl?.trim() ?? '';
    if (last.isNotEmpty) {
      return last;
    }
    final all = addresses;
    return all.isEmpty ? '' : all.first;
  }

  /// Whether the address in use is the LAN one.
  bool get usingLan => hasLan && currentUrl == lanUrl.trim();

  Map<String, Object?> toJson() => {
    'id': id,
    'type': type.name,
    'name': name,
    'publicUrl': publicUrl,
    'lanUrl': lanUrl,
    'username': username,
    'lastGoodUrl': lastGoodUrl,
    'ignorePublicCert': ignorePublicCert,
    'ignoreLanCert': ignoreLanCert,
  };

  static MusicServer? fromJson(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    final type = SourceType.values.asNameMap()['${raw['type']}'];
    if (type == null) {
      return null;
    }
    return MusicServer(
      id: '${raw['id'] ?? ''}',
      type: type,
      name: '${raw['name'] ?? ''}'.isEmpty ? type.name : '${raw['name']}',
      publicUrl: '${raw['publicUrl'] ?? ''}',
      lanUrl: '${raw['lanUrl'] ?? ''}',
      username: '${raw['username'] ?? ''}',
      lastGoodUrl: raw['lastGoodUrl'] == null ? null : '${raw['lastGoodUrl']}',
      // `ignoreCert` was a single flag before it became per address.
      ignorePublicCert:
          raw['ignorePublicCert'] as bool? ?? raw['ignoreCert'] == true,
      ignoreLanCert: raw['ignoreLanCert'] as bool? ?? raw['ignoreCert'] == true,
    );
  }

  static String newId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 20)}';
}