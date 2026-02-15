import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddSplitBillPage extends StatefulWidget {
  const AddSplitBillPage({super.key});

  @override
  State<AddSplitBillPage> createState() => _AddSplitBillPageState();
}

class _AddSplitBillPageState extends State<AddSplitBillPage> {
  final _formKey = GlobalKey<FormState>();
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  
  final _titleController = TextEditingController();
  final _totalController = TextEditingController();
  List<Map<String, dynamic>> participants = [];
  int participantId = 0;

  void addParticipant() {
    setState(() {
      participants.add({
        'id': participantId++,
        'name': '',
        'share': 0.0,
        'paid': false,
      });
    });
  }

  void removeParticipant(int id) {
    setState(() {
      participants.removeWhere((p) => p['id'] == id);
    });
  }

  Future<void> _saveBill() async {
    if (!_formKey.currentState!.validate() || participants.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill all fields and add participants')),
        );
      }
      return;
    }

    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final billData = {
        'title': _titleController.text,
        'total': double.parse(_totalController.text),
        'participants': participants,
        'uid': user.uid,
        'createdAt': Timestamp.now(),
      };

      await _firestore.collection('split_bills').add(billData);
      
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Split Bill'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Bill Description',
                    prefixIcon: Icon(Icons.restaurant),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value!.isEmpty ? 'Enter bill description' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _totalController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Total Amount',
                    prefixText: '₹ ',
                    prefixIcon: Icon(Icons.attach_money),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value!.isEmpty ? 'Enter total amount' : null,
                ),
                const SizedBox(height: 24),
                const Text('Participants', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                
                ...participants.map((participant) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            initialValue: participant['name'],
                            decoration: const InputDecoration(
                              labelText: 'Name',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (value) {
                              participant['name'] = value;
                            },
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            initialValue: participant['share'].toString(),
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Share',
                              prefixText: '₹ ',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (value) {
                              participant['share'] = double.tryParse(value) ?? 0.0;
                            },
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => removeParticipant(participant['id']),
                        ),
                      ],
                    ),
                  ),
                )).toList(),
                
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: addParticipant,
                  icon: const Icon(Icons.person_add),
                  label: const Text('Add Participant'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A8A),
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saveBill,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A8A),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      'Create Split Bill',
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
