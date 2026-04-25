import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../widgets/side_nav.dart';
import 'package:flutter_fintracker/screens/splitbill/fintracker_splitbill.dart';
import 'package:flutter_fintracker/screens/budgets/fintracker_budget.dart';
import 'package:flutter_fintracker/screens/dashboard/fintracker_home.dart';
import 'package:flutter_fintracker/screens/transactions/fintracker_transaction.dart';
import 'add_bills.dart';
import '../auth/fintracker_login.dart';
import '../../previous_tips.dart';
import '../../recurring_payments.dart';
import '../splitbill/split_bills_request_page.dart';
import 'fintracker_allBills.dart';
import 'fintracker_overdue.dart';
// Add to fintracker_bills.dart

import '../../services/notification_service.dart';

class BillNotificationHelper {
  /// Call this after loading bills from Firestore.
  /// Pass the list of bill documents.
  static Future<void> scheduleBillNotifications(
    List<QueryDocumentSnapshot> docs,
  ) async {
    // Cancel existing bill notifications before rescheduling
    for (int i = 100; i < 200; i++) {
      await NotificationService.cancel(i);
    }

    int idCounter = 100;

    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final name = data['name'] ?? 'Bill';
      final amount = data['amount'] ?? '';
      final dueDate = (data['nextDueDate'] as Timestamp).toDate();
      final now = DateTime.now();
      final diff = dueDate.difference(now).inDays;

      // Already overdue → show immediately
      if (diff < 0) {
        await NotificationService.showImmediate(
          id: idCounter++,
          title: '🔴 Overdue Bill: $name',
          body: '₹$amount is overdue! Please pay immediately.',
          payload: 'bill_overdue_${doc.id}',
        );
      }

      // Due in 3 days → schedule reminder at 9 AM that day
      else if (diff <= 3) {
        final reminderDate = DateTime(
          dueDate.year,
          dueDate.month,
          dueDate.day,
          9,
          0,
        );

        if (reminderDate.isAfter(now)) {
          await NotificationService.scheduleNotification(
            id: idCounter++,
            title: '⚠️ Bill Due Soon: $name',
            body: '₹$amount is due in $diff day(s). Tap to review.',
            scheduledDate: reminderDate,
            payload: 'bill_due_${doc.id}',
          );
        }
      }
      // 7-day advance reminder
      else if (diff <= 7) {
        final sevenDayReminder = DateTime(
          dueDate.year,
          dueDate.month,
          dueDate.day - 7,
          9,
          0,
        );
        

        if (sevenDayReminder.isAfter(now)) {
          await NotificationService.scheduleNotification(
            id: idCounter++,
            title: '📅 Upcoming Bill: $name',
            body: '₹$amount is due on ${dueDate.day}/${dueDate.month}. Plan ahead!',
            scheduledDate: sevenDayReminder,
            payload: 'bill_upcoming_${doc.id}',
          );
        }
      }
    }
  }
}

class BillsPage extends StatefulWidget {
  const BillsPage({super.key});

  @override
  State<BillsPage> createState() => _BillsPageState();
}

