import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_fintracker/screens/accounts/accounts_page.dart';
import 'package:flutter_fintracker/screens/budgets/fintracker_budget.dart';
import 'package:flutter_fintracker/screens/dashboard/fintracker_home.dart';
import 'package:flutter_fintracker/screens/savings/fintracker_savings.dart';
import 'package:flutter_fintracker/screens/splitbill/fintracker_splitbill.dart';
import 'package:flutter_fintracker/screens/bills/fintracker_bills.dart';
import '../../widgets/side_nav.dart';
import '../../previous_tips.dart';
import '../../recurring_payments.dart';
import '../splitbill/split_bills_request_page.dart';
import '../auth/fintracker_login.dart';

class TransactionsPage extends StatefulWidget {
  const TransactionsPage({super.key});

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String searchQuery = '';
  String selectedType = 'All Types';
  String selectedCategory = 'All Categories';
  String selectedAccount = 'All Accounts';
  String selectedPeriod = 'Month';
  bool sortAscending = false; // date sort toggle

  int selectedNavIndex = 1;

  static const Color primaryBlue = Color(0xFF083549);

  // ── Period helpers ──────────────────────────────────────────────
  DateTime get _periodStart {
    final now = DateTime.now();
    switch (selectedPeriod) {
      case 'Week':
        return now.subtract(Duration(days: now.weekday - 1));
      case 'Year':
        return DateTime(now.year, 1, 1);
      case 'Month':
      default:
        return DateTime(now.year, now.month, 1);
    }
  }

