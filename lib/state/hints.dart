import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One-time hints for gestures that are otherwise invisible. Each is shown
/// until dismissed once; the ids are persisted, so keep them stable.
enum Hint {
  /// Long-press drag of blocks, long press on a day header, pinch zoom.
  timeline,

  /// Long press on the map adds something there.
  map,

  /// Long-press drag of nodes, pinch zoom.
  canvas,
}

/// Overridden in main(); null keeps dismissals in memory only (tests).
final hintPrefsProvider = Provider<SharedPreferences?>((ref) => null);

const _prefsKey = 'seenHints';

/// The hints dismissed so far.
class HintsNotifier extends Notifier<Set<Hint>> {
  SharedPreferences? get _prefs => ref.read(hintPrefsProvider);

  @override
  Set<Hint> build() {
    final names = ref.watch(hintPrefsProvider)?.getStringList(_prefsKey) ?? const <String>[];
    return {for (final h in Hint.values) if (names.contains(h.name)) h};
  }

  void dismiss(Hint h) {
    if (state.contains(h)) return;
    state = {...state, h};
    _save();
  }

  /// Shows every hint again (trip list menu).
  void resetAll() {
    state = const {};
    _save();
  }

  void _save() => _prefs?.setStringList(_prefsKey, [for (final h in state) h.name]);
}

final hintsProvider = NotifierProvider<HintsNotifier, Set<Hint>>(HintsNotifier.new);
