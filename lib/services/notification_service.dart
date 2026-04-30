import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:flutter/material.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const _androidChannel = AndroidNotificationChannel(
    'fintracker_channel',
    'FinTracker Alerts',
    description: 'Budget, bill, and savings alerts',
    importance: Importance.max,
    playSound: true,
  );

  static Future<void> scheduleSavingsReminder() async {
  await scheduleDailyReminder(
    id: 6001,
    title: "💰 Small savings, big progress",
    body: "Add a small amount to your savings goal today. Even ₹50 counts!",
    hour: 18,
    minute: 30,
    payload: "daily_savings_reminder",
  );
}

static Future<void> scheduleDailyReminder({
  required int id,
  required String title,
  required String body,
  required int hour,
  required int minute,
  String? payload,
}) async {
  final now = tz.TZDateTime.now(tz.local);

  var scheduledTime = tz.TZDateTime(
    tz.local,
    now.year,
    now.month,
    now.day,
    hour,
    minute,
  );

  if (scheduledTime.isBefore(now)) {
    scheduledTime = scheduledTime.add(const Duration(days: 1));
  }

  await _plugin.zonedSchedule(
    id,
    title,
    body,
    scheduledTime,
    NotificationDetails(
      android: AndroidNotificationDetails(
        _androidChannel.id,
        _androidChannel.name,
        channelDescription: _androidChannel.description,
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    ),
    payload: payload,
    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
    matchDateTimeComponents: DateTimeComponents.time,
  );
}

static Future<void> scheduleDailyExpenseReminders() async {
  await scheduleDailyReminder(
    id: 5001,
    title: "💰 Track your spending",
    body: "Don’t forget to add today’s income or expenses.",
    hour: 14,
    minute: 0,
    payload: "daily_tracker_afternoon",
  );

  await scheduleDailyReminder(
    id: 5002,
    title: "📊 Update FinTracker",
    body: "Quick reminder to record your transactions for the day.",
    hour: 19,
    minute: 0,
    payload: "daily_tracker_evening",
  );
}
  // ─── Initialize ───────────────────────────────────────────────
  static Future<void> init() async {
    tz_data.initializeTimeZones();

    // Android init
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS init
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Create high-importance channel (Android 8+)
    await _plugin
    .resolvePlatformSpecificImplementation<   // ← add < here
        AndroidFlutterLocalNotificationsPlugin>()
    ?.createNotificationChannel(_androidChannel);
  }

  static void _onNotificationTap(NotificationResponse response) {
    // Handle deep links here if needed
    debugPrint('Notification tapped: ${response.payload}');
  }

  // ─── Show immediate notification ──────────────────────────────
  static Future<void> showImmediate({
    required String title,
    required String body,
    int id = 0,
    String? payload,
  }) async {
    await _plugin.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: payload,
    );
  }

  // ─── Schedule a notification ───────────────────────────────────
  static Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    final tzDate = tz.TZDateTime.from(scheduledDate, tz.local);

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tzDate,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: payload,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // ─── Cancel a notification ─────────────────────────────────────
  static Future<void> cancel(int id) => _plugin.cancel(id);
  static Future<void> cancelAll() => _plugin.cancelAll();
}