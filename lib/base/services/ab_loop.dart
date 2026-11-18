import 'package:material_ui/material_ui.dart';

/// A per-track A–B loop. The two points are media positions inside the current
/// song; when B is reached playback jumps back to A. The loop is deliberately
/// cleared by a track change, because points from one song mean nothing in the
/// next one.
class AbLoopController {
  final start = ValueNotifier<Duration?>(null);
  final end = ValueNotifier<Duration?>(null);
  final enabled = ValueNotifier<bool>(false);

  bool get active {
    final a = start.value;
    final b = end.value;
    return enabled.value &&
        a != null &&
        b != null &&
        b > a &&
        b - a > const Duration(milliseconds: 500);
  }

  Duration? get a => start.value;
  Duration? get b => end.value;

  void setStart(Duration value) {
    start.value = value;
    final currentEnd = end.value;
    if (currentEnd != null && currentEnd <= value) {
      end.value = null;
      enabled.value = false;
    }
  }

  void setEnd(Duration value) {
    end.value = value;
    final currentStart = start.value;
    if (currentStart != null && value <= currentStart) {
      start.value = null;
      enabled.value = false;
    }
  }

  void setEnabled(bool value) {
    enabled.value = value && start.value != null && end.value != null;
  }

  void clear() {
    enabled.value = false;
    start.value = null;
    end.value = null;
  }
}

final abLoop = AbLoopController();
