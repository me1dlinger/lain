import 'package:flutter/foundation.dart';

/// When on, only a local library may be used. The app switches to it on
/// startup and every path that would activate an online source is refused.
final offlineModeNotifier = ValueNotifier<bool>(false);

/// With offline mode on, use the current server's already cached songs instead
/// of switching to the local library. Those songs play from disk, so the server
/// does not have to answer.
final offlineUseCachedLibraryNotifier = ValueNotifier<bool>(false);

/// The server whose cache is used offline. Kept because switching to the local
/// library clears the active server; this is what lets the cached library come
/// back without waiting for the network.
final offlineServerIdNotifier = ValueNotifier<String>('');
