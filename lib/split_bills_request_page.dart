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
    setState(() => processingId = requestDoc.id);

    final data = requestDoc.data() as Map<String, dynamic>;
    final String billId = (data["billId"] ?? "").toString();
    final String toUid = (data["toUid"] ?? "").toString();

    // Only add user to participantUids — NO transaction here.
    // The transaction is created when they mark as paid from the detail sheet.
    await FirebaseFirestore.instance
        .collection("split_bills")
        .doc(billId)
        .update({
      "participantUids": FieldValue.arrayUnion([toUid]),
      "updatedAt": Timestamp.now(),
    });

    await requestDoc.reference.update({
      "status": "accepted",
      "updatedAt": Timestamp.now(),
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("Request accepted")));
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text("Accept failed: $e")));
  } finally {
    if (mounted) setState(() => processingId = null);
  }
}

Future<void> _rejectRequest(DocumentSnapshot requestDoc) async {
  try {
    setState(() => processingId = requestDoc.id);
    // Only update the request — don't touch the bill document
    await requestDoc.reference.update({
      "status": "rejected",
      "updatedAt": Timestamp.now(),
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("Request rejected")));
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text("Reject failed: $e")));
  } finally {
    if (mounted) setState(() => processingId = null);
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