  // ── Nav ────────────────────────────────────────────────────────
  void handleNavTap(int index) {
    if (index == selectedNavIndex) { Navigator.pop(context); return; }
    switch (index) {
      case 0: Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DashboardScreen())); break;
      case 1: Navigator.pop(context); break;
      case 2: Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const BudgetPlannerScreen())); break;
      case 3: Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const SavingsPage())); break;
      case 4: Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const SplitBillPage())); break;
      case 5: Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const BillsPage())); break;
      case 6: Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AccountsPage())); break;
    }
  }

  // ── Styled dropdown ─────────────────────────────────────────────
  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Expanded(
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(10),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            isDense: true,
            icon: const Icon(Icons.keyboard_arrow_down, size: 18),
            style: const TextStyle(fontSize: 12, color: Colors.black87),
            items: items
                .map((e) => DropdownMenuItem(value: e, child: Text(e, overflow: TextOverflow.ellipsis)))
                .toList(),
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }

  // ── Transaction detail bottom sheet ────────────────────────────
  void _showTransactionDetail(Map<String, dynamic> data) {
    final amount = (data['amount'] ?? 0).toDouble();
    final type = data['type'] ?? '';
    final category = data['category'] ?? 'Uncategorized';
    final description = data['description'] ?? '';
    final account = data['account'] ?? '';
    final isRecurring = data['isRecurring'] ?? false;
    final date = (data['date'] as Timestamp).toDate();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: type == 'income'
                          ? Colors.green.withOpacity(0.12)
                          : Colors.red.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      type == 'income' ? Icons.arrow_downward : Icons.arrow_upward,
                      color: type == 'income' ? Colors.green : Colors.red,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(category,
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis),
                        Text('${date.day}/${date.month}/${date.year}',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      type == 'income'
                          ? '+ ₹${amount.toStringAsFixed(2)}'
                          : '- ₹${amount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: type == 'income' ? Colors.green : Colors.red,
                      ),
                      textAlign: TextAlign.right,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 10),
              _detailRow(Icons.account_balance_wallet, 'Account', account.isEmpty ? '—' : account),
              const SizedBox(height: 10),
              _detailRow(Icons.repeat, 'Recurring', isRecurring ? 'Yes' : 'No'),
              const SizedBox(height: 10),
              _detailRow(Icons.notes, 'Description',
                  description.isEmpty ? 'No description added' : description),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: primaryBlue),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              Text(value,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  softWrap: true),
            ],
          ),
        ),
      ],
    );
  }

  // ── Stats card ──────────────────────────────────────────────────
  Widget _buildStatsCard(List<Map<String, dynamic>> filtered) {
    if (selectedCategory == 'All Categories') return const SizedBox.shrink();

    final periodFiltered = filtered.where((data) {
      final date = (data['date'] as Timestamp).toDate();
      return date.isAfter(_periodStart);
    }).toList();

    final total = periodFiltered.fold<double>(
        0, (sum, d) => sum + (d['amount'] as num).toDouble());
    final count = periodFiltered.length;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: primaryBlue,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(selectedCategory,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text('₹${total.toStringAsFixed(2)}',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                Text('$count transaction${count == 1 ? '' : 's'}',
                    style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: ['Week', 'Month', 'Year'].map((p) {
              final active = selectedPeriod == p;
              return GestureDetector(
                onTap: () => setState(() => selectedPeriod = p),
                child: Container(
                  margin: const EdgeInsets.only(left: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: active ? Colors.white : Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(p,
                      style: TextStyle(
                        color: active ? primaryBlue : Colors.white70,
                        fontSize: 11,
                        fontWeight: active ? FontWeight.bold : FontWeight.normal,
                      )),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Category chip ───────────────────────────────────────────────
  Widget _categoryChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text("User not logged in")));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7FBFF),
      appBar: AppBar(
        backgroundColor: primaryBlue,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        title: const Text("Transactions",
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        actions: [
          StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection("split_bill_requests")
                .where("toUid", isEqualTo: user.uid)
                .where("status", isEqualTo: "pending")
                .snapshots(),
            builder: (context, snapshot) {
              final count = snapshot.data?.docs.length ?? 0;
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications, color: Colors.white),
                    onPressed: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const SplitBillRequestsPage())),
                  ),
                  if (count > 0)
                    Positioned(
                      right: 8, top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                        constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                        child: Text("$count",
                            style: const TextStyle(color: Colors.white, fontSize: 10),
                            textAlign: TextAlign.center),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.repeat, color: Colors.white),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const RecurringPaymentsPage())),
          ),
          IconButton(
            icon: const Icon(Icons.lightbulb, color: Colors.yellow),
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const TipsPage())),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _handleLogout,
          ),
        ],
      ),

      drawer: Drawer(
        child: SideNav(selectedIndex: selectedNavIndex, onItemTap: handleNavTap),
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('transactions')
            .where('uid', isEqualTo: user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final allDocs = snapshot.data?.docs ?? [];

          // Build dynamic filter options
          final categories = <String>{'All Categories'};
          final accounts = <String>{'All Accounts'};
          for (final doc in allDocs) {
            final data = doc.data() as Map<String, dynamic>;
            if (data['category'] != null) categories.add(data['category']);
            if (data['account'] != null) accounts.add(data['account']);
          }

          // Validate selected values still exist
          if (!categories.contains(selectedCategory)) selectedCategory = 'All Categories';
          if (!accounts.contains(selectedAccount)) selectedAccount = 'All Accounts';

          // Apply filters
          final filtered = allDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final type = data['type'] ?? '';
            final category = (data['category'] ?? 'Uncategorized').toString();
            final account = (data['account'] ?? '').toString();
            final description = (data['description'] ?? '').toString();

            final matchesSearch =
                category.toLowerCase().contains(searchQuery) ||
                description.toLowerCase().contains(searchQuery);
            final matchesType = selectedType == 'All Types' ||
                (selectedType == 'Income' && type == 'income') ||
                (selectedType == 'Expense' && type == 'expense');
            final matchesCategory =
                selectedCategory == 'All Categories' || category == selectedCategory;
            final matchesAccount =
                selectedAccount == 'All Accounts' || account == selectedAccount;

            return matchesSearch && matchesType && matchesCategory && matchesAccount;
          }).map((doc) => doc.data() as Map<String, dynamic>).toList();

          // Sort by date
          filtered.sort((a, b) {
            final aDate = (a['date'] as Timestamp).toDate();
            final bDate = (b['date'] as Timestamp).toDate();
            return sortAscending ? aDate.compareTo(bDate) : bDate.compareTo(aDate);
          });

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Title + filters ──
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("All Transactions",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),

                    // Search bar
                    TextField(
                      onChanged: (v) => setState(() => searchQuery = v.toLowerCase()),
                      decoration: InputDecoration(
                        hintText: "Search transactions...",
                        hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                        prefixIcon: Icon(Icons.search, size: 20, color: Colors.grey.shade400),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // 3 dropdowns in a row
                    Row(
                      children: [
                        _buildDropdown(
                          value: selectedType,
                          items: ['All Types', 'Income', 'Expense'],
                          onChanged: (v) => setState(() => selectedType = v!),
                        ),
                        const SizedBox(width: 8),
                        _buildDropdown(
                          value: selectedCategory,
                          items: categories.toList(),
                          onChanged: (v) => setState(() => selectedCategory = v!),
                        ),
                        const SizedBox(width: 8),
                        _buildDropdown(
                          value: selectedAccount,
                          items: accounts.toList(),
                          onChanged: (v) => setState(() => selectedAccount = v!),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // ── Stats card ──
              _buildStatsCard(filtered),

              // ── Column headers ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: Row(
                  children: [
                    // Date with sort toggle
                    GestureDetector(
                      onTap: () => setState(() => sortAscending = !sortAscending),
                      child: Row(
                        children: [
                          const Text("Date",
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black54)),
                          const SizedBox(width: 2),
                          Icon(
                            sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                            size: 13,
                            color: Colors.black45,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      flex: 3,
                      child: Text("Description",
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.black54)),
                    ),
                    const Expanded(
                      flex: 2,
                      child: Text("Category",
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.black54)),
                    ),
                    const Expanded(
                      flex: 2,
                      child: Text("Account",
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.black54)),
                    ),
                    const Text("Amount",
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.black54)),
                  ],
                ),
              ),

              const Divider(height: 1),

              // ── Transaction rows ──
              Expanded(
                child: filtered.isEmpty
                    ? const Center(child: Text("No transactions found"))
                    : ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) =>
                            Divider(height: 1, color: Colors.grey.shade200),
                        itemBuilder: (context, index) {
                          final data = filtered[index];
                          final amount = (data['amount'] ?? 0).toDouble();
                          final type = data['type'] ?? '';
                          final category = data['category'] ?? 'Uncategorized';
                          final description = data['description'] ?? '';
                          final account = data['account'] ?? '—';
                          final date = (data['date'] as Timestamp).toDate();

                          final monthNames = [
                            'Jan','Feb','Mar','Apr','May','Jun',
                            'Jul','Aug','Sep','Oct','Nov','Dec'
                          ];
                          final dateStr =
                              '${monthNames[date.month - 1]} ${date.day}, ${date.year}';

                          return InkWell(
                            onTap: () => _showTransactionDetail(data),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Date
                                  SizedBox(
                                    width: 72,
                                    child: Text(dateStr,
                                        style: TextStyle(
                                            fontSize: 11, color: Colors.grey.shade600)),
                                  ),
                                  const SizedBox(width: 8),

                                  // Description
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      description.isNotEmpty ? description : category,
                                      style: const TextStyle(
                                          fontSize: 13, fontWeight: FontWeight.w500),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),

                                  // Category chip
                                  Expanded(
                                    flex: 2,
                                    child: _categoryChip(category),
                                  ),
                                  const SizedBox(width: 6),

                                  // Account
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      account,
                                      style: TextStyle(
                                          fontSize: 12, color: Colors.grey.shade500),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 4),

                                  // Amount
                                  Text(
                                    type == 'income'
                                        ? '+₹${amount.toStringAsFixed(2)}'
                                        : '₹${amount.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: type == 'income'
                                          ? Colors.green.shade600
                                          : Colors.red.shade600,
                                    ),
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

  // ── Logout ──────────────────────────────────────────────────────
  Future<void> _handleLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to log out?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBlue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Logout", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (shouldLogout ?? false) {
      await FirebaseAuth.instance.signOut();
      if (!context.mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    }
  }
}