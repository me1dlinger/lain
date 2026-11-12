import 'dart:io';

import 'package:flutter/services.dart';

import 'package:lain/base/app.dart';
import 'package:lain/base/data/notice_setting.dart';
import 'package:lain/base/services/interaction.dart';
import 'package:lain/l10n/generated/app_localizations.dart';

/// Reminds the listener, once per cellular session, that streaming online
/// music consumes mobile data.
///
/// The active network is read from Android's ConnectivityManager through a
/// small method channel; `NetworkInterface.list()` cannot tell the *active*
/// transport apart from an idle cellular interface while Wi-Fi is connected.
class MobileDataNoticeService {
  static const _channel = MethodChannel('com.meidlinger.lain.mobile_network');

  bool _warned = false;
  bool _checking = false;

  /// Call when a song that is not cached starts. [usesNetwork] is false for a
  /// local file, and those spend no data.
  Future<void> maybeWarn({required bool usesNetwork}) async {
    if (!usesNetwork || !mobileDataWarningNotifier.value) {
      return;
    }
    if (_checking) {
      return;
    }
    _checking = true;
    final cellular = await _isCellular();
    _checking = false;
    if (!cellular) {
      // Leaving cellular resets the reminder, so the next time the listener
      // goes out of Wi-Fi they hear about it once more.
      _warned = false;
      return;
    }
    if (_warned) {
      return;
    }
    final context = globalNavigatorKey.currentContext;
    if (context == null || !context.mounted) {
      return;
    }
    _warned = true;
    showCenterMessage(AppLocalizations.of(context).mobileDataNotice);
  }

  Future<bool> _isCellular() async {
    // Desktops have no cellular radio. iOS has one, but the reminder is wired
    // to the Android connectivity manager; returning false there only means no
    // reminder, never a wrong one.
    if (!Platform.isAndroid) {
      return false;
    }
    try {
      return await _channel.invokeMethod<bool>('isCellular') ?? false;
    } catch (_) {
      return false;
    }
  }
}

final mobileDataNotice = MobileDataNoticeService();
