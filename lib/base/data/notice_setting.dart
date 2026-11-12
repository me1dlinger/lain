import 'package:flutter/foundation.dart';

/// Whether the cellular-data reminder is shown when an online song starts.
/// Kept in its own file so the notice service can read it without importing
/// the whole settings module.
final mobileDataWarningNotifier = ValueNotifier<bool>(true);
