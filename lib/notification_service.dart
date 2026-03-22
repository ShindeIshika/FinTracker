import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final _notifications = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    const settings = InitializationSettings(android: android, iOS: ios);
    await _notifications.initialize(settings);
  }

  static Future<void> showBudgetAlert(String category, double percent) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'budget_alerts',
        'Budget Alerts',
        channelDescription: 'Alerts when budget limit is near',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );

    await _notifications.show(
      category.hashCode,
      '⚠️ Budget Alert: $category',
      'You have used ${percent.toStringAsFixed(0)}% of your budget!',
      details,
    );
  }
}