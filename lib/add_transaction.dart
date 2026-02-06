import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddTransactionPage extends StatefulWidget {
  final String type; // 'income' or 'expense'

  const AddTransactionPage({super.key, required this.type});

  @override
  State<AddTransactionPage> createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends State<AddTransactionPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _newCategoryController = TextEditingController();

  String _selectedCategory = 'General';
  String _selectedAccount = 'Cash';
  DateTime _selectedDate = DateTime.now();

  final List<String> categories = [
    'Food',
    'Travel',
    'Shopping',
    'Bills',
    'Salary',
    'General',
  ];

  final List<String> accounts = ['Cash', 'Bank', 'GPay'];

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final Color primaryBlue = const Color(0xFF083549);
  final Color accentRed = Colors.redAccent;

  Future<void> _saveTransaction() async {
  final user = _auth.currentUser;

  if (user == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("User not logged in")),
    );
    return;
  }

  if (!_formKey.currentState!.validate()) {
    return;
  }

  final double amount = double.parse(_amountController.text);

  try {
    // 1️⃣ Save transaction
    await _firestore.collection('transactions').add({
      'uid': user.uid,
      'type': widget.type, // 'income' or 'expense'
      'amount': amount,
      'category': _selectedCategory,
      'account': _selectedAccount,
      'date': Timestamp.fromDate(_selectedDate),
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 2️⃣ Update budget ONLY if EXPENSE
    if (widget.type == 'expense') {
      final budgetQuery = await _firestore
          .collection('budgets')
          .where('uid', isEqualTo: user.uid)
          .where('category', isEqualTo: _selectedCategory)
          .limit(1)
          .get();

      if (budgetQuery.docs.isNotEmpty) {
        final budgetDoc = budgetQuery.docs.first;

        await _firestore
            .collection('budgets')
            .doc(budgetDoc.id)
            .update({
          'spent': FieldValue.increment(amount),
        });
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Transaction added successfully")),
    );

    Navigator.pop(context, true);
  } catch (e) {
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
            onPressed: () {
              Navigator.pop(ctx);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryBlue),
            onPressed: () {
              final newCat = _newCategoryController.text.trim();
              if (newCat.isNotEmpty && !categories.contains(newCat)) {
                setState(() {
                  categories.add(newCat);
                  _selectedCategory = newCat;
                });
              }
              _newCategoryController.clear();
              Navigator.pop(ctx);
            },
            child: const Text('Add',
            style: TextStyle(
              color: Colors.white,
            ),),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryBlue,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.type == 'expense' ? 'Add Expense' : 'Add Income',
          style: TextStyle(color: Colors.white),
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
                  if (value == null || value.isEmpty) {
                    return 'Amount required';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Enter a valid number';
                  }
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
                value: _selectedCategory,
                items: categories
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
                value: _selectedAccount,
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
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
