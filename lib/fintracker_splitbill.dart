import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'add_split_bill.dart';
import 'fintracker_login.dart';
import 'fintracker_transaction.dart';
import 'widgets/side_nav.dart';
import 'previous_tips.dart';
import 'recurring_payments.dart';
import 'fintracker_home.dart';
import 'fintracker_budget.dart';
import 'fintracker_bills.dart';
import 'split_bills_request_page.dart';

const String kExpenseType = "expense";
const String kIncomeType = "income";
const String kSplitBillCategory = "Split Bill";
const String kDefaultAccount = "Cash";

class SplitBillPage extends StatefulWidget {
  const SplitBillPage({super.key});

  @override
  State<SplitBillPage> createState() => _SplitBillPageState();
}

class _SplitBillPageState extends State<SplitBillPage> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;

  int selectedIndex = 4;

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

  String _firstNameFromParticipant(Map<String, dynamic> p) {
    return _extractFirstName(p);
  }

  String _displayNameFromData(Map<String, dynamic> data) {
    return _extractFirstName(data);
  }

  String _money(double value) => "₹${value.toStringAsFixed(0)}";

  List<Map<String, dynamic>> _getParticipants(Map<String, dynamic> bill) {
    final raw = bill["participants"] ?? [];
    return List<Map<String, dynamic>>.from(
      (raw as List).map((e) => Map<String, dynamic>.from(e)),
    );
    }

  double _getTotal(Map<String, dynamic> bill) {
    return ((bill["total"] ?? 0) as num).toDouble();
  }

  double _sharePerPerson(Map<String, dynamic> bill) {
    final participants = _getParticipants(bill);
    if (participants.isEmpty) return 0;
    return _getTotal(bill) / participants.length;
  }

  double _getUserBalance(Map<String, dynamic> bill, String uid) {
    final participants = _getParticipants(bill);
    if (participants.isEmpty) return 0;

    final share = _sharePerPerson(bill);

    for (final p in participants) {
      if ((p["uid"] ?? "").toString() == uid) {
        final paid = ((p["paid"] ?? 0) as num).toDouble();
        return paid - share; // +ve receive, -ve owe
      }
    }
    return 0;
  }

  String? _getMySettlementStatus(Map<String, dynamic> bill) {
    final uid = auth.currentUser?.uid;
    if (uid == null) return null;

    final settlements = Map<String, dynamic>.from(bill["userSettlements"] ?? {});
    if (!settlements.containsKey(uid)) return null;

    final mine = Map<String, dynamic>.from(settlements[uid] ?? {});
    return mine["status"]?.toString();
  }

  List<String> calculateSettlements(Map<String, dynamic> bill) {
    final participants = _getParticipants(bill);
    final total = _getTotal(bill);

    if (participants.isEmpty) return [];

    final share = total / participants.length;

    final List<Map<String, dynamic>> creditors = [];
    final List<Map<String, dynamic>> debtors = [];

    for (final p in participants) {
      final paid = ((p["paid"] ?? 0) as num).toDouble();
      final balance = paid - share;
      final firstName = _firstNameFromParticipant(p);

      if (balance > 0.01) {
        creditors.add({
          "name": firstName,
          "amount": balance,
        });
      } else if (balance < -0.01) {
        debtors.add({
          "name": firstName,
          "amount": -balance,
        });
      }
    }

    final List<String> settlements = [];
    int i = 0;
    int j = 0;

    while (i < debtors.length && j < creditors.length) {
      final double pay = debtors[i]["amount"] < creditors[j]["amount"]
          ? debtors[i]["amount"]
          : creditors[j]["amount"];

      final debtorName = debtors[i]["name"].toString().trim();
      final creditorName = creditors[j]["name"].toString().trim();

      settlements.add("$debtorName owes $creditorName ${_money(pay)}");

      debtors[i]["amount"] -= pay;
      creditors[j]["amount"] -= pay;

      if (debtors[i]["amount"] <= 0.01) i++;
      if (creditors[j]["amount"] <= 0.01) j++;
    }

    return settlements;
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

  Future<void> _showAddAppUserDialog({
    required List<Map<String, dynamic>> editableParticipants,
    required void Function(void Function()) setDialogState,
  }) async {
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

                          final alreadyExists = editableParticipants.any(
                            (p) => (p["uid"] ?? "").toString() == uid,
                          );

                          if (alreadyExists) {
                            setInnerState(() {
                              loading = false;
                              error = "User already added";
                            });
                            return;
                          }

                          setDialogState(() {
                            editableParticipants.add({
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

  Future<void> _upsertCreatorInitialTransaction({
    required String billId,
    required String uid,
    required String title,
    required double creatorPaid,
  }) async {
    final existing = await firestore
        .collection("transactions")
        .where("splitBillId", isEqualTo: billId)
        .where("uid", isEqualTo: uid)
        .where("transactionRole", isEqualTo: "initial_payment")
        .limit(1)
        .get();

    if (creatorPaid <= 0) {
      for (final doc in existing.docs) {
        await doc.reference.delete();
      }
      return;
    }

    final txData = {
      "title": "$title - Split Bill",
      "amount": creatorPaid,
      "type": kExpenseType,
      "category": kSplitBillCategory,
      "account": kDefaultAccount,
      "date": Timestamp.now(),
      "uid": uid,
      "splitBillId": billId,
      "transactionRole": "initial_payment",
    };

    if (existing.docs.isEmpty) {
      await firestore.collection("transactions").add(txData);
    } else {
      await existing.docs.first.reference.update(txData);
    }
  }

  Future<void> _upsertSettlementTransaction({
    required String billId,
    required String uid,
    required String title,
    required double amount,
    required String action,
  }) async {
    final existing = await firestore
        .collection("transactions")
        .where("splitBillId", isEqualTo: billId)
        .where("uid", isEqualTo: uid)
        .where("transactionRole", isEqualTo: "settlement")
        .limit(1)
        .get();

    final txData = {
      "title": "$title - Settlement",
      "amount": amount,
      "type": action == "paid" ? kExpenseType : kIncomeType,
      "category": kSplitBillCategory,
      "account": kDefaultAccount,
      "date": Timestamp.now(),
      "uid": uid,
      "splitBillId": billId,
      "transactionRole": "settlement",
      "settlementAction": action,
    };

    if (existing.docs.isEmpty) {
      await firestore.collection("transactions").add(txData);
    } else {
      await existing.docs.first.reference.update(txData);
    }
  }

  Future<void> _markSettlement({
    required Map<String, dynamic> bill,
    required String billId,
    required String action,
  }) async {
    final user = auth.currentUser;
    if (user == null) return;

    final balance = _getUserBalance(bill, user.uid);

    double amount = 0;
    if (action == "paid") {
      amount = balance < 0 ? -balance : 0;
    } else {
      amount = balance > 0 ? balance : 0;
    }

    if (amount <= 0) return;

    final Map<String, dynamic> settlements =
        Map<String, dynamic>.from(bill["userSettlements"] ?? {});

    final Map<String, dynamic> existing =
        Map<String, dynamic>.from(settlements[user.uid] ?? {});

    if (existing["status"] == action) {
      return;
    }

    settlements[user.uid] = {
      "status": action,
      "amount": amount,
      "updatedAt": Timestamp.now(),
    };

    await firestore.collection("split_bills").doc(billId).update({
      "userSettlements": settlements,
    });

    await _upsertSettlementTransaction(
      billId: billId,
      uid: user.uid,
      title: (bill["title"] ?? "Split Bill").toString(),
      amount: amount,
      action: action,
    );
  }

  Future<void> showSettlementDialog(
    BuildContext context,
    Map<String, dynamic> bill,
    String billId,
    String action,
  ) async {
    final user = auth.currentUser;
    if (user == null) return;

    final balance = _getUserBalance(bill, user.uid);

    double amount = 0;
    if (action == "paid") {
      amount = balance < 0 ? -balance : 0;
    } else {
      amount = balance > 0 ? balance : 0;
    }

    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            action == "paid"
                ? "You do not owe anything in this bill."
                : "No one owes you anything in this bill.",
          ),
        ),
      );
      return;
    }

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(action == "paid" ? "Mark as Paid" : "Mark as Received"),
        content: Text(
          action == "paid"
              ? "Amount: ${_money(amount)}\nThis will be added to transactions as expense."
              : "Amount: ${_money(amount)}\nThis will be added to transactions as income.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              await _markSettlement(
                bill: bill,
                billId: billId,
                action: action,
              );
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text("Confirm"),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteBill(
    String billId,
    DocumentReference billRef,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Bill"),
        content: const Text("Are you sure you want to delete this bill?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      await deleteBillWithRequests(billId, billRef);
    }
  }

  Future<void> _updateBillAndRequests({
    required DocumentSnapshot doc,
    required Map<String, dynamic> oldBill,
    required String title,
    required double total,
    required List<Map<String, dynamic>> newParticipants,
  }) async {
    final currentUid = auth.currentUser!.uid;
    final billId = doc.id;

    final oldParticipants = _getParticipants(oldBill);
    final oldParticipantUids =
        List<String>.from(oldBill["participantUids"] ?? []);
    final oldSettlements =
        Map<String, dynamic>.from(oldBill["userSettlements"] ?? {});

    final oldAppUserUids = oldParticipants
        .where((p) => p["isuser"] == true && p["uid"] != null)
        .map((p) => p["uid"].toString())
        .toSet();

    final newAppUserUids = newParticipants
        .where((p) => p["isuser"] == true && p["uid"] != null)
        .map((p) => p["uid"].toString())
        .toSet();

    final removedUids = oldAppUserUids.difference(newAppUserUids);
    final addedUids = newAppUserUids.difference(oldAppUserUids);

    final acceptedParticipantUids = <String>{currentUid};

    for (final uid in newAppUserUids) {
      if (uid == currentUid) {
        acceptedParticipantUids.add(uid);
      } else if (oldParticipantUids.contains(uid)) {
        acceptedParticipantUids.add(uid);
      }
    }

    for (final uid in removedUids) {
      oldSettlements.remove(uid);
    }

    await doc.reference.update({
      "title": title,
      "total": total,
      "participants": newParticipants,
      "participantUids": acceptedParticipantUids.toList(),
      "userSettlements": oldSettlements,
      "updatedAt": Timestamp.now(),
    });

    for (final uid in removedUids) {
      final reqs = await firestore
          .collection("split_bill_requests")
          .where("billId", isEqualTo: billId)
          .where("toUid", isEqualTo: uid)
          .get();

      for (final r in reqs.docs) {
        await r.reference.delete();
      }

      final removedSettlementTx = await firestore
          .collection("transactions")
          .where("splitBillId", isEqualTo: billId)
          .where("uid", isEqualTo: uid)
          .where("transactionRole", isEqualTo: "settlement")
          .get();

      for (final tx in removedSettlementTx.docs) {
        await tx.reference.delete();
      }
    }

    for (final uid in addedUids) {
      if (uid == currentUid) continue;

      final existing = await firestore
          .collection("split_bill_requests")
          .where("billId", isEqualTo: billId)
          .where("toUid", isEqualTo: uid)
          .limit(1)
          .get();

      final participant = newParticipants.firstWhere(
        (p) => (p["uid"] ?? "").toString() == uid,
        orElse: () => <String, dynamic>{},
      );

      if (existing.docs.isEmpty) {
        await firestore.collection("split_bill_requests").add({
          "billId": billId,
          "billTitle": title,
          "total": total,
          "fromUid": currentUid,
          "toUid": uid,
          "participantName": participant["name"] ?? "User",
          "status": "pending",
          "date": Timestamp.now(),
        });
      } else {
        await existing.docs.first.reference.update({
          "billTitle": title,
          "total": total,
          "participantName": participant["name"] ?? "User",
          "status": "pending",
          "date": Timestamp.now(),
        });
      }
    }

    final existingRequests = await firestore
        .collection("split_bill_requests")
        .where("billId", isEqualTo: billId)
        .get();

    for (final req in existingRequests.docs) {
      final data = req.data();
      final toUid = (data["toUid"] ?? "").toString();

      if (newAppUserUids.contains(toUid)) {
        final participant = newParticipants.firstWhere(
          (p) => (p["uid"] ?? "").toString() == toUid,
          orElse: () => <String, dynamic>{},
        );

        await req.reference.update({
          "billTitle": title,
          "total": total,
          "participantName": participant["name"] ?? "User",
        });
      }
    }

    final creatorParticipant = newParticipants.firstWhere(
      (p) => (p["uid"] ?? "").toString() == currentUid,
      orElse: () => {"paid": 0},
    );

    final creatorPaid = ((creatorParticipant["paid"] ?? 0) as num).toDouble();

    await _upsertCreatorInitialTransaction(
      billId: billId,
      uid: currentUid,
      title: title,
      creatorPaid: creatorPaid,
    );
  }

  Future<void> showEditBillDialog(
    BuildContext context,
    DocumentSnapshot doc,
    Map<String, dynamic> bill,
  ) async {
    final titleController = TextEditingController(text: bill["title"] ?? "");
    final totalController =
        TextEditingController(text: (bill["total"] ?? "").toString());

    final List<Map<String, dynamic>> editableParticipants = _getParticipants(bill);

    await showDialog(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Edit Bill"),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: titleController,
                        decoration: const InputDecoration(labelText: "Title"),
                      ),
                      TextField(
                        controller: totalController,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: "Total"),
                      ),
                      const SizedBox(height: 12),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Participants",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...List.generate(editableParticipants.length, (index) {
                        final participant = editableParticipants[index];
                        final nameController = TextEditingController(
                          text: participant["name"] ?? "",
                        );
                        final paidController = TextEditingController(
                          text: (participant["paid"] ?? 0).toString(),
                        );

                        final bool isSelf =
                            (participant["uid"] ?? "").toString() ==
                                auth.currentUser!.uid;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(8),
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
                                TextField(
                                  controller: paidController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  decoration: const InputDecoration(
                                    labelText: "Amount Paid",
                                  ),
                                  onChanged: (value) {
                                    participant["paid"] =
                                        double.tryParse(value.trim()) ?? 0;
                                  },
                                ),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      participant["isuser"] == true
                                          ? "App user"
                                          : "Manual participant",
                                    ),
                                    if (!isSelf)
                                      TextButton(
                                        onPressed: () {
                                          setDialogState(() {
                                            editableParticipants.removeAt(index);
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
                            child: TextButton.icon(
                              onPressed: () {
                                setDialogState(() {
                                  editableParticipants.add({
                                    "name": "",
                                    "paid": 0.0,
                                    "isuser": false,
                                  });
                                });
                              },
                              icon: const Icon(Icons.person_add_alt_1),
                              label: const Text("Manual"),
                            ),
                          ),
                          Expanded(
                            child: TextButton.icon(
                              onPressed: () async {
                                await _showAddAppUserDialog(
                                  editableParticipants: editableParticipants,
                                  setDialogState: setDialogState,
                                );
                              },
                              icon: const Icon(Icons.person_search),
                              label: const Text("App User"),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final total = double.tryParse(totalController.text.trim());

                    if (titleController.text.trim().isEmpty || total == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Enter valid title and total"),
                        ),
                      );
                      return;
                    }

                    if (editableParticipants.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Add at least one participant"),
                        ),
                      );
                      return;
                    }

                    for (final p in editableParticipants) {
                      if ((p["name"] ?? "").toString().trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Participant name cannot be empty"),
                          ),
                        );
                        return;
                      }
                    }

                    await _updateBillAndRequests(
                      doc: doc,
                      oldBill: bill,
                      title: titleController.text.trim(),
                      total: total,
                      newParticipants: editableParticipants,
                    );

                    if (!mounted) return;
                    Navigator.pop(context);
                  },
                  child: const Text("Save"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> deleteBillWithRequests(
    String billId,
    DocumentReference billRef,
  ) async {
    try {
      final batch = firestore.batch();

      final requests = await firestore
          .collection("split_bill_requests")
          .where("billId", isEqualTo: billId)
          .get();

      for (final doc in requests.docs) {
        batch.delete(doc.reference);
      }

      final transactions = await firestore
          .collection("transactions")
          .where("splitBillId", isEqualTo: billId)
          .get();

      for (final tx in transactions.docs) {
        batch.delete(tx.reference);
      }

      batch.delete(billRef);

      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Bill deleted successfully")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Delete failed: $e")),
      );
    }
  }

  Widget balanceCard(String label, double amount, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(label),
          const SizedBox(height: 5),
          Text(
            _money(amount),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = auth.currentUser?.uid;
    if (currentUid == null) {
      return const Scaffold(
        body: Center(child: Text("User not logged in")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF083549),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        title: const Text(
          "Split The Bill",
          style: TextStyle(
            fontSize: 24,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          StreamBuilder<QuerySnapshot>(
            stream: firestore
                .collection("split_bill_requests")
                .where("toUid", isEqualTo: currentUid)
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
              if (!context.mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
              );
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: SideNav(
          selectedIndex: selectedIndex,
          onItemTap: (index) {
            Navigator.pop(context);
            if (index == selectedIndex) return;

            setState(() {
              selectedIndex = index;
            });

            switch (index) {
              case 0:
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => FintrackerHome()),
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
                  MaterialPageRoute(
                    builder: (_) => const BudgetPlannerScreen(),
                  ),
                );
                break;
              case 3:
                break;
              case 4:
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
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddSplitBillPage()),
          );
        },
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: firestore
            .collection("split_bills")
            .where("participantUids", arrayContains: currentUid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          if (!snapshot.hasData) {
            return const Center(child: Text("No data"));
          }

          final docs = [...snapshot.data!.docs];

          docs.sort((a, b) {
            final adata = a.data() as Map<String, dynamic>;
            final bdata = b.data() as Map<String, dynamic>;
            final at = adata["date"] as Timestamp?;
            final bt = bdata["date"] as Timestamp?;
            if (at == null && bt == null) return 0;
            if (at == null) return 1;
            if (bt == null) return -1;
            return bt.compareTo(at);
          });

          if (docs.isEmpty) {
            return const Center(child: Text("No bills yet"));
          }

          double youOwe = 0;
          double theyOwe = 0;

          for (final doc in docs) {
            final bill = doc.data() as Map<String, dynamic>;
            final balance = _getUserBalance(bill, currentUid);

            if (balance < 0) {
              youOwe += -balance;
            } else if (balance > 0) {
              theyOwe += balance;
            }
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: balanceCard("You Owe", youOwe, Colors.red),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: balanceCard("They Owe", theyOwe, Colors.green),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final bill = docs[index].data() as Map<String, dynamic>;
                    final settlements = calculateSettlements(bill);
                    final isCreator = bill["createdBy"] == currentUid ||
                        bill["uid"] == currentUid;

                    final myBalance = _getUserBalance(bill, currentUid);
                    final myStatus = _getMySettlementStatus(bill);

                    final canMarkPaid = myBalance < -0.01 && myStatus != "paid";
                    final canMarkReceived =
                        myBalance > 0.01 && myStatus != "received";

                    return Card(
                      margin: const EdgeInsets.all(10),
                      child: ListTile(
                        title: Text(bill["title"] ?? "Untitled"),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Total ${_money(_getTotal(bill))} | ${_getParticipants(bill).length} people",
                            ),
                            const SizedBox(height: 5),
                            ...settlements.map(
                              (s) => Text(
                                s,
                                style:
                                    const TextStyle(color: Colors.deepPurple),
                              ),
                            ),
                            if (myStatus == "paid")
                              const Text(
                                "You marked this as Paid",
                                style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            if (myStatus == "received")
                              const Text(
                                "You marked this as Received",
                                style: TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                          ],
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) async {
                            if (value == "edit") {
                              await showEditBillDialog(context, docs[index], bill);
                            } else if (value == "delete") {
                              await _confirmDeleteBill(
                                docs[index].id,
                                docs[index].reference,
                              );
                            } else if (value == "paid") {
                              await showSettlementDialog(
                                context,
                                bill,
                                docs[index].id,
                                "paid",
                              );
                            } else if (value == "received") {
                              await showSettlementDialog(
                                context,
                                bill,
                                docs[index].id,
                                "received",
                              );
                            }
                          },
                          itemBuilder: (context) => [
                            if (isCreator)
                              const PopupMenuItem(
                                value: "edit",
                                child: Text("Edit"),
                              ),
                            if (isCreator)
                              const PopupMenuItem(
                                value: "delete",
                                child: Text("Delete"),
                              ),
                            if (canMarkPaid)
                              const PopupMenuItem(
                                value: "paid",
                                child: Text("Mark as Paid"),
                              ),
                            if (canMarkReceived)
                              const PopupMenuItem(
                                value: "received",
                                child: Text("Mark as Received"),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}