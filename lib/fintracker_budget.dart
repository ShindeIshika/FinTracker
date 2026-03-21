import 'package:flutter/material.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
import 'widgets/side_nav.dart';
import 'package:flutter_fintracker/fintracker_bills.dart';
import 'package:flutter_fintracker/fintracker_login.dart';
import 'package:flutter_fintracker/recurring_payments.dart';
import 'package:flutter_fintracker/previous_tips.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'category_service.dart';

String formatCategory(String text) {
  if (text.isEmpty) return text;
  return text[0].toUpperCase() + text.substring(1);
}

String normalizeCategory(String text) {
  return text.trim().toLowerCase();
}

final Map<String, IconData> categoryIcons = {
  'food & drinks': Icons.fastfood,
  'transport': Icons.directions_car,
  'shopping': Icons.shopping_bag,
  'entertainment': Icons.movie,
  'bills & utilities': Icons.receipt_long,
  'health & fitness': Icons.local_hospital,
  'others': Icons.category,
};

final Map<String, Color> categoryColors = {
  'food & drinks': Colors.orange,
  'transport': Colors.blue,
  'shopping': Colors.purple,
  'entertainment': Colors.redAccent,
  'bills & utilities': Colors.brown,
  'health & fitness': Colors.green,
  'others': Colors.grey,
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
    final screenWidth = MediaQuery.of(context).size.width;

    int crossAxisCount = 1;
    if (screenWidth >= 1000) {
      crossAxisCount = 3;
    } else if (screenWidth >= 650) {
      crossAxisCount = 2;
    } else {
      crossAxisCount = 1;
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF083549),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        title: const Text(
          "Budget Planner",
          style: TextStyle(
            fontSize: 24,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
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
      body: Container(
        padding: const EdgeInsets.all(16),
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
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
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
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('budgets')
                    .where('uid', isEqualTo: _auth.currentUser?.uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  final docs = snapshot.data!.docs;

                  if (docs.isEmpty) {
                    return const Center(
                      child: Text("No budget goals added"),
                    );
                  }

                  return Column(
                    children: [
                      Expanded(
                        child: GridView.builder(
                          itemCount: docs.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            childAspectRatio: screenWidth < 650 ? 1.6 : 1.25,
                          ),
                          itemBuilder: (context, index) {
                            final data =
                                docs[index].data() as Map<String, dynamic>;

                            final spent = (data['spent'] as num).toDouble();
                            final limit = (data['limit'] as num).toDouble();
                            final progress =
                                limit > 0 ? (spent / limit).clamp(0.0, 1.0) : 0.0;
                            final remaining = limit - spent;

                            Color progressColor;
                            if (progress >= 1) {
                              progressColor = Colors.red;
                            } else if (progress >= 0.75) {
                              progressColor = Colors.orange;
                            } else {
                              progressColor = Colors.blue;
                            }

                            final category =
                                (data['category'] as String).toLowerCase();

                            final icon =
                                categoryIcons[category] ?? Icons.category;
                            final iconColor =
                                categoryColors[category] ?? progressColor;

                            return Container(
                              padding: const EdgeInsets.all(14),
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
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      CircleAvatar(
                                        radius: 18,
                                        backgroundColor:
                                            iconColor.withOpacity(0.15),
                                        child: Icon(
                                          icon,
                                          size: 18,
                                          color: iconColor,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              formatCategory(data['category']),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              "${(progress * 100).toStringAsFixed(0)}% used",
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: progressColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        icon: const Icon(Icons.delete_outline),
                                        color:
                                            const Color.fromARGB(255, 173, 5, 5),
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
                                  const SizedBox(height: 12),
                                  Text(
                                    "₹${spent.toStringAsFixed(0)} / ₹${limit.toStringAsFixed(0)}",
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: LinearProgressIndicator(
                                      value: progress,
                                      minHeight: 8,
                                      backgroundColor:
                                          progressColor.withOpacity(0.2),
                                      color: progressColor,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
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
          width: double.infinity,
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
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 20,
            runSpacing: 14,
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
    return SizedBox(
      width: 120,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 4),
          Text(
            "₹${amount.toStringAsFixed(0)}",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

Future<void> addBudgetGoal() async {
  final limitController = TextEditingController();
  final categories = CategoryService.getAll();
  String? selectedCategory = categories.isNotEmpty ? categories.first : null;

  await showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text("Add Budget Goal"),

            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [

                // ✅ DROPDOWN
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  items: categories.map((cat) => DropdownMenuItem(
                    value: cat,
                    child: Text(cat),
                  )).toList(),
                  onChanged: (value) {
                    setStateDialog(() {
                      selectedCategory = value;
                    });
                  },
                  decoration: const InputDecoration(labelText: "Category"),
                ),

                const SizedBox(height: 10),

                // ✅ ADD CATEGORY BUTTON
                TextButton(
                  onPressed: () async {
                    final controller = TextEditingController();

                    await showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text("Add Category"),
                        content: TextField(
                          controller: controller,
                          decoration: const InputDecoration(
                            hintText: "Enter category",
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text("Cancel"),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              final added = CategoryService.addCategory(controller.text.trim());

                              if (!added) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Category already exists")),
                                );
                                return;
                              }

                              Navigator.pop(context);

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Category added to Expenses ✅"),
                                ),
                              );

                              // 🔥 refresh dropdown AND select the new category
                              setStateDialog(() {
                                selectedCategory = controller.text.trim();
                              });
                            },
                            child: const Text("Add"),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Text("Add Category"),
                ),

                const SizedBox(height: 10),

                // ✅ LIMIT INPUT
                TextField(
                  controller: limitController,
                  decoration:
                      const InputDecoration(labelText: "Limit (₹)"),
                  keyboardType: TextInputType.number,
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
                  final category = selectedCategory;
                  final limit = double.tryParse(limitController.text.trim()) ?? 0;

                  if (category == null || category.isEmpty || limit <= 0) return;

                  final normalizedCategory = category.toLowerCase();

                  final user = _auth.currentUser;
                  if (user == null) return;

                  final existing = await _firestore
                      .collection('budgets')
                      .where('uid', isEqualTo: user.uid)
                      .where('category', isEqualTo: normalizedCategory)
                      .get();

                  if (existing.docs.isNotEmpty) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Budget already exists for this category"),
                      ),
                    );
                    return;
                  }

                  await _firestore.collection('budgets').add({
                    'uid': user.uid,
                    'category': normalizedCategory,
                    'limit': limit,
                    'spent': 0.0,
                  });

                  Navigator.pop(context);
                },
                child: const Text("Add"),
              ),
            ],
          );
        },
      );
    },
  );
}
  void handleNavTap(int index) {
    if (index == selectedNavIndex) return;

    setState(() => selectedNavIndex = index);

    if (index == 0) {
      Navigator.pushReplacementNamed(context, '/dashboard');
    } else if (index == 1) {
      Navigator.pushReplacementNamed(context, '/transactions');
    } else if (index == 3) {
      Navigator.pushReplacementNamed(context, '/savings');
    } else if (index == 4) {
      Navigator.pushReplacementNamed(context, '/split');
    } else if (index == 5) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const BillsPage()),
      );
    }
  }
}