class _BillsPageState extends State<BillsPage> {
  final user = FirebaseAuth.instance.currentUser;
  int selectedNavIndex = 5;
  bool _alertShown = false;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const Color bgColor = Color(0xFFF1F5F9);
  static const Color primary = Color.fromARGB(255, 38, 15, 42);
  static const Color accent = Color(0xFF083549);
  static const Color danger = Color.fromARGB(255, 200, 31, 31);
  static const Color success = Color.fromARGB(255, 10, 104, 16);
  static const Color warning = Color.fromARGB(255, 183, 103, 12);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF083549),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        title: const Text(
          "Bill Manager",
          style: TextStyle(
            fontSize: 24,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection("split_bill_requests")
                .where("toUid", isEqualTo: _auth.currentUser?.uid)
                .where("status", isEqualTo: "pending")
                .snapshots(),
            builder: (context, snapshot) {
              final count = snapshot.data?.docs.length ?? 0;

              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications, color: Colors.white),
                    tooltip: "Split Bill Requests",
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SplitBillRequestsPage(),
                        ),
                      );
                    },
                  ),
                  if (count > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        child: Text(
                          "$count",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.repeat, color: Colors.white),
            tooltip: "Recurring Payments",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const RecurringPaymentsPage(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.lightbulb, color: Colors.yellow),
            tooltip: "Finance Tips",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const TipsPage(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: "Logout",
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
              );
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: SideNav(
          selectedIndex: selectedNavIndex,
          onItemTap: handleNavTap,
        ),
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('bills')
            .where('uid', isEqualTo: user!.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs.toList()
            ..sort((a, b) {
              final aDue = (a['nextDueDate'] as Timestamp).toDate();
              final bDue = (b['nextDueDate'] as Timestamp).toDate();
              return aDue.compareTo(bDue);
            });
            WidgetsBinding.instance.addPostFrameCallback((_) {
  BillNotificationHelper.scheduleBillNotifications(docs);
});


          final now = DateTime.now();
          int upcoming = 0;
          int overdue = 0;

          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final due = (data['nextDueDate'] as Timestamp).toDate();
            final diff = due.difference(now).inDays;

            if (diff < 0) {
              overdue++;
            } else if (diff <= 3) {
              upcoming++;
            }
          }

          int total = docs.length;
          List<String> alerts = [];

          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final due = (data['nextDueDate'] as Timestamp).toDate();
            final diff = due.difference(DateTime.now()).inDays;

            if (diff < 0) {
              alerts.add("${data['name']} is OVERDUE!");
            } else if (diff <= 3) {
              alerts.add("${data['name']} is due in $diff day(s)");
            }
          }

          if (alerts.isNotEmpty && !_alertShown) {
            _alertShown = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(alerts.first),
                  backgroundColor: danger,
                  duration: const Duration(seconds: 4),
                ),
              );
            });
          }

          return Padding(
            padding: const EdgeInsets.all(28),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 6),
                          Text(
                            "Manage your recurring payments",
                            style: TextStyle(color: Colors.grey),
                          )
                        ],
                      ),
                      Row(
                        children: [
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accent,
                              padding: const EdgeInsets.all(14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const AddEditBillPage(),
                                ),
                              );
                            },
                            child: const Icon(Icons.add, color: Colors.white),
                          ),
                          const SizedBox(width: 12),
                        ],
                      )
                    ],
                  ),

                  const SizedBox(height: 20),

                  if (alerts.isNotEmpty)
                    Column(
                      children: alerts
                          .map((alert) => Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.warning,
                                        color: Colors.red),
                                    const SizedBox(width: 10),
                                    Expanded(child: Text(alert)),
                                  ],
                                ),
                              ))
                          .toList(),
                    ),

                  const SizedBox(height: 30),

                  /// ================= STAT CARDS =================
                  // In your build method, replace the stat cards Row with:
