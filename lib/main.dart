import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'theme/app_theme.dart';
import 'screens/welcome_screen.dart';
import 'firebase_options.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/profile_setup_screen.dart';
import 'screens/main_navigation_screen.dart';
import 'services/strava_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'utils/map_loader.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Load Google Maps SDK (Web only)
  await loadGoogleMaps();

  runApp(const CruizrApp());
}

class CruizrApp extends StatelessWidget {
  const CruizrApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cruizr',
      debugShowCheckedModeBanner: false,
      theme: CruizrTheme.themeData,
      home: const StravaCallbackWrapper(child: AuthGate()),
    );
  }
}

class StravaCallbackWrapper extends StatefulWidget {
  final Widget child;
  const StravaCallbackWrapper({super.key, required this.child});

  @override
  State<StravaCallbackWrapper> createState() => _StravaCallbackWrapperState();
}

class _StravaCallbackWrapperState extends State<StravaCallbackWrapper> {
  bool _isProcessing = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _checkAuthCode();
  }

  Future<void> _checkAuthCode() async {
    if (kIsWeb) {
      final uri = Uri.base;
      final code = uri.queryParameters['code'];

      if (code != null) {
        setState(() {
          _isProcessing = true;
          _statusMessage = "Connecting to Strava...";
        });

        final success = await StravaService().handleAuthCallback(code);

        if (mounted) {
          setState(() {
            _statusMessage =
                success ? "Connected! Redirecting..." : "Connection failed.";
          });

          // Small delay to read message
          await Future.delayed(const Duration(seconds: 2));

          setState(() {
            _isProcessing = false;
          });

          // TODO: Ideally clean up the URL here, but requires dart:html or external router
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isProcessing) {
      return Scaffold(
        backgroundColor: CruizrTheme.background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: CruizrTheme.accentPink),
              const SizedBox(height: 16),
              Text(
                _statusMessage ?? "Processing...",
                style: const TextStyle(
                  color: CruizrTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return widget.child;
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // 1. Auth State Loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // 2. User Not Logged In
        if (!snapshot.hasData) {
          return const WelcomeScreen();
        }

        // 3. User Logged In -> Check Firestore for Profile
        final User user = snapshot.data!;
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .snapshots(),
          builder: (context, profileSnapshot) {
            // Firestore Loading
            if (profileSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            // Profile Doesn't Exist (or error) -> Go to Profile Setup
            if (!profileSnapshot.hasData || !profileSnapshot.data!.exists) {
              return const ProfileSetupScreen();
            }

            // Check if profile is complete (has new onboarding fields)
            final profileData =
                profileSnapshot.data!.data() as Map<String, dynamic>?;
            if (profileData == null ||
                !profileData.containsKey('activities') ||
                !profileData.containsKey('activityLevel')) {
              return const ProfileSetupScreen();
            }

            // Profile Exists and Complete -> Go Home
            return const MainNavigationScreen();
          },
        );
      },
    );
  }
}
