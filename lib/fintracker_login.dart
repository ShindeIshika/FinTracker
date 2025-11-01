import 'package:flutter/material.dart'; 
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // REQUIRED for username lookup
import 'fintracker_signup.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController loginIdController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool isPasswordVisible = false;
  
  // Instance to interact with Firestore
  final FirebaseFirestore _db = FirebaseFirestore.instance; 
  
  // State to toggle between Username (true) and Email (false) login mode
  bool _isUsingUsername = true; 

  // --- Utility & Database Functions ---

  // Helper to check if the input looks like an email (simple check)
  bool _isEmail(String input) {
    return input.contains('@');
  }

  void _showSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }
  
  // 🔑 CRITICAL FUNCTION: Looks up the email in Firestore using the username
  Future<String?> _fetchEmailFromDatabase(String username) async {
    try {
      // Query the 'users' collection where the 'username' field matches the input
      final querySnapshot = await _db
          .collection('users') 
          .where('username', isEqualTo: username)
          .limit(1) 
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        // Return the 'email' field from the found document
        return querySnapshot.docs.first.data()['email'] as String?;
      }
      return null; // Username not found
    } catch (e) {
      print('Firestore lookup error: $e');
      _showSnackbar('A database error occurred. Please check your connection.');
      return null;
    }
  }

  // --- Login Logic ---

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
      
    String input = loginIdController.text.trim();
    String emailToUse = '';

    // 1. Determine the email address to use for Firebase Auth
    if (_isUsingUsername) {
      if (_isEmail(input)) {
        // Case A: User entered an email while in "Username" mode (Acceptable)
        emailToUse = input;
      } else {
        // Case B: User entered a non-email value (a true Username)
        
        _showSnackbar('Verifying username...');
        
        // 🚨 CRITICAL STEP: Fetch the email from Firestore using the username
        String? fetchedEmail = await _fetchEmailFromDatabase(input);
        
        if (fetchedEmail == null) {
          _showSnackbar('Username not found. Please check your entry.');
          return;
        }
        emailToUse = fetchedEmail;
      }
    } else {
      // Case C: User is in "Email" mode (Input is guaranteed to be an email by validator)
      emailToUse = input;
    }

    // 2. Attempt Firebase sign-in using the determined email address
    try {
      UserCredential user = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailToUse, 
        password: passwordController.text.trim(),
      );

      _showSnackbar('Login Successful! Welcome ${user.user?.email}');
      // TODO: Navigate to HomePage

    } on FirebaseAuthException catch (e) {
      // Catch specific Firebase auth errors (e.g., wrong password, user not found)
      _showSnackbar(e.message ?? 'Login failed. Check your credentials.');
    }
  }

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
                    // Logo
                    ClipOval(
                      child: Image.asset(
                        'assets/images/FinTracker_Logo.png',
                        width: 180, 
                        height: 180, 
                        fit: BoxFit.cover, 
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 4. Dynamic Login Field (Username or Email)
                    TextFormField(
                      controller: loginIdController,
                      keyboardType: _isUsingUsername ? TextInputType.text : TextInputType.emailAddress,
                      decoration: InputDecoration(
                        // Dynamic label based on the state
                        labelText: _isUsingUsername ? "Username" : "Email",
                        // Dynamic icon based on the state
                        prefixIcon: Icon(_isUsingUsername ? Icons.person_outline : Icons.email_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return _isUsingUsername ? "Please enter your username" : "Please enter your email";
                        }
                        // If in Email mode, enforce email validation
                        if (!_isUsingUsername && !_isEmail(value)) {
                           return "Enter a valid email address";
                        }
                        return null;
                      },
                    ),

                    // 5. Login Toggle Button
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          // Toggle the state and clear the input field
                          setState(() {
                            _isUsingUsername = !_isUsingUsername;
                            loginIdController.clear();
                          });
                        },
                        child: Text(
                          _isUsingUsername ? "Log in with Email" : "Log in with Username",
                          style: const TextStyle(color: Color(0xFF083549)),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 10),

                    // Password Field
                    TextFormField(
                      controller: passwordController,
                      obscureText: !isPasswordVisible,
                      decoration: InputDecoration(
                        labelText: "Password",
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(isPasswordVisible ? Icons.visibility : Icons.visibility_off),
                          onPressed: () {
                            setState(() {
                              isPasswordVisible = !isPasswordVisible;
                            });
                          },
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return "Please enter your password";
                        if (value.length < 6) return "Password must be at least 6 characters";
                        return null;
                      },
                    ),
                    const SizedBox(height: 30),

                    // Login button 
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF083549),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _login, // Calls the updated login logic
                        child: const Text(
                          "Login",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Sign up link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Don’t have an account? "),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const FintrackerSignUp()),
                            );
                          },
                          child: const Text(
                            "Sign up",
                            style: TextStyle(color: Color(0xFF083549), fontWeight: FontWeight.bold),
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