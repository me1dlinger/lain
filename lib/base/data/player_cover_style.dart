import 'package:flutter/foundation.dart';

/// How the now-playing page draws its artwork: as the normal square cover, or
/// as a rotating vinyl record with the cover as its label.
enum PlayerCoverStyle { square, vinyl }

final playerCoverStyleNotifier = ValueNotifier<PlayerCoverStyle>(
  PlayerCoverStyle.square,
);
