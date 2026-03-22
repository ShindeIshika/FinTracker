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

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _money(double v) => "₹${v.toStringAsFixed(0)}";

  String _getName(Map<String, dynamic> p) {
    for (final key in ["firstName", "firstname", "first_name", "name",
                        "username", "email"]) {
      final v = (p[key] ?? "").toString().trim();
      if (v.isNotEmpty) {
        return key == "email" ? v.split("@").first : v.split(" ").first;
      }
    }
    return "User";
  }

  List<Map<String, dynamic>> _participants(Map<String, dynamic> bill) {
    final raw = bill["participants"] ?? [];
    return List<Map<String, dynamic>>.from(
        (raw as List).map((e) => Map<String, dynamic>.from(e)));
  }

  double _total(Map<String, dynamic> bill) =>
      ((bill["total"] ?? 0) as num).toDouble();

  double _share(Map<String, dynamic> bill) {
    final p = _participants(bill);
    return p.isEmpty ? 0 : _total(bill) / p.length;
  }

  /// balance > 0  → this uid is owed money (creditor)
  /// balance < 0  → this uid owes money   (debtor)
  double _balanceOf(Map<String, dynamic> bill, String uid) {
    final share = _share(bill);
    for (final p in _participants(bill)) {
      if ((p["uid"] ?? "").toString() == uid) {
        return ((p["paid"] ?? 0) as num).toDouble() - share;
      }
    }
    return 0;
  }

  /// Derive a stable settlement key for any participant (app user or manual).
  String _debtorKey(Map<String, dynamic> p) {
    final uid = (p["uid"] ?? "").toString();
    final isAppUser = p["isuser"] == true;
    if (isAppUser && uid.isNotEmpty) return uid;
    // Manual participant — use a name-based key
    return "manual_${(p["name"] ?? "unknown").toString().trim().replaceAll(" ", "_")}";
  }

  /// settlement status stored per debtorKey
  String? _settlementStatus(Map<String, dynamic> bill, String debtorKey) {
    final s = Map<String, dynamic>.from(bill["userSettlements"] ?? {});
    return s[debtorKey]?["status"]?.toString();
  }

  // ── Who-owes-who summary strings ─────────────────────────────────────────
  List<String> _oweSummary(Map<String, dynamic> bill) {
    final parts = _participants(bill);
    final share = _share(bill);

    final creditors = <Map<String, dynamic>>[];
    final debtors = <Map<String, dynamic>>[];

    for (final p in parts) {
      final bal = ((p["paid"] ?? 0) as num).toDouble() - share;
      if (bal > 0.01) creditors.add({"name": _getName(p), "amt": bal});
      if (bal < -0.01) debtors.add({"name": _getName(p), "amt": -bal});
    }

    final result = <String>[];
    int i = 0, j = 0;
    while (i < debtors.length && j < creditors.length) {
      final pay = debtors[i]["amt"] < creditors[j]["amt"]
          ? debtors[i]["amt"] as double
          : creditors[j]["amt"] as double;
      result.add(
          "${debtors[i]["name"]} owes ${creditors[j]["name"]} ${_money(pay)}");
      debtors[i]["amt"] -= pay;
      creditors[j]["amt"] -= pay;
      if ((debtors[i]["amt"] as double) <= 0.01) i++;
      if ((creditors[j]["amt"] as double) <= 0.01) j++;
    }
    return result;
  }

  // ── Transaction helpers ───────────────────────────────────────────────────

  Future<void> _addTx({
    required String uid,
    required String billId,
    required String billTitle,
    required double amount,
    required String type,       // "income" | "expense"
    required String roleTag,    // unique per person per bill
  }) async {
    // Skip writing a transaction if there is no real uid (manual participant)
    if (uid.isEmpty) return;

    final col = firestore.collection("transactions");
    final existing = await col
        .where("splitBillId", isEqualTo: billId)
        .where("uid", isEqualTo: uid)
        .where("transactionRole", isEqualTo: roleTag)
        .limit(1)
        .get();

    final data = {
      "uid": uid,
      "splitBillId": billId,
      "transactionRole": roleTag,
      "title": "$billTitle - Split Bill",
      "amount": amount,
      "type": type,
      "category":"$billTitle - Split Bill" ,
      "account": kDefaultAccount,
      "date": Timestamp.now(),
    };

    if (existing.docs.isEmpty) {
      await col.add(data);
    } else {
      await existing.docs.first.reference.update(data);
    }
  }

  // ── Mark as Received (creditor action) ───────────────────────────────────
  /// Called by the creditor to record that a specific debtor has paid them.
  /// Works for both app-users (debtorUid non-empty) and manual participants.
  Future<void> _markReceived({
    required Map<String, dynamic> bill,
    required String billId,
    required Map<String, dynamic> debtorParticipant, // full participant map
  }) async {
    final creditorUid = auth.currentUser!.uid;
    final debtorKey = _debtorKey(debtorParticipant);
    final debtorUid = (debtorParticipant["uid"] ?? "").toString(); // may be empty for manual

    // Compute the amount this debtor owes
    final share = _share(bill);
    final paid = ((debtorParticipant["paid"] ?? 0) as num).toDouble();
    final amount = (share - paid).abs();
    final title = (bill["title"] ?? "Split Bill").toString();

    // Update settlement map for debtorKey → "paid"
    final settlements =
        Map<String, dynamic>.from(bill["userSettlements"] ?? {});
    settlements[debtorKey] = {
      "status": "paid",
      "amount": amount,
      "settledBy": creditorUid,
      "updatedAt": Timestamp.now(),
    };
    // Also mark creditor's receive-record for this debtor
    final creditorRecvKey = "${creditorUid}_recv_$debtorKey";
    settlements[creditorRecvKey] = {
      "status": "received",
      "amount": amount,
      "updatedAt": Timestamp.now(),
    };

    await firestore.collection("split_bills").doc(billId).update({
      "userSettlements": settlements,
    });

    // Income for creditor (always an app user)
    await _addTx(
      uid: creditorUid,
      billId: billId,
      billTitle: title,
      amount: amount,
      type: kIncomeType,
      roleTag: "recv_from_${debtorKey.substring(0, debtorKey.length.clamp(0, 20))}",
    );

    // Expense for debtor — only written if debtor is an app user
    if (debtorUid.isNotEmpty) {
      await _addTx(
        uid: debtorUid,
        billId: billId,
        billTitle: title,
        amount: amount,
        type: kExpenseType,
        roleTag: "paid_to_${creditorUid.substring(0, 8)}",
      );
    }
  }

  // ── Mark as Paid (debtor action — only for app-user current user) ─────────
  Future<void> _markPaid({
    required Map<String, dynamic> bill,
    required String billId,
  }) async {
    final debtorUid = auth.currentUser!.uid;
    final myBalance = _balanceOf(bill, debtorUid); // negative
    final amount = -myBalance;
    final title = (bill["title"] ?? "Split Bill").toString();

    // Find the creditor (person with positive balance)
    String creditorUid = "";
    for (final p in _participants(bill)) {
      final uid = (p["uid"] ?? "").toString();
      final bal = _balanceOf(bill, uid);
      if (bal > 0.01) {
        creditorUid = uid;
        break;
      }
    }

    final settlements =
        Map<String, dynamic>.from(bill["userSettlements"] ?? {});
    settlements[debtorUid] = {
      "status": "paid",
      "amount": amount,
      "updatedAt": Timestamp.now(),
    };

    await firestore.collection("split_bills").doc(billId).update({
      "userSettlements": settlements,
    });

    // Expense for debtor (self)
    await _addTx(
      uid: debtorUid,
      billId: billId,
      billTitle: title,
      amount: amount,
      type: kExpenseType,
      roleTag: "paid_to_${creditorUid.isNotEmpty ? creditorUid.substring(0, 8) : "creditor"}",
    );

    // Income for creditor
    if (creditorUid.isNotEmpty) {
      await _addTx(
        uid: creditorUid,
        billId: billId,
        billTitle: title,
        amount: amount,
        type: kIncomeType,
        roleTag: "recv_from_${debtorUid.substring(0, 8)}",
      );
    }
  }

  // ── Mark Manual Participant as Paid (creditor-initiated on behalf of manual user) ──
  /// Used when the current user is the creditor and wants to mark a manual
  /// (non-app) participant as having paid. Identical flow to _markReceived.
  Future<void> _markManualPaid({
    required Map<String, dynamic> bill,
    required String billId,
    required Map<String, dynamic> manualParticipant,
  }) => _markReceived(
        bill: bill,
        billId: billId,
        debtorParticipant: manualParticipant,
      );

  // ── Bill Detail Bottom Sheet ──────────────────────────────────────────────
  void _showDetail(
      BuildContext context, Map<String, dynamic> initialBill, String billId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StreamBuilder<DocumentSnapshot>(
        stream: firestore.collection("split_bills").doc(billId).snapshots(),
        builder: (ctx, snap) {
          final bill = snap.hasData && snap.data!.exists
              ? snap.data!.data() as Map<String, dynamic>
              : initialBill;

          final currentUid = auth.currentUser!.uid;
          final myBalance = _balanceOf(bill, currentUid);
          final iAmCreditor = myBalance > 0.01;
          final iAmDebtor = myBalance < -0.01;
          final share = _share(bill);
          final total = _total(bill);
          final summary = _oweSummary(bill);
          final parts = _participants(bill);

          // Check if ALL debts are settled
          bool allSettled = true;
          for (final p in parts) {
            final paid = ((p["paid"] ?? 0) as num).toDouble();
            final balance = paid - share;
            if (balance >= -0.01) continue; // not a debtor, skip

            final dKey = _debtorKey(p);
            final status = _settlementStatus(bill, dKey);
            if (status != "paid") {
              allSettled = false;
              break;
            }
          }

          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.65,
            maxChildSize: 0.95,
            builder: (_, ctrl) => ListView(
              controller: ctrl,
              padding: const EdgeInsets.all(20),
              children: [
                // drag handle
                Center(
                  child: Container(
                    width: 40, height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),

                // ── Title + settled badge ──────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: Text(bill["title"] ?? "Untitled",
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                    ),
                    if (allSettled)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Colors.green.withOpacity(0.4))),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle,
                                size: 14, color: Colors.green),
                            SizedBox(width: 4),
                            Text("Settled",
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  "Total: ${_money(total)}  •  "
                  "${parts.length} people  •  ${_money(share)} each",
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),

                const Divider(height: 28),
                const Text("Participants",
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 10),

                // ── Participant rows ───────────────────────────────────
                ...parts.map((p) {
                  final uid = (p["uid"] ?? "").toString();
                  final name = _getName(p);
                  final paid = ((p["paid"] ?? 0) as num).toDouble();
                  final balance = paid - share;
                  final isAppUser = p["isuser"] == true;
                  final isManual = !isAppUser || uid.isEmpty;
                  final isCurrentUser = uid == currentUid && uid.isNotEmpty;

                  final dKey = _debtorKey(p);
                  final creditorRecvKey = "${currentUid}_recv_$dKey";
                  final creditorAlreadyMarked =
                      (bill["userSettlements"] ?? {})[creditorRecvKey] != null;

                  final status = _settlementStatus(bill, dKey);
                  final isDebtor = balance < -0.01;

                  // Creditor can mark received for:
                  //   - any app-user debtor (not themselves)
                  //   - any manual participant debtor
                  final showMarkReceived = iAmCreditor &&
                      isDebtor &&
                      !isCurrentUser &&
                      status != "paid" &&
                      !creditorAlreadyMarked;

                  // Debtor can self-mark only if they are the current app user
                  final showMarkPaid = iAmDebtor &&
                      isCurrentUser &&
                      status != "paid";

                  // Manual participant — creditor can mark as paid on their behalf
                  final showMarkManualPaid = iAmCreditor &&
                      isManual &&
                      isDebtor &&
                      status != "paid" &&
                      !creditorAlreadyMarked;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor:
                              const Color(0xFF083549).withOpacity(0.1),
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : "?",
                            style: const TextStyle(
                                color: Color(0xFF083549),
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14)),
                                  if (isManual) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                          color: Colors.orange.withOpacity(0.12),
                                          borderRadius:
                                              BorderRadius.circular(8)),
                                      child: const Text("Manual",
                                          style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.orange,
                                              fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ],
                              ),
                              Text("Paid: ${_money(paid)}",
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.grey)),
                              Text(
                                balance >= 0
                                    ? "Gets back ${_money(balance)}"
                                    : "Owes ${_money(-balance)}",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: balance >= 0
                                      ? Colors.green
                                      : Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // ── Action / status ──────────────────────────
                        if (status == "paid")
                          _badge("Paid ✓", Colors.green)
                        else if (creditorAlreadyMarked && !isCurrentUser)
                          _badge("Received ✓", Colors.blue)
                        // showMarkManualPaid is a subset of showMarkReceived,
                        // so we use a single button for both cases below.
                        else if (showMarkReceived || showMarkManualPaid)
                          _actionButton(
                            label: isManual ? "Mark Paid" : "Mark Received",
                            color: Colors.green,
                            onTap: () async {
                              await _markReceived(
                                bill: bill,
                                billId: billId,
                                debtorParticipant: p,
                              );
                              // Sheet rebuilds automatically via stream
                            },
                          )
                        else if (showMarkPaid)
                          _actionButton(
                            label: "Mark Paid",
                            color: Colors.orange,
                            onTap: () async {
                              await _markPaid(bill: bill, billId: billId);
                              // Sheet rebuilds automatically via stream
                            },
                          ),
                      ],
                    ),
                  );
                }),

                // ── Who owes who ───────────────────────────────────────
                if (summary.isNotEmpty) ...[
                  const Divider(height: 28),
                  const Text("Who Owes Who",
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 8),
                  ...summary.map((s) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(children: [
                          const Icon(Icons.arrow_forward,
                              size: 14, color: Colors.deepPurple),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(s,
                                style: const TextStyle(
                                    color: Colors.deepPurple,
                                    fontSize: 13)),
                          ),
                        ]),
                      )),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _badge(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20)),
        child: Text(label,
            style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.bold)),
      );

  Widget _actionButton(
          {required String label,
          required Color color,
          required VoidCallback onTap}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withOpacity(0.4))),
          child: Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.bold)),
        ),
      );

  // ── Delete bill ───────────────────────────────────────────────────────────
  Future<void> _deleteBill(String billId, DocumentReference ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Bill"),
        content: const Text("Are you sure?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel")),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Delete")),
        ],
      ),
    );
    if (ok != true) return;

    final batch = firestore.batch();
    for (final doc in (await firestore
            .collection("split_bill_requests")
            .where("billId", isEqualTo: billId)
            .get())
        .docs) {
      batch.delete(doc.reference);
    }
    for (final tx in (await firestore
            .collection("transactions")
            .where("splitBillId", isEqualTo: billId)
            .get())
        .docs) {
      batch.delete(tx.reference);
    }
    batch.delete(ref);
    await batch.commit();

    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("Bill deleted")));
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final currentUid = auth.currentUser?.uid ?? "";

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF083549),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text("Split The Bill",
            style: TextStyle(
                fontSize: 22,
                color: Colors.white,
                fontWeight: FontWeight.bold)),
        actions: [
          // Notification bell
          StreamBuilder<QuerySnapshot>(
            stream: firestore
                .collection("split_bill_requests")
                .where("toUid", isEqualTo: currentUid)
                .where("status", isEqualTo: "pending")
                .snapshots(),
            builder: (context, snap) {
              final count = snap.data?.docs.length ?? 0;
              return Stack(children: [
                IconButton(
                  icon: const Icon(Icons.notifications,
                      color: Colors.white),
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              const SplitBillRequestsPage())),
                ),
                if (count > 0)
                  Positioned(
                    right: 8, top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle),
                      constraints: const BoxConstraints(
                          minWidth: 18, minHeight: 18),
                      child: Text("$count",
                          style: const TextStyle(
                              color: Colors.white, fontSize: 10),
                          textAlign: TextAlign.center),
                    ),
                  ),
              ]);
            },
          ),
          IconButton(
            icon: const Icon(Icons.repeat, color: Colors.white),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(
                    builder: (_) => const RecurringPaymentsPage())),
          ),
          IconButton(
            icon: const Icon(Icons.lightbulb, color: Colors.yellow),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const TipsPage())),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (!context.mounted) return;
              Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (_) => const LoginPage()));
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
            setState(() => selectedIndex = index);
            switch (index) {
              case 0:
                Navigator.pushReplacement(context,
                    MaterialPageRoute(builder: (_) => FintrackerHome()));
                break;
              case 1:
                Navigator.pushReplacement(context,
                    MaterialPageRoute(
                        builder: (_) => const TransactionsPage()));
                break;
              case 2:
                Navigator.pushReplacement(context,
                    MaterialPageRoute(
                        builder: (_) => const BudgetPlannerScreen()));
                break;
              case 5:
                Navigator.pushReplacement(context,
                    MaterialPageRoute(
                        builder: (_) => const BillsPage()));
                break;
            }
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF083549),
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AddSplitBillPage())),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: firestore
            .collection("split_bills")
            .where("participantUids", arrayContains: currentUid)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text("Error: ${snap.error}"));
          }

          final docs = [...(snap.data?.docs ?? [])];
          docs.sort((a, b) {
            final at = (a.data() as Map)["date"] as Timestamp?;
            final bt = (b.data() as Map)["date"] as Timestamp?;
            if (at == null && bt == null) return 0;
            if (at == null) return 1;
            if (bt == null) return -1;
            return bt.compareTo(at);
          });

          if (docs.isEmpty) {
            return const Center(
                child: Text("No bills yet. Tap + to add one."));
          }

          // Summary totals
          // Summary totals — exclude settled balances
