import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

const String kExpenseType = "expense";
const String kIncomeType = "income";
const String kSplitBillCategory = "Split Bill";
const String kDefaultAccount = "Cash";

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

  // ADD these new variables:
final List<Map<String, dynamic>> billItems = [];
final TextEditingController itemNameController = TextEditingController();
final TextEditingController itemAmountController = TextEditingController();

// Computed total from items (or manual if no items)
double get _computedTotal {
  if (billItems.isEmpty) return double.tryParse(totalController.text.trim()) ?? 0;
  return billItems.fold(0.0, (sum, item) => sum + (item["amount"] as double));
}

  List<Map<String, dynamic>> participants = [];

  String _extractFirstName(Map<String, dynamic> data) {
    final firstName = (data["firstName"] ??
            data["firstname"] ??
            data["first_name"] ??
            "")
        .toString()
        .trim();
    if (firstName.isNotEmpty) return firstName;

    final name = (data["name"] ?? "").toString().trim();
    if (name.isNotEmpty) return name.split(" ").first;

    final username = (data["username"] ?? "").toString().trim();
    if (username.isNotEmpty) return username;

    final email = (data["email"] ?? "").toString().trim();
    if (email.isNotEmpty) return email.split("@").first;

    return "User";
  }

  String _displayNameFromData(Map<String, dynamic> data) {
    return _extractFirstName(data);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _addCreatorAsParticipant();
    });
  }

  Future<void> _addCreatorAsParticipant() async {
    final user = auth.currentUser;
    if (user == null) return;

    final alreadyExists = participants.any(
      (p) => (p["uid"] ?? "").toString() == user.uid,
    );
    if (alreadyExists) return;

    String firstName = "";
    String displayName = "You";
    String username = "";
    String email = user.email ?? "";

    try {
      DocumentSnapshot<Map<String, dynamic>> userDoc =
          await firestore.collection("users").doc(user.uid).get();

      if (!userDoc.exists && user.email != null) {
        final byEmail = await firestore
            .collection("users")
            .where("email", isEqualTo: user.email)
            .limit(1)
            .get();

        if (byEmail.docs.isNotEmpty) {
          userDoc = byEmail.docs.first;
        }
      }

      if (userDoc.exists) {
        final data = Map<String, dynamic>.from(userDoc.data() ?? {});
        firstName = (data["firstName"] ??
                data["firstname"] ??
                data["first_name"] ??
                "")
            .toString()
            .trim();
        displayName = _displayNameFromData(data);
        username = (data["username"] ?? "").toString();
        email = (data["email"] ?? user.email ?? "").toString();
      } else {
        displayName = ((user.displayName ?? "").trim().isNotEmpty)
            ? user.displayName!.trim().split(" ").first
            : ((user.email ?? "").isNotEmpty
                ? user.email!.split("@").first
                : "You");
        firstName = displayName;
        username = user.email ?? "";
      }
    } catch (_) {
      displayName = ((user.displayName ?? "").trim().isNotEmpty)
          ? user.displayName!.trim().split(" ").first
          : ((user.email ?? "").isNotEmpty
              ? user.email!.split("@").first
              : "You");
      firstName = displayName;
      username = user.email ?? "";
    }

    if (!mounted) return;

    setState(() {
      participants.add({
        "firstName": firstName,
        "name": displayName,
        "paid": 0.0,
        "uid": user.uid,
        "username": username,
        "email": email,
        "isuser": true,
      });
    });
  }

  Future<Map<String, dynamic>?> _findUserByUsernameOrEmail(String value) async {
    final q = value.trim();
    if (q.isEmpty) return null;

    final usersRef = firestore.collection("users");

    QuerySnapshot snap =
        await usersRef.where("username", isEqualTo: q).limit(1).get();

    if (snap.docs.isEmpty) {
      snap = await usersRef.where("email", isEqualTo: q).limit(1).get();
    }

    if (snap.docs.isEmpty) return null;

    final doc = snap.docs.first;
    final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);

    return {
      "uid": data["uid"] ?? doc.id,
      "firstName": (data["firstName"] ??
              data["firstname"] ??
              data["first_name"] ??
              "")
          .toString()
          .trim(),
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

                          if (!mounted) return;

                          setState(() {
                            participants.add({
                              "firstName": foundUser["firstName"] ?? "",
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

  Future<void> _createCreatorInitialTransaction({
    required String billId,
    required String title,
    required double amount,
    required String uid,
  }) async {
    if (amount <= 0) return;

    await firestore.collection("transactions").add({
      "title": "$title - Split Bill",
      "amount": amount,
      "type": kExpenseType,
      "category": kSplitBillCategory,
      "account": kDefaultAccount,
      "date": Timestamp.now(),
      "uid": uid,
      "splitBillId": billId,
      "transactionRole": "initial_payment",
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

    double paidSum = 0;
    for (final p in participants) {
      paidSum += ((p["paid"] ?? 0) as num).toDouble();
    }

    if ((paidSum - total).abs() > 0.01) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Total paid by participants must equal bill total. Now it is ₹${paidSum.toStringAsFixed(0)}",
          ),
        ),
      );
      return;
    }

    final creatorUid = user.uid;

    final creatorExists = participants.any(
      (p) => (p["uid"] ?? "").toString() == creatorUid,
    );

    if (!creatorExists) {
      participants.insert(0, {
        "firstName": ((user.displayName ?? "").trim().isNotEmpty)
            ? user.displayName!.trim().split(" ").first
            : ((user.email ?? "").isNotEmpty
                ? user.email!.split("@").first
                : "You"),
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
      "uid": creatorUid,
      "date": Timestamp.now(),
      "participants": participants,
      "participantUids": [creatorUid],
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

    await _createCreatorInitialTransaction(
      billId: billRef.id,
      title: title,
      amount: creatorPaid,
      uid: creatorUid,
    );

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  void dispose() {
    titleController.dispose();
    totalController.dispose();
    super.dispose();
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