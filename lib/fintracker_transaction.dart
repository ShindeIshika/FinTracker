import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_fintracker/fintracker_bills.dart';
import 'package:flutter_fintracker/fintracker_savings.dart';
import 'widgets/side_nav.dart';
import 'add_transaction.dart';
import 'package:flutter_fintracker/fintracker_home.dart';
import 'package:flutter_fintracker/fintracker_budget.dart';
import 'package:flutter_fintracker/fintracker_splitbill.dart';
import 'package:flutter_fintracker/fintracker_login.dart';
import 'previous_tips.dart';
import 'recurring_payments.dart';
import 'split_bills_request_page.dart';


final FirebaseFirestore _firestore = FirebaseFirestore.instance;
final FirebaseAuth _auth = FirebaseAuth.instance;
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
      appBar: AppBar(
        backgroundColor: const Color(0xFF083549),
        iconTheme: const IconThemeData(color: Colors.white),
  elevation: 0,

        title: const Text(
          "Transactions",
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
          /// SIDE NAV
        child:  SideNav(
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
        Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const SavingsPage()),
      );
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
  },
),
      ),

          /// MAIN CONTENT
        
            body: Column(
              children: [
                _buildTopBar(context),
                _buildSearchAndFilters(),

                /// TABLE SECTION
                Expanded(
  child: Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 700),
        child: SizedBox(
          width: 700,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),

              /// TABLE HEADER
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: const [
                    Expanded(
                      flex: 2,
                      child: Text(
                        "Date",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        "Description",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        "Category",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        "Account",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          "Amount",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
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
                      .where(
                        'uid',
                        isEqualTo: FirebaseAuth.instance.currentUser!.uid,
                      )
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(
                        child: Text("No Transactions Yet"),
                      );
                    }

                    final allTransactions = snapshot.data!.docs;

                    final categories = allTransactions
                        .map((doc) =>
                            (doc.data() as Map<String, dynamic>)['category']
                                ?.toString() ??
                            "Uncategorized")
                        .toSet()
                        .toList();

                    categoryList = ['All', ...categories];

                    final transactions = allTransactions.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;

                      final type = data['type'];
                      final account = data['account'] ?? "—";
                      final category = data['category'] ?? "Uncategorized";

                      final matchesSearch = category
                          .toString()
                          .toLowerCase()
                          .contains(searchQuery);

                      final matchesType =
                          selectedType == 'All' || type == selectedType;

                      final matchesAccount = selectedAccount == 'All' ||
                          account == selectedAccount;

                      final matchesCategory = selectedCategory == 'All' ||
                          category == selectedCategory;

                      return matchesSearch &&
                          matchesType &&
                          matchesAccount &&
                          matchesCategory;
                    }).toList();

                    return ListView.builder(
                      itemCount: transactions.length,
                      itemBuilder: (context, index) {
                        final data =
                            transactions[index].data() as Map<String, dynamic>;

                        final amount = data['amount'];
                        final type = data['type'];
                        final category = data['category'] ?? "Uncategorized";
                        final account = data['account'] ?? "—";
                        final date = (data['date'] as Timestamp)
                            .toDate()
                            .toString()
                            .substring(0, 10);

                        return Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      date,
                                      style: const TextStyle(fontSize: 13),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),

                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      category,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),

                                  Expanded(
                                    flex: 2,
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          category,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.blue,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ),

                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      account,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Colors.black54,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),

                                  Expanded(
                                    flex: 2,
                                    child: Align(
                                      alignment: Alignment.centerRight,
                                      child: Text(
                                        type == 'income'
                                            ? "+ ₹$amount"
                                            : "₹$amount",
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: type == 'income'
                                              ? Colors.green
                                              : Colors.red,
                                        ),
                                        overflow: TextOverflow.ellipsis,
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
    ),
  ),
),           ],
            ),
          );
  }

  /// TOP BAR WITH BUTTONS
  Widget _buildTopBar(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(16),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 2, 135, 7),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AddTransactionPage(type: 'income'),
                ),
              );
            },
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text(
              'Add Income',
              style: TextStyle(color: Colors.white),
            ),
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
                  builder: (_) => const AddTransactionPage(type: 'expense'),
                ),
              );
            },
            icon: const Icon(Icons.remove, color: Colors.white),
            label: const Text(
              'Add Expense',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    ),
  );
}
  /// SEARCH + FILTERS
  Widget _buildSearchAndFilters() {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
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
    ),
  );
}
}