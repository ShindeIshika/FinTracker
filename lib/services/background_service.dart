import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:workmanager/workmanager.dart';

const taskName = "billCheckTask";

// This runs even when app is closed
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      // Must initialize Firebase in background isolate
      await Firebase.initializeApp();

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return Future.value(true);

      final notifications = FlutterLocalNotificationsPlugin();

      // Init notifications in background
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      await notifications.initialize(
        const InitializationSettings(android: androidSettings),
      );

      final now = DateTime.now();

      final snapshot = await FirebaseFirestore.instance
          .collection('bills')
          .where('uid', isEqualTo: user.uid)
          .get();

      int id = 200; // use different range from foreground notifications

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final name = data['name'] ?? 'Bill';
        final amount = data['amount'] ?? '';

        if (data['nextDueDate'] == null) continue;

        final dueDate = (data['nextDueDate'] as Timestamp).toDate();
        final diff = dueDate.difference(now).inDays;

        String? title;
        String? body;

        if (diff < 0) {
          title = '🔴 Overdue Bill: $name';
          body = '₹$amount is overdue! Please pay immediately.';
        } else if (diff <= 3) {
          title = '⚠️ Bill Due Soon: $name';
          body = '₹$amount is due in $diff day(s).';
        } else if (diff <= 7) {
          title = '📅 Upcoming Bill: $name';
          body = '₹$amount due on ${dueDate.day}/${dueDate.month}.';
        }

        if (title != null) {
          await notifications.show(
            id++,
            title,
            body,
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'bill_channel',
                'Bill Alerts',
                channelDescription: 'Alerts for upcoming and overdue bills',
                importance: Importance.high,
                priority: Priority.high,
              ),
            ),
          );
        }
      }
    } catch (e) {
      print("Background task error: $e");
    }

    return Future.value(true);
  });
}