import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/recipe.dart';
import '../theme/app_theme.dart';
import '../utils/step_duration.dart';

/// Full-screen, step-by-step cooking guide. Keeps the screen awake so it never
/// dims mid-recipe, shows one large step at a time, and keeps the ingredient
/// list one tap away (with a check-off list) so you never leave the flow.
class CookingModeScreen extends StatefulWidget {
  final Recipe recipe;
  const CookingModeScreen({super.key, required this.recipe});

  @override
  State<CookingModeScreen> createState() => _CookingModeScreenState();
}

class _CookingModeScreenState extends State<CookingModeScreen> {
  final _controller = PageController();
  int _index = 0;
  // Persisted while cooking so ticks survive re-opening the ingredients sheet.
  final Set<int> _checkedIngredients = {};

  // A single kitchen timer that keeps counting as you move between steps, so
  // you can start "simmer 10 min" and read ahead without leaving the flow.
  Timer? _ticker;
  Duration? _timerTotal; // null when no timer has been set
  Duration _timerRemaining = Duration.zero;
  int? _timerStep; // step the running timer was started from (for its label)
  bool _timerRunning = false;
  bool _timerFinished = false;

  List<String> get _steps => widget.recipe.steps;
  List<String> get _ingredients => widget.recipe.ingredients;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable(); // don't let the screen sleep while cooking
  }

  @override
  void dispose() {
    _ticker?.cancel();
    WakelockPlus.disable();
    _controller.dispose();
    super.dispose();
  }

  void _startTimer(Duration duration, int step) {
    _ticker?.cancel();
    HapticFeedback.mediumImpact();
    setState(() {
      _timerTotal = duration;
      _timerRemaining = duration;
      _timerStep = step;
      _timerRunning = true;
      _timerFinished = false;
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final next = _timerRemaining - const Duration(seconds: 1);
      if (next <= Duration.zero) {
        _onTimerDone();
      } else {
        setState(() => _timerRemaining = next);
      }
    });
  }

  void _onTimerDone() {
    _ticker?.cancel();
    _ticker = null;
    setState(() {
      _timerRunning = false;
      _timerFinished = true;
      _timerRemaining = Duration.zero;
    });
    _soundAlarm();
  }

  /// Best-effort alert without an audio dependency: a short burst of strong
  /// haptics plus the platform alert sound, stopping if the user dismisses.
  Future<void> _soundAlarm() async {
    for (var i = 0; i < 4; i++) {
      if (!mounted || !_timerFinished) return;
      HapticFeedback.heavyImpact();
      SystemSound.play(SystemSoundType.alert);
      await Future.delayed(const Duration(milliseconds: 600));
    }
  }

  void _toggleTimer() {
    if (_timerRunning) {
      _ticker?.cancel();
      _ticker = null;
      setState(() => _timerRunning = false);
    } else if (_timerRemaining > Duration.zero) {
      setState(() => _timerRunning = true);
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        final next = _timerRemaining - const Duration(seconds: 1);
        if (next <= Duration.zero) {
          _onTimerDone();
        } else {
          setState(() => _timerRemaining = next);
        }
      });
    }
  }

  void _clearTimer() {
    _ticker?.cancel();
    _ticker = null;
    setState(() {
      _timerTotal = null;
      _timerRemaining = Duration.zero;
      _timerStep = null;
      _timerRunning = false;
      _timerFinished = false;
    });
  }

  void _goTo(int i) {
    _controller.animateToPage(
      i,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  void _showIngredients() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            void toggle(int i) {
              setState(() {
                if (_checkedIngredients.contains(i)) {
                  _checkedIngredients.remove(i);
                } else {
                  _checkedIngredients.add(i);
                }
              });
              setSheetState(() {});
            }

            return SafeArea(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.7,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          height: 4,
                          width: 44,
                          decoration: BoxDecoration(
                            color: AppColors.line,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Text('Ingredients',
                              style:
                                  AppText.display(20, weight: FontWeight.w800)),
                          const SizedBox(width: 8),
                          Text(
                            '${_checkedIngredients.length}/${_ingredients.length}',
                            style: AppText.sans(14,
                                weight: FontWeight.w700,
                                color: AppColors.muted),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _ingredients.length,
                          itemBuilder: (context, i) => _IngredientTile(
                            text: _ingredients[i],
                            checked: _checkedIngredients.contains(i),
                            onTap: () => toggle(i),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = _steps.length;
    final isLast = _index == total - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header: close, title, ingredients shortcut.
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 12, 6),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Exit cooking mode',
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      widget.recipe.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.sans(15,
                          weight: FontWeight.w700, color: AppColors.muted),
                    ),
                  ),
                  if (_ingredients.isNotEmpty)
                    TextButton.icon(
                      onPressed: _showIngredients,
                      icon: const Icon(Icons.checklist_rounded, size: 20),
                      label: const Text('Ingredients'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.forest,
                        backgroundColor: AppColors.sage,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30)),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: total == 0 ? 0 : (_index + 1) / total,
                        minHeight: 6,
                        backgroundColor: AppColors.line,
                        valueColor:
                            const AlwaysStoppedAnimation(AppColors.primary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('${_index + 1}/$total',
                      style: AppText.sans(14,
                          weight: FontWeight.w800, color: AppColors.primary)),
                ],
              ),
            ),
            _TimerBar(
              total: _timerTotal,
              remaining: _timerRemaining,
              running: _timerRunning,
              finished: _timerFinished,
              stepLabel: _timerStep == null ? '' : 'Step ${_timerStep! + 1}',
              onToggle: _toggleTimer,
              onClear: _clearTimer,
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (i) => setState(() => _index = i),
                itemCount: total,
                itemBuilder: (context, i) {
                  final duration = parseStepDuration(_steps[i]);
                  return _StepPage(
                    number: i + 1,
                    total: total,
                    text: _steps[i],
                    timerDuration: duration,
                    isTimerActiveHere: _timerTotal != null && _timerStep == i,
                    onStartTimer: duration == null
                        ? null
                        : () => _startTimer(duration, i),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Row(
                children: [
                  if (_index > 0)
                    Expanded(
                      child: SizedBox(
                        height: 56,
                        child: OutlinedButton(
                          onPressed: () => _goTo(_index - 1),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.forest,
                            side: const BorderSide(color: AppColors.line),
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(AppRadii.button)),
                          ),
                          child: const Text('Back'),
                        ),
                      ),
                    ),
                  if (_index > 0) const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () =>
                          isLast ? Navigator.pop(context) : _goTo(_index + 1),
                      child: Text(isLast ? 'Finish' : 'Next'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepPage extends StatelessWidget {
  final int number;
  final int total;
  final String text;
  final Duration? timerDuration;
  final bool isTimerActiveHere;
  final VoidCallback? onStartTimer;
  const _StepPage({
    required this.number,
    required this.total,
    required this.text,
    this.timerDuration,
    this.isTimerActiveHere = false,
    this.onStartTimer,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.blush,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text('STEP $number OF $total',
                style: AppText.sans(13,
                    weight: FontWeight.w800,
                    color: AppColors.primaryPressed,
                    spacing: 1)),
          ),
          const SizedBox(height: 28),
          Text(
            text,
            style: AppText.display(28, weight: FontWeight.w600, height: 1.35),
          ),
          if (timerDuration != null && onStartTimer != null) ...[
            const SizedBox(height: 28),
            _StartTimerButton(
              duration: timerDuration!,
              active: isTimerActiveHere,
              onTap: onStartTimer!,
            ),
          ],
        ],
      ),
    );
  }
}

/// The "Start N-min timer" chip shown on a step whose text mentions a time.
class _StartTimerButton extends StatelessWidget {
  final Duration duration;
  final bool active;
  final VoidCallback onTap;
  const _StartTimerButton(
      {required this.duration, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(active ? Icons.refresh_rounded : Icons.timer_outlined,
          size: 20),
      label: Text(active
          ? 'Restart ${durationLabel(duration)} timer'
          : 'Start ${durationLabel(duration)} timer'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primaryPressed,
        backgroundColor: AppColors.blush,
        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.35)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30)),
        textStyle: AppText.sans(15, weight: FontWeight.w800),
      ),
    );
  }
}

