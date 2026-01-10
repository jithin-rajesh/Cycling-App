import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'sign_in_screen.dart';
import 'sign_up_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'onboarding/activities_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = false;

  // Heartbeat animation
  late AnimationController _heartbeatController;
  late Animation<double> _heartbeatAnimation;

  @override
  void initState() {
    super.initState();
    _heartbeatController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    // Create a heartbeat pattern: quick pulse, quick pulse, pause
    _heartbeatAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.15), weight: 10),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0), weight: 10),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.1), weight: 10),
      TweenSequenceItem(tween: Tween(begin: 1.1, end: 1.0), weight: 10),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 60),
    ]).animate(CurvedAnimation(
      parent: _heartbeatController,
      curve: Curves.easeInOut,
    ));

    _heartbeatController.repeat();
  }

  @override
  void dispose() {
    _heartbeatController.dispose();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await GoogleSignIn(
        clientId: '764206559936-uof1bq0upc1hpnopa8eo944t7f4ptsup.apps.googleusercontent.com',
      ).signIn();

      if (googleUser != null) {
        // Obtain the auth details from the request
        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

        // Create a new credential
        final OAuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        // Once signed in, return the UserCredential
        await FirebaseAuth.instance.signInWithCredential(credential);
        // Navigation is handled by AuthGate in main.dart
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CruizrTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              // Logo with heartbeat animation
              Center(
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Center(
                    child: AnimatedBuilder(
                      animation: _heartbeatAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _heartbeatAnimation.value,
                          child: const Icon(
                            Icons.favorite_rounded,
                            size: 60,
                            color: CruizrTheme.accentPink,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 48),
              
              // Title
              Text(
                'Cruizr',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              
              // Tagline
              Text(
                'Your Rhythm. Your Journey.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: CruizrTheme.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(),

              // Buttons
              FilledButton(
                onPressed: _isLoading ? null : () {
                   Navigator.of(context).push(
                     MaterialPageRoute(builder: (context) => const SignUpScreen()),
                   );
                },
                child: const Text('Start Moving'),
              ),
              const SizedBox(height: 16),
              
              FilledButton(
                onPressed: _isLoading ? null : () {
                   Navigator.of(context).push(
                     MaterialPageRoute(builder: (context) => const SignInScreen()),
                   );
                },
                style: FilledButton.styleFrom(
                  backgroundColor: CruizrTheme.surface,
                  foregroundColor: CruizrTheme.primaryDark,
                ),
                child: const Text('Sign In'),
              ),

              const SizedBox(height: 32),
              
              // Divider
              Row(
                children: [
                   Expanded(child: Divider(color: CruizrTheme.border.withOpacity(0.5))),
                   Padding(
                     padding: const EdgeInsets.symmetric(horizontal: 16),
                     child: Text(
                       'or connect with',
                       style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12, fontStyle: FontStyle.italic),
                     ),
                   ),
                   Expanded(child: Divider(color: CruizrTheme.border.withOpacity(0.5))),
                ],
              ),
              const SizedBox(height: 24),
              
              // Social Connect
              Column(
                children: [
                  _socialButton(
                    context, 
                    'Continue with Google', 
                    Icons.g_mobiledata,
                    onPressed: _signInWithGoogle,
                    isLoading: _isLoading,
                  ),
                  // Facebook button removed as requested
                ],
              ),
              
              const SizedBox(height: 32),
              Center(
                 child: TextButton(
                   onPressed: _isLoading ? null : () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const ActivitiesScreen(isExploreMode: true),
                        ),
                      );
                   },
                   child: Row(
                     mainAxisSize: MainAxisSize.min,
                     children: [
                       Text(
                         'Explore first', 
                         style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                           fontStyle: FontStyle.italic
                         )
                       ),
                       const Icon(Icons.arrow_forward, size: 16, color: CruizrTheme.textSecondary),
                     ],
                   ),
                 ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _socialButton(
    BuildContext context, 
    String text, 
    IconData icon, 
    {required VoidCallback onPressed, bool isLoading = false}
  ) {
    return SizedBox(
      height: 56,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: CruizrTheme.surface,
          foregroundColor: CruizrTheme.primaryDark,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: isLoading 
          ? const SizedBox(
              height: 24, 
              width: 24, 
              child: CircularProgressIndicator(strokeWidth: 2)
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 24),
                const SizedBox(width: 12),
                Text(
                  text,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
      ),
    );
  }
}
