import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AccountsPage extends StatefulWidget {
  const AccountsPage({super.key});

  @override
  State<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends State<AccountsPage> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  static const _primary = Color(0xFF083549);

  CollectionReference get _accountsRef => _firestore
      .collection('users')
      .doc(_auth.currentUser!.uid)
      .collection('accounts');

  // ── Icon / colour helpers ──────────────────────────────────────
  IconData _iconFor(String type) {
    switch (type) {
      case 'Bank':
        return Icons.account_balance;
      case 'Wallet':
        return Icons.account_balance_wallet;
      case 'Cash':
      default:
        return Icons.payments_outlined;
    }
  }

  Color _colorFor(String type) {
    switch (type) {
      case 'Bank':
        return const Color(0xFF1565C0);
      case 'Wallet':
        return const Color(0xFF6A1B9A);
      case 'Cash':
      default:
        return const Color(0xFF2E7D32);
    }
  }

  // ── Add / Edit dialog ─────────────────────────────────────────
  Future<void> _showAccountDialog({DocumentSnapshot? doc}) async {
    final isEditing = doc != null;
    final data = isEditing ? doc!.data() as Map<String, dynamic> : null;

    final nameController =
        TextEditingController(text: isEditing ? data!['name'] : '');
    final balanceController = TextEditingController(
        text: isEditing ? (data!['balance'] as num).toStringAsFixed(2) : '');
    String selectedType = isEditing ? (data!['type'] ?? 'Cash') : 'Cash';

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            isEditing ? 'Edit Account' : 'Add Account',
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: _primary),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Account name
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Account Name',
                  hintText: 'e.g. HDFC Savings',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),

              // Type selector (Cash / Wallet / Bank)
              DropdownButtonFormField<String>(
                value: selectedType,
                decoration: InputDecoration(
                  labelText: 'Account Type',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                items: ['Cash', 'Wallet', 'Bank']
                    .map((t) => DropdownMenuItem(
                          value: t,
                          child: Row(
                            children: [
                              Icon(_iconFor(t),
                                  size: 18, color: _colorFor(t)),
                              const SizedBox(width: 8),
                              Text(t),
                            ],
                          ),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setDialogState(() => selectedType = v);
                },
              ),
              const SizedBox(height: 16),

              // Balance
              TextField(
                controller: balanceController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Current Balance (₹)',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final name = nameController.text.trim();
                final balance =
                    double.tryParse(balanceController.text.trim()) ?? 0;

                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter account name')),
                  );
                  return;
                }

                if (isEditing) {
                  await _accountsRef.doc(doc!.id).update({
                    'name': name,
                    'type': selectedType,
                    'balance': balance,
                  });
                } else {
                  await _accountsRef.add({
                    'name': name,
                    'type': selectedType,
                    'balance': balance,
                    'createdAt': FieldValue.serverTimestamp(),
                  });
                }

                if (context.mounted) Navigator.pop(context);
              },
              child: Text(
                isEditing ? 'Update' : 'Add',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Delete with confirmation ──────────────────────────────────
  Future<void> _deleteAccount(String id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Account'),
        content: Text('Delete "$name"? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) await _accountsRef.doc(id).delete();
  }

  // ── Build ──────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _primary,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Accounts',
          style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            tooltip: 'Add Account',
            onPressed: _showAccountDialog,
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _accountsRef.orderBy('createdAt').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];

          // ── Summary totals ──────────────────────────────────
          double totalBalance = 0;
          double cashTotal = 0;
          double walletTotal = 0;
          double bankTotal = 0;

          for (final doc in docs) {
            final d = doc.data() as Map<String, dynamic>;
            final bal = (d['balance'] as num).toDouble();
            totalBalance += bal;
            switch (d['type'] ?? 'Cash') {
              case 'Cash':
                cashTotal += bal;
                break;
              case 'Wallet':
                walletTotal += bal;
                break;
              case 'Bank':
                bankTotal += bal;
                break;
            }
          }

          return Column(
            children: [
              // ── Total balance hero card ──────────────────────
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 20),
                decoration: BoxDecoration(
                  color: _primary,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: _primary.withOpacity(0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total Balance',
                      style:
                          TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₹ ${totalBalance.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _miniStat('Wallet', walletTotal,
                            Icons.account_balance_wallet),
                        const SizedBox(width: 16),
                        _miniStat(
                            'Bank', bankTotal, Icons.account_balance),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Account list ────────────────────────────────
              Expanded(
                child: docs.isEmpty
                    ? _emptyState()
                    : ListView.builder(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          final d =
                              doc.data() as Map<String, dynamic>;
                          final name = d['name'] ?? 'Account';
                          final type = d['type'] ?? 'Cash';
                          final balance =
                              (d['balance'] as num).toDouble();
                          final color = _colorFor(type);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 8,
                                  offset: Offset(0, 3),
                                ),
                              ],
                            ),
                            child: ListTile(
                              contentPadding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                              leading: CircleAvatar(
                                backgroundColor:
                                    color.withOpacity(0.12),
                                child: Icon(_iconFor(type),
                                    color: color, size: 22),
                              ),
                              title: Text(
                                name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15),
                              ),
                              subtitle: Text(
                                type,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade500),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '₹ ${balance.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: balance >= 0
                                          ? Colors.green.shade700
                                          : Colors.red,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  PopupMenuButton<String>(
                                    onSelected: (v) {
                                      if (v == 'edit') {
                                        _showAccountDialog(doc: doc);
                                      } else if (v == 'delete') {
                                        _deleteAccount(doc.id, name);
                                      }
                                    },
                                    itemBuilder: (_) => const [
                                      PopupMenuItem(
                                          value: 'edit',
                                          child: Row(children: [
                                            Icon(Icons.edit, size: 16),
                                            SizedBox(width: 8),
                                            Text('Edit'),
                                          ])),
                                      PopupMenuItem(
                                          value: 'delete',
                                          child: Row(children: [
                                            Icon(Icons.delete,
                                                size: 16,
                                                color: Colors.red),
                                            SizedBox(width: 8),
                                            Text('Delete',
                                                style: TextStyle(
                                                    color: Colors.red)),
                                          ])),
                                    ],
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAccountDialog,
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Account'),
      ),
    );
  }

  Widget _miniStat(String label, double amount, IconData icon) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: Colors.white60),
              const SizedBox(width: 4),
              Text(label,
                  style: const TextStyle(
                      color: Colors.white60, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '₹${amount.toStringAsFixed(0)}',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.account_balance_wallet_outlined,
              size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text(
            'No accounts yet',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF083549)),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your cash, wallet, and bank accounts\nto track balances accurately.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showAccountDialog,
            icon: const Icon(Icons.add),
            label: const Text('Add First Account'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  AccountSummaryWidget — compact card for embedding on Dashboard
// ─────────────────────────────────────────────────────────────────────────────

class AccountSummaryWidget extends StatelessWidget {
  final VoidCallback? onTap;

  const AccountSummaryWidget({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('accounts')
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: const Color(0xFF083549).withOpacity(0.2)),
                boxShadow: const [
                  BoxShadow(
                      color: Colors.black12,
                      blurRadius: 6,
                      offset: Offset(0, 3)),
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.account_balance_wallet,
                      color: Colors.grey.shade400),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Set up your accounts to track balances',
                      style: TextStyle(
                          color: Colors.grey.shade500, fontSize: 13),
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Colors.grey.shade400),
                ],
              ),
            ),
          );
        }

        double total = 0;
        for (final doc in docs) {
          final d = doc.data() as Map<String, dynamic>;
          total += (d['balance'] as num).toDouble();
        }

        return GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(
                    color: Colors.black12,
                    blurRadius: 6,
                    offset: Offset(0, 3))
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.account_balance_wallet,
                            size: 16, color: Color(0xFF083549)),
                        SizedBox(width: 6),
                        Text(
                          'Accounts',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF083549),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          '₹ ${total.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF083549),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right,
                            size: 18, color: Colors.grey),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: docs.map((doc) {
                    final d = doc.data() as Map<String, dynamic>;
                    final type = d['type'] ?? 'Cash';
                    final name = d['name'] ?? 'Account';
                    final bal = (d['balance'] as num).toDouble();

                    Color chipColor;
                    IconData chipIcon;
                    switch (type) {
                      case 'Bank':
                        chipColor = const Color(0xFF1565C0);
                        chipIcon = Icons.account_balance;
                        break;
                      case 'Wallet':
                        chipColor = const Color(0xFF6A1B9A);
                        chipIcon = Icons.account_balance_wallet;
                        break;
                      default:
                        chipColor = const Color(0xFF2E7D32);
                        chipIcon = Icons.payments_outlined;
                    }

                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: chipColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: chipColor.withOpacity(0.25)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(chipIcon, size: 13, color: chipColor),
                          const SizedBox(width: 5),
                          Text(
                            '$name  ₹${bal.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: chipColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}