import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// One configured comment server.
///
/// The comment API (see the `review_api` project) is a plain GET endpoint that
/// takes a song name and an artist and answers with a list of comments. Like a
/// music server it has a LAN and a public address - only one of them is usually
/// reachable, depending on where the user is - and may require a token derived
/// from its credentials.
///
/// Several can be stored at once; the active one answers the comment page, and
/// a long press in the list switches between them.
class CommentServer {
  final String id;
  String name;

  /// Protocol: `http` or `https`.
  String scheme;

  /// The addresses, each host plus port. The LAN one is tried first (it is
  /// faster when it works), then the public one.
  String lanHost;
  String lanPort;
  String publicHost;
  String publicPort;

  /// Credentials are optional: a server deployed without them needs none.
  String username;
  String password;

  /// Accept the address's certificate without validating it, per address,
  /// since a NAS on the LAN usually serves a self-signed certificate while the
  /// public one does not.
  bool ignoreLanCert;
  bool ignorePublicCert;

  /// Address that last answered a request, so a switch between home and away
  /// does not probe both every time.
  String? lastGoodUrl;

  CommentServer({
    required this.id,
    required this.name,
    this.scheme = 'http',
    this.lanHost = '',
    this.lanPort = '',
    this.publicHost = '',
    this.publicPort = '',
    this.username = '',
    this.password = '',
    this.ignoreLanCert = false,
    this.ignorePublicCert = false,
    this.lastGoodUrl,
  });

  bool get isSecure => scheme == 'https';

  /// A token is only required by a server deployed with credentials.
  bool get needsToken => username.trim().isNotEmpty || password.isNotEmpty;

  /// The token the server expects: sha256 of username + password + the base
  /// URL it was configured with, exactly as the review_app server computes it.
  String tokenFor(String baseUrl) =>
      sha256.convert(utf8.encode('$username$password$baseUrl')).toString();

  bool get hasLan => lanHost.trim().isNotEmpty;

  bool get hasPublic => publicHost.trim().isNotEmpty;

  bool get isUsable => hasLan || hasPublic;

  String _url(String host, String port) {
    final value = host.trim();
    if (value.isEmpty) {
      return '';
    }
    final portText = port.trim();
    final buffer = StringBuffer('$scheme://$value');
    if (portText.isNotEmpty) {
      buffer.write(':$portText');
    }
    return buffer.toString();
  }

  String get lanUrl => _url(lanHost, lanPort);

  String get publicUrl => _url(publicHost, publicPort);

  /// Addresses to try, the last good one first (it is where the app already
  /// worked), then the LAN one, then the public one.
  List<String> get addresses {
    final result = <String>[];
    void add(String? url) {
      final value = url?.trim() ?? '';
      if (value.isNotEmpty && !result.contains(value)) {
        result.add(value);
      }
    }

    add(lastGoodUrl);
    add(lanUrl);
    add(publicUrl);
    return result;
  }

  /// Address in use right now, for the list's subtitle.
  String get currentUrl {
    final last = lastGoodUrl?.trim() ?? '';
    if (last.isNotEmpty) {
      return last;
    }
    final all = addresses;
    return all.isEmpty ? '' : all.first;
  }

  /// Whether [url] is the LAN address, for the list's "LAN" label.
  bool isLan(String url) => hasLan && url == lanUrl;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'scheme': scheme,
    'lanHost': lanHost,
    'lanPort': lanPort,
    'publicHost': publicHost,
    'publicPort': publicPort,
    'username': username,
    'password': password,
    'ignoreLanCert': ignoreLanCert,
    'ignorePublicCert': ignorePublicCert,
    'lastGoodUrl': lastGoodUrl,
  };

  static CommentServer? fromJson(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    final id = '${raw['id'] ?? ''}';
    if (id.isEmpty) {
      return null;
    }
    return CommentServer(
      id: id,
      name: '${raw['name'] ?? ''}',
      scheme: '${raw['scheme'] ?? 'http'}',
      lanHost: '${raw['lanHost'] ?? ''}',
      lanPort: '${raw['lanPort'] ?? ''}',
      publicHost: '${raw['publicHost'] ?? ''}',
      publicPort: '${raw['publicPort'] ?? ''}',
      username: '${raw['username'] ?? ''}',
      password: '${raw['password'] ?? ''}',
      ignoreLanCert: raw['ignoreLanCert'] as bool? ?? false,
      ignorePublicCert: raw['ignorePublicCert'] as bool? ?? false,
      lastGoodUrl: raw['lastGoodUrl'] == null ? null : '${raw['lastGoodUrl']}',
    );
  }

  static String newId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 20)}';
}
