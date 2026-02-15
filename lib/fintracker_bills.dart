import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'widgets/side_nav.dart';
import 'package:flutter_fintracker/fintracker_splitbill.dart';
import 'package:flutter_fintracker/fintracker_budget.dart';
import 'package:flutter_fintracker/fintracker_home.dart';
import 'package:flutter_fintracker/fintracker_transaction.dart';

class BillsPage extends StatefulWidget {
  const BillsPage({super.key});

  @override
  State<BillsPage> createState() => _BillsPageState();
}

class _BillsPageState extends State<BillsPage> {
  final user = FirebaseAuth.instance.currentUser;
  int selectedNavIndex = 5;

  // 🎨 Your Premium Colors
  static const Color bgColor = Color(0xFFF1F5F9);
  static const Color primary = Color.fromARGB(255, 38, 15, 42);
  static const Color accent = Color.fromARGB(255, 13, 15, 104);
  static const Color danger = Color.fromARGB(255, 200, 31, 31);
  static const Color success = Color.fromARGB(255, 10, 104, 16);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SideNav(
            selectedIndex: selectedNavIndex,
            onItemTap: handleNavTap,
          ),

          /// MAIN CONTENT
          Expanded(
            child: StreamBuilder(
              stream: FirebaseFirestore.instance
                  .collection('bills')
                  .where('uid', isEqualTo: user!.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                      child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;
                final now = DateTime.now();

                int upcoming = 0;
                int overdue = 0;
                int pending = docs.length;

                for (var doc in docs) {
                  int dueDay = doc['dueDate'];
                  DateTime dueDate =
                      DateTime(now.year, now.month, dueDay);

                  if (dueDate.isBefore(now)) {
                    overdue++;
                  } else {
                    upcoming++;
                  }
                }

                return Padding(
                  padding: const EdgeInsets.all(28),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        /// HEADER
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  "Bills & Reminders",
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF083549),
                                  ),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  "Manage your bills and payment reminders",
                                  style: TextStyle(
                                      color: Colors.grey),
                                )
                              ],
                            ),
                            Row(
                              children: [
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: accent,
                                    shape:
                                        RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(
                                              14),
                                    ),
                                    padding:
                                        const EdgeInsets.all(
                                            14),
                                  ),
                                  onPressed: () {},
                                  child: const Icon(Icons.add,
                                      color: Colors.white),
                                ),
                                const SizedBox(width: 12),
                                IconButton(
                                  onPressed: () async {
                                    await FirebaseAuth
                                        .instance
                                        .signOut();
                                    Navigator.pushReplacementNamed(
                                        context, '/login');
                                  },
                                  icon: const Icon(Icons.logout,
                                      color: primary),
                                )
                              ],
                            )
                          ],
                        ),

                        const SizedBox(height: 32),

                        /// PREMIUM STAT CARDS
                        Row(
                          children: [
                            _buildStatCard(
                                "Total Upcoming",
                                upcoming.toString(),
                                accent),
                            const SizedBox(width: 18),
                            _buildStatCard(
                                "Overdue",
                                overdue.toString(),
                                danger),
                            const SizedBox(width: 18),
                            _buildStatCard(
                                "Pending",
                                pending.toString(),
                                primary),
                          ],
                        ),

                        const SizedBox(height: 42),

                        const Text(
                          "Your Bills",
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold),
                        ),

                        const SizedBox(height: 20),

                        ...docs.map((doc) =>
                            _buildBillCard(doc)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

   void handleNavTap(int index) {
  if (index == selectedNavIndex) return;

  setState(() {
    selectedNavIndex = index;
  });

  switch (index) {
    case 0: // Dashboard
      Navigator.pushReplacement(context, 
      MaterialPageRoute(builder: (_)=> const DashboardScreen()),
      );
      break;
    case 1: // Transactions
      Navigator.push(context, 
      MaterialPageRoute(builder: (_) => const TransactionsPage()),
      );
      break;
    case 2: // Budget
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const BudgetPlannerScreen()),
      );
      break;
    case 3: // Savings
      // Navigate to savings page if exists
      break;
    case 4: // Split Bills
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const SplitBillsScreen()),
      );
      break;
    case 5:
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const BillsPage()),
    );
  }
  }

  /// ================= PREMIUM GRADIENT STAT CARD =================

  Widget _buildStatCard(
      String title, String value, Color baseColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              baseColor.withOpacity(0.75),
              baseColor,
              baseColor.withOpacity(0.9),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: baseColor.withOpacity(0.35),
              blurRadius: 22,
              offset: const Offset(0, 12),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ================= BILL CARD =================

  Widget _buildBillCard(QueryDocumentSnapshot doc) {
    final data =
        doc.data() as Map<String, dynamic>;

    final now = DateTime.now();
    int dueDay = data['dueDate'];

    DateTime dueDate =
        DateTime(now.year, now.month, dueDay);

    bool isOverdue = dueDate.isBefore(now);

    String status =
        isOverdue ? "OVERDUE" : "UPCOMING";

    Color badgeColor =
        isOverdue ? danger : success;

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
            offset: Offset(0, 10),
          )
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.receipt_long,
                color: accent),
          ),
          const SizedBox(width: 22),

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
                          const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5),
                      decoration: BoxDecoration(
                        color: badgeColor,
                        borderRadius:
                            BorderRadius.circular(10),
                      ),
                      child: Text(
                        status,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight:
                                FontWeight.bold),
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  "₹${data['amount']}",
                  style: const TextStyle(
                      fontWeight: FontWeight.w600),
                ),
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
              IconButton(
                icon: const Icon(Icons.check_circle,
                    color: success),
                onPressed: () async {
                  await _markAsPaid(doc);
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

    await FirebaseFirestore.instance
        .collection('transactions')
        .add({
      'uid': user!.uid,
      'amount': data['amount'],
      'category': data['category'],
      'type': 'Expense',
      'createdAt': Timestamp.now(),
    });

    await FirebaseFirestore.instance
        .collection('bills')
        .doc(doc.id)
        .update({
      'lastPaidDate': Timestamp.now(),
    });
  }
}
