import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../domain/reminders.dart';
import '../domain/zones.dart';

/// A [Reminder] with its words, ready to be scheduled.
class ReminderNotice {
  final Reminder reminder;
  final String title;
  final String body;
  const ReminderNotice(this.reminder, this.title, this.body);
}

/// What the app may do with notifications on this phone.
class ReminderPermissions {
  /// Notifications may be shown (Android 13+: POST_NOTIFICATIONS granted).
  final bool notifications;

  /// Alarms fire on the minute (Android 12+: "Alarms & reminders" allowed).
  /// Without it they are inexact: Android may defer them, the further ahead
  /// they are scheduled the longer (up to hours).
  final bool exactAlarms;

  const ReminderPermissions({this.notifications = true, this.exactAlarms = true});
}

/// Schedules trip reminders as local notifications. Overridden in tests.
abstract class ReminderScheduler {
  /// Replaces every scheduled reminder with [notices] (empty = cancel all).
  Future<void> sync(List<ReminderNotice> notices);

  Future<ReminderPermissions> permissions();

  /// Asks for the notification permission (Android 13+, iOS). Returns
  /// whether notifications may be shown afterwards.
  Future<bool> requestNotifications();

  /// Opens the system screen for exact alarms (Android 12+).
  Future<void> requestExactAlarms();

  /// Opens the app's notification settings (after a permanent denial).
  Future<void> openSettings();

  /// Payloads ([Reminder.payload]) of tapped notifications while running.
  Stream<String> get taps;

  /// Payload of the notification that started the app, if any.
  Future<String?> launchPayload();
}

/// [ReminderScheduler] on flutter_local_notifications. Times are passed
/// as UTC instants, so no device zone lookup is needed.
class LocalReminderScheduler implements ReminderScheduler {
  final _plugin = FlutterLocalNotificationsPlugin();
  final _taps = StreamController<String>.broadcast();
  Future<bool>? _init;

  static const _channel = AndroidNotificationDetails(
    'trip_reminders',
    'Trip reminders',
    channelDescription: 'Departures, check-in and check-out',
    importance: Importance.high,
    priority: Priority.high,
    category: AndroidNotificationCategory.reminder,
  );

  bool get _supported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  IOSFlutterLocalNotificationsPlugin? get _ios =>
      _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();

  Future<bool> _ready() => _init ??= () async {
        if (!_supported) return false;
        ensureTimeZones();
        await _plugin.initialize(
          settings: const InitializationSettings(
            android: AndroidInitializationSettings('@drawable/ic_launcher_monochrome'),
            // Asked for when reminders are switched on, not at app start.
            iOS: DarwinInitializationSettings(
              requestAlertPermission: false,
              requestBadgePermission: false,
              requestSoundPermission: false,
            ),
          ),
          onDidReceiveNotificationResponse: (r) {
            if (r.payload != null) _taps.add(r.payload!);
          },
        );
        return true;
      }();

  @override
  Future<void> sync(List<ReminderNotice> notices) async {
    if (!await _ready()) return;
    // Exact when allowed, else inexact (may be deferred a little in doze).
    final exact = (await _android?.canScheduleExactNotifications()) ?? true;
    final mode = exact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle;
    await _plugin.cancelAllPendingNotifications();
    final now = DateTime.now().toUtc();
    for (final n in notices) {
      final r = n.reminder;
      if (!r.fireAt.isAfter(now)) continue;
      try {
        await _plugin.zonedSchedule(
          id: r.id,
          title: n.title,
          body: n.body,
          scheduledDate: tz.TZDateTime.from(r.fireAt, tz.UTC),
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              _channel.channelId,
              _channel.channelName,
              channelDescription: _channel.channelDescription,
              importance: _channel.importance,
              priority: _channel.priority,
              category: _channel.category,
              styleInformation: BigTextStyleInformation(n.body),
              when: r.eventAt.millisecondsSinceEpoch,
            ),
            iOS: const DarwinNotificationDetails(),
          ),
          androidScheduleMode: mode,
          payload: r.payload,
        );
      } catch (e) {
        // One bad entry must not keep the others from being scheduled.
        debugPrint('Scheduling reminder ${r.id} failed: $e');
      }
    }
  }

  @override
  Future<ReminderPermissions> permissions() async {
    if (!await _ready()) return const ReminderPermissions(notifications: false, exactAlarms: false);
    final android = _android;
    if (android != null) {
      return ReminderPermissions(
        notifications: await android.areNotificationsEnabled() ?? true,
        exactAlarms: await android.canScheduleExactNotifications() ?? true,
      );
    }
    final ios = await _ios?.checkPermissions();
    return ReminderPermissions(notifications: ios?.isEnabled ?? true);
  }

  @override
  Future<bool> requestNotifications() async {
    if (!await _ready()) return false;
    final android = _android;
    if (android != null) return await android.requestNotificationsPermission() ?? false;
    return await _ios?.requestPermissions(alert: true, sound: true, badge: false) ?? false;
  }

  @override
  Future<void> requestExactAlarms() async {
    if (!await _ready()) return;
    await _android?.requestExactAlarmsPermission();
  }

  @override
  Future<void> openSettings() async {
    if (!await _ready()) return;
    await (_android?.openAppNotificationSettings() ?? _ios?.openAppNotificationSettings());
  }

  @override
  Stream<String> get taps => _taps.stream;

  @override
  Future<String?> launchPayload() async {
    if (!await _ready()) return null;
    final d = await _plugin.getNotificationAppLaunchDetails();
    return d?.didNotificationLaunchApp == true ? d?.notificationResponse?.payload : null;
  }
}