Row(
  children: [
    Expanded(
      child: _buildStatCard("Upcoming", upcoming.toString(), accent),
    ),
    const SizedBox(width: 10),
    Expanded(
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const OverdueBillsPage()),
        ),
        child: _buildStatCard("Overdue", overdue.toString(), danger),
      ),
    ),
    const SizedBox(width: 10),
    Expanded(
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AllBillsPage()),
        ),
        child: _buildStatCard("Total Bills", total.toString(), primary),
      ),
    ),
  ],
),                  const SizedBox(height: 40),

                  const Text(
                    "Bill Alerts",
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 20),

                  if (docs.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: Text(
                          "No bills added yet",
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ),

                  ...docs.map((doc) => _buildBillCard(doc)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void handleNavTap(int index) {
    if (index == selectedNavIndex) return;

    setState(() {
      selectedNavIndex = index;
    });

    switch (index) {
      case 0:
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => FintrackerHome()));
        break;
      case 1:
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const TransactionsPage()));
        break;
      case 2:
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (_) => const BudgetPlannerScreen()));
        break;
      case 4:
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const SplitBillPage()));
        break;
      case 5:
        break;
    }
  }

 Widget _buildStatCard(String title, String value, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16), // ← reduced from 24
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [color.withOpacity(0.75), color],
      ),
      borderRadius: BorderRadius.circular(16), // ← reduced from 24
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox( // ← this forces text to shrink if needed
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 4),
        FittedBox( // ← same here
          fit: BoxFit.scaleDown,
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
        ),
      ],
    ),
  );
}
  Widget _buildBillCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    final now = DateTime.now();
    final DateTime dueDate =
        (data['nextDueDate'] as Timestamp).toDate();

    final int difference = dueDate.difference(now).inDays;

    DateTime? lastPaid;

    if (data['lastPaidDate'] != null) {
      lastPaid = (data['lastPaidDate'] as Timestamp).toDate();
    }

    bool showBill = false;

    if (difference < 0) {
      showBill = true;
    } else if (difference <= 3) {
      showBill = true;
    } else if (lastPaid != null &&
        now.difference(lastPaid).inDays <= 2) {
      showBill = true;
    }

    if (!showBill) {
      return const SizedBox();
    }

    String status;
    Color badgeColor;

    if (lastPaid != null &&
        now.difference(lastPaid).inDays <= 2) {
      status = "PAID";
      badgeColor = success;
    } else if (difference < 0) {
      status = "OVERDUE";
      badgeColor = danger;
    } else if (difference <= 3) {
      status = "DUE SOON";
      badgeColor = warning;
    } else {
      status = "UPCOMING";
      badgeColor = primary;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
              blurRadius: 18,
              color: Colors.black12,
              offset: Offset(0, 10))
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      data['name'],
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: badgeColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        status,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold),
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 10),
                Text("₹${data['amount']}"),
                const SizedBox(height: 6),
                Text(
                  "Due: ${dueDate.day}/${dueDate.month}/${dueDate.year}",
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
          Column(
            children: [
              if (status != "PAID")
                IconButton(
                  icon: const Icon(Icons.check_circle, color: success),
                  onPressed: () async {
                    await _markAsPaid(doc);
                  },
                ),
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddEditBillPage(billDoc: doc),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: danger),
                onPressed: () async {
                  await FirebaseFirestore.instance
                      .collection('bills')
                      .doc(doc.id)
                      .delete();
                },
              ),
            ],
          )
        ],
      ),
    );
  }

  Future<void> _markAsPaid(QueryDocumentSnapshot doc) async {
  final data = doc.data() as Map<String, dynamic>;
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  // Load user accounts first
  final accountsSnap = await FirebaseFirestore.instance
      .collection('users')
      .doc(user!.uid)
      .collection('accounts')
      .get();

  final accounts = accountsSnap.docs.map((d) {
    return {
      'id': d.id,
      'name': d['name'],
      'type': d['type'],
      'balance': (d['balance'] as num).toDouble(),
    };
  }).toList();

  // If no accounts, fall back to old behaviour
  if (accounts.isEmpty) {
    await _markAsPaidWithAccount(doc, null, null);
    return;
  }

  // Show account picker bottom sheet
  if (!mounted) return;
  await showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Pay from which account?",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "₹${data['amount']} will be deducted from the selected account",
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 20),
            ...accounts.map((acc) {
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      const Color(0xFF083549).withOpacity(0.1),
                  child: Icon(
                    acc['type'] == 'Bank'
                        ? Icons.account_balance
                        : acc['type'] == 'Cash'
                            ? Icons.wallet
                            : Icons.phone_android,
                    color: const Color(0xFF083549),
                    size: 20,
                  ),
                ),
                title: Text(
                  acc['name'],
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  "₹${(acc['balance'] as double).toStringAsFixed(0)} available",
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  Navigator.pop(context);
                  await _markAsPaidWithAccount(
                    doc,
                    acc['id'],
                    acc['name'],
                  );
                },
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}
Future<void> _markAsPaidWithAccount(
  QueryDocumentSnapshot doc,
  String? accountId,
  String? accountName,
) async {
  final data = doc.data() as Map<String, dynamic>;
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  final now = DateTime.now();
  final nextDue = (data['nextDueDate'] as Timestamp).toDate();
  final int interval = data['interval'] ?? 1;
  final frequency = (data['frequency'] ?? '').toString().toLowerCase();

  // Calculate next due date
  DateTime updatedNextDue;
  if (frequency == 'monthly') {
    updatedNextDue = DateTime(
      nextDue.year,
      nextDue.month + interval,
      nextDue.day,
    );
  } else if (frequency == 'yearly') {
    updatedNextDue = DateTime(
      nextDue.year + interval,
      nextDue.month,
      nextDue.day,
    );
  } else {
    updatedNextDue = nextDue.add(Duration(days: 30 * interval));
  }

  final amount = (data['amount'] as num).toDouble();

  // Save transaction with account info
  await FirebaseFirestore.instance.collection('transactions').add({
    'uid': user.uid,
    'amount': amount,
    'category': data['name'] ?? 'Bill',
    'description': '${data['name']} bill payment',
    'accountId': accountId,
    'accountName': accountName ?? 'Cash',
    'type': 'expense',
    'date': Timestamp.fromDate(now),
    'createdAt': FieldValue.serverTimestamp(),
    'source': 'bill',
  });

  // Deduct from account balance if account selected
  if (accountId != null) {
    final accountRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('accounts')
        .doc(accountId);

    await FirebaseFirestore.instance.runTransaction((txn) async {
      final accountSnap = await txn.get(accountRef);
      if (!accountSnap.exists) return;

      final currentBalance =
          (accountSnap['balance'] as num).toDouble();
      txn.update(accountRef, {
        'balance': currentBalance - amount,
      });
    });
  }

  // Update bill dates
  await FirebaseFirestore.instance
      .collection('bills')
      .doc(doc.id)
      .update({
    'lastPaidDate': Timestamp.fromDate(now),
    'nextDueDate': Timestamp.fromDate(updatedNextDue),
  });

  if (!mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        accountName != null
            ? "Bill paid from $accountName ✓"
            : "Bill marked as paid ✓",
      ),
      backgroundColor: Colors.green,
    ),
  );
}
}