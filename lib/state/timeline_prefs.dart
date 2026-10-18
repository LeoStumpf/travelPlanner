import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'hints.dart';

/// How the timeline runs: days left to right with the layers as rows, or
/// top to bottom with the layers as columns.
enum TimelineAxis { horizontal, vertical }

const _prefsKey = 'timelineAxis';

/// The timeline's orientation, kept on the device across restarts (in the
/// same shared preferences as the hints; null there keeps it in memory).
class TimelineAxisNotifier extends Notifier<TimelineAxis> {
  @override
  TimelineAxis build() {
    final name = ref.watch(hintPrefsProvider)?.getString(_prefsKey);
    return TimelineAxis.values.where((a) => a.name == name).firstOrNull ?? TimelineAxis.horizontal;
  }

  void toggle() {
    state = state == TimelineAxis.horizontal ? TimelineAxis.vertical : TimelineAxis.horizontal;
    ref.read(hintPrefsProvider)?.setString(_prefsKey, state.name);
  }
}

final timelineAxisProvider = NotifierProvider<TimelineAxisNotifier, TimelineAxis>(TimelineAxisNotifier.new);
