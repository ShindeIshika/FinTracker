import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';

class AddTransactionPage extends StatefulWidget {
  final String type; // 'income' or 'expense'

  const AddTransactionPage({super.key, required this.type});

  @override
  State<AddTransactionPage> createState() => _AddTransactionPageState();
}

// Category colors for PieChart (can be moved to global file)
final Map<String, Color> categoryColors = {
  'Food': const Color.fromARGB(255, 91, 54, 0),
  'Travel': const Color.fromARGB(255, 2, 54, 97),
  'Shopping': const Color.fromARGB(255, 68, 2, 79),
  'Bills': const Color.fromARGB(255, 156, 12, 2),
  'Salary': const Color.fromARGB(255, 0, 100, 90),
  'Bonus': Colors.green,
  'Interest': Colors.blue,
  'Other': Colors.grey,
  'General': Colors.purple,
};

class _AddTransactionPageState extends State<AddTransactionPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _newCategoryController = TextEditingController();
  

  bool _isRecurring = false;
final String _repeatType = 'weekly'; // daily / weekly / custom
final List<int> _selectedDays = [];


  String _selectedCategory = '';
  String _selectedAccount = 'Cash';
  DateTime _selectedDate = DateTime.now();

  // Separate categories for income and expense
  List<String> incomeCategories = ['Salary', 'Bonus', 'Interest', 'Other'];
  List<String> expenseCategories = ['Food', 'Travel', 'Shopping', 'Bills', 'General'];

  final List<String> accounts = ['Cash', 'Bank', 'UPI'];

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final Color primaryBlue = const Color(0xFF083549);
  final Color accentRed = Colors.redAccent;

  @override
  void initState() {
    super.initState();
    // Initialize selected category to first in the list for the type
    final currentCategories =
        widget.type == 'income' ? incomeCategories : expenseCategories;
    _selectedCategory = currentCategories.isNotEmpty ? currentCategories.first : 'Other';
  }

  Future<void> _saveTransaction() async {
    final user = _auth.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User not logged in")),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;
    if (_isRecurring && _selectedDays.isEmpty) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text("Please select at least one day")),
  );
  return;
}


    final double amount = double.parse(_amountController.text);
    try {
  // 1️⃣ Always save main transaction
  final transactionRef = await _firestore.collection('transactions').add({
    'uid': user.uid,
    'type': widget.type,
    'amount': amount,
    'category': _selectedCategory,
    'account': _selectedAccount,
    'date': Timestamp.fromDate(_selectedDate),
    'createdAt': FieldValue.serverTimestamp(),
  });

  // 2️⃣ If recurring is ON → also save recurring rule
  if (_isRecurring) {
    await _firestore.collection('recurring_payments').add({
      'uid': user.uid,
      'transactionId': transactionRef.id,
      'type': widget.type,
      'amount': amount,
      'category': _selectedCategory,
      'account': _selectedAccount,
      'startDate': Timestamp.fromDate(_selectedDate),
      'repeatType': _repeatType,
      'days': _selectedDays,
      'isActive': true,
      'lastGenerated': null,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // 3️⃣ Budget logic (UNCHANGED)
  if (widget.type == 'expense') {
    final budgetQuery = await _firestore
        .collection('budgets')
        .where('uid', isEqualTo: user.uid)
        .where('category', isEqualTo: _selectedCategory)
        .limit(1)
        .get();

    if (budgetQuery.docs.isNotEmpty) {
      final budgetDoc = budgetQuery.docs.first;
      await _firestore.collection('budgets').doc(budgetDoc.id).update({
        'spent': FieldValue.increment(amount),
      });
    }
  }

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text("Transaction added successfully")),
  );

  Navigator.pop(context, true);
}

    catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  void _addNewCategory() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add New Category'),
        content: TextField(
          controller: _newCategoryController,
          decoration: const InputDecoration(hintText: 'Enter category name'),
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
                    if (!incomeCategories.contains(newCat)) incomeCategories.add(newCat);
                  } else {
                    if (!expenseCategories.contains(newCat)) expenseCategories.add(newCat);
                  }
                  _selectedCategory = newCat;

                  // Generate unique random color if not exists
                  categoryColors.putIfAbsent(newCat, () {
                    final random = Random();
                    return Color.fromARGB(
                      255,
                      random.nextInt(156) + 100,
                      random.nextInt(156) + 100,
                      random.nextInt(156) + 100,
                    );
                  });
                });
              }
              _newCategoryController.clear();
              Navigator.pop(ctx);
            },
            child: const Text(
              'Add',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentCategories =
        widget.type == 'income' ? incomeCategories : expenseCategories;

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
              /// AMOUNT
              const Text(
                'Amount',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Enter amount',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: primaryBlue),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: accentRed),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Amount required';
                  if (double.tryParse(value) == null) return 'Enter a valid number';
                  return null;
                },
              ),

              const SizedBox(height: 20),

              /// CATEGORY
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Category',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextButton.icon(
                    onPressed: _addNewCategory,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Category'),
                    style: TextButton.styleFrom(foregroundColor: accentRed),
                  ),
                ],
              ),
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                items: currentCategories
                    .toSet()
                    .map(
                      (c) => DropdownMenuItem(
                        value: c,
                        child: Text(c),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = value!;
                  });
                },
              ),

              const SizedBox(height: 20),

              /// ACCOUNT
              const Text(
                'Account',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              DropdownButtonFormField<String>(
                initialValue: _selectedAccount,
                items: accounts
                    .map(
                      (a) => DropdownMenuItem(
                        value: a,
                        child: Text(a),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedAccount = value!;
                  });
                },
              ),

             const SizedBox(height: 20),

SwitchListTile(
  title: const Text(
    "Make Payment Recurring?",
    style: TextStyle(fontWeight: FontWeight.bold),
  ),
  value: _isRecurring,
  activeThumbColor: accentRed,
  activeTrackColor: accentRed.withValues(alpha: 0.5),

  onChanged: (value) {
    setState(() {
      _isRecurring = value;
    });
  },
),

if (_isRecurring) ...[
  const SizedBox(height: 10),
  const Text(
    "Repeat On",
    style: TextStyle(fontWeight: FontWeight.bold),
  ),
  const SizedBox(height: 10),

  Wrap(
    spacing: 8,
    children: List.generate(7, (index) {
      final dayNumber = index + 1;
      final dayName = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"][index];
      final isSelected = _selectedDays.contains(dayNumber);

      return ChoiceChip(
        label: Text(dayName),
        selected: isSelected,
        selectedColor: accentRed,
        onSelected: (selected) {
          setState(() {
            if (selected) {
              _selectedDays.add(dayNumber);
            } else {
              _selectedDays.remove(dayNumber);
            }
          });
        },
      );
    }),
  ),
],

const SizedBox(height: 20),




              const SizedBox(height: 20),

              /// DATE
              const Text(
                'Date',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                ),
                trailing: Icon(Icons.calendar_today, color: primaryBlue),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                    builder: (context, child) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: ColorScheme.light(
                            primary: primaryBlue,
                            onPrimary: Colors.white,
                            onSurface: Colors.black,
                          ),
                          textButtonTheme: TextButtonThemeData(
                            style: TextButton.styleFrom(foregroundColor: accentRed),
                          ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (picked != null) {
                    setState(() {
                      _selectedDate = picked;
                    });
                  }
                },
              ),

              const SizedBox(height: 30),

              /// SAVE BUTTON
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: _saveTransaction,
                child: const Text(
                  'Save Transaction',
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}