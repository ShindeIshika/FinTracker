import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'widgets/side_nav.dart';
import 'package:flutter_fintracker/fintracker_splitbill.dart';
import 'package:flutter_fintracker/fintracker_budget.dart';
import 'package:flutter_fintracker/fintracker_home.dart';
import 'package:flutter_fintracker/fintracker_transaction.dart';
import 'add_bills.dart';
import 'fintracker_login.dart';
import 'previous_tips.dart';
import 'recurring_payments.dart';
import 'split_bills_request_page.dart';

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
  static const Color accent = Color.fromARGB(255, 13, 15, 104);
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
          "Bills And Reminders",
          style: TextStyle(
            fontSize: 24,
            color:Colors.white,
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
          child:SideNav(
            selectedIndex: selectedNavIndex,
            onItemTap: handleNavTap,
          ),
      ),

          /// ================= MAIN CONTENT =================
        
            body: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('bills')
                  .where('uid', isEqualTo: user!.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                      child: CircularProgressIndicator());
                }
                

                /// 🔥 SORT BY NEXT DUE DATE
                final docs = snapshot.data!.docs.toList()
                  ..sort((a, b) {
                    final aDue =
                        (a['nextDueDate'] as Timestamp).toDate();
                    final bDue =
                        (b['nextDueDate'] as Timestamp).toDate();
                    return aDue.compareTo(bDue);
                  });

                final now = DateTime.now();
int upcoming = 0;
int overdue = 0;

