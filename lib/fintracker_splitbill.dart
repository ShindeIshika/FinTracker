import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_fintracker/fintracker_bills.dart';
import 'package:flutter_fintracker/fintracker_budget.dart';
import 'package:flutter_fintracker/fintracker_home.dart';
import 'package:flutter_fintracker/add_transaction.dart';
import 'package:flutter_fintracker/fintracker_login.dart';
import 'package:flutter_fintracker/fintracker_transaction.dart';
import 'widgets/side_nav.dart';
import 'package:flutter_fintracker/add_split_bill.dart';


class SplitBillsScreen extends StatefulWidget {
  const SplitBillsScreen({super.key});

  @override
  State<SplitBillsScreen> createState() => _SplitBillsScreenState();
}

class _SplitBillsScreenState extends State<SplitBillsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  int selectedNavIndex = 4; // Split Bills is index 4
  String firstName = "User";
  
  double youOwe = 10.0;
  double theyOwe = 25.0;
  
  List<Map<String, dynamic>> splitBills = [];

  @override
  void initState() {
    super.initState();
    fetchUserName();
    fetchSplitBills();
  }

  void handleNavTap(int index) {
    if (index == selectedNavIndex) return;

    setState(() {
      selectedNavIndex = index;
    });

    switch (index) {
      case 0: // Dashboard
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
        break;
      case 1: // Transaction
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const TransactionsPage()),
        );
        break;
      case 2: // Budget
         Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const BudgetPlannerScreen()),
        );
        break;
       case 4: // Split Bills
         Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const SplitBillsScreen()),
        );
        break;
        case 5: // Bills
         Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const BillsPage()),
        );
        break;

     
    }
  }

  Future<void> fetchUserName() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (doc.exists) {
      setState(() {
        firstName = doc['firstName'];
      });
    }
  }

  Future<void> fetchSplitBills() async {
    final user = _auth.currentUser;
    if (user == null) return;

    // For demo - replace with real Firestore 'split_bills' collection
    setState(() {
      splitBills = [
        {
          'id': '1',
          'title': 'Dinner restaurant',
          'total': 80.0,
          'date': Timestamp.now(),
          'participants': [
            {'name': 'Mia Chen', 'share': 30.0, 'paid': false},
            {'name': 'John', 'share': 25.0, 'paid': false},
            {'name': 'You', 'share': 25.0, 'paid': true},
          ]
        },
        {
          'id': '2',
          'title': 'Uber trip 20-10',
          'total': 60.0,
          'date': Timestamp.now(),
          'participants': [
            {'name': 'You', 'share': 20.0, 'paid': true},
            {'name': 'Sarah', 'share': 20.0, 'paid': false},
            {'name': 'Mike', 'share': 20.0, 'paid': false},
          ]
        }
      ];
      
      // Calculate balances
      youOwe = splitBills
          .expand((bill) => bill['participants'])
          .where((p) => p['name'] == 'You' && !p['paid'])
          .fold(0.0, (sum, p) => sum + (p['share'] as num).toDouble());
      theyOwe = splitBills
          .expand((bill) => bill['participants'])
          .where((p) => p['name'] != 'You' && !p['paid'])
          .fold(0.0, (sum, p) => sum + (p['share'] as num).toDouble());
    });
  }

  String formatDate(Timestamp date) {
    final d = date.toDate();
    return '${d.day}-${d.month}-${d.year}';
  }

  void settleBill(String billId) {
    // Update Firestore - mark as paid
    setState(() {
      fetchSplitBills();
    });
  }

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
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Split Bills",
                          style: TextStyle(
                            fontSize: 24,
                            color: Color(0xFF083549),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.logout),
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
                    Text(
                      "Welcome, $firstName",
                      style: const TextStyle(fontSize: 16, color: Colors.blueGrey),
                    ),
                    const SizedBox(height: 30),

                    // Balances Row
                    Row(
                      children: [
                        Expanded(
                          child: _balanceCard('You owe', youOwe, true),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _balanceCard('They owe', theyOwe, false),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),

                    // Split Bills List
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 6,
                            offset: Offset(0, 3),
                          )
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Split Bills & Track Payments",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF083549),
                            ),
                          ),
                          const SizedBox(height: 20),
                          ...splitBills.map((bill) => _billCard(bill, context)).toList(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddSplitBillPage(), // ← NEW SCREEN
            ),
          );
          if (result == true) {
            fetchSplitBills(); // Refresh list
          }
        },
        backgroundColor: const Color(0xFF1E3A8A), // Dark blue
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _balanceCard(String label, double amount, bool isOwe) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isOwe ? Colors.red.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOwe ? Colors.red.shade200 : Colors.green.shade200,
        ),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: isOwe ? Colors.red.shade700 : Colors.green.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '₹ ${amount.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isOwe ? Colors.red.shade700 : Colors.green.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _billCard(Map<String, dynamic> bill, BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                bill['title'],
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF083549),
                ),
              ),
              Text(
                formatDate(bill['date']),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Participants
          ...bill['participants'].map<Widget>((participant) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    participant['name'],
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF083549),
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        '₹ ${(participant['share'] as num).toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: participant['paid']
                              ? Colors.green.shade700
                              : Colors.red.shade700,
                        ),
                      ),
                      if (!participant['paid'])
                        Icon(
                          Icons.pending,
                          color: Colors.orange.shade600,
                          size: 16,
                        ),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
          
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total: ₹ ${bill['total'].toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF083549),
                ),
              ),
              ElevatedButton(
                onPressed: () => settleBill(bill['id']),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Paid'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
