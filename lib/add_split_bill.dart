import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

const String kExpenseType = "expense";
const String kIncomeType = "income";
class AddSplitBillPage extends StatefulWidget {
  const AddSplitBillPage({super.key});

  @override
  State<AddSplitBillPage> createState() => _AddSplitBillPageState();
}

class _AddSplitBillPageState extends State<AddSplitBillPage> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;

  final TextEditingController titleController = TextEditingController();
  final TextEditingController totalController = TextEditingController();

String _displayNameFromData(Map<String, dynamic> data) {
  final name = (data["name"] ?? "").toString().trim();
  if (name.isNotEmpty) {
    return name.split(" ").first;
  }

  final username = (data["username"] ?? "").toString().trim();
  if (username.isNotEmpty) {
    return username.split("@").first;
  }

  final email = (data["email"] ?? "").toString().trim();
  if (email.isNotEmpty) {
    return email.split("@").first;
  }

  return "User";
}
  List<Map<String, dynamic>> participants = [];

  @override
  void initState() {
    super.initState();
    _addCreatorAsParticipant();
  }

  void _addCreatorAsParticipant() {
    final user = auth.currentUser;
    if (user == null) return;

    final alreadyExists = participants.any(
      (p) => (p["uid"] ?? "").toString() == user.uid,
    );

    if (!alreadyExists) {
      participants.add({
        "name": user.displayName ?? user.email ?? "You",
        "paid": 0.0,
        "uid": user.uid,
        "username": user.email ?? "",
        "email": user.email ?? "",
        "isuser": true,
      });
    }
  }

  Future<Map<String, dynamic>?> _findUserByUsernameOrEmail(String value) async {
    final q = value.trim();
    if (q.isEmpty) return null;

    final usersRef = firestore.collection("users");

    QuerySnapshot snap = await usersRef.where("username", isEqualTo: q).limit(1).get();
    if (snap.docs.isEmpty) {
      snap = await usersRef.where("email", isEqualTo: q).limit(1).get();
    }

    if (snap.docs.isEmpty) return null;

    final doc = snap.docs.first;
    final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);

    return {
  "uid": data["uid"] ?? doc.id,
  "name": _displayNameFromData(data),
  "username": data["username"] ?? "",
  "email": data["email"] ?? "",
};
  }

  Future<void> _showAddAppUserDialog() async {
    final controller = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) {
        bool loading = false;
        String? error;

        return StatefulBuilder(
          builder: (ctx, setInnerState) {
            return AlertDialog(
              title: const Text("Add App User"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      labelText: "Enter username or email",
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: loading
                      ? null
                      : () async {
                          setInnerState(() {
                            loading = true;
                            error = null;
                          });

                          final foundUser =
                              await _findUserByUsernameOrEmail(controller.text);

                          if (foundUser == null) {
                            setInnerState(() {
                              loading = false;
                              error = "User not found";
                            });
                            return;
                          }

                          final uid = foundUser["uid"].toString();

                          final alreadyExists = participants.any(
                            (p) => (p["uid"] ?? "").toString() == uid,
                          );

                          if (alreadyExists) {
                            setInnerState(() {
                              loading = false;
                              error = "User already added";
                            });
                            return;
                          }

                          setState(() {
                            participants.add({
                              "name": foundUser["name"],
                              "paid": 0.0,
                              "uid": uid,
                              "username": foundUser["username"],
                              "email": foundUser["email"],
                              "isuser": true,
                            });
                          });

                          if (mounted) Navigator.pop(ctx);
                        },
                  child: loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text("Add"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _addManualParticipant() {
    setState(() {
      participants.add({
        "name": "",
        "paid": 0.0,
        "isuser": false,
      });
    });
  }

  Future<void> saveBill() async {
    final user = auth.currentUser;
    if (user == null) return;

    final title = titleController.text.trim();
    final total = double.tryParse(totalController.text.trim());

    if (title.isEmpty || total == null || total <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter valid title and total")),
      );
      return;
    }

    if (participants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Add participants")),
      );
      return;
    }

    for (final p in participants) {
      if ((p["name"] ?? "").toString().trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Participant name cannot be empty")),
        );
        return;
      }
    }

    final creatorUid = user.uid;

    bool creatorExists = participants.any(
      (p) => (p["uid"] ?? "").toString() == creatorUid,
    );

    if (!creatorExists) {
      participants.insert(0, {
        "name": ((user.displayName ?? "").trim().isNotEmpty)
    ? user.displayName!.trim().split(" ").first
    : ((user.email ?? "").isNotEmpty
        ? user.email!.split("@").first
        : "You"),
        "paid": 0.0,
        "uid": creatorUid,
        "username": user.email ?? "",
        "email": user.email ?? "",
        "isuser": true,
      });
    }

    final billRef = await firestore.collection("split_bills").add({
      "title": title,
      "total": total,
      "createdBy": creatorUid,
      "uid": creatorUid, // backward compatibility
      "date": Timestamp.now(),
      "participants": participants,
      "participantUids": [creatorUid], // only creator sees first
      "userSettlements": {},
    });

    for (final p in participants) {
      if (p["isuser"] == true &&
          p["uid"] != null &&
          p["uid"].toString() != creatorUid) {
        await firestore.collection("split_bill_requests").add({
          "billId": billRef.id,
          "billTitle": title,
          "total": total,
          "fromUid": creatorUid,
          "toUid": p["uid"],
          "participantName": p["name"] ?? "User",
          "status": "pending",
          "date": Timestamp.now(),
        });
      }
    }

    final creatorParticipant = participants.firstWhere(
      (p) => (p["uid"] ?? "").toString() == creatorUid,
      orElse: () => {"paid": 0},
    );

    final creatorPaid = ((creatorParticipant["paid"] ?? 0) as num).toDouble();

    if (creatorPaid > 0) {
      await firestore.collection("transactions").add({
        "title": "$title - Split Bill",
        "amount": creatorPaid,
        "type": "expense",
        "category": title,
        "account": "Cash",
        "date": Timestamp.now(),
        "uid": creatorUid,
        "splitBillId": billRef.id,
      });
    }

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Add Split Bill"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: "Bill Title",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: totalController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: "Total Amount",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Participants",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            ...List.generate(participants.length, (index) {
              final participant = participants[index];
              final nameController =
                  TextEditingController(text: participant["name"] ?? "");
              final paidController = TextEditingController(
                text: (participant["paid"] ?? 0).toString(),
              );

              final bool isSelf =
                  (participant["uid"] ?? "").toString() == auth.currentUser!.uid;

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    children: [
                      TextField(
                        controller: nameController,
                        readOnly: participant["isuser"] == true,
                        decoration: InputDecoration(
                          labelText: participant["isuser"] == true
                              ? "Participant Name (App user)"
                              : "Participant Name",
                        ),
                        onChanged: (value) {
                          participant["name"] = value.trim();
                        },
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: paidController,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: "Amount Paid",
                        ),
                        onChanged: (value) {
                          participant["paid"] = double.tryParse(value.trim()) ?? 0;
                        },
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            participant["isuser"] == true
                                ? "App user"
                                : "Manual participant",
                          ),
                          if (!isSelf)
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  participants.removeAt(index);
                                });
                              },
                              child: const Text("Remove"),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _addManualParticipant,
                    icon: const Icon(Icons.person_add_alt_1),
                    label: const Text("Add Manual"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _showAddAppUserDialog,
                    icon: const Icon(Icons.person_search),
                    label: const Text("Add App User"),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: saveBill,
                child: const Text("Save Bill"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}