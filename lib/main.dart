import 'package:flutter/material.dart';
import 'package:flutter_fintracker/screens/bills/fintracker_bills.dart';
import 'package:flutter_fintracker/screens/budgets/fintracker_budget.dart';
import 'package:flutter_fintracker/screens/dashboard/fintracker_home.dart';
import 'screens/auth/email_verification_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_fintracker/screens/auth/fintracker_login.dart';
import 'package:flutter_fintracker/screens/savings/fintracker_savings.dart';
import 'package:flutter_fintracker/screens/splitbill/fintracker_splitbill.dart';
import 'package:flutter_fintracker/screens/transactions/fintracker_transaction.dart';
import 'firebase_options.dart'; 
import 'package:firebase_auth/firebase_auth.dart';// correct file name
import 'services/notification_service.dart';
import 'package:workmanager/workmanager.dart';
import 'services/background_service.dart';
import 'package:flutter_fintracker/screens/accounts/accounts_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';



void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await NotificationService.init();

  // Register background task
  await Workmanager().initialize(
    callbackDispatcher,
    isInDebugMode: false,
  );

  await Workmanager().registerPeriodicTask(
    "bill_check_task",
    taskName,
    frequency: const Duration(hours: 1),
    constraints: Constraints(
      networkType: NetworkType.connected,
    ),
  );

  runApp(const FinTrackerApp());
}

class FinTrackerApp extends StatefulWidget {
  const FinTrackerApp({super.key});

  @override
  State<FinTrackerApp> createState() => _FinTrackerAppState();
}

class _FinTrackerAppState extends State<FinTrackerApp> {
  bool isDarkMode = false;

  void toggleTheme(bool value) {
    setState(() {
      isDarkMode = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ThemeController(
      isDarkMode: isDarkMode,
      toggleTheme: toggleTheme,
      child: MaterialApp(
        title: 'FinTracker',
        debugShowCheckedModeBanner: false,

        // ✅ LIGHT THEME
        theme: ThemeData(
          brightness: Brightness.light,
          colorSchemeSeed: const Color(0xFF083549),
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFFF7FBFF),
          cardColor: Colors.white,
        ),

        // ✅ DARK THEME
        darkTheme: ThemeData(
          brightness: Brightness.dark,
          colorSchemeSeed: const Color(0xFF083549),
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFF121212),
          cardColor: const Color(0xFF1E1E1E),
        ),

        themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,

        routes: {
          '/login': (_) => const LoginPage(),
          '/dashboard': (_) => FintrackerHome(),
          '/transactions': (_) => const TransactionsPage(),
          '/budget': (_) => const BudgetPlannerScreen(),
          '/savings': (_) => const SavingsPage(),
          '/split': (_) => const SplitBillPage(),
          '/bills': (_) => const BillsPage(),
          // In the routes map:
        '/accounts': (_) => const AccountsPage(),
          '/verify-email': (context) {
            final email =
                ModalRoute.of(context)?.settings.arguments as String?;
            return EmailVerificationScreen(email: email);
          },
          '/forgot-password': (_) => const ForgotPasswordScreen(),
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
      final user = snapshot.data!;

      if (!user.emailVerified) {
        return EmailVerificationScreen(email: user.email);
      }

      return FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get(),
        builder: (context, userSnap) {
          if (userSnap.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          // User doc exists and setup is done, OR doc doesn't exist
          return const FintrackerHome();
        },
      );
    }

    // No user logged in
    return const LoginPage();
  },
),
              ),
    );
  }
}

// ✅ GLOBAL THEME CONTROLLER
class ThemeController extends InheritedWidget {
  final bool isDarkMode;
  final Function(bool) toggleTheme;

  const ThemeController({
    super.key,
    required this.isDarkMode,
    required this.toggleTheme,
    required Widget child,
  }) : super(child: child);

  static ThemeController of(BuildContext context) {
    final ThemeController? result =
        context.dependOnInheritedWidgetOfExactType<ThemeController>();
    assert(result != null, 'No ThemeController found in context');
    return result!;
  }

  @override
  bool updateShouldNotify(ThemeController oldWidget) {
    return isDarkMode != oldWidget.isDarkMode;
  }
}