import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'fintracker_login.dart';

class FintrackerSignUp extends StatefulWidget {
  const FintrackerSignUp({super.key});

  @override
  State<FintrackerSignUp> createState() => _FintrackerSignUpState();
}

class _FintrackerSignUpState extends State<FintrackerSignUp> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController firstName = TextEditingController();
  final TextEditingController lastName = TextEditingController();
  final TextEditingController userName = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPassword = TextEditingController();

  // 🔹 State
  bool isPasswordVisible = false;
  bool _isLoading = false;

  // 🔹 Firebase
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 🔹 Validation patterns
  final RegExp _emailRegex =
      RegExp(r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.(com|in|org|net|edu)$");
  final RegExp _passwordRegex =
      RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[\W_]).{8,}$');
  final RegExp _usernameRegex = RegExp(r'^[a-zA-Z0-9_.@]{3,20}$');

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<bool> _isUsernameTaken(String username) async {
    final query = await _db
        .collection('users')
        .where('username', isEqualTo: username.toLowerCase())
        .get();
    return query.docs.isNotEmpty;
  }

  // ==========================================================
  // 🔹 Register User
  // ==========================================================

  Future<void> _registerUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final username = userName.text.trim().toLowerCase();

    try {
      // Step 1: Check if username is already taken
      if (await _isUsernameTaken(username)) {
        _showSnack('Username already taken. Please choose another.');
        setState(() => _isLoading = false);
        return;
      }

      // Step 2: Create user with Firebase Auth
      final userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim().toLowerCase(),
        password: passwordController.text.trim(),
      );

      // ✅ STEP 2.1: Send verification email
      await userCredential.user!.sendEmailVerification();

      // Step 3: Store user data in Firestore
      await _db.collection('users').doc(userCredential.user!.uid).set({
        'firstName': firstName.text.trim(),
        'lastName': lastName.text.trim(),
        'username': username,
        'email': emailController.text.trim().toLowerCase(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      _showSnack('Account created successfully!');

      Navigator.pushReplacementNamed(
        context,
        '/verify-email',
        arguments: emailController.text.trim(),
      );
    } on FirebaseAuthException catch (e) {
      _showSnack(e.message ?? 'Registration failed.');
    } catch (e) {
      _showSnack('An unexpected error occurred.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ==========================================================
  // 🔹 UI BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF083549),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Card(
              color: Colors.white,
              elevation: 10,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(
                  color: Color.fromARGB(255, 193, 216, 235),
                  width: 2,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "Create Account",
                        style: TextStyle(
                          color: Color(0xFF083549),
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 30),

                      // --- First & Last Name ---
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: firstName,
                              decoration: _fieldDecoration("First Name"),
                              validator: (v) =>
                                  v == null || v.isEmpty ? "Required" : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: lastName,
                              decoration: _fieldDecoration("Last Name"),
                              validator: (v) =>
                                  v == null || v.isEmpty ? "Required" : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // --- Username ---
                      TextFormField(
                        controller: userName,
                        decoration: _fieldDecoration("Username"),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return "Enter a username";
                          }
                          if (!_usernameRegex.hasMatch(value)) {
                            return "Use lowercase letters, numbers, _ (4–16 chars)";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // --- Email ---
                      TextFormField(
                        controller: emailController,
                        decoration: _fieldDecoration(
                          "Email",
                          prefix: const Icon(Icons.email_outlined),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return "Enter your email";
                          }
                          if (!_emailRegex.hasMatch(value)) {
                            return "Enter a valid email (e.g. name@gmail.com)";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // --- Password ---
                      TextFormField(
                        controller: passwordController,
                        obscureText: !isPasswordVisible,
                        decoration: _fieldDecoration(
                          "Password",
                          prefix: const Icon(Icons.lock_outline),
                          suffix: IconButton(
                            icon: Icon(
                              isPasswordVisible
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () => setState(() {
                              isPasswordVisible = !isPasswordVisible;
                            }),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return "Enter a password";
                          }
                          if (!_passwordRegex.hasMatch(value)) {
                            return "Must contain upper, lower, number, symbol (8+ chars)";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // --- Confirm Password ---
                      TextFormField(
                        controller: confirmPassword,
                        obscureText: true,
                        decoration: _fieldDecoration(
                          "Confirm Password",
                          prefix: const Icon(Icons.lock),
                        ),
                        validator: (value) {
                          if (value != passwordController.text) {
                            return "Passwords do not match";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 30),

                      // --- Sign Up Button ---
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
                          onPressed: _isLoading ? null : _registerUser,
                          child: _isLoading
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                              : const Text(
                                  "Sign Up",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // --- Redirect to Login ---
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text("Already have an account? "),
                          GestureDetector(
                            onTap: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const LoginPage(),
                                ),
                              );
                            },
                            child: const Text(
                              "Login",
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
      ),
    );
  }

  // ==========================================================
  // 🔹 Input Decoration Helper
  // ==========================================================
  InputDecoration _fieldDecoration(String hint,
      {Widget? prefix, Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: prefix,
      suffixIcon: suffix,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
      fillColor: Colors.grey[100],
    );
  }
}
