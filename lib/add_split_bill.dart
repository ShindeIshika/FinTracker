import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddSplitBillPage extends StatefulWidget {
  const AddSplitBillPage({super.key});

  @override
  State<AddSplitBillPage> createState() => _AddSplitBillPageState();
}

class _AddSplitBillPageState extends State<AddSplitBillPage> {

  final titleController = TextEditingController();
  final totalController = TextEditingController();
  final nameController = TextEditingController();
  final paidController = TextEditingController();
  final usernameController = TextEditingController();

  bool isUser = false;

  List<Map<String, dynamic>> participants = [];

  Future<void> addParticipant() async {

  String uid = "";

  if (isUser && usernameController.text.isNotEmpty) {

    var query = await FirebaseFirestore.instance
        .collection("users")
        .where("username", isEqualTo: usernameController.text)
        .get();

    if (query.docs.isNotEmpty) {
      uid = query.docs.first.id;
    }
  }

  participants.add({
    "name": nameController.text,
    "paid": double.parse(paidController.text),
    "isuser": isUser,
    "username": usernameController.text,
    "uid": uid
  });

  nameController.clear();
  paidController.clear();
  usernameController.clear();

  setState(() {});
}
  Future<void> saveBill() async {

    final user = FirebaseAuth.instance.currentUser;

    await FirebaseFirestore.instance.collection("split_bills").add({
  "title": titleController.text,
  "total": double.parse(totalController.text),
  "createdBy": user!.uid,
  "date": Timestamp.now(),
  "participants": participants,
  "participantUIDs": participants
      .where((p) => p["isUser"] == true)
      .map((p) => p["uid"])
      .toList(), // <-- NEW FIELD
});

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(title: const Text("Add Split Bill")),

      body: Padding(
        padding: const EdgeInsets.all(16),

        child: Column(

          children: [

            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: "Title"),
            ),

            TextField(
              controller: totalController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Total"),
            ),

            const SizedBox(height: 20),

            const Text("Add Participant"),

            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "Name"),
            ),

            TextField(
              controller: paidController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Amount Paid"),
            ),

            Row(
              children: [

                Checkbox(
                  value: isUser,
                  onChanged: (v) {
                    setState(() {
                      isUser = v!;
                    });
                  },
                ),

                const Text("App User")

              ],
            ),

            if (isUser)
              TextField(
                controller: usernameController,
                decoration: const InputDecoration(labelText: "Username"),
              ),

            ElevatedButton(
              onPressed: addParticipant,
              child: const Text("Add Participant"),
            ),

            Expanded(
              child: ListView.builder(

                itemCount: participants.length,

                itemBuilder: (context, index) {

                  var p = participants[index];

                  return ListTile(
                    title: Text(p['name']),
                    subtitle: Text("Paid ₹${p['paid']}"),
                  );
                },
              ),
            ),

            ElevatedButton(
              onPressed: saveBill,
              child: const Text("Save Bill"),
            )

          ],
        ),
      ),
    );
  }
}