import 'package:flutter/material.dart';

class SplitBillPage extends StatefulWidget {
  const SplitBillPage({super.key});

  @override
  State<SplitBillPage> createState() => _SplitBillPageState();
}

class _SplitBillPageState extends State<SplitBillPage> {
  final TextEditingController _totalAmountController = TextEditingController();
  final List<TextEditingController> _nameControllers = [];
  double _splitAmount = 0.0;

  void _addPerson() {
    setState(() {
      _nameControllers.add(TextEditingController());
    });
  }

  void _removePerson(int index) {
    setState(() {
      _nameControllers.removeAt(index);
    });
  }

  void _calculateSplit() {
    if (_nameControllers.isEmpty || _totalAmountController.text.isEmpty) return;
    final total = double.tryParse(_totalAmountController.text) ?? 0.0;
    final perPerson = total / _nameControllers.length;

    setState(() {
      _splitAmount = perPerson;
    });
  }

  @override
  void dispose() {
    _totalAmountController.dispose();
    for (var controller in _nameControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const darkBlue = Color(0xFF0A3D52);

    return Scaffold(
      backgroundColor: Colors.blueGrey[50],
      appBar: AppBar(
        backgroundColor: darkBlue,
        title: const Text(
          'Split the Bill',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Total amount
              const Text(
                'Enter Total Amount:',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: darkBlue,
                    fontSize: 16),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _totalAmountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'e.g. 1200',
                  prefixIcon: const Icon(Icons.currency_rupee),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // People section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'People:',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: darkBlue,
                        fontSize: 16),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: darkBlue,
                    ),
                    onPressed: _addPerson,
                    icon: const Icon(Icons.person_add, color: Colors.white),
                    label: const Text('Add', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // List of people
              Column(
                children: _nameControllers.asMap().entries.map((entry) {
                  final index = entry.key;
                  final controller = entry.value;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: controller,
                            decoration: InputDecoration(
                              hintText: 'Person ${index + 1}',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.redAccent),
                          onPressed: () => _removePerson(index),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 20),

              // Calculate Button
              Center(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 146, 33, 33),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _calculateSplit,
                  child: const Text(
                    'Split Bill',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              if (_splitAmount > 0)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 4),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Each person should pay:',
                        style: TextStyle(
                            color: darkBlue, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '₹${_splitAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: darkBlue,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
