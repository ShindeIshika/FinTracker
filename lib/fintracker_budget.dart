import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'widgets/side_nav.dart';


class BudgetPlannerScreen extends StatefulWidget {
  const BudgetPlannerScreen({super.key});

  @override
  State<BudgetPlannerScreen> createState() => _BudgetPlannerScreenState();
}

class _BudgetPlannerScreenState extends State<BudgetPlannerScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  int hoveredIndex = -1;
  int selectedNavIndex = 2;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          SideNav(
  selectedIndex: selectedNavIndex,
  onItemTap: handleNavTap,
),

          Expanded(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFF7FBFF), Color(0xFFEFF3F6)],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// HEADER
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Budget Planner",
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF083549),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: addBudgetGoal,
                        icon: const Icon(Icons.add),
                        label: const Text("Add Goal"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF026787),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  /// BUDGET GRID
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: _firestore
                          .collection('budgets')
                          .where('uid', isEqualTo: _auth.currentUser?.uid)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }

                        final docs = snapshot.data!.docs;
                        if (docs.isEmpty) {
                          return const Center(
                              child: Text("No budget goals added"));
                        }

                        return GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 20,
                            crossAxisSpacing: 20,
                            childAspectRatio: 1.6,
                          ),
                          itemCount: docs.length,
                          itemBuilder: (context, index) {
                            final data =
                                docs[index].data() as Map<String, dynamic>;

                            final spent =
                                (data['spent'] as num).toDouble();
                            final limit =
                                (data['limit'] as num).toDouble();
                            final progress =
                                (spent / limit).clamp(0.0, 1.0);
                            final remaining = limit - spent;

                            Color progressColor;
                            if (progress >= 1) {
                              progressColor = Colors.red;
                            } else if (progress >= 0.75) {
                              progressColor = Colors.orange;
                            } else {
                              progressColor = Colors.blue;
                            }

                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 12,
                                    offset: const Offset(0, 6),
                                  )
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  /// TOP ROW
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 22,
                                        backgroundColor:
                                            progressColor.withOpacity(0.15),
                                        child: Icon(
                                          Icons.account_balance_wallet,
                                          color: progressColor,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          data['category'],
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        "${(progress * 100).toStringAsFixed(0)}%",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: progressColor,
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 14),

                                  /// AMOUNT
                                  Text(
                                    "₹${spent.toStringAsFixed(0)} / ₹${limit.toStringAsFixed(0)}",
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),

                                  const SizedBox(height: 10),

                                  /// PROGRESS BAR
                                  LinearProgressIndicator(
                                    value: progress,
                                    minHeight: 7,
                                    backgroundColor:
                                        progressColor.withOpacity(0.2),
                                    color: progressColor,
                                    borderRadius: BorderRadius.circular(6),
                                  ),

                                  const SizedBox(height: 10),

                                  /// FOOTER TEXT
                                  Text(
                                    remaining >= 0
                                        ? "₹${remaining.toStringAsFixed(0)} left for this month"
                                        : "₹${remaining.abs().toStringAsFixed(0)} over budget",
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: remaining >= 0
                                          ? Colors.green
                                          : Colors.red,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// ADD BUDGET DIALOG
  Future<void> addBudgetGoal() async {
    final categoryController = TextEditingController();
    final limitController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Add Budget Goal"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: categoryController,
              decoration: const InputDecoration(labelText: "Category"),
            ),
            TextField(
              controller: limitController,
              decoration: const InputDecoration(labelText: "Limit (₹)"),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              final category = categoryController.text.trim();
              final limit =
                  double.tryParse(limitController.text.trim()) ?? 0;

              if (category.isEmpty || limit <= 0) return;

              final user = _auth.currentUser;
              if (user == null) return;

              await _firestore.collection('budgets').add({
                'uid': user.uid,
                'category': category,
                'limit': limit,
                'spent': 0.0,
              });

              Navigator.pop(context);
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  void handleNavTap(int index) {
    setState(() => selectedNavIndex = index);

    if (index == 0) {
      Navigator.pushReplacementNamed(context, '/dashboard');
    } else if (index == 1) {
      Navigator.pushReplacementNamed(context, '/transactions');
    } else if (index == 3) {
      Navigator.pushReplacementNamed(context, '/profile');
    }
  }

  /// SIDE NAV
  Widget buildSideNav({
    required int selectedIndex,
    required Function(int) onItemTap,
  }) {
    final navItems = [
      {'icon': Icons.dashboard, 'label': 'Dashboard'},
      {'icon': Icons.receipt_long, 'label': 'Transactions'},
      {'icon': Icons.pie_chart, 'label': 'Budget'},
      {'icon': Icons.person, 'label': 'Profile'},
    ];

    return Container(
      width: 220,
      color: const Color(0xFF083549),
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.account_balance_wallet,
                    color: Colors.white, size: 28),
                SizedBox(width: 10),
                Text(
                  'FinTracker',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          ...List.generate(navItems.length, (index) {
            final item = navItems[index];
            final isSelected = selectedIndex == index;

            return GestureDetector(
              onTap: () => onItemTap(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(item['icon'] as IconData,
                        color: isSelected
                            ? const Color(0xFF083549)
                            : Colors.white),
                    const SizedBox(width: 12),
                    Text(
                      item['label'] as String,
                      style: TextStyle(
                        color: isSelected
                            ? const Color(0xFF083549)
                            : Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
