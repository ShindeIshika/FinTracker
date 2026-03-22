import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String? email;

  const EmailVerificationScreen({Key? key, this.email}) : super(key: key);

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState
    extends State<EmailVerificationScreen> {
  bool isLoading = false;

  // ✅ Check verification
  Future<void> checkEmailVerified() async {
    setState(() => isLoading = true);

    try {
      User? user = FirebaseAuth.instance.currentUser;
      await user?.reload();
      user = FirebaseAuth.instance.currentUser;

      if (user != null && user.emailVerified) {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/dashboard');
      } else {
        _showMessage("Email not verified yet");
      }
    } catch (e) {
      _showMessage("Error checking verification");
    }

    setState(() => isLoading = false);
  }

  // ✅ Resend email
  Future<void> resendEmail() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      await user?.sendEmailVerification();

      _showMessage(
        "Verification email resent to ${user?.email ?? 'your email'}",
      );
    } catch (e) {
      _showMessage("Error sending verification");
    }
  }

  void _showMessage(String msg) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  void goBackToLogin() {
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    final routeEmail =
        ModalRoute.of(context)?.settings.arguments as String?;

    final email = routeEmail ??
        widget.email ??
        FirebaseAuth.instance.currentUser?.email ??
        "No email found";

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Card(
              color: const Color(0xFF083549),
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 📧 Icon
                    const Icon(
                      Icons.email_outlined,
                      size: 70,
                      color: Colors.white,
                    ),

                    const SizedBox(height: 20),

                    // 🏷 Title
                    const Text(
                      "Verify Your Email",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // 📩 Label
                    const Text(
                      "Verification email sent to:",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),

                    const SizedBox(height: 6),

                    // 📧 Email (highlighted)
                    Text(
                      email,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF4FC3F7),
                      ),
                    ),

                    const SizedBox(height: 16),

                    const Divider(color: Colors.white24),

                    const SizedBox(height: 16),

                    // 📄 Description
                    const Text(
                      "Please verify your email to continue.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white60,
                      ),
                    ),

                    const SizedBox(height: 30),

                    // 🔘 Continue Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0A4D68),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed:
                            isLoading ? null : checkEmailVerified,
                        child: isLoading
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text(
                                "Continue",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // 🔁 Resend
                    TextButton(
                      onPressed: resendEmail,
                      child: const Text(
                        "Resend Email",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),

                    // 🔙 Back
                    TextButton(
                      onPressed: goBackToLogin,
                      child: const Text(
                        "Back to Login",
                        style: TextStyle(color: Colors.white),
                      ),
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