import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'add_split_bill.dart';
import 'fintracker_login.dart';
import 'fintracker_transaction.dart';
import 'widgets/side_nav.dart';
import 'previous_tips.dart';
import 'recurring_payments.dart';
import 'fintracker_home.dart';
import 'fintracker_budget.dart';
import 'fintracker_bills.dart';

class SplitBillPage extends StatefulWidget {
  const SplitBillPage({super.key});

  @override
  State<SplitBillPage> createState() => _SplitBillPageState();
}

class _SplitBillPageState extends State<SplitBillPage> {

  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;
int selectedIndex = 4;
  double youOwe = 0;
  double theyOwe = 0;

  List<String> calculateSettlements(Map<String, dynamic> bill) {

  List participants = bill['participants'];
  double total = (bill['total'] as num).toDouble();

  double share = total / participants.length;

  List<Map<String, dynamic>> creditors = [];
  List<Map<String, dynamic>> debtors = [];

  for (var p in participants) {

    double paid = (p['paid'] as num).toDouble();
    double balance = paid - share;

    if (balance > 0) {
      creditors.add({
        "name": p['name'],
        "amount": balance
      });
    } else if (balance < 0) {
      debtors.add({
        "name": p['name'],
        "amount": -balance
      });
    }

  }

  List<String> settlements = [];

  int i = 0;
  int j = 0;

  while (i < debtors.length && j < creditors.length) {

    double pay = debtors[i]['amount'] < creditors[j]['amount']
        ? debtors[i]['amount']
        : creditors[j]['amount'];

    settlements.add(
        "${debtors[i]['name']} owes ${creditors[j]['name']} ₹${pay.toStringAsFixed(0)}");

    debtors[i]['amount'] -= pay;
    creditors[j]['amount'] -= pay;

    if (debtors[i]['amount'] == 0) i++;
    if (creditors[j]['amount'] == 0) j++;

  }

  return settlements;
}

  void calculateBalances(List<QueryDocumentSnapshot> docs) {

    final user = auth.currentUser;

    double owe = 0;
    double owed = 0;

    for (var doc in docs) {

      var bill = doc.data() as Map<String, dynamic>;
      List participants = bill['participants'];

      double share = bill['total'] / participants.length;

      for (var p in participants) {

        if (p['uid'] == user!.uid) {

          double paid = (p['paid'] as num).toDouble();

          if (paid < share) {
            owe += (share - paid);
          }

          if (paid > share) {
            owed += (paid - share);
          }
        }
      }
    }

    setState(() {
      youOwe = owe;
      theyOwe = owed;
    });
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        backgroundColor: const Color(0xFF083549),
        iconTheme: const IconThemeData(color: Colors.white),
  elevation: 0,

        title: const Text(
          "Split The Bill",
          style: TextStyle(
            fontSize: 24,
            color:Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),

        actions: [

    IconButton(
      icon: const Icon(Icons.repeat, color: Colors.white),
      tooltip: "Recurring Payments",
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const RecurringPaymentsPage(),
          ),
        );
      },
    ),

    IconButton(
      icon: const Icon(Icons.lightbulb, color: Colors.yellow),
      tooltip: "Finance Tips",
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const TipsPage(),
          ),
        );
      },
    ),

    IconButton(
      icon: const Icon(Icons.logout, color: Colors.white),
      tooltip: "Logout",
      onPressed: () async {
        await FirebaseAuth.instance.signOut();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
        );
      },
    ),

  ],
),
      drawer: Drawer(
          /// SIDE NAV
        child:  SideNav(
  selectedIndex: selectedIndex,
  onItemTap: (index) {

    Navigator.pop(context);
    if (index == selectedIndex) return;

    setState(() {
      selectedIndex = index;
    });

    switch (index) {
      case 0:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
        break;

      case 1:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const TransactionsPage()),
        );
        break;

      case 2:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const BudgetPlannerScreen()),
        );
        break;

      case 3:
        //savings
        break;

      case 4:
        break;
      case 5:
      Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const BillsPage()),
        );
        break;
    }
  },
),
      ),


      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () async {

          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddSplitBillPage()),
          );
        },
      ),

     body: StreamBuilder<QuerySnapshot>(

  stream: firestore
      .collection("split_bills")
      //.orderBy("date", descending: true)
      .snapshots(),

  builder: (context, snapshot) {

    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }

    if (snapshot.hasError) {
  return Center(
    child: Text("Error: ${snapshot.error}"),
  );
}

if (!snapshot.hasData) {
  return const Center(child: Text("No data"));
}

    var docs = snapshot.data!.docs;

    if (docs.isEmpty) {
      return const Center(child: Text("No bills yet"));
    }

    double youOwe = 0;
    double theyOwe = 0;

    final user = auth.currentUser;

    for (var doc in docs) {

      var bill = doc.data() as Map<String, dynamic>;
      List participants = bill['participants'];

      double share = bill['total'] / participants.length;

      for (var p in participants) {

        if (p['uid'] == user!.uid) {

          double paid = (p['paid'] as num).toDouble();

          if (paid < share) {
            youOwe += (share - paid);
          }

          if (paid > share) {
            theyOwe += (paid - share);
          }

        }

      }

    }

    return Column(
      children: [

        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [

              Expanded(
                child: balanceCard("You Owe", youOwe, Colors.red),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: balanceCard("They Owe", theyOwe, Colors.green),
              ),

            ],
          ),
        ),

        Expanded(
          child: ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {

              var bill = docs[index].data() as Map<String, dynamic>;
              var settlements = calculateSettlements(bill);

              return Card(
                margin: const EdgeInsets.all(10),
                child: ListTile(
                  title: Text(bill['title']),
                  
subtitle: Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [

    Text(
      "Total ₹${bill['total']} | ${bill['participants'].length} people",
    ),

    const SizedBox(height: 5),

    ...settlements.map((s) => Text(
          s,
          style: const TextStyle(color: Colors.deepPurple),
        )),

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

  Widget balanceCard(String label, double amount, Color color) {

    return Container(

      padding: const EdgeInsets.all(20),

      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),

      child: Column(

        children: [

          Text(label),

          const SizedBox(height: 5),

          Text(
            "₹${amount.toStringAsFixed(0)}",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),

        ],
      ),
    );
  }
}