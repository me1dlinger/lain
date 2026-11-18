import 'package:material_ui/material_ui.dart';
import 'package:lain/base/audio_handler.dart';
import 'package:lain/base/services/ab_loop.dart';
import 'package:lain/base/services/color_manager.dart';
import 'package:lain/base/services/interaction.dart';
import 'package:lain/base/utils/common_utils.dart';
import 'package:lain/base/widgets/my_sheet.dart';
import 'package:lain/base/widgets/my_switch.dart';
import 'package:lain/l10n/generated/app_localizations.dart';

/// A guided A–B loop editor: two draggable handles over the song's timeline,
/// plus "set at what is playing now" buttons. No text fields - the positions
/// are set where the listener can see them.
Future<void> showAbLoopSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    builder: (context) => const MySheet(height: 390, _AbLoopSheet()),
  );
}

class _AbLoopSheet extends StatefulWidget {
  const _AbLoopSheet();

  @override
  State<_AbLoopSheet> createState() => _AbLoopSheetState();
}

class _AbLoopSheetState extends State<_AbLoopSheet> {
  @override
  void initState() {
    super.initState();
    final duration = audioHandler.getCurrentDuration();
    final position = audioHandler.getPosition();
    if (abLoop.a == null) {
      abLoop.start.value = position;
    }
    if (abLoop.b == null) {
      final start = abLoop.a ?? Duration.zero;
      final fallback = start + const Duration(seconds: 30);
      abLoop.end.value =
          duration > start ? (fallback < duration ? fallback : duration) : start;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textColor = colorManager.getSpecificTextColor();
    return ListenableBuilder(
      listenable: Listenable.merge([abLoop.start, abLoop.end, abLoop.enabled]),
      builder: (context, child) {
        final duration = audioHandler.getCurrentDuration();
        final a = abLoop.a;
        final b = abLoop.b;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.abLoop,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 14),
              StreamBuilder<Duration>(
                stream: audioHandler.getPositionStream(),
                builder: (context, snapshot) {
                  final position = snapshot.data ?? audioHandler.getPosition();
                  return _Timeline(
                    duration: duration,
                    position: position,
                    a: a,
                    b: b,
                    onA: (value) => abLoop.setStart(value),
                    onB: (value) => abLoop.setEnd(value),
                  );
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _rangeChip('A', a, textColor),
                  const SizedBox(width: 8),
                  _rangeChip('B', b, textColor),
                  const Spacer(),
                  if (a != null && b != null && b > a)
                    Text(
                      formatDuration(b - a),
                      style: TextStyle(
                        fontSize: 12,
                        color: textColor.withAlpha(150),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        abLoop.setStart(audioHandler.getPosition());
                        tryVibrateLight();
                      },
                      child: Text(l10n.abSetA),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        abLoop.setEnd(audioHandler.getPosition());
                        tryVibrateLight();
                      },
                      child: Text(l10n.abSetB),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Text(
                    l10n.abLoop,
                    style: TextStyle(fontSize: 15, color: textColor),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: 50,
                    child: MySwitch(
                      valueNotifier: abLoop.enabled,
                      onToggleCallBack: () {
                        final wanted = abLoop.enabled.value;
                        abLoop.setEnabled(wanted);
                        if (wanted && !abLoop.active) {
                          showCenterMessage(l10n.abNeedBoth);
                        }
                        tryVibrateLight();
                      },
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  TextButton(
                    onPressed: () {
                      abLoop.clear();
                      setState(() {});
                    },
                    child: Text(
                      l10n.abClear,
                      style: TextStyle(color: textColor.withAlpha(150)),
                    ),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(l10n.confirm),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _rangeChip(String label, Duration? value, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: textColor.withAlpha(14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        value == null ? '$label --:--' : '$label ${formatDuration(value)}',
        style: TextStyle(fontSize: 11, color: textColor.withAlpha(190)),
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  final Duration duration;
  final Duration position;
  final Duration? a;
  final Duration? b;
  final ValueChanged<Duration> onA;
  final ValueChanged<Duration> onB;

  const _Timeline({
    required this.duration,
    required this.position,
    required this.a,
    required this.b,
    required this.onA,
    required this.onB,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = colorManager.getSpecificTextColor();
    final accent = colorManager.getSpecificHighlightTextColor();
    return SizedBox(
      height: 74,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          const inset = 11.0;
          final trackWidth = (width - inset * 2).clamp(1.0, width);
          double xOf(Duration value) {
            if (duration <= Duration.zero) {
              return inset;
            }
            return inset +
                (value.inMilliseconds / duration.inMilliseconds)
                    .clamp(0.0, 1.0) *
                    trackWidth;
          }

          Duration durationAt(double x) {
            if (duration <= Duration.zero) {
              return Duration.zero;
            }
            return Duration(
              milliseconds: (((x - inset) / trackWidth).clamp(0.0, 1.0) *
                      duration.inMilliseconds)
                  .round(),
            );
          }

          final ax = a == null ? null : xOf(a!);
          final bx = b == null ? null : xOf(b!);
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: inset,
                right: inset,
                top: 30,
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: textColor.withAlpha(28),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              if (ax != null && bx != null && bx > ax)
                Positioned(
                  left: ax,
                  width: bx - ax,
                  top: 30,
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: accent.withAlpha(170),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              Positioned(
                left: (xOf(position) - 1).clamp(0.0, width - 2),
                top: 18,
                child: Container(
                  width: 2,
                  height: 28,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              if (ax != null)
                _handle(
                  context: context,
                  x: ax,
                  width: width,
                  label: 'A',
                  color: textColor.withAlpha(220),
                  onDrag: (dx) => onA(durationAt(ax + dx)),
                ),
              if (bx != null)
                _handle(
                  context: context,
                  x: bx,
                  width: width,
                  label: 'B',
                  color: accent,
                  onDrag: (dx) => onB(durationAt(bx + dx)),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _handle({
    required BuildContext context,
    required double x,
    required double width,
    required String label,
    required Color color,
    required ValueChanged<double> onDrag,
  }) {
    return Positioned(
      left: (x - 11).clamp(0.0, width - 22),
      top: 18,
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeLeftRight,
        child: GestureDetector(
          onHorizontalDragUpdate: (details) => onDrag(details.delta.dx),
          child: Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
