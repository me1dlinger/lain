import 'dart:ui';

import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/l10n/generated/app_localizations.dart';
import 'package:sylvakru/l10n/generated/app_localizations_en.dart';

String formatDuration(Duration duration, {bool ms = true}) {
  String twoDigits(int n) => n.toString().padLeft(2, "0");
  if (ms) {
    final minutes = twoDigits(duration.inMinutes);
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  return "${twoDigits((duration.inMinutes / 60).toInt())}:${twoDigits(duration.inMinutes.remainder(60))}";
}

/// Bytes as a short human-readable size ("1.2 GB"); empty for nothing to show.
String formatSize(int bytes) {
  if (bytes <= 0) {
    return '';
  }
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final decimals = (unit == 0 || value >= 100) ? 0 : 1;
  return '${value.toStringAsFixed(decimals)} ${units[unit]}';
}

int compareVersion(String a, String b) {
  final aParts = a.split('.').map(int.parse).toList();
  final bParts = b.split('.').map(int.parse).toList();

  final length = aParts.length > bParts.length ? aParts.length : bParts.length;

  for (int i = 0; i < length; i++) {
    final aVal = i < aParts.length ? aParts[i] : 0;
    final bVal = i < bParts.length ? bParts[i] : 0;

    if (aVal != bVal) {
      return aVal.compareTo(bVal);
    }
  }
  return 0;
}

AppLocalizations getAppLocalizations() {
  if (globalNavigatorKey.currentContext != null) {
    return AppLocalizations.of(globalNavigatorKey.currentContext!);
  } else {
    if (localeNotifier.value != null) {
      return lookupAppLocalizations(localeNotifier.value!);
    } else {
      late AppLocalizations appLocalizations;
      try {
        appLocalizations = lookupAppLocalizations(
          PlatformDispatcher.instance.locale,
        );
      } catch (_) {
        appLocalizations = AppLocalizationsEn();
      }
      return appLocalizations;
    }
  }
}
