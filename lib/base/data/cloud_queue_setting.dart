import 'package:flutter/foundation.dart';

/// Whether the play queue is mirrored to the server's OpenSubsonic play queue
/// (`savePlayQueue`), so another device can pick it up.
///
/// Restoring in the other direction is always a manual action: a queue that is
/// already playing here is never replaced without the user asking for it.
final cloudQueueEnabledNotifier = ValueNotifier<bool>(true);