/// A persistent kitchen-timer bar that stays visible across steps while a timer
/// is set. Shows the countdown with pause/resume, flips to an alert state when
/// time's up, and clears on dismiss.
class _TimerBar extends StatelessWidget {
  final Duration? total;
  final Duration remaining;
  final bool running;
  final bool finished;
  final String stepLabel;
  final VoidCallback onToggle;
  final VoidCallback onClear;
  const _TimerBar({
    required this.total,
    required this.remaining,
    required this.running,
    required this.finished,
    required this.stepLabel,
    required this.onToggle,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    if (total == null) return const SizedBox.shrink();

    final pct = total!.inSeconds == 0
        ? 0.0
        : remaining.inSeconds / total!.inSeconds;
    final bg = finished ? AppColors.primary : AppColors.surface;
    final onBg = finished ? Colors.white : AppColors.ink;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: finished ? AppColors.primary : AppColors.line),
          boxShadow: finished ? AppShadows.subtle : null,
        ),
        child: Row(
          children: [
            Icon(
              finished ? Icons.notifications_active_rounded : Icons.timer_rounded,
              color: finished ? Colors.white : AppColors.primary,
              size: 24,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    finished
                        ? "Time's up!"
                        : '${formatTimer(remaining)}${running ? '' : '  ·  paused'}',
                    style: finished
                        ? AppText.sans(18,
                            weight: FontWeight.w800, color: onBg)
                        : AppText.display(22,
                            weight: FontWeight.w800, color: onBg),
                  ),
                  if (stepLabel.isNotEmpty)
                    Text(stepLabel,
                        style: AppText.sans(12,
                            color: finished
                                ? Colors.white70
                                : AppColors.muted)),
                  if (!finished) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: LinearProgressIndicator(
                        value: pct.clamp(0.0, 1.0),
                        minHeight: 4,
                        backgroundColor: AppColors.line,
                        valueColor:
                            const AlwaysStoppedAnimation(AppColors.primary),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (finished)
              TextButton(
                onPressed: onClear,
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                child: const Text('Dismiss'),
              )
            else ...[
              IconButton(
                onPressed: onToggle,
                icon: Icon(running
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded),
                color: AppColors.primary,
                tooltip: running ? 'Pause' : 'Resume',
              ),
              IconButton(
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded),
                color: AppColors.muted,
                tooltip: 'Cancel timer',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _IngredientTile extends StatelessWidget {
  final String text;
  final bool checked;
  final VoidCallback onTap;
  const _IngredientTile({
    required this.text,
    required this.checked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 24,
              width: 24,
              margin: const EdgeInsets.only(top: 1, right: 12),
              decoration: BoxDecoration(
                color: checked ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: checked ? AppColors.primary : AppColors.line,
                    width: 1.6),
              ),
              child: checked
                  ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                  : null,
            ),
            Expanded(
              child: Text(
                text,
                style: AppText.sans(15,
                    color: checked ? AppColors.muted : AppColors.ink,
                    height: 1.5,
                    weight: FontWeight.w500).copyWith(
                  decoration: checked
                      ? TextDecoration.lineThrough
                      : TextDecoration.none,
                  decorationColor: AppColors.muted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
