import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState
    extends State<EmailVerificationScreen> {

  bool isLoading = false;

  Future<void> checkEmailVerified() async {
    setState(() => isLoading = true);

    User? user = FirebaseAuth.instance.currentUser;
    await user?.reload();

    if (user != null && user.emailVerified) {
      if (!mounted) return;

      Navigator.pushReplacementNamed(context, '/dashboard');
    } else {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Email not verified yet")),
      );
    }

    setState(() => isLoading = false);
  }

  Future<void> resendEmail() async {
    try {
      await FirebaseAuth.instance.currentUser!.sendEmailVerification();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Verification email resent")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  Future<void> goBackToLogin() async {
    await FirebaseAuth.instance.signOut();

    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Verify Email"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            const Icon(Icons.email, size: 80),
            const SizedBox(height: 20),

            const Text(
              "A verification link has been sent to your email.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),

            const SizedBox(height: 20),

            const Text(
              "Please verify your email before continuing.",
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 30),

            ElevatedButton(
              onPressed: isLoading ? null : checkEmailVerified,
              child: isLoading
                  ? const CircularProgressIndicator()
                  : const Text("I have verified"),
            ),

            const SizedBox(height: 10),

            TextButton(
              onPressed: resendEmail,
              child: const Text("Resend Email"),
            ),

            const SizedBox(height: 10),

            TextButton(
              onPressed: goBackToLogin,
              child: const Text("Back to Login"),
            ),
          ],
        ),
      ),
    );
  }
}