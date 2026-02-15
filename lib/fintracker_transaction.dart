import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_fintracker/fintracker_bills.dart';
import 'widgets/side_nav.dart';
import 'add_transaction.dart';
import 'package:flutter_fintracker/fintracker_home.dart';
import 'package:flutter_fintracker/fintracker_budget.dart';
import 'package:flutter_fintracker/fintracker_splitbill.dart';
class TransactionsPage extends StatefulWidget {
  const TransactionsPage({super.key});

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  int selectedIndex = 1;

  String searchQuery = '';
String selectedType = 'All';
String selectedAccount = 'All';
String selectedCategory = 'All';
List<String> categoryList = ['All'];



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          /// SIDE NAV
         SideNav(
  selectedIndex: selectedIndex,
  onItemTap: (index) {
    if (index == selectedIndex) return;

    setState(() {
      selectedIndex = index;
    });

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
        //savings
        break;

      case 4:
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
        break;
    }
  },
),


          /// MAIN CONTENT
          Expanded(
            child: Column(
              children: [
                _buildTopBar(context),
                _buildSearchAndFilters(),

                /// TABLE SECTION
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        const SizedBox(height: 10),

                        /// TABLE HEADER
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          child: Row(
                            children: const [
                              Expanded(flex: 2, child: Text("Date", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                              Expanded(flex: 3, child: Text("Description", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                              Expanded(flex: 2, child: Text("Category", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                              Expanded(flex: 2, child: Text("Account", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                              Expanded(
                                flex: 2,
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: Text("Amount", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const Divider(height: 1),

                        /// FIRESTORE DATA
                        Expanded(
                          child: StreamBuilder<QuerySnapshot>(

                            stream: FirebaseFirestore.instance
                                .collection('transactions')
                                .where('uid',
                                    isEqualTo: FirebaseAuth
                                        .instance.currentUser!.uid)
                                //.orderBy('date', descending: true)
                                .snapshots(),
                            builder: (context, snapshot) {
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
final allTransactions = snapshot.data!.docs;
final categories = allTransactions
    .map((doc) =>
        (doc.data() as Map<String, dynamic>)['category']?.toString() ?? "Uncategorized")
    .toSet()
    .toList();


categoryList = ['All', ...categories];


final transactions = allTransactions.where((doc) {
  final data = doc.data() as Map<String, dynamic>;

  final type = data['type'];
  final account = data['account'] ?? "—";
final category = data['category'] ?? "Uncategorized";


  final matchesSearch =
      category.toString().toLowerCase().contains(searchQuery);

  final matchesType =
      selectedType == 'All' || type == selectedType;

  final matchesAccount =
      selectedAccount == 'All' || account == selectedAccount;

  final matchesCategory =
      selectedCategory == 'All' || category == selectedCategory;

  return matchesSearch &&
      matchesType &&
      matchesAccount &&
      matchesCategory;
}).toList();


                              return ListView.builder(
                                itemCount: transactions.length,
                                itemBuilder: (context, index) {
                                  final data =
                                      transactions[index].data()
                                          as Map<String, dynamic>;

                                  final amount = data['amount'];
                                  final type = data['type'];
                                  final category = data['category'];
                                  final account = data['account'];
                                  final date =
                                      (data['date'] as Timestamp)
                                          .toDate()
                                          .toString()
                                          .substring(0, 10);

                                  return Column(
                                    children: [
                                      Container(
                                        padding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 16,
                                                vertical: 14),
                                        child: Row(
                                          children: [

                                            /// DATE
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                date,
                                                style: const TextStyle(
                                                    fontSize: 13),
                                              ),
                                            ),

                                            /// DESCRIPTION
                                            Expanded(
                                              flex: 3,
                                              child: Text(
                                                category,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight:
                                                      FontWeight.w500,
                                                ),
                                              ),
                                            ),

                                            /// CATEGORY CHIP
                                            Expanded(
  flex: 2,
  child: Align(
    alignment: Alignment.centerLeft,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        category,
        style: const TextStyle(
          fontSize: 12,
          color: Colors.blue,
        ),
      ),
    ),
  ),
),


                                            /// ACCOUNT
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                account,
                                                style:
                                                    const TextStyle(
                                                  fontSize: 13,
                                                  color:
                                                      Colors.black54,
                                                ),
                                              ),
                                            ),

                                            /// AMOUNT
                                            Expanded(
                                              flex: 2,
                                              child: Align(
                                                alignment: Alignment
                                                    .centerRight,
                                                child: Text(
                                                  type == 'income'
                                                      ? "+ ₹$amount"
                                                      : "₹$amount",
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight:
                                                        FontWeight
                                                            .bold,
                                                    color:
                                                        type ==
                                                                'income'
                                                            ? Colors
                                                                .green
                                                            : Colors
                                                                .red,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      const Divider(height: 1),
                                    ],
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
          ),
        ],
      ),
    );
  }

  /// TOP BAR WITH BUTTONS
  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Text(
            'Transactions',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const Spacer(),

          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 2, 135, 7),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        const AddTransactionPage(type: 'income')),
              );
            },
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('Add Income',
                style: TextStyle(color: Colors.white)),
          ),

          const SizedBox(width: 10),

          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 194, 21, 9),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        const AddTransactionPage(type: 'expense')),
              );
            },
            icon: const Icon(Icons.remove, color: Colors.white),
            label: const Text('Add Expense',
                style: TextStyle(color: Colors.white)),
          ),

          const SizedBox(width: 20),

          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
    );
  }

  /// SEARCH + FILTERS
  Widget _buildSearchAndFilters() {
    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 280,
            child: TextField(
              onChanged: (value) {
    setState(() {
      searchQuery = value.toLowerCase();
    });
  },
              decoration: InputDecoration(
                hintText: 'Search transactions...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          DropdownButton<String>(
  value: selectedType,
  items: const [
    DropdownMenuItem(value: "All", child: Text("All Types")),
    DropdownMenuItem(value: "income", child: Text("Income")),
    DropdownMenuItem(value: "expense", child: Text("Expense")),
  ],
  onChanged: (value) {
    setState(() {
      selectedType = value!;
    });
  },
),

          const SizedBox(width: 10),

          DropdownButton<String>(
  value: selectedAccount,
  items: const [
    DropdownMenuItem(value: "All", child: Text("All Accounts")),
    DropdownMenuItem(value: "Cash", child: Text("Cash")),
    DropdownMenuItem(value: "Bank", child: Text("Bank")),
    DropdownMenuItem(value: "Online", child: Text("Online"))
  ],
  onChanged: (value) {
    setState(() {
      selectedAccount = value!;
    });
  },
),

const SizedBox(width: 10),

DropdownButton<String>(
  value: selectedCategory,
  items: categoryList.map((category) {
    return DropdownMenuItem(
      value: category,
      child: Text(
        category == 'All' ? 'All Categories' : category,
      ),
    );
  }).toList(),
  onChanged: (value) {
    setState(() {
      selectedCategory = value!;
    });
  },
),


        ],
      ),
    );
  }
}
