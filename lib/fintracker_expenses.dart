import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'category_service.dart';

class ExpensesPage extends StatefulWidget {
  const ExpensesPage({super.key});

  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage> {
  @override
  void initState() {
    super.initState();

    final user = _auth.currentUser;
    if (user != null) {
      // Load categories from budgets like "ishika"
      CategoryService.syncWithBudgets(user.uid);
      CategoryService.removeDuplicates();
    }
  }
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<String> get _categories => CategoryService.getAll();

  // ✅ Expenses
  final List<Map<String, dynamic>> _expenses = [
    {
      'category': 'Grocery Shopping',
      'type': 'food & drinks',
      'date': '01 Nov 2024',
      'amount': 2500.0,
    },
    {
      'category': 'Electricity Bill',
      'type': 'bills & utilities',
      'date': '30 Oct 2024',
      'amount': 1800.0,
    },
    {
      'category': 'Movie Tickets',
      'type': 'entertainment',
      'date': '28 Oct 2024',
      'amount': 600.0,
    },
    {
      'category': 'Uber Ride',
      'type': 'transport',
      'date': '27 Oct 2024',
      'amount': 350.0,
    },
  ];

  // ✅ Total
  double get totalExpense => _expenses.fold(
      0, (sum, item) => sum + (item['amount'] as num).toDouble());

  // 🔐 Logout
  void _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  void _showLogoutMenu(BuildContext context, Offset offset) async {
    final screenSize = MediaQuery.of(context).size;

    await showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy,
        screenSize.width - offset.dx,
        0,
      ),
      items: const [
        PopupMenuItem(
          value: 'logout',
          child: Row(
            children: [
              Icon(Icons.logout, color: Color.fromARGB(255, 146, 33, 33)),
              SizedBox(width: 10),
              Text('Logout'),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'logout') _logout();
    });
  }

  // ❌ Delete Expense
  void _deleteExpense(int index) {
    setState(() {
      _expenses.removeAt(index);
    });
  }

Future<void> showCreateBudgetDialog({
  required String category,
  required double amount,
}) async {
  final normalizedCategory = category.toLowerCase();

  await showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text("Create Budget"),
      content: Text(
        "Create a budget for ${category[0].toUpperCase() + category.substring(1)} with ₹${(amount * 5).toStringAsFixed(0)} limit?",
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: () async {
            final user = _auth.currentUser;
            if (user == null) return;

            await _firestore.collection('budgets').add({
              'uid': user.uid,
              'category': normalizedCategory,
              'limit': amount * 5,
              'spent': amount, // ✅ deduct FIRST expense instantly 🔥
            });

            Navigator.pop(context);
          },
          child: const Text("Create"),
        ),
      ],
    ),
  );
}
  // ➕ Add Category
  void _showAddCategoryDialog() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Add Category"),
        content: TextField(
          controller: controller,
          decoration:
              const InputDecoration(hintText: "Enter category name"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              final newCategory = controller.text.trim();

              if (newCategory.isEmpty) return;

              final added = CategoryService.addCategory(newCategory);
              CategoryService.notifier.notifyListeners(); // Ensure Expenses Page is updated

              if (!added) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Category already exists")),
                );
                return;
              }

              // refresh UI
              setState(() {});

              Navigator.pop(context);
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }


  // ➕ Add Expense
  void _addExpense() {
    final categoryController = TextEditingController();
    final noteController = TextEditingController();
    final amountController = TextEditingController();

    DateTime selectedDate = DateTime.now();
    String selectedCategory = CategoryService.getAll().isNotEmpty
      ? CategoryService.getAll().first
      : '';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text("Add Expense"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Expense Name
                    TextField(
                      controller: categoryController,
                      decoration: const InputDecoration(
                        labelText: "Expense Name",
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Category Dropdown
ValueListenableBuilder<List<String>>(
  valueListenable: CategoryService.notifier,
  builder: (context, categories, _) {
    final uniqueCategories = categories.toSet().toList();  // Remove duplicates

    if (uniqueCategories.isEmpty) {
      return const Text("No categories available");
    }

    if (!uniqueCategories.contains(selectedCategory)) {
      selectedCategory = uniqueCategories.first;
    }

    return DropdownButtonFormField<String>(
      value: selectedCategory,
      items: uniqueCategories.map((cat) {
        return DropdownMenuItem(
          value: cat,
          child: Text(
            cat[0].toUpperCase() + cat.substring(1),  // Capitalize category name
          ),
        );
      }).toList(),
      onChanged: (value) {
        setStateDialog(() {
          selectedCategory = value!;
        });
      },
      decoration: const InputDecoration(labelText: "Category"),
    );
  },
)
                    const SizedBox(height: 8),

                    // Amount
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: "Amount"),
                    ),

                    // Note
                    TextField(
                      controller: noteController,
                      decoration: const InputDecoration(labelText: "Note"),
                    ),
                    const SizedBox(height: 10),

                    // Date Picker
                    Row(
                      children: [
                        Text(
                          'Date: ${selectedDate.day}-${selectedDate.month}-${selectedDate.year}',
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.calendar_today),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (picked != null) {
                              setStateDialog(() => selectedDate = picked);
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (categoryController.text.isEmpty ||
                        amountController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please fill required fields'),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                      return;
                    }

                    final amount = double.tryParse(amountController.text) ?? 0;
                    final categoryName = selectedCategory;

                    final user = _auth.currentUser;
                    if (user == null) return;

                    // Check budget
                    final existingBudget = await _firestore
                        .collection('budgets')
                        .where('uid', isEqualTo: user.uid)
                        .where('category', isEqualTo: categoryName.toLowerCase())
                        .get();

                    if (existingBudget.docs.isNotEmpty) {
                      // Deduct from budget
                      final doc = existingBudget.docs.first;
                      await _firestore
                          .collection('budgets')
                          .doc(doc.id)
                          .update({
                        'spent': FieldValue.increment(amount),
                      });
                    } else {
                      // Prompt to create budget
                      await showCreateBudgetDialog(
                        category: categoryName,
                        amount: amount,
                      );
                    }

                    // Add expense locally
                    setState(() {
                      _expenses.add({
                        'category': categoryController.text,
                        'type': categoryName,
                        'date':
                            "${selectedDate.day.toString().padLeft(2, '0')} ${_monthName(selectedDate.month)} ${selectedDate.year}",
                        'amount': amount,
                        'note': noteController.text,
                      });
                    });

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

  String _monthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    const darkBlue = Color(0xFF0A3D52);

    return Scaffold(
      backgroundColor: Colors.blueGrey[50],
      appBar: AppBar(
        backgroundColor: darkBlue,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'FinTracker',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: Colors.white,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: GestureDetector(
              onTapDown: (details) {
                _showLogoutMenu(context, details.globalPosition);
              },
              child: const CircleAvatar(
                backgroundColor: Colors.white24,
                child: Icon(Icons.person, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
        body: Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [

    // ✅ Categories Section
    Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Categories",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton.icon(
                onPressed: _showAddCategoryDialog,
                icon: const Icon(Icons.add, color: Colors.red),
                label: const Text(
                  "Add Category",
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
          SizedBox(
            height: 150,
            child: ListView.builder(
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                return ListTile(
                  dense: true,
                  title: Text(category),
                );
              },
            ),
          ),
        ],
      ),
    ),

    // Expenses Title
    const Padding(
      padding: EdgeInsets.fromLTRB(16, 20, 0, 8),
      child: Text(
        'Expenses',
        style: TextStyle(
          color: darkBlue,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),

    // Total Card
    Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4)
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Total Expenses:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(
            '₹${totalExpense.toStringAsFixed(2)}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: darkBlue,
            ),
          ),
        ],
      ),
    ),

    // Expense List
    Expanded(
    child: ListView.builder(
      itemCount: _expenses.length,
      itemBuilder: (context, index) {
        final e = _expenses[index];

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: darkBlue,
              child: Text(
                e['category'][0].toUpperCase(),
                style: const TextStyle(color: Colors.white),
              ),
            ),
            title: Text(e['category']),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${e['type']} • ${e['date']}'),
                if (e['note'] != null && e['note'].toString().isNotEmpty)
                  Text(
                    e['note'],
                    style: const TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('₹${e['amount']}'),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                  onPressed: () => _deleteExpense(index),
                ),
              ],
            ),
          ),
        );
      },
    ),
  ),
  ],
),
      floatingActionButton:
          FloatingActionButton.extended(
        backgroundColor:
            const Color.fromARGB(255, 146, 33, 33),
        onPressed: _addExpense,
        icon: const Icon(Icons.add,
            color: Colors.white),
        label: const Text(
          'Add Expense',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}