import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,   // 👈 iOS permissions
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(android: android, iOS: ios);
    await _plugin.initialize(settings);

    // 👇 Android 13+ requires explicit permission request
    await _plugin
        .resolvePlatformSpecificImplementation
            <AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  static Future<void> sendBudgetAlert({
    required String category,
    required double percent,
    required double remaining,
  }) async {
    String title;
    String body;

    if (percent >= 1.0) {
      title = "⚠️ Budget Exceeded: $category";
      body =
          "You've gone ₹${remaining.abs().toStringAsFixed(0)} over your $category budget!";
    } else {
      title = "🔔 Budget Alert: $category";
      body =
          "You've used ${(percent * 100).toStringAsFixed(0)}% of your $category budget. "
          "Only ₹${remaining.toStringAsFixed(0)} left.";
    }

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'budget_channel',
        'Budget Alerts',
        channelDescription: 'Alerts when budget limits are near or exceeded',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,            // 👈 ensure sound plays
        enableVibration: true,      // 👈 vibration
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,         // 👈 show banner even when app is open
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _plugin.show(
      category.hashCode.abs(), // 👈 .abs() to avoid negative IDs crashing Android
      title,
      body,
      details,
    );
  }
}