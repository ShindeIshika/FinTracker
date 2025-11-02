import 'package:flutter/material.dart';
import 'fintracker_login.dart'; 
//import 'fintracker_signup.dart';
import 'package:firebase_core/firebase_core.dart'; // Firebase core
import 'firebase_options.dart'; // correct file name
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
      home: const LoginPage(), // first screen
    );
  }
}