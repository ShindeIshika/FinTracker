import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'widgets/side_nav.dart';

String formatCategory(String text) {
  if (text.isEmpty) return text;
  return text[0].toUpperCase() + text.substring(1);
}
String normalizeCategory(String text) {
  return text.trim().toLowerCase();
}


final Map<String, IconData> categoryIcons = {
  'food': Icons.fastfood,
  'transport': Icons.directions_car,
  'shopping': Icons.shopping_bag,
  'entertainment': Icons.movie,
  'health': Icons.local_hospital,
  'education': Icons.school,
  'bills': Icons.receipt_long,
  'gift':Icons.card_giftcard,
};

final Map<String, Color> categoryColors = {
  'food': Colors.orange,
  'transport': Colors.blue,
  'shopping': Colors.purple,
  'entertainment': Colors.redAccent,
  'health': Colors.green,
  'education': Colors.indigo,
  'bills': Colors.brown,
  'gift':Colors.pink
};


class BudgetPlannerScreen extends StatefulWidget {
  const BudgetPlannerScreen({super.key});

  @override
  State<BudgetPlannerScreen> createState() => _BudgetPlannerScreenState();
}

class _BudgetPlannerScreenState extends State<BudgetPlannerScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
              padding: const EdgeInsets.all(20),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Budget Planner",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF083549),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: addBudgetGoal,
                        icon: const Icon(Icons.add),
                        label: const Text("Add Goal"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF083549),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

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

                        return Column(
                          children: [
                            Expanded(
                              child: GridView.builder(
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  mainAxisSpacing: 16,
                                  crossAxisSpacing: 16,
                                  childAspectRatio: 1.2,
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

                                  final category = (data['category'] as String).toLowerCase();

                                  final icon = categoryIcons[category] ?? Icons.category;
                                  final iconColor = categoryColors[category] ?? progressColor;


                                  return Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Colors.black12,
                                          blurRadius: 8,
                                          offset: Offset(0, 4),
                                        )
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            CircleAvatar(
                                               radius: 18,
                                              backgroundColor: iconColor.withOpacity(0.15),
                                            child: Icon(
                                                icon,
                                                size: 18,
                                                color: iconColor,
                                              ),
                                             ),

                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                data['category'],
                                                style: const TextStyle(
                                                  fontSize: 14,
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
                                            IconButton(
  icon: const Icon(Icons.delete_outline),
  color: const Color.fromARGB(255, 173, 5, 5),
  tooltip: "Delete goal",
  onPressed: () async {
    await _firestore
        .collection('budgets')
        .doc(docs[index].id)
        .delete();
  },
),

                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          "₹${spent.toStringAsFixed(0)} / ₹${limit.toStringAsFixed(0)}",
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        LinearProgressIndicator(
                                          value: progress,
                                          minHeight: 6,
                                          backgroundColor:
                                              progressColor.withOpacity(0.2),
                                          color: progressColor,
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          remaining >= 0
                                              ? "₹${remaining.toStringAsFixed(0)} left"
                                              : "₹${remaining.abs().toStringAsFixed(0)} over budget",
                                          style: TextStyle(
                                            fontSize: 12,
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
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildBudgetSummaryCard(),
                          ],
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

  Widget _buildBudgetSummaryCard() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('budgets')
          .where('uid', isEqualTo: _auth.currentUser?.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();

        double totalLimit = 0;
        double totalSpent = 0;

        for (var doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          totalLimit += (data['limit'] as num).toDouble();
          totalSpent += (data['spent'] as num).toDouble();
        }

        final remaining = totalLimit - totalSpent;

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 10,
                offset: Offset(0, 4),
              )
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _summaryItem("Total Budget", totalLimit, Colors.blue),
              _summaryItem("Spent", totalSpent, Colors.red),
              _summaryItem("Remaining", remaining, Colors.green),
            ],
          ),
        );
      },
    );
  }

  Widget _summaryItem(String label, double amount, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 13, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(
          "₹${amount.toStringAsFixed(0)}",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

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
    final limit = double.tryParse(limitController.text.trim()) ?? 0;

    if (category.isEmpty || limit <= 0) return;

    final user = _auth.currentUser;
    if (user == null) return;

final categories = categoryController.text.trim().toLowerCase();

    // 🔍 CHECK IF BUDGET FOR THIS CATEGORY ALREADY EXISTS
    final existing = await _firestore
        .collection('budgets')
        .where('uid', isEqualTo: user.uid)
        .where('category', isEqualTo: categories)
        .get();

    if (existing.docs.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Budget already exists for this category"),
        ),
      );
      return; 
    }
 
    // ✅ ADD BUDGET
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
    if (index == selectedNavIndex) return;

    setState(() => selectedNavIndex = index);

    if (index == 0) {
      Navigator.pushReplacementNamed(context, '/dashboard');
    } else if (index == 1) {
      //Navigator.pushReplacementNamed(context, '/transactions');
    } else if (index == 3) {
      Navigator.pushReplacementNamed(context, '/profile');
    }
  }
}
