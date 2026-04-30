import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';
import 'package:flutter_fintracker/screens/budgets/fintracker_budget.dart';
class AddTransactionPage extends StatefulWidget {
  final String type; // 'income' or 'expense'

  const AddTransactionPage({super.key, required this.type});

  @override
  State<AddTransactionPage> createState() => _AddTransactionPageState();
}

final Map<String, Color> categoryColors = {
  'Food & Drinks': Colors.brown,
  'Transport': Colors.blue,
  'Shopping': Colors.purple,
  'Entertainment': Colors.red,
  'Bills & Utilities': Colors.teal,
  'Health & Fitness': Colors.green,
  'Rent': Colors.orange,
  'Education': Colors.indigo,
  'Travel': Colors.cyan,
  'Groceries': Colors.lime,
  'Personal Care': Colors.pink,
  'Subscriptions': Colors.deepPurple,
  'EMI / Loan': Colors.red,
  'Others': Colors.grey,
  'Salary': Colors.green,
  'Bonus': Colors.orange,
  'Investments / Interest': Colors.blue,
  'Freelance / Side Hustle': Colors.pink,
  'Rental Income': Colors.teal,
  'Gift / Cashback': Colors.amber,
};

class _AddTransactionPageState extends State<AddTransactionPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _newCategoryController = TextEditingController();

  String _selectedCategory = '';
  String? _selectedAccountId;   // Firestore doc ID of selected account
  String _selectedAccountName = '';
  DateTime _selectedDate = DateTime.now();

  bool _isRecurring = false;
  List<int> _selectedDays = [];

  // Loaded from Firestore accounts subcollection
  List<Map<String, dynamic>> _accounts = [];
  bool _accountsLoading = true;

  List<String> expenseCategories = [
    'Food & Drinks', 'Transport', 'Shopping', 'Entertainment',
    'Bills & Utilities', 'Health & Fitness', 'Rent', 'Education',
    'Travel', 'Groceries', 'Personal Care', 'Subscriptions',
    'EMI / Loan', 'Others',
  ];

  List<String> incomeCategories = [
    'Salary', 'Investments / Interest', 'Freelance / Side Hustle',
    'Bonus', 'Rental Income', 'Gift / Cashback', 'Others',
  ];

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final Color primaryBlue = const Color(0xFF083549);
  final Color accentRed = Colors.redAccent;

  @override
  void initState() {
    super.initState();
    final currentCategories =
        widget.type == 'income' ? incomeCategories : expenseCategories;
    _selectedCategory =
        currentCategories.isNotEmpty ? currentCategories.first : 'Others';
    _loadAccounts();
  }

  // ── Load accounts from Firestore ──────────────────────────────
  Future<void> _loadAccounts() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final snap = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('accounts')
        .orderBy('createdAt')
        .get();

    if (!mounted) return;

    final loaded = snap.docs.map((d) => {
      'id': d.id,
      'name': d['name'] as String,
      'type': d['type'] as String,
      'balance': (d['balance'] as num).toDouble(),
    }).toList();

    setState(() {
      _accounts = loaded;
      _accountsLoading = false;
      if (loaded.isNotEmpty) {
        _selectedAccountId = loaded.first['id'] as String;
        _selectedAccountName = loaded.first['name'] as String;
      }
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _newCategoryController.dispose();
    super.dispose();
  }

  // ── Save transaction ──────────────────────────────────────────
  Future<void> _saveTransaction() async {
    final user = _auth.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not logged in')),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    if (_isRecurring && _selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select at least one day for recurring')),
      );
      return;
    }

    final double amount = double.parse(_amountController.text);
    final String description = _descriptionController.text.trim();

    try {
      // 1️⃣ Save transaction
      await _firestore.collection('transactions').add({
        'uid': user.uid,
        'type': widget.type,
        'amount': amount,
        'category': _selectedCategory,
        'account': _selectedAccountName,
        'accountId': _selectedAccountId,
        'description': description,
        'date': Timestamp.fromDate(_selectedDate),
        'isRecurring': _isRecurring,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 2️⃣ Recurring payment
      if (_isRecurring && widget.type == 'expense') {
        await _firestore.collection('recurring_payments').add({
          'uid': user.uid,
          'category': _selectedCategory,
          'amount': amount,
          'account': _selectedAccountName,
          'description': description,
          'days': _selectedDays,
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // 3️⃣ Update budget spent
      if (widget.type == 'expense') {
  final budgetQuery = await _firestore
      .collection('budgets')
      .where('uid', isEqualTo: user.uid)
      .where('category', isEqualTo: _selectedCategory.toLowerCase())
      .limit(1)
      .get();

  if (budgetQuery.docs.isNotEmpty) {
    final budgetDoc = budgetQuery.docs.first;

    await _firestore
        .collection('budgets')
        .doc(budgetDoc.id)
        .update({'spent': FieldValue.increment(amount)});

    final updatedBudgetQuery = await _firestore
        .collection('budgets')
        .where('uid', isEqualTo: user.uid)
        .where('category', isEqualTo: _selectedCategory.toLowerCase())
        .limit(1)
        .get();

    await BudgetNotificationHelper.checkBudgetAlerts(
      updatedBudgetQuery.docs,
    );
  }
}
      // 4️⃣ Update account balance
      if (_selectedAccountId != null) {
        final accountRef = _firestore
            .collection('users')
            .doc(user.uid)
            .collection('accounts')
            .doc(_selectedAccountId);

        await _firestore.runTransaction((txn) async {
          final snap = await txn.get(accountRef);
          if (!snap.exists) return;
          final current = (snap['balance'] as num).toDouble();
          final updated = widget.type == 'income'
              ? current + amount
              : current - amount;
          txn.update(accountRef, {'balance': updated});
        });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaction added successfully')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  // ── Add category dialog ───────────────────────────────────────
  void _addNewCategory() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add New Category'),
        content: TextField(
          controller: _newCategoryController,
          decoration:
              const InputDecoration(hintText: 'Enter category name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryBlue),
            onPressed: () {
              final newCat = _newCategoryController.text.trim();
              if (newCat.isNotEmpty) {
                setState(() {
                  if (widget.type == 'income') {
                    if (!incomeCategories.contains(newCat))
                      incomeCategories.add(newCat);
                  } else {
                    if (!expenseCategories.contains(newCat))
                      expenseCategories.add(newCat);
                  }
                  _selectedCategory = newCat;
                  categoryColors.putIfAbsent(newCat, () {
                    final r = Random();
                    return Color.fromARGB(255,
                        r.nextInt(156) + 100,
                        r.nextInt(156) + 100,
                        r.nextInt(156) + 100);
                  });
                });
              }
              _newCategoryController.clear();
              Navigator.pop(ctx);
            },
            child: const Text('Add', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── Recurring day picker ──────────────────────────────────────
  void _showDayPicker() {
    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    List<int> tempDays = List.from(_selectedDays);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => StatefulBuilder(builder: (context, setSheet) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Select Recurring Days',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: primaryBlue)),
              const SizedBox(height: 8),
              const Text('Transaction will auto-repeat on selected days',
                  style: TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: List.generate(7, (index) {
                  final dayNumber = index + 1;
                  final isSelected = tempDays.contains(dayNumber);
                  return ChoiceChip(
                    label: Text(dayNames[index]),
                    selected: isSelected,
                    selectedColor: primaryBlue,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                    onSelected: (selected) {
                      setSheet(() {
                        if (selected) {
                          tempDays.add(dayNumber);
                        } else {
                          tempDays.remove(dayNumber);
                        }
                      });
                    },
                  );
                }),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () {
                    setState(() => _selectedDays = tempDays);
                    Navigator.pop(context);
                  },
                  child: const Text('Confirm Days',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  // ── Build ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final currentCategories =
        widget.type == 'income' ? incomeCategories : expenseCategories;

    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final selectedDayLabels =
        _selectedDays.map((d) => dayNames[d - 1]).join(', ');

    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryBlue,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.type == 'expense' ? 'Add Expense' : 'Add Income',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [

              // ── AMOUNT ──────────────────────────────────────
              const Text('Amount',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Enter amount',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: accentRed)),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Amount required';
                  if (double.tryParse(value) == null)
                    return 'Enter a valid number';
                  return null;
                },
              ),

              const SizedBox(height: 20),

              // ── CATEGORY ────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Category',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  TextButton.icon(
                    onPressed: _addNewCategory,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Category'),
                    style:
                        TextButton.styleFrom(foregroundColor: accentRed),
                  ),
                ],
              ),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                items: currentCategories
                    .toSet()
                    .map((c) =>
                        DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (value) =>
                    setState(() => _selectedCategory = value!),
              ),

              const SizedBox(height: 20),

              // ── ACCOUNT ─────────────────────────────────────
              const Text('Account',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),

              if (_accountsLoading)
                const LinearProgressIndicator()
              else if (_accounts.isEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: Colors.orange, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'No accounts set up yet. Go to Accounts to add one.',
                          style:
                              TextStyle(color: Colors.orange, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                )
              else
                DropdownButtonFormField<String>(
                  value: _selectedAccountId,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  items: _accounts.map((a) {
                    IconData icon;
                    switch (a['type']) {
                      case 'Bank':
                        icon = Icons.account_balance;
                        break;
                      case 'Wallet':
                        icon = Icons.account_balance_wallet;
                        break;
                      default:
                        icon = Icons.payments_outlined;
                    }
                    return DropdownMenuItem<String>(
                      value: a['id'] as String,
                      child: Row(
                        children: [
                          Icon(icon, size: 16, color: Colors.grey),
                          const SizedBox(width: 8),
                          Text(
                            '${a['name']}  ·  ₹${(a['balance'] as double).toStringAsFixed(0)}',
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (id) {
                    if (id == null) return;
                    final acc = _accounts.firstWhere((a) => a['id'] == id);
                    setState(() {
                      _selectedAccountId = id;
                      _selectedAccountName = acc['name'] as String;
                    });
                  },
                ),

              const SizedBox(height: 20),

              // ── DESCRIPTION ─────────────────────────────────
              const Text('Description',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Add a note (optional)',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: accentRed)),
                ),
              ),

              const SizedBox(height: 20),

              // ── DATE ────────────────────────────────────────
              const Text('Date',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                    '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}'),
                trailing:
                    Icon(Icons.calendar_today, color: primaryBlue),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                    builder: (context, child) => Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: ColorScheme.light(
                          primary: primaryBlue,
                          onPrimary: Colors.white,
                          onSurface: Colors.black,
                        ),
                        textButtonTheme: TextButtonThemeData(
                          style: TextButton.styleFrom(
                              foregroundColor: accentRed),
                        ),
                      ),
                      child: child!,
                    ),
                  );
                  if (picked != null)
                    setState(() => _selectedDate = picked);
                },
              ),

              // ── RECURRING (expense only) ─────────────────────
              if (widget.type == 'expense') ...[
                const SizedBox(height: 10),
                const Divider(),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Recurring Payment',
                            style:
                                TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text('Auto-repeat on selected days',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600)),
                      ],
                    ),
                    Switch(
                      value: _isRecurring,
                      activeColor: primaryBlue,
                      onChanged: (val) {
                        setState(() {
                          _isRecurring = val;
                          if (val && _selectedDays.isEmpty) {
                            Future.delayed(
                                const Duration(milliseconds: 200),
                                _showDayPicker);
                          }
                        });
                      },
                    ),
                  ],
                ),
                if (_isRecurring) ...[
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: _showDayPicker,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: primaryBlue.withOpacity(0.4)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.repeat, color: primaryBlue, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _selectedDays.isEmpty
                                  ? 'Tap to select days'
                                  : selectedDayLabels,
                              style: TextStyle(
                                color: _selectedDays.isEmpty
                                    ? Colors.grey
                                    : primaryBlue,
                                fontWeight: _selectedDays.isEmpty
                                    ? FontWeight.normal
                                    : FontWeight.w600,
                              ),
                            ),
                          ),
                          Icon(Icons.chevron_right,
                              color: Colors.grey.shade400),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                const Divider(),
              ],

              const SizedBox(height: 24),

              // ── SAVE ────────────────────────────────────────
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _saveTransaction,
                child: const Text('Save Transaction',
                    style: TextStyle(fontSize: 16, color: Colors.white)),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}