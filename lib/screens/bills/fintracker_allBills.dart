import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AllBillsPage extends StatelessWidget {
  const AllBillsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
            "All Bills",
            style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF083549),
        iconTheme: const IconThemeData(color: Colors.white), // 🔥 back arrow
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

        if (snapshot.hasError) {
            return Center(
            child: Text("Error: ${snapshot.error}"),
            );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
            child: Text("No bills found"),
            );
        }

        final docs = snapshot.data!.docs.toList()
            ..sort((a, b) {
                final aData = a.data() as Map<String, dynamic>;
                final bData = b.data() as Map<String, dynamic>;

                final aDue = aData['nextDueDate'] != null
                    ? (aData['nextDueDate'] as Timestamp).toDate()
                    : DateTime(2100);

                final bDue = bData['nextDueDate'] != null
                    ? (bData['nextDueDate'] as Timestamp).toDate()
                    : DateTime(2100);

                return aDue.compareTo(bDue);
            });

        return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;

            final due =
                (data['nextDueDate'] as Timestamp).toDate();

            return ListTile(
                title: Text(data['name']),
                subtitle: Text(
                    "₹${data['amount']} • Due: ${due.day}/${due.month}/${due.year}"),
            );
            },
        );
        }
      ),
    );
  }
}