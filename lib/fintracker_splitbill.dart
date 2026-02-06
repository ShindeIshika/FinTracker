import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_fintracker/fintracker_home.dart';
import 'package:flutter_fintracker/fintracker_budget.dart';
import 'widgets/side_nav.dart';


class SplitBillsScreen extends StatefulWidget {
  const SplitBillsScreen({super.key});

  @override
  State<SplitBillsScreen> createState() => _SplitBillsScreenState();
}

class _SplitBillsScreenState extends State<SplitBillsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  int selectedNavIndex = 4; // Split Bills
  bool loading = true;
  List<Map<String, dynamic>> splits = [];

  @override
  void initState() {
    super.initState();
    fetchSplitBills();
  }

  Future<void> fetchSplitBills() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final snapshot = await _firestore
        .collection('SplitTheBill')
        .orderBy('createdAt', descending: true)
        .get();

    final List<Map<String, dynamic>> temp = [];
    for (var doc in snapshot.docs) {
      final data = doc.data();
      // Only include splits where current user is a participant
      final participants = List<Map<String, dynamic>>.from(data['participants'] ?? []);
      if (participants.any((p) => p['uid'] == user.uid) || data['uid'] == user.uid) {
        temp.add(data);
      }
    }

    setState(() {
      splits = temp;
      loading = false;
    });
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
      case 2:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const BudgetPlannerScreen()),
        );
        break;
      case 4:
        break; // Already here
    }

    setState(() {
      selectedNavIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          SideNav(selectedIndex: selectedNavIndex, onItemTap: handleNavTap),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(20),
              color: Colors.white, // ✅ White background
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Split Bills",
                            style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF083549)),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            "Split expenses with friends and track payments",
                            style: TextStyle(fontSize: 16, color: Colors.blueGrey),
                          ),
                          const SizedBox(height: 20),

                          // Split list
                          Column(
                            children: splits.map((split) {
                              return _splitCard(split);
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _splitCard(Map<String, dynamic> split) {
    final participants = List<Map<String, dynamic>>.from(split['participants'] ?? []);
    final isPaid = split['paid'] ?? false;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title & Your share
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                split['title'] ?? 'Untitled',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF083549)),
              ),
              Text(
                "Your share: \$${split['amount'] ?? 0}",
                style: TextStyle(
                  color: isPaid ? Colors.green : Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            "Created by ${split['name'] ?? 'Unknown'} on ${split['createdAt'] != null ? (split['createdAt'] as Timestamp).toDate().toLocal().toString().split(' ')[0] : 'Unknown'}",
            style: const TextStyle(color: Colors.blueGrey),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: participants.map((p) {
              return _participantTile(p);
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _participantTile(Map<String, dynamic> p) {
    final name = p['name'] ?? 'Unknown';
    final amount = p['amount'] ?? 0.0;
    final paid = p['paid'] ?? false;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: Colors.blue.shade200,
            child: Text(
              name[0].toUpperCase(),
              style: const TextStyle(fontSize: 12, color: Colors.white),
            ),
          ),
          const SizedBox(width: 8),
          Text(name),
          const SizedBox(width: 8),
          Text(
            "\$${amount.toStringAsFixed(2)}",
            style: TextStyle(
              color: paid ? Colors.green : Colors.orange,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            paid ? Icons.check_circle : Icons.hourglass_bottom,
            color: paid ? Colors.green : Colors.orange,
            size: 16,
          ),
        ],
      ),
    );
  }
}