double youOwe = 0, theyOwe = 0;
for (final doc in docs) {
  final bill = doc.data() as Map<String, dynamic>;
  final bal = _balanceOf(bill, currentUid);
  final settlements = Map<String, dynamic>.from(bill["userSettlements"] ?? {});

  if (bal < 0) {
    // I am a debtor — only count if I haven't marked paid
    final myStatus = settlements[currentUid]?["status"]?.toString();
    if (myStatus != "paid") youOwe += -bal;
  } else if (bal > 0) {
    // I am a creditor — subtract what has already been received
    double pendingOwed = bal;
    final parts = _participants(bill);
    final share = _share(bill);
    for (final p in parts) {
      final pPaid = ((p["paid"] ?? 0) as num).toDouble();
      final pBal = pPaid - share;
      if (pBal >= -0.01) continue; // not a debtor, skip

      final dKey = _debtorKey(p);
      final creditorRecvKey = "${currentUid}_recv_$dKey";
      final alreadyReceived =
          settlements[creditorRecvKey] != null || settlements[dKey]?["status"] == "paid";

      if (alreadyReceived) {
        // Deduct this debtor's share from what they still owe me
        final theirDebt = (share - pPaid).abs();
        pendingOwed -= theirDebt;
      }
    }
    if (pendingOwed > 0.01) theyOwe += pendingOwed;
  }
}

          return Column(children: [
            // ── Summary cards ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(children: [
                Expanded(child: _summaryCard("You Owe", youOwe, Colors.red)),
                const SizedBox(width: 12),
                Expanded(
                    child: _summaryCard(
                        "They Owe You", theyOwe, Colors.green)),
              ]),
            ),

            // ── Bill list ──────────────────────────────────────────
            Expanded(
              child: ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final bill =
                      docs[i].data() as Map<String, dynamic>;
                  final billId = docs[i].id;
                  final isCreator = bill["createdBy"] == currentUid ||
                      bill["uid"] == currentUid;
                  final myBal = _balanceOf(bill, currentUid);
                  final summary = _oweSummary(bill);

                  return GestureDetector(
                    onTap: () =>
                        _showDetail(context, bill, billId),
                    child: Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    bill["title"] ?? "Untitled",
                                    style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF083549)),
                                  ),
                                ),
                                if (isCreator)
                                  PopupMenuButton<String>(
                                    onSelected: (v) async {
                                      if (v == "edit") {
                                        await _showEditDialog(
                                            context,
                                            docs[i],
                                            bill);
                                      } else if (v == "delete") {
                                        await _deleteBill(
                                            billId,
                                            docs[i].reference);
                                      }
                                    },
                                    itemBuilder: (_) => [
                                      const PopupMenuItem(
                                          value: "edit",
                                          child: Text("Edit")),
                                      const PopupMenuItem(
                                          value: "delete",
                                          child: Text("Delete")),
                                    ],
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "${_money(_total(bill))} total  •  "
                              "${_participants(bill).length} people  •  "
                              "${_money(_share(bill))} each",
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey),
                            ),
                            if (summary.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              ...summary.map((s) => Text(s,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.deepPurple))),
                            ],
                            const SizedBox(height: 6),
                            // ── Compute settled status for card ──
                            Builder(builder: (_) {
                              final settlements = Map<String, dynamic>.from(
                                  bill["userSettlements"] ?? {});
                              final parts = _participants(bill);
                              final share = _share(bill);

                              int debtorCount = 0;
                              int settledCount = 0;

                              for (final p in parts) {
                                final paid2 =
                                    ((p["paid"] ?? 0) as num).toDouble();
                                final bal2 = paid2 - share;
                                if (bal2 >= -0.01) continue;

                                debtorCount++;
                                final dKey = _debtorKey(p);
                                if (settlements[dKey]?["status"] == "paid") {
                                  settledCount++;
                                }
                              }

                              final fullySettled =
                                  debtorCount > 0 &&
                                      settledCount == debtorCount;

                              if (fullySettled) {
                                return const Row(children: [
                                  Icon(Icons.check_circle,
                                      size: 14, color: Colors.green),
                                  SizedBox(width: 4),
                                  Text("Bill fully settled",
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.green,
                                          fontWeight: FontWeight.w600)),
                                ]);
                              }

                              if (myBal > 0.01) {
                                return Text(
                                  "You are owed ${_money(myBal)} "
                                  "($settledCount/$debtorCount settled)",
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.green,
                                      fontWeight: FontWeight.w600),
                                );
                              } else if (myBal < -0.01) {
                                final myStatus =
                                    settlements[currentUid]?["status"]
                                        ?.toString();
                                return Text(
                                  myStatus == "paid"
                                      ? "You paid ✓"
                                      : "You owe ${_money(-myBal)}",
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: myStatus == "paid"
                                          ? Colors.green
                                          : Colors.red,
                                      fontWeight: FontWeight.w600),
                                );
                              }
                              return const SizedBox();
                            }),
                            const SizedBox(height: 4),
                            const Text("Tap for details",
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.blueGrey)),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ]);
        },
      ),
    );
  }

  Widget _summaryCard(String label, double amount, Color color) =>
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.2))),
        child: Column(children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(_money(amount),
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: color)),
        ]),
      );

  // ── Edit bill dialog ──────────────────────────────────────────────────────
  Future<void> _showEditDialog(BuildContext context,
      DocumentSnapshot doc, Map<String, dynamic> bill) async {
    final titleCtrl =
        TextEditingController(text: bill["title"] ?? "");
    final totalCtrl = TextEditingController(
        text: (bill["total"] ?? "").toString());
    final parts = List<Map<String, dynamic>>.from(
        _participants(bill).map((e) => Map<String, dynamic>.from(e)));

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text("Edit Bill"),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                      controller: titleCtrl,
                      decoration:
                          const InputDecoration(labelText: "Title")),
                  TextField(
                      controller: totalCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(
                              decimal: true),
                      decoration:
                          const InputDecoration(labelText: "Total")),
                  const SizedBox(height: 12),
                  ...List.generate(parts.length, (idx) {
                    final part = parts[idx];
                    final nc = TextEditingController(
                        text: part["name"] ?? "");
                    final pc = TextEditingController(
                        text: (part["paid"] ?? 0).toString());
                    final isSelf =
                        (part["uid"] ?? "") == auth.currentUser!.uid;
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(children: [
                          TextField(
                              controller: nc,
                              readOnly: part["isuser"] == true,
                              decoration: const InputDecoration(
                                  labelText: "Name"),
                              onChanged: (v) =>
                                  part["name"] = v.trim()),
                          TextField(
                              controller: pc,
                              keyboardType:
                                  const TextInputType
                                      .numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                  labelText: "Amount Paid"),
                              onChanged: (v) => part["paid"] =
                                  double.tryParse(v.trim()) ?? 0),
                          if (!isSelf)
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () =>
                                    setSt(() => parts.removeAt(idx)),
                                child: const Text("Remove"),
                              ),
                            ),
                        ]),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () async {
                final total =
                    double.tryParse(totalCtrl.text.trim());
                if (titleCtrl.text.trim().isEmpty ||
                    total == null) return;
                await doc.reference.update({
                  "title": titleCtrl.text.trim(),
                  "total": total,
                  "participants": parts,
                  "updatedAt": Timestamp.now(),
                });
                if (!mounted) return;
                Navigator.pop(ctx);
              },
              child: const Text("Save"),
            ),
          ],
        ),
      ),
    );
  }
}