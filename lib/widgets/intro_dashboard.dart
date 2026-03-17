import 'package:flutter/material.dart';

class EmptyDashboardIntro extends StatelessWidget {
  final VoidCallback onAddIncome;
  final VoidCallback onAddExpense;

  const EmptyDashboardIntro({
    super.key,
    required this.onAddIncome,
    required this.onAddExpensSe,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "👋 Welcome to FinTracker",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF083549),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            "Start by adding your first income or expense.\n"
            "Once you do, your dashboard will come alive with insights 📊",
            style: TextStyle(
              fontSize: 15,
              color: Colors.blueGrey,
            ),
          ),

          const SizedBox(height: 24),

          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onAddExpense,
                  icon: const Icon(Icons.remove_circle_outline),
                  label: const Text("Add Expense"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onAddIncome,
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text("Add Income"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          const Divider(),

          const SizedBox(height: 10),

          const Text(
            "✨ What you’ll see here soon",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF083549),
            ),
          ),
          const SizedBox(height: 8),
          const Text("• Spending breakdown by category"),
          const Text("• Monthly income vs expenses"),
          const Text("• Recent transaction history"),
        ],
      ),
    );
  }
}
