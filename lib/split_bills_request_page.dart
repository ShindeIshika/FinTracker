import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SplitBillRequestsPage extends StatelessWidget {
  const SplitBillRequestsPage({super.key});

  Future<void> _acceptRequest(DocumentSnapshot requestDoc) async {
    final data = requestDoc.data() as Map<String, dynamic>;
    final billId = data["billId"];
    final toUid = data["toUid"];

    final billRef =
        FirebaseFirestore.instance.collection("split_bills").doc(billId);

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final billSnap = await transaction.get(billRef);
      if (!billSnap.exists) {
        transaction.update(requestDoc.reference, {"status": "bill_deleted"});
        return;
      }

      final billData = billSnap.data() as Map<String, dynamic>;
      final currentUids = List<String>.from(billData["participantUids"] ?? []);

      if (!currentUids.contains(toUid)) {
        currentUids.add(toUid);
      }

      transaction.update(billRef, {
        "participantUids": currentUids,
        "updatedAt": Timestamp.now(),
      });

      transaction.update(requestDoc.reference, {
        "status": "accepted",
      });
    });
  }

  Future<void> _rejectRequest(DocumentSnapshot requestDoc) async {
    final data = requestDoc.data() as Map<String, dynamic>;
    final billId = data["billId"];
    final toUid = data["toUid"];

    final billRef =
        FirebaseFirestore.instance.collection("split_bills").doc(billId);

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final billSnap = await transaction.get(billRef);

      if (billSnap.exists) {
        final billData = billSnap.data() as Map<String, dynamic>;

        final participants = List<Map<String, dynamic>>.from(
          ((billData["participants"] ?? []) as List)
              .map((e) => Map<String, dynamic>.from(e)),
        );

        participants.removeWhere(
          (p) => (p["uid"] ?? "").toString() == toUid,
        );

        final participantUids =
            List<String>.from(billData["participantUids"] ?? []);
        participantUids.removeWhere((uid) => uid == toUid);

        final userSettlements =
            Map<String, dynamic>.from(billData["userSettlements"] ?? {});
        userSettlements.remove(toUid);

        transaction.update(billRef, {
          "participants": participants,
          "participantUids": participantUids,
          "userSettlements": userSettlements,
          "updatedAt": Timestamp.now(),
        });
      }

      transaction.update(requestDoc.reference, {
        "status": "rejected",
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text("User not logged in")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Split Bill Requests"),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("split_bill_requests")
            .where("toUid", isEqualTo: uid)
            .where("status", isEqualTo: "pending")
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(child: Text("No pending requests"));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;

              return Card(
                margin: const EdgeInsets.all(10),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: ListTile(
                    title: Text(data["billTitle"] ?? "Split Bill"),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Total ₹${data["total"] ?? 0}"),
                        if (data["participantName"] != null)
                          Text("Added as: ${data["participantName"]}"),
                      ],
                    ),
                    trailing: Wrap(
                      spacing: 8,
                      children: [
                        TextButton(
                          onPressed: () => _rejectRequest(docs[index]),
                          child: const Text("Reject"),
                        ),
                        ElevatedButton(
                          onPressed: () => _acceptRequest(docs[index]),
                          child: const Text("Accept"),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}