import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SplitBillRequestsPage extends StatefulWidget {
  const SplitBillRequestsPage({super.key});

  @override
  State<SplitBillRequestsPage> createState() => _SplitBillRequestsPageState();
}

class _SplitBillRequestsPageState extends State<SplitBillRequestsPage> {
  String? processingId;

 Future<void> _acceptRequest(DocumentSnapshot requestDoc) async {
  try {
    final data = requestDoc.data() as Map<String, dynamic>;
    final String billId = (data["billId"] ?? "").toString();
    final String toUid = (data["toUid"] ?? "").toString();

    final billRef =
        FirebaseFirestore.instance.collection("split_bills").doc(billId);

    final batch = FirebaseFirestore.instance.batch();

    batch.update(billRef, {
      "participantUids": FieldValue.arrayUnion([toUid]),
      "updatedAt": Timestamp.now(),
    });

    batch.update(requestDoc.reference, {
      "status": "accepted",
      "updatedAt": Timestamp.now(),
    });

    await batch.commit();
  } catch (e) {
    rethrow;
  }
}

  Future<void> _rejectRequest(DocumentSnapshot requestDoc) async {
    try {
      setState(() {
        processingId = requestDoc.id;
      });

      final data = requestDoc.data() as Map<String, dynamic>;
      final String billId = (data["billId"] ?? "").toString();
      final String toUid = (data["toUid"] ?? "").toString();

      if (billId.isEmpty || toUid.isEmpty) {
        throw Exception("Invalid request data");
      }

      final billRef =
          FirebaseFirestore.instance.collection("split_bills").doc(billId);

      final billSnap = await billRef.get();

      final batch = FirebaseFirestore.instance.batch();

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

        batch.update(billRef, {
          "participants": participants,
          "participantUids": participantUids,
          "userSettlements": userSettlements,
          "updatedAt": Timestamp.now(),
        });
      }

      batch.update(requestDoc.reference, {
        "status": "rejected",
        "updatedAt": Timestamp.now(),
      });

      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Request rejected")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Reject failed: $e")),
      );
    } finally {
      if (mounted) {
        setState(() {
          processingId = null;
        });
      }
    }
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
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final bool isProcessing = processingId == doc.id;

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
                    trailing: isProcessing
                        ? const SizedBox(
                            height: 28,
                            width: 28,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Wrap(
                            spacing: 8,
                            children: [
                              TextButton(
                                onPressed: () => _rejectRequest(doc),
                                child: const Text("Reject"),
                              ),
                              ElevatedButton(
                                onPressed: () => _acceptRequest(doc),
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