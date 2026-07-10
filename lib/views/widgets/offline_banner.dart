import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/connectivity_service.dart';
import '../../theme/app_theme.dart';

/// Slim strip shown above the bottom nav while the app is offline and serving
/// cached data. Debounced so a brief cache read on cold start (before the first
/// server sync) doesn't flash the banner; hides immediately when back online.
class OfflineBanner extends ConsumerStatefulWidget {
  const OfflineBanner({super.key});

  @override
  ConsumerState<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends ConsumerState<OfflineBanner> {
  bool _visible = false;
  Timer? _timer;

  void _handle(bool offline) {
    if (offline) {
      _timer ??= Timer(const Duration(milliseconds: 1500), () {
        if (mounted) setState(() => _visible = true);
      });
    } else {
      _timer?.cancel();
      _timer = null;
      if (_visible && mounted) setState(() => _visible = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final offline = ref.watch(offlineProvider).asData?.value ?? false;
    // Reconcile after the frame so we never call setState during build.
    WidgetsBinding.instance.addPostFrameCallback((_) => _handle(offline));

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      alignment: Alignment.bottomCenter,
      child: _visible
          ? Container(
              width: double.infinity,
              color: AppColors.forest,
              padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.cloud_off_rounded,
                      size: 16, color: Colors.white),
                  const SizedBox(width: 8),
                  Text("You're offline, showing saved recipes",
                      style: AppText.sans(13,
                          color: Colors.white, weight: FontWeight.w600)),
                ],
              ),
            )
          : const SizedBox(width: double.infinity),
    );
  }
}
