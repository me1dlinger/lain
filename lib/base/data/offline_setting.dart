import 'package:flutter/foundation.dart';

/// When on, only a local library may be used. The app switches to it on
/// startup and every path that would activate an online source is refused.
final offlineModeNotifier = ValueNotifier<bool>(false);
