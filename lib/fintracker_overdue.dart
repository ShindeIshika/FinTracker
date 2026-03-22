import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OverdueBillsPage extends StatelessWidget {
  const OverdueBillsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF083549),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          "Overdue Bills",
          style: TextStyle(color: Colors.white),
        ),
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('bills')
            .where('uid', isEqualTo: user!.uid)
            .snapshots(),
        builder: (context, snapshot) {

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text("No bills found"),
            );
          }

          final now = DateTime.now();

          /// 🔥 FILTER ONLY OVERDUE BILLS
          final overdueBills = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;

            if (data['nextDueDate'] == null) return false;

            final due = (data['nextDueDate'] as Timestamp).toDate();

            final today = DateTime(now.year, now.month, now.day);
            final dueDateOnly = DateTime(due.year, due.month, due.day);

            return dueDateOnly.isBefore(today);
          }).toList();

          if (overdueBills.isEmpty) {
            return const Center(
                child: Text(
                "No overdue bills 🎉",
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey,
                ),
                ),
            );
            }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: overdueBills.length,
            itemBuilder: (context, index) {

              final data =
                  overdueBills[index].data() as Map<String, dynamic>;

              final due =
                  (data['nextDueDate'] as Timestamp).toDate();

              final daysLate =
                  DateTime.now().difference(due).inDays;

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      blurRadius: 10,
                      color: Colors.black12,
                    )
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                data['name'],
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  "OVERDUE",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 6),

                          Text("₹${data['amount']}"),

                          const SizedBox(height: 4),

                          Text(
                            "Due: ${due.day}/${due.month}/${due.year}",
                            style: const TextStyle(color: Colors.grey),
                          ),

                          const SizedBox(height: 4),

                          Text(
                            "$daysLate day(s) overdue",
                            style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}