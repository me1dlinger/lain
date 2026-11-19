import 'package:flutter/foundation.dart';

/// Manual override for the classic Bluetooth (AVRCP) publisher.
///
/// Off (the default) is adaptive: the publisher is chosen from the current
/// audio output, so a classic Bluetooth route gets the classic publishing
/// shape and a smart-link car keeps the normal one.
///
/// On: the classic Bluetooth shape is used on every output. This is the
/// fallback for a head unit whose route the platform does not report as an
/// A2DP/SCO output.
final classicBluetoothBroadcastNotifier = ValueNotifier<bool>(false);

/// The last observed output route, for the settings page: true while a classic
/// Bluetooth output device is active.
final classicBluetoothRouteNotifier = ValueNotifier<bool>(false);
