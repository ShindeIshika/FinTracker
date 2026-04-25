import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddEditBillPage extends StatefulWidget {
  final DocumentSnapshot? billDoc;

  const AddEditBillPage({super.key, this.billDoc});

  @override
  State<AddEditBillPage> createState() => _AddEditBillPageState();
}

class _AddEditBillPageState extends State<AddEditBillPage> {
  final _formKey = GlobalKey<FormState>();
  final user = FirebaseAuth.instance.currentUser;

  final nameController = TextEditingController();
  final amountController = TextEditingController();

  String frequency = "Monthly";
  int interval = 1;
  DateTime selectedDueDate = DateTime.now();

  bool get isEditing => widget.billDoc != null;

  @override
  void initState() {
    super.initState();

    if (isEditing) {
      final data = widget.billDoc!.data() as Map<String, dynamic>;

      nameController.text = data['name'] ?? "";
      amountController.text = (data['amount'] ?? 0).toString();

      frequency = data['frequency'] ?? "Monthly";
      interval = data['interval'] ?? 1;

      if (data['nextDueDate'] != null) {
        selectedDueDate =
            (data['nextDueDate'] as Timestamp).toDate();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? "Edit Bill" : "Add Bill"),
        backgroundColor: const Color(0xFF203A43),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF0F2027),
              Color(0xFF203A43),
              Color(0xFF2C5364),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              width: 500,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    blurRadius: 25,
                    color: Colors.black26,
                    offset: Offset(0, 12),
                  )
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    _buildInput("Bill Name", nameController),
                    const SizedBox(height: 18),

                    _buildInput("Amount", amountController, isNumber: true),
                    const SizedBox(height: 18),

                    const SizedBox(height: 4),

                    /// Due Date Picker
                    const Text(
                      "Next Due Date",
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),

                    GestureDetector(
                      onTap: _pickDate,
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          "${selectedDueDate.day}/${selectedDueDate.month}/${selectedDueDate.year}",
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    /// Frequency
                    const Text(
                      "Frequency",
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),

                    DropdownButtonFormField<String>(
                      initialValue: frequency,
                      decoration: _dropdownDecoration(),
                      items: const [
                        DropdownMenuItem(
                          value: "Monthly",
                          child: Text("Monthly"),
                        ),
                        DropdownMenuItem(
                          value: "Yearly",
                          child: Text("Yearly"),
                        ),
                      ],
                      onChanged: (val) {
                        setState(() {
                          frequency = val!;
                        });
                      },
                    ),

                    const SizedBox(height: 18),

                    /// Interval
                    const Text(
                      "Repeat Every",
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),

                    DropdownButtonFormField<int>(
                      initialValue: interval,
                      decoration: _dropdownDecoration(),
                      items: List.generate(
                        12,
                        (index) => DropdownMenuItem(
                          value: index + 1,
                          child: Text(
                              "${index + 1} ${frequency == "Monthly" ? "Month(s)" : "Year(s)"}"),
                        ),
                      ),
                      onChanged: (val) {
                        setState(() {
                          interval = val!;
                        });
                      },
                    ),

                    const SizedBox(height: 30),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.all(16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          backgroundColor: const Color(0xFF2C5364),
                        ),
                        onPressed: _saveBill,
                        child: Text(
                          isEditing ? "Update Bill" : "Add Bill",
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16),
                        ),
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDueDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        selectedDueDate = picked;
      });
    }
  }

  InputDecoration _dropdownDecoration() {
    return InputDecoration(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
      ),
    );
  }

  Widget _buildInput(String label,
      TextEditingController controller,
      {bool isNumber = false}) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : null,
      validator: (val) =>
          val == null || val.isEmpty ? "Required" : null,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  Future<void> _saveBill() async {
    if (!_formKey.currentState!.validate()) return;

    final data = {
      'uid': user!.uid,
      'name': nameController.text,
      'amount': double.parse(amountController.text),
      'frequency': frequency,
      'interval': interval,
      'nextDueDate': Timestamp.fromDate(selectedDueDate),
      'createdAt': FieldValue.serverTimestamp(),
    };

    if (isEditing) {
      await FirebaseFirestore.instance
          .collection('bills')
          .doc(widget.billDoc!.id)
          .update(data);
    } else {
      await FirebaseFirestore.instance
          .collection('bills')
          .add({
        ...data,
        'lastPaidDate': null,
      });
    }

    Navigator.pop(context);
  }
}
