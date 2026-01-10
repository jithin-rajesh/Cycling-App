import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';
import 'profile_setup_screen.dart';
import 'sign_in_screen.dart';

class SignUpScreen extends StatefulWidget {
  final List<String> preSelectedActivities;

  const SignUpScreen({super.key, this.preSelectedActivities = const []});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  Future<void> _signUp() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 1. Create User
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      // 2. Update Display Name (Initial)
      if (userCredential.user != null && _nameController.text.isNotEmpty) {
        await userCredential.user!.updateDisplayName(_nameController.text.trim());
      }

      if (mounted) {
        // 3. Navigate to Profile Setup
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => ProfileSetupScreen(
              preSelectedActivities: widget.preSelectedActivities,
            ),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.message}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CruizrTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Join Cruizr',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontStyle: FontStyle.italic,
            fontSize: 20,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: CruizrTheme.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                   const SizedBox(height: 16),
                  // Header
                  Text(
                    'Create Your\nActive Account',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      height: 1.2,
                      fontSize: 40,
                    ),
                    textAlign: TextAlign.left,
                  ),
                  const SizedBox(height: 48),

                  // Form
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 8),
                        child: Text('Full Name', style: Theme.of(context).textTheme.bodyMedium),
                      ),
                      TextField(
                         controller: _nameController,
                         style: Theme.of(context).textTheme.bodyLarge,
                         cursorColor: CruizrTheme.primaryDark,
                         decoration: const InputDecoration(
                            hintText: 'John Doe',
                         ),
                      ),
                      const SizedBox(height: 24),
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 8),
                        child: Text('Email Address', style: Theme.of(context).textTheme.bodyMedium),
                      ),
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: Theme.of(context).textTheme.bodyLarge,
                        cursorColor: CruizrTheme.primaryDark,
                        decoration: const InputDecoration(
                          hintText: 'your.email@example.com',
                        ),
                      ),
                      const SizedBox(height: 24),
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 8),
                        child: Text('Create Password', style: Theme.of(context).textTheme.bodyMedium),
                      ),
                      TextField(
                        controller: _passwordController,
                        obscureText: !_isPasswordVisible,
                        style: Theme.of(context).textTheme.bodyLarge,
                        cursorColor: CruizrTheme.primaryDark,
                        decoration: InputDecoration(
                          hintText: 'Minimum 8 characters',
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Password Strength Indicator (Simulated)
                      Row(
                        children: [
                          Expanded(child: Container(height: 4, decoration: BoxDecoration(color: CruizrTheme.accentPink, borderRadius: BorderRadius.circular(2)))),
                          const SizedBox(width: 8),
                          Expanded(child: Container(height: 4, decoration: BoxDecoration(color: CruizrTheme.accentPink.withOpacity(0.5), borderRadius: BorderRadius.circular(2)))),
                          const SizedBox(width: 8),
                          Expanded(child: Container(height: 4, decoration: BoxDecoration(color: CruizrTheme.surface, borderRadius: BorderRadius.circular(2)))),
                          const SizedBox(width: 8),
                          Expanded(child: Container(height: 4, decoration: BoxDecoration(color: CruizrTheme.surface, borderRadius: BorderRadius.circular(2)))),
                        ],
                      ),

                       const SizedBox(height: 24),
                       // Confirm Password (Added field for UI completeness, logic can simply check it matches or ignore for now)
                       Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 8),
                        child: Text('Confirm Password', style: Theme.of(context).textTheme.bodyMedium),
                      ),
                      TextField(
                        obscureText: true,
                        style: Theme.of(context).textTheme.bodyLarge,
                        cursorColor: CruizrTheme.primaryDark,
                        decoration: const InputDecoration(
                          hintText: 'Re-enter your password',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Terms Checkbox
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 24,
                        width: 24,
                        child: Checkbox(
                          value: true, // simplified for UI demo
                          onChanged: (val) {},
                          activeColor: CruizrTheme.primaryDark,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12),
                            children: const [
                              TextSpan(text: 'I agree to Cruizr\'s '),
                              TextSpan(text: 'Terms of Service', style: TextStyle(fontWeight: FontWeight.bold, color: CruizrTheme.primaryDark)),
                              TextSpan(text: ' and acknowledge the '),
                              TextSpan(text: 'Privacy Policy', style: TextStyle(fontWeight: FontWeight.bold, color: CruizrTheme.primaryDark)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Sign Up Button
                  FilledButton(
                    onPressed: _isLoading ? null : _signUp,
                    child: _isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Create My Account'),
                  ),

                  const SizedBox(height: 32),
                  
                  // Footer
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Already active? ",
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
                      ),
                      GestureDetector(
                        onTap: () {
                           Navigator.of(context).pushReplacement(
                              MaterialPageRoute(builder: (context) => const SignInScreen()),
                           );
                        },
                        child: Text(
                          'Sign In',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: CruizrTheme.primaryDark, 
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Playfair Display' // Use Serif for emphasis
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
