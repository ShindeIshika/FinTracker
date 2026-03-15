import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:flutter_fintracker/fintracker_home.dart';
import 'package:flutter_fintracker/fintracker_transaction.dart';
import 'package:flutter_fintracker/fintracker_budget.dart';
import 'package:flutter_fintracker/fintracker_bills.dart';
import 'package:flutter_fintracker/fintracker_splitbill.dart';
import 'package:flutter_fintracker/fintracker_login.dart';
import 'package:flutter_fintracker/previous_tips.dart';
import 'package:flutter_fintracker/recurring_payments.dart';
import 'widgets/side_nav.dart';
import  'split_bills_request_page.dart';

class SavingsPage extends StatefulWidget {
  const SavingsPage({super.key});

  @override
  State<SavingsPage> createState() => _SavingsPageState();
}

class _SavingsPageState extends State<SavingsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  int selectedNavIndex = 3;
  String firstName = "User";

  @override
  void initState() {
    super.initState();
    fetchUserName();
  }

  Future<void> fetchUserName() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (!mounted) return;

    if (doc.exists) {
      setState(() {
        firstName = doc['firstName'] ?? "User";
      });
    }
  }

  void handleNavTap(int index) {
    if (index == selectedNavIndex) return;

    switch (index) {
      case 0:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
        break;
      case 1:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const TransactionsPage()),
        );
        break;
      case 2:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const BudgetPlannerScreen()),
        );
        break;
      case 3:
        break;
      case 4:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const SplitBillPage()),
        );
        break;
      case 5:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const BillsPage()),
        );
        break;
    }
  }

  Stream<QuerySnapshot> getSavingsGoalsStream() {
    final user = _auth.currentUser;
    if (user == null) {
      return const Stream.empty();
    }

    return _firestore
        .collection('savings_goals')
        .where('uid', isEqualTo: user.uid)
        //.orderBy('createdAt', descending: false)
        .snapshots();
  }

  Future<void> addSavingsGoal() async {
    final titleController = TextEditingController();
    final targetController = TextEditingController();
    final savedController = TextEditingController();
    final estimatedController = TextEditingController();

    String selectedIcon = 'shield';

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Add Savings Goal"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: "Goal Title",
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: targetController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Target Amount",
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: savedController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Saved Amount",
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: estimatedController,
                      decoration: const InputDecoration(
                        labelText: "Estimated Completion (eg. March 2026)",
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      value: selectedIcon,
                      decoration: const InputDecoration(
                        labelText: "Icon",
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'shield',
                          child: Text('Shield'),
                        ),
                        DropdownMenuItem(
                          value: 'flight',
                          child: Text('Flight'),
                        ),
                        DropdownMenuItem(
                          value: 'home',
                          child: Text('Home'),
                        ),
                        DropdownMenuItem(
                          value: 'school',
                          child: Text('Education'),
                        ),
                        DropdownMenuItem(
                          value: 'car',
                          child: Text('Car'),
                        ),
                        DropdownMenuItem(
                          value: 'wallet',
                          child: Text('General'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            selectedIcon = value;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final user = _auth.currentUser;
                    if (user == null) return;

                    final title = titleController.text.trim();
                    final target =
                        double.tryParse(targetController.text.trim()) ?? 0;
                    final saved =
                        double.tryParse(savedController.text.trim()) ?? 0;
                    final estimated = estimatedController.text.trim();

                    if (title.isEmpty || target <= 0) return;

                    await _firestore.collection('savings_goals').add({
                      'uid': user.uid,
                      'title': title,
                      'targetAmount': target,
                      'savedAmount': saved,
                      'iconKey': selectedIcon,
                      'estimatedMonth':
                          estimated.isEmpty ? 'Not set' : estimated,
                      'createdAt': FieldValue.serverTimestamp(),
                      'updatedAt': FieldValue.serverTimestamp(),
                    });

                    if (mounted) Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D6EAA),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text("Add Goal"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> addContribution(
    String goalId,
    double currentSaved,
    double targetAmount,
  ) async {
    final amountController = TextEditingController();
    final noteController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Add Contribution"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Contribution Amount",
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(
                  labelText: "Note (optional)",
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                final amount =
                    double.tryParse(amountController.text.trim()) ?? 0;
                if (amount <= 0) return;

                final newSaved = currentSaved + amount;

                await _firestore.collection('savings_goals').doc(goalId).update({
                  'savedAmount': newSaved > targetAmount ? targetAmount : newSaved,
                  'updatedAt': FieldValue.serverTimestamp(),
                });

                await _firestore
                    .collection('savings_goals')
                    .doc(goalId)
                    .collection('contributions')
                    .add({
                  'amount': amount,
                  'note': noteController.text.trim(),
                  'date': FieldValue.serverTimestamp(),
                });

                if (mounted) Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D6EAA),
                foregroundColor: Colors.white,
              ),
              child: const Text("Add"),
            ),
          ],
        );
      },
    );
  }

  Future<void> deleteGoal(String goalId) async {
    await _firestore.collection('savings_goals').doc(goalId).delete();
  }

  IconData getGoalIcon(String iconKey) {
    switch (iconKey) {
      case 'shield':
        return Icons.shield_outlined;
      case 'flight':
        return Icons.flight_outlined;
      case 'home':
        return Icons.home_outlined;
      case 'school':
        return Icons.school_outlined;
      case 'car':
        return Icons.directions_car_outlined;
      case 'wallet':
        return Icons.account_balance_wallet_outlined;
      default:
        return Icons.savings_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF083549),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        title: const Text(
          "Savings Goals",
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
              if (!mounted) return;
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
          onItemTap: (index) {
            Navigator.pop(context);
            handleNavTap(index);
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: addSavingsGoal,
        backgroundColor: const Color(0xFF0D6EAA),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text("Add Goal"),
      ),
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF7FBFF), Color(0xFFEFF3F6)],
          ),
        ),
        child: StreamBuilder<QuerySnapshot>(
          stream: getSavingsGoalsStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return ListView(
                children: [
                  Text(
                    "Welcome, $firstName",
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.blueGrey,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildEmptyState(),
                ],
              );
            }

            final docs = snapshot.data!.docs;

            double totalTarget = 0;
            double totalSaved = 0;

            final goals = docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final target = (data['targetAmount'] as num).toDouble();
              final saved = (data['savedAmount'] as num).toDouble();

              totalTarget += target;
              totalSaved += saved;

              return {
                'id': doc.id,
                ...data,
              };
            }).toList();

            final overallProgress =
                totalTarget == 0 ? 0.0 : (totalSaved / totalTarget).clamp(0.0, 1.0);

            return ListView(
              children: [
                Text(
                  "Welcome, $firstName",
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.blueGrey,
                  ),
                ),
                const SizedBox(height: 18),

                _buildOverallProgressCard(
                  totalSaved: totalSaved,
                  totalTarget: totalTarget,
                  overallProgress: overallProgress,
                ),

                const SizedBox(height: 20),

                LayoutBuilder(
                  builder: (context, constraints) {
                    final isMobile = constraints.maxWidth < 700;

                    if (isMobile) {
                      return Column(
                        children: goals.map((goal) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _buildGoalCard(goal),
                          );
                        }).toList(),
                      );
                    }

                    return Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: goals.map((goal) {
                        return SizedBox(
                          width: (constraints.maxWidth - 16) / 2,
                          child: _buildGoalCard(goal),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 3),
          )
        ],
      ),
      child: const Column(
        children: [
          Icon(
            Icons.savings_outlined,
            size: 64,
            color: Color(0xFF0D6EAA),
          ),
          SizedBox(height: 12),
          Text(
            "No savings goals yet",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF083549),
            ),
          ),
          SizedBox(height: 8),
          Text(
            "Tap 'Add Goal' to start tracking your financial goals.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.blueGrey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverallProgressCard({
    required double totalSaved,
    required double totalTarget,
    required double overallProgress,
  }) {
    final percent = (overallProgress * 100).round();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 3),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.trending_up, size: 22, color: Colors.black87),
              SizedBox(width: 10),
              Text(
                "Overall Progress",
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF083549),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "₹${totalSaved.toStringAsFixed(0)}",
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "of ₹${totalTarget.toStringAsFixed(0)} saved",
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.blueGrey,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "$percent%",
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF0D6EAA),
                    ),
                  ),
                  const Text(
                    "Complete",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.blueGrey,
                    ),
                  ),
                ],
              )
            ],
          ),

          const SizedBox(height: 22),

          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: overallProgress,
              minHeight: 16,
              backgroundColor: const Color(0xFFD7E7F2),
              color: const Color(0xFF0D6EAA),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalCard(Map<String, dynamic> goal) {
    final goalId = goal['id'];
    final title = goal['title'] ?? 'Goal';
    final target = (goal['targetAmount'] as num).toDouble();
    final saved = (goal['savedAmount'] as num).toDouble();
    final estimatedMonth = goal['estimatedMonth'] ?? 'Not set';
    final iconKey = goal['iconKey'] ?? 'wallet';

    final progress = target == 0 ? 0.0 : (saved / target).clamp(0.0, 1.0);
    final percent = (progress * 100).round();
    final remaining = (target - saved).clamp(0, double.infinity);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 3),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: const Color(0xFFE6EEF3),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  getGoalIcon(iconKey),
                  color: const Color(0xFF0D6EAA),
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                    color: Colors.black,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => deleteGoal(goalId),
                icon: const Icon(Icons.delete_outline),
                color: Colors.red.shade400,
              ),
            ],
          ),

          const SizedBox(height: 20),

          Row(
            children: [
              SizedBox(
                width: 130,
                height: 130,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 120,
                      height: 120,
                      child: CircularProgressIndicator(
                        value: 1,
                        strokeWidth: 14,
                        backgroundColor: const Color(0xFFECEFF3),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFFECEFF3),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 120,
                      height: 120,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 14,
                        backgroundColor: Colors.transparent,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF0D6EAA),
                        ),
                      ),
                    ),
                    Text(
                      "$percent%",
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Saved",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blueGrey,
                      ),
                    ),
                    Text(
                      "₹${saved.toStringAsFixed(0)}",
                      style: const TextStyle(
                        fontSize: 22,
                        color: Colors.black,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "Target",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blueGrey,
                      ),
                    ),
                    Text(
                      "₹${target.toStringAsFixed(0)}",
                      style: const TextStyle(
                        fontSize: 22,
                        color: Colors.black,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 6),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Remaining",
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.blueGrey,
                ),
              ),
              Text(
                "₹${remaining.toStringAsFixed(0)}",
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF0D6EAA),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Est. Completion",
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.blueGrey,
                ),
              ),
              Text(
                estimatedMonth,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => addContribution(goalId, saved, target),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(color: Colors.grey.shade300),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                "Add Contribution",
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}