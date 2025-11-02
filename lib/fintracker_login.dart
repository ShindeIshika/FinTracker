import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_fintracker/fintracker_expenses.dart';
import 'fintracker_signup.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // ==========================================================
  // 🔹 Controllers & State
  // ==========================================================
  final _formKey = GlobalKey<FormState>();
  final TextEditingController loginIdController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool isPasswordVisible = false;
  bool _isUsingUsername = true; // Toggle between username/email login

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ==========================================================
  // 🔹 Helper Functions
  // ==========================================================

  void _showSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  // 🔍 Fetch email from Firestore using username
  Future<String?> _fetchEmailFromDatabase(String username) async {
    try {
      print("🔹 Looking up Firestore for username: $username");

      final querySnapshot = await _db
          .collection('users')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final email = querySnapshot.docs.first.data()['email'] as String?;
        print(" Found email for $username: $email");
        return email;
      } else {
        print(" No document found for username: $username");
        return null;
      }
    } catch (e) {
      print("🔥 Firestore lookup error: $e");
      _showSnackbar('Database lookup failed.');
      return null;
    }
  }

  // ==========================================================
  // 🔹 Login Logic
  // ==========================================================

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    final input = loginIdController.text.trim();
    final password = passwordController.text.trim();
    String? emailToUse;

    print("\n========== LOGIN ATTEMPT ==========");
    print("🔹 Input: $input");
    print("🔹 Mode: ${_isUsingUsername ? 'Username' : 'Email'}");
    print("==================================");

    _showSnackbar('Verifying credentials...');

    try {
      if (_isUsingUsername) {
        // 🔍 Username mode → Lookup Firestore for email
        final fetchedEmail = await _fetchEmailFromDatabase(input);
        if (fetchedEmail == null) {
          _showSnackbar('Username not found. Please check your entry.');
          return;
        }
        emailToUse = fetchedEmail;
      } else {
        // 📧 Email mode → Use input directly
        emailToUse = input;
      }

      print("🚀 Attempting FirebaseAuth login with: $emailToUse");

      final user = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailToUse,
        password: password,
      );

      print("✅ Login successful for: ${user.user?.email}");
      _showSnackbar('Login Successful! Welcome ${user.user?.email}');
      // TODO: Navigate to HomePage
      
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const ExpensesPage()),
      );
    } on FirebaseAuthException catch (e) {
      print("🔥 FirebaseAuthException: ${e.code} - ${e.message}");
      _showSnackbar(e.message ?? 'Login failed. Please try again.');
    } catch (e) {
      print("🔥 Unexpected login error: $e");
      _showSnackbar('An unexpected error occurred.');
    }
  }

  // ==========================================================
  // 🔹 UI BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // --- App Logo ---
                    ClipOval(
                      child: Image.asset(
                        'assets/images/FinTracker_Logo.png',
                        width: 180,
                        height: 180,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // --- Username / Email Field ---
                    TextFormField(
                      controller: loginIdController,
                      keyboardType: _isUsingUsername
                          ? TextInputType.text
                          : TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: _isUsingUsername ? "Username" : "Email",
                        prefixIcon: Icon(
                          _isUsingUsername
                              ? Icons.person_outline
                              : Icons.email_outlined,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return _isUsingUsername
                              ? "Please enter your username"
                              : "Please enter your email";
                        }
                        if (!_isUsingUsername && !value.contains('@')) {
                          return "Enter a valid email address";
                        }
                        return null;
                      },
                    ),

                    // --- Toggle Login Mode ---
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          setState(() {
                            _isUsingUsername = !_isUsingUsername;
                            loginIdController.clear();
                          });
                        },
                        child: Text(
                          _isUsingUsername
                              ? "Login with Email"
                              : "Login with Username",
                          style: const TextStyle(color: Color(0xFF083549)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // --- Password Field ---
                    TextFormField(
                      controller: passwordController,
                      obscureText: !isPasswordVisible,
                      decoration: InputDecoration(
                        labelText: "Password",
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            isPasswordVisible
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() {
                              isPasswordVisible = !isPasswordVisible;
                            });
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "Please enter your password";
                        }
                        if (value.length < 6) {
                          return "Password must be at least 6 characters";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 30),

                    // --- Login Button ---
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF083549),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _login,
                        child: const Text(
                          "Login",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // --- Sign Up Redirect ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Don’t have an account? "),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const FintrackerSignUp(),
                              ),
                            );
                          },
                          child: const Text(
                            "Sign up",
                            style: TextStyle(
                              color: Color(0xFF083549),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
