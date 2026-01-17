import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ExpensesPage extends StatefulWidget {
  const ExpensesPage({super.key});

  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage> {
  final List<Map<String, dynamic>> _expenses = [
    {
      'category': 'Grocery Shopping',
      'type': 'Food',
      'date': '01 Nov 2024',
      'amount': 2500.0,
    },
    {
      'category': 'Electricity Bill',
      'type': 'Utilities',
      'date': '30 Oct 2024',
      'amount': 1800.0,
    },
    {
      'category': 'Movie Tickets',
      'type': 'Entertainment',
      'date': '28 Oct 2024',
      'amount': 600.0,
    },
    {
      'category': 'Uber Ride',
      'type': 'Transport',
      'date': '27 Oct 2024',
      'amount': 350.0,
    },
  ];

  double get totalExpense =>
      _expenses.fold(0, (sum, item) => sum + (item['amount'] as double));

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
          offset.dx, offset.dy, screenSize.width - offset.dx, 0),
      items: [
        const PopupMenuItem(
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

  void _deleteExpense(int index) {
    setState(() {
      _expenses.removeAt(index);
    });
  }

  // 🧩 Add Expense Function
  void _addExpense() {
    final categoryController = TextEditingController();
    final typeController = TextEditingController();
    final amountController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Add Expense"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: categoryController,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: typeController,
                  decoration: const InputDecoration(
                    labelText: 'Type (e.g., Food, Transport)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
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
                          setState(() => selectedDate = picked);
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
              onPressed: () {
                if (categoryController.text.isEmpty ||
                    typeController.text.isEmpty ||
                    amountController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please fill all fields'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                  return;
                }

                setState(() {
                  _expenses.add({
                    'category': categoryController.text,
                    'type': typeController.text,
                    'date':
                        "${selectedDate.day.toString().padLeft(2, '0')} ${_monthName(selectedDate.month)} ${selectedDate.year}",
                    'amount': double.parse(amountController.text),
                  });
                });

                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0A3D52),
              ),
              child: const Text("Save",style: TextStyle(color: Colors.white),),
            ),
          ],
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
              onTapDown: (TapDownDetails details) {
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
          // Title below app bar
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

          // Total Expenses Card
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Expenses:',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                Text(
                  '₹${totalExpense.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: darkBlue),
                ),
              ],
            ),
          ),

          // Expense list
          Expanded(
            child: ListView.builder(
              itemCount: _expenses.length,
              itemBuilder: (context, index) {
                final e = _expenses[index];
                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: darkBlue,
                      child: Text(
                        e['category'][0],
                        style: const TextStyle(color: Colors.white, fontSize: 18),
                      ),
                    ),
                    title: Text(
                      e['category'],
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text('${e['type']} • ${e['date']}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '₹${e['amount']}',
                          style: const TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.bold),
                        ),
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

      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color.fromARGB(255, 146, 33, 33),
        onPressed: _addExpense,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Add Expense',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}
