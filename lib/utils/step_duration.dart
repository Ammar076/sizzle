/// Detects a cooking/waiting duration mentioned in a recipe step, so Cooking
/// Mode can offer a one-tap timer. Handles "simmer for 10 minutes", "bake 25
/// min", "rest 1 hour", "boil 90 seconds", and ranges like "cook 5-7 minutes"
/// (uses the upper bound). Only the first duration in the step is used; returns
/// null when no time is mentioned.
Duration? parseStepDuration(String step) {
  final re = RegExp(
    r'(\d+(?:\.\d+)?)\s*(?:(?:-|–|—|to)\s*(\d+(?:\.\d+)?)\s*)?'
    r'(hours?|hrs?|hr|h|minutes?|mins?|min|seconds?|secs?|sec)\b',
    caseSensitive: false,
  );

  final match = re.firstMatch(step);
  if (match == null) return null;

  final lower = double.tryParse(match.group(1) ?? '');
  final upper = double.tryParse(match.group(2) ?? '');
  final amount = upper ?? lower; // for a range, take the longer time
  if (amount == null || amount <= 0) return null;

  final unit = match.group(3)!.toLowerCase();
  final int seconds;
  if (unit.startsWith('h')) {
    seconds = (amount * 3600).round();
  } else if (unit.startsWith('s')) {
    seconds = amount.round();
  } else {
    seconds = (amount * 60).round(); // minutes
  }

  if (seconds <= 0 || seconds > 24 * 3600) return null;
  return Duration(seconds: seconds);
}

/// mm:ss, or h:mm:ss once there's an hour or more on the clock.
String formatTimer(Duration d) {
  final total = d.inSeconds < 0 ? 0 : d.inSeconds;
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  final mm = m.toString().padLeft(2, '0');
  final ss = s.toString().padLeft(2, '0');
  return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
}

/// Short, friendly label for a detected duration, e.g. "10 min", "1 hr",
/// "45 sec", falling back to a clock (m:ss) for mixed values like 90 seconds.
String durationLabel(Duration d) {
  final s = d.inSeconds;
  if (s % 3600 == 0) return '${d.inHours} hr';
  if (s % 60 == 0) return '${d.inMinutes} min';
  if (s < 60) return '$s sec';
  return formatTimer(d);
}
