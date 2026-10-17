import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';

/// Runs the automatic backup on app start and whenever the app goes to the
/// background, if the last one is older than a day.
class AutoBackupListener extends ConsumerStatefulWidget {
  final Widget child;
  const AutoBackupListener({super.key, required this.child});

  @override
  ConsumerState<AutoBackupListener> createState() => _AutoBackupListenerState();
}

class _AutoBackupListenerState extends ConsumerState<AutoBackupListener> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onStateChange: (s) {
      if (s == AppLifecycleState.paused || s == AppLifecycleState.detached) _run();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    final backup = ref.read(autoBackupProvider);
    if (backup == null) return;
    try {
      final written = await backup.runIfDue();
      if (written != null && mounted) ref.invalidate(backupsProvider);
    } catch (e) {
      // A failed backup must never disturb the user; the next trigger retries.
      debugPrint('Auto backup failed: $e');
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
