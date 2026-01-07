import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../theme/app_theme.dart';
import 'sign_up_screen.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  Future<void> _signInWithEmail() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
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

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn(
        clientId: '764206559936-uof1bq0upc1hpnopa8eo944t7f4ptsup.apps.googleusercontent.com',
      ).signIn();
      if (googleUser != null) {
        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final OAuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        await FirebaseAuth.instance.signInWithCredential(credential);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Google Sign-In Error: $e')),
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
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CruizrTheme.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo / Brand Name
                  Padding(
                    padding: const EdgeInsets.only(bottom: 48.0),
                    child: Column(
                      children: [
                        Container(
                           padding: const EdgeInsets.all(16),
                           decoration: BoxDecoration(
                             color: Colors.white,
                             shape: BoxShape.circle,
                             boxShadow: [
                               BoxShadow(
                                 color: Colors.black.withOpacity(0.05),
                                 blurRadius: 20,
                                 offset: const Offset(0, 10),
                               ),
                             ],
                           ),
                           child: const Icon(Icons.favorite_rounded, size: 40, color: CruizrTheme.accentPink),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'ActivePulse',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontSize: 36,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your Rhythm. Your Journey.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                             fontStyle: FontStyle.italic,
                             letterSpacing: 1.2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  // Title Section
                  Text(
                    'Welcome Back',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // Form Section
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                        child: Text('Password', style: Theme.of(context).textTheme.bodyMedium),
                      ),
                      TextField(
                        controller: _passwordController,
                        obscureText: !_isPasswordVisible,
                        style: Theme.of(context).textTheme.bodyLarge,
                        cursorColor: CruizrTheme.primaryDark,
                        decoration: InputDecoration(
                          hintText: '••••••••',
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                              color: CruizrTheme.textSecondary,
                            ),
                            onPressed: () {
                              setState(() {
                                _isPasswordVisible = !_isPasswordVisible;
                              });
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        // Forgot password logic
                      },
                      child: Text(
                        'Forgot Password?',
                        style: TextStyle(
                          color: CruizrTheme.textSecondary.withOpacity(0.8),
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  FilledButton(
                    onPressed: _isLoading ? null : _signInWithEmail,
                    child: _isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Sign In'),
                  ),

                  const SizedBox(height: 32),
                  
                  // Divider
                  Row(
                    children: [
                      const Expanded(child: Divider(color: CruizrTheme.border)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'or connect with',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontStyle: FontStyle.italic,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const Expanded(child: Divider(color: CruizrTheme.border)),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Social Sign-In
                  OutlinedButton(
                    onPressed: _isLoading ? null : _signInWithGoogle,
                    style: OutlinedButton.styleFrom(
                      backgroundColor: CruizrTheme.surface, 
                      side: BorderSide.none,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                         // Placeholder G icon if no asset
                         const Text('G', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)), 
                         const SizedBox(width: 12),
                         Text('Continue with Google', style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 48),
                  
                  // Footer
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "New to ActivePulse?",
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      TextButton(
                        onPressed: () {
                           Navigator.of(context).push(
                             MaterialPageRoute(builder: (context) => const SignUpScreen()),
                           );
                        },
                        child: const Text(
                          'Sign Up',
                          style: TextStyle(color: CruizrTheme.primaryDark, fontWeight: FontWeight.bold),
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
    );
  }
}
