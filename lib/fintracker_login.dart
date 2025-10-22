import 'package:flutter/material.dart';  
import 'package:firebase_auth/firebase_auth.dart';                       


class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool isPasswordVisible = false;

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
                   width: 180,  // diameter of the circle
                   height: 180, // same as width for perfect circle
                   fit: BoxFit.cover, // makes the image fill the circle
                    ),
                    ),
                    const SizedBox(height: 20), // spacing between logo and email field


                    // Email field
                    TextFormField(
                      controller: emailController,
                      decoration: InputDecoration(
                        labelText: "Email",
                        prefixIcon: const Icon(Icons.email_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return "Please enter your email";
                        if (!value.contains('@')) return "Enter a valid email";
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Password field
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
                        onPressed:() async {
                          if(_formKey.currentState!.validate())
                          {
                            try 
                            {
                              UserCredential user= await FirebaseAuth.instance.signInWithEmailAndPassword
                              (email: emailController.text.trim(), 
                              password: passwordController.text.trim());

                              ScaffoldMessenger.of(context).showSnackBar
                              (SnackBar(content: Text('Login Successful! Welcome ${user.user?.email}')),
                              );

                              // TODO: Navigate to HomePage
                              // Navigator.push(context, MaterialPageRoute(builder: (context) => HomePage()));
                            }
                            on FirebaseAuthException catch (e) {
                            // Show error message from Firebase
                            ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(e.message ?? 'Login failed')),
                           );
                          }
                          }
                        },
                        child: const Text(
                          "Login",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,color:Colors.white),
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
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Sign Up clicked')),
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
