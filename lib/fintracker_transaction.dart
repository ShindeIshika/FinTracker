import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_fintracker/fintracker_budget.dart';
import 'package:flutter_fintracker/fintracker_savings.dart';
import 'package:flutter_fintracker/fintracker_splitbill.dart';
import 'package:flutter_fintracker/fintracker_bills.dart';
import 'widgets/side_nav.dart';
import 'previous_tips.dart';
import 'recurring_payments.dart';
import 'split_bills_request_page.dart';
import 'fintracker_login.dart';

class TransactionsPage extends StatefulWidget {
  const TransactionsPage({super.key});

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String searchQuery = '';
  String selectedType = 'All';

  // Transactions is index 1 in the nav
  int selectedNavIndex = 1;

  void handleNavTap(int index) {
    if (index == selectedNavIndex) {
      Navigator.pop(context); // close drawer
      return;
    }

    switch (index) {
      case 0:
        Navigator.pop(context); // go back to Dashboard
        break;
      case 1:
        Navigator.pop(context); // already here
        break;
      case 2:
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const BudgetPlannerScreen()));
        break;
      case 3:
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const SavingsPage()));
        break;
      case 4:
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const SplitBillPage()));
        break;
      case 5:
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const BillsPage()));
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("User not logged in")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF083549),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        title: const Text(
          "Transactions",
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
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
                    onPressed: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const SplitBillRequestsPage())),
                  ),
                  if (count > 0)
                    Positioned(
                      right: 8, top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                        constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                        child: Text("$count",
                            style: const TextStyle(color: Colors.white, fontSize: 10),
                            textAlign: TextAlign.center),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.repeat, color: Colors.white),
            tooltip: "Recurring Payments",
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const RecurringPaymentsPage())),
          ),
          IconButton(
            icon: const Icon(Icons.lightbulb, color: Colors.yellow),
            tooltip: "Finance Tips",
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const TipsPage())),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: "Logout",
            onPressed: _handleLogout,
          ),
        ],
      ),

      // ✅ Added Drawer with SideNav — mirrors DashboardScreen
      drawer: Drawer(
        child: SideNav(
          selectedIndex: selectedNavIndex,
          onItemTap: handleNavTap,
        ),
      ),

      body: Column(
        children: [
          _buildSearch(),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('transactions')
                  .where('uid', isEqualTo: user.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text("Error: ${snapshot.error}"));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("No Transactions Yet"));
                }

                final transactions = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final type = data['type'] ?? '';
                  final category = data['category'] ?? 'Uncategorized';

                  final matchesSearch = category
                      .toString()
                      .toLowerCase()
                      .contains(searchQuery);

                  final matchesType =
                      selectedType == 'All' || type == selectedType;

                  return matchesSearch && matchesType;
                }).toList();

                return ListView.builder(
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    final data =
                        transactions[index].data() as Map<String, dynamic>;

                    final amount = (data['amount'] ?? 0).toDouble();
                    final type = data['type'];
                    final category = data['category'] ?? 'Uncategorized';
                    final date = (data['date'] as Timestamp)
                        .toDate()
                        .toString()
                        .substring(0, 10);

                    return ListTile(
                      title: Text(category),
                      subtitle: Text(date),
                      trailing: Text(
                        type == 'income'
                            ? "+ ₹${amount.toStringAsFixed(2)}"
                            : "- ₹${amount.toStringAsFixed(2)}",
                        style: TextStyle(
                          color: type == 'income' ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

Future<void> _handleLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to log out?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF083549),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              "Logout",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (shouldLogout ?? false) {
      await FirebaseAuth.instance.signOut();
      if (!context.mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    }
  }
  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              onChanged: (value) {
                setState(() {
                  searchQuery = value.toLowerCase();
                });
              },
              decoration: const InputDecoration(
                hintText: "Search...",
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 10),
          DropdownButton<String>(
            value: selectedType,
            items: const [
              DropdownMenuItem(value: "All", child: Text("All")),
              DropdownMenuItem(value: "income", child: Text("Income")),
              DropdownMenuItem(value: "expense", child: Text("Expense")),
            ],
            onChanged: (value) {
              setState(() {
                selectedType = value!;
              });
            },
          ),
        ],
      ),
    );
  }
}