for (var doc in docs) {
  final data = doc.data() as Map<String, dynamic>;
  final due =
      (data['nextDueDate'] as Timestamp).toDate();

  final diff =
      due.difference(now).inDays;

  if (diff < 0) {
    overdue++;
  } else if (diff <= 3) {
    upcoming++;
  }
}

                int total = docs.length;

                List<String> alerts = [];

                for (var doc in docs) {
  final data =
      doc.data() as Map<String, dynamic>;

  final due =
      (data['nextDueDate'] as Timestamp).toDate();

  final diff =
      due.difference(DateTime.now()).inDays;

  if (diff < 0) {
    alerts.add("${data['name']} is OVERDUE!");
  } else if (diff <= 3) {
    alerts.add(
        "${data['name']} is due in $diff day(s)");
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
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [

                        /// ================= HEADER =================
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            const Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                
                                SizedBox(height: 6),
                                Text(
                                  "Manage your recurring payments",
                                  style: TextStyle(
                                      color:
                                          Colors.grey),
                                )
                              ],
                            ),
                            Row(
                              children: [
                                ElevatedButton(
                                  style:
                                      ElevatedButton
                                          .styleFrom(
                                    backgroundColor:
                                        accent,
                                    padding:
                                        const EdgeInsets
                                            .all(14),
                                    shape:
                                        RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius
                                              .circular(
                                                  14),
                                    ),
                                  ),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const AddEditBillPage(),
                                      ),
                                    );
                                  },
                                  child: const Icon(
                                      Icons.add,
                                      color:
                                          Colors.white),
                                ),
                                const SizedBox(
                                    width: 12),
                              
                                
                              ],
                            )
                          ],
                        ),

                        const SizedBox(height: 20),

                        /// ================= ALERTS =================
                        if (alerts.isNotEmpty)
                          Column(
                            children: alerts
                                .map((alert) =>
                                    Container(
                                      margin:
                                          const EdgeInsets
                                              .only(
                                                  bottom:
                                                      10),
                                      padding:
                                          const EdgeInsets
                                              .all(14),
                                      decoration:
                                          BoxDecoration(
                                        color: Colors
                                            .red
                                            .shade50,
                                        borderRadius:
                                            BorderRadius
                                                .circular(
                                                    12),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                              Icons
                                                  .warning,
                                              color: Colors
                                                  .red),
                                          const SizedBox(
                                              width:
                                                  10),
                                          Expanded(
                                              child:
                                                  Text(
                                                      alert)),
                                        ],
                                      ),
                                    ))
                                .toList(),
                          ),

                        const SizedBox(height: 30),

                        /// ================= STAT CARDS =================
                        Row(
                          children: [
                            _buildStatCard(
                                "Upcoming",
                                upcoming.toString(),
                                accent),
                            const SizedBox(width: 18),
                            _buildStatCard(
                                "Overdue",
                                overdue.toString(),
                                danger),
                            const SizedBox(width: 18),
                            _buildStatCard(
                                "Total Bills",
                                total.toString(),
                                primary),
                          ],
                        ),

                        const SizedBox(height: 40),

                        const Text(
                          "Your Bills",
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight:
                                  FontWeight.bold),
                        ),

                        const SizedBox(height: 20),

                        if (docs.isEmpty)
                          const Center(
                              child: Padding(
                            padding:
                                EdgeInsets.all(40),
                            child: Text(
                              "No bills added yet",
                              style: TextStyle(
                                  color:
                                      Colors.grey),
                            ),
                          )),

                        ...docs.map(
                            (doc) =>
                                _buildBillCard(doc)),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
  }

  /// ================= NAVIGATION =================

  void handleNavTap(int index) {
    if (index == selectedNavIndex) return;

    setState(() {
      selectedNavIndex = index;
    });

    switch (index) {
      case 0:
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    const DashboardScreen()));
        break;
      case 1:
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    const TransactionsPage()));
        break;
      case 2:
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    const BudgetPlannerScreen()));
        break;
      case 4:
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    const SplitBillPage()));
        break;
      case 5:
        break;
    }
  }

  /// ================= STAT CARD =================

  Widget _buildStatCard(
      String title, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withOpacity(0.75),
              color,
            ],
          ),
          borderRadius:
              BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 28,
                fontWeight:
                    FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: const TextStyle(
                  color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  /// ================= BILL CARD =================

  Widget _buildBillCard(
      QueryDocumentSnapshot doc) {
    final data =
        doc.data() as Map<String, dynamic>;

   final now = DateTime.now();
final DateTime dueDate =
    (data['nextDueDate'] as Timestamp).toDate();

final int difference =
    dueDate.difference(now).inDays;

DateTime? lastPaid;

if (data['lastPaidDate'] != null) {
  lastPaid =
      (data['lastPaidDate'] as Timestamp).toDate();
}

/// -------- VISIBILITY LOGIC --------

bool showBill = false;

if (difference < 0) {
  // Overdue
  showBill = true;
} else if (difference <= 3) {
  // 3 days before due
  showBill = true;
} else if (lastPaid != null &&
    now.difference(lastPaid).inDays <= 2) {
  // show 2 days after payment
  showBill = true;
}

if (!showBill) {
  return const SizedBox(); // 🔥 Hide bill
}

/// -------- STATUS LOGIC --------

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
        borderRadius:
            BorderRadius.circular(24),
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
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      data['name'],
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight:
                              FontWeight.bold),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding:
                          const EdgeInsets
                              .symmetric(
                                  horizontal:
                                      10,
                                  vertical:
                                      5),
                      decoration:
                          BoxDecoration(
                        color: badgeColor,
                        borderRadius:
                            BorderRadius
                                .circular(
                                    10),
                      ),
                      child: Text(
                        status,
                        style:
                            const TextStyle(
                                color: Colors
                                    .white,
                                fontSize:
                                    11,
                                fontWeight:
                                    FontWeight
                                        .bold),
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 10),
                Text("₹${data['amount']}"),
                const SizedBox(height: 6),
                Text(
                  "Due: ${dueDate.day}/${dueDate.month}/${dueDate.year}",
                  style: const TextStyle(
                      color: Colors.grey),
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
                      builder: (_) =>
                          AddEditBillPage(
                              billDoc: doc),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete,
                    color: danger),
                onPressed: () async {
                  await FirebaseFirestore
                      .instance
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

  /// ================= MARK AS PAID =================

  Future<void> _markAsPaid(
      QueryDocumentSnapshot doc) async {
    final data =
        doc.data() as Map<String, dynamic>;

    final now = DateTime.now();
    final nextDue =
        (data['nextDueDate'] as Timestamp)
            .toDate();

    final int interval =
        data['interval'] ?? 1;

    final frequency =
        (data['frequency'] ?? '')
            .toString()
            .toLowerCase();

    DateTime updatedNextDue;

    if (frequency == 'monthly') {
      updatedNextDue = DateTime(
          nextDue.year,
          nextDue.month + interval,
          nextDue.day);
    } else if (frequency == 'yearly') {
      updatedNextDue = DateTime(
          nextDue.year + interval,
          nextDue.month,
          nextDue.day);
    } else {
      updatedNextDue =
          nextDue.add(Duration(
              days: 30 * interval));
    }

    await FirebaseFirestore.instance
    .collection('transactions')
    .add({
  'uid': user!.uid,
  'amount': data['amount'],
  'category': data['category'] ?? "Bill",
  'account': "Bank", // 👈 ADD THIS
  'type': 'expense', // 👈 keep lowercase consistent
  'date': Timestamp.fromDate(now),
  'createdAt': FieldValue.serverTimestamp(),
  'source': 'bill',
});


    await FirebaseFirestore.instance
        .collection('bills')
        .doc(doc.id)
        .update({
      'lastPaidDate':
          Timestamp.fromDate(now),
      'nextDueDate':
          Timestamp.fromDate(
              updatedNextDue),
    });
  }
}
