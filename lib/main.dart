import 'package:flutter/material.dart';
import 'package:flutter_fintracker/fintracker_bills.dart';
import 'package:flutter_fintracker/fintracker_budget.dart';
import 'package:flutter_fintracker/fintracker_home.dart';
//import 'fintracker_login.dart'; 
import 'package:firebase_core/firebase_core.dart'; // Firebase core
import 'package:flutter_fintracker/fintracker_login.dart';
import 'package:flutter_fintracker/fintracker_savings.dart';
import 'package:flutter_fintracker/fintracker_splitbill.dart';
import 'package:flutter_fintracker/fintracker_transaction.dart';
import 'firebase_options.dart'; 
import 'package:firebase_auth/firebase_auth.dart';// correct file name
// import your page widgets

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Ensures Flutter is ready
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform, // Firebase config for the platform
  );
  runApp(const FinTrackerApp());
}

class FinTrackerApp extends StatelessWidget {
  const FinTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
  title: 'FinTracker',
  debugShowCheckedModeBanner: false,
  theme: ThemeData(
    colorSchemeSeed: const Color(0xFF083549),
    useMaterial3: true,
  ),
  routes: {
    '/login': (_) => const LoginPage(),
    '/dashboard': (_) => const DashboardScreen(),
    '/transactions': (_) => const TransactionsPage(),
    '/budget': (_) => const BudgetPlannerScreen(),
    '/savings':(_)=> const SavingsPage(),
    '/split': (_) => const SplitBillPage(),
    '/bills': (_)=> const BillsPage(),
  },
  home: StreamBuilder<User?>(
    stream: FirebaseAuth.instance.authStateChanges(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      }

      if (snapshot.hasData) {
        return const DashboardScreen();
      }

      return const LoginPage();
    },
  ),
);
  }
}