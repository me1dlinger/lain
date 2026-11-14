import 'package:flutter/foundation.dart';
import 'package:lain/base/app.dart';
import 'package:lain/base/data/config.dart';
import 'package:lain/base/services/stream_client.dart';

/// When on, a streamed source reached over its LAN address is played straight
/// from the server: no transcode is asked for and the offline cache is neither
/// read nor filled. Off keeps LAN and public behaving the same way.
final lanDirectNotifier = ValueNotifier<bool>(false);

String _trimUrl(String url) {
  var value = url.trim();
  while (value.endsWith('/')) {
    value = value.substring(0, value.length - 1);
  }
  return value;
}

/// Whether the settings ask for LAN direct playback and the active server is
/// actually being reached over its LAN address.
///
/// The server record keeps the address that answered (`lastGoodUrl`); the live
/// client can also have failed over to the LAN address before the record was
/// saved, so its base URL is checked as well. Feiniu appends its API path to the
/// address, hence the prefix check.
bool get lanDirectActive {
  if (!lanDirectNotifier.value) {
    return false;
  }
  // The switch is offered for streamed sources only; a local or WebDAV source
  // keeps its own playback path even if the stored flag stayed on.
  if (!isStreamSource) {
    return false;
  }
  final server = config.activeServer;
  if (server == null) {
    return false;
  }
  if (server.usingLan) {
    return true;
  }
  final lan = _trimUrl(server.lanUrl);
  if (lan.isEmpty) {
    return false;
  }
  final base = _trimUrl(streamClient?.baseUrl ?? '');
  return base == lan || base.startsWith('$lan/');
}
