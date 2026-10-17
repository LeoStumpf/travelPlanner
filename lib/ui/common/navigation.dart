import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/map_layout.dart';
import '../../domain/models.dart';
import 'l10n.dart';

/// Opens a URI in another app; false when nothing handles it. Replaced in
/// widget tests.
final externalLauncherProvider = Provider<Future<bool> Function(Uri)>((ref) => (uri) async {
      try {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        return false;
      }
    });

/// Hands [item]'s place (see [navigationTarget]) to a maps app for
/// directions, falling back to Google Maps on the web; a snackbar says so
/// when no app takes it.
Future<void> openNavigation(BuildContext context, WidgetRef ref, TripData data, PlanItem item) async {
  final target = navigationTarget(data, item);
  if (target == null) return;
  final messenger = ScaffoldMessenger.maybeOf(context);
  final failed = context.l10n.noNavigationApp;
  final launch = ref.read(externalLauncherProvider);
  for (final uri in navigationUris(target)) {
    if (await launch(uri)) return;
  }
  messenger?.showSnackBar(SnackBar(content: Text(failed)));
}
