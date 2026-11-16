import 'package:flutter/foundation.dart';

/// How the cover is used behind the lyric card.
enum ShareCardBackground { blur, crop, aurora, pixelate, halftone }

final shareCardTopTextNotifier = ValueNotifier<String>('LAIN · 临音');
final shareCardBackgroundNotifier = ValueNotifier<ShareCardBackground>(
  ShareCardBackground.blur,
);
final shareCardTextSizeNotifier = ValueNotifier<double>(22);
final shareCardCoverSizeNotifier = ValueNotifier<double>(164);
final shareCardShowTranslationNotifier = ValueNotifier<bool>(false);
