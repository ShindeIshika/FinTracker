import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TransactionsPage extends StatefulWidget {
  const TransactionsPage({super.key});

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  String searchQuery = '';
  String selectedType = 'All';

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
        backgroundColor: const Color(0xFF083549), // ✅ background color
        iconTheme: const IconThemeData(color: Colors.white), // ✅ back arrow white
        elevation: 0,
        title: const Text(
          "Transactions",
          style: TextStyle(
            color: Colors.white, // ✅ white text
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      body: Column(
        children: [
          _buildSearch(),

          /// ✅ FIXED MAIN LIST (NO SCROLL CONFLICT)
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('transactions')
                  .where('uid', isEqualTo: user.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                /// 🔴 ERROR CHECK
                if (snapshot.hasError) {
                  return Center(
                      child: Text("Error: ${snapshot.error}"));
                }

                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator());
                }

                if (!snapshot.hasData ||
                    snapshot.data!.docs.isEmpty) {
                  return const Center(
                      child: Text("No Transactions Yet"));
                }

                final transactions = snapshot.data!.docs.where((doc) {
                  final data =
                      doc.data() as Map<String, dynamic>;

                  final type = data['type'] ?? '';
                  final category =
                      data['category'] ?? 'Uncategorized';

                  final matchesSearch = category
                      .toString()
                      .toLowerCase()
                      .contains(searchQuery);

                  final matchesType = selectedType == 'All' ||
                      type == selectedType;

                  return matchesSearch && matchesType;
                }).toList();

                return ListView.builder(
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    final data = transactions[index].data()
                        as Map<String, dynamic>;

                    final amount =
                        (data['amount'] ?? 0).toDouble();
                    final type = data['type'];
                    final category =
                        data['category'] ?? 'Uncategorized';

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
                            : "₹${amount.toStringAsFixed(2)}",
                        style: TextStyle(
                          color: type == 'income'
                              ? Colors.green
                              : Colors.red,
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

  /// 🔍 SEARCH BAR
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
              DropdownMenuItem(
                  value: "All", child: Text("All")),
              DropdownMenuItem(
                  value: "income", child: Text("Income")),
              DropdownMenuItem(
                  value: "expense", child: Text("Expense")),
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