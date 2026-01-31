import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'challenges_screen.dart';

import 'routes_screen.dart';
import 'start_activity_screen.dart';
import 'community_screen.dart'; // Added
import 'dart:async'; // Added for StreamSubscription
import '../services/strava_service.dart'; // Added

import 'package:flutter/foundation.dart';
import 'package:uni_links/uni_links.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _initDeepLinkListener();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _initDeepLinkListener() {
    // Check for initial link if app was closed
    getInitialLink().then((initialLink) {
      if (initialLink != null) _handleLink(initialLink);
    });

    // Listen for links while app is open
    // linkStream is not supported on Web and throws an error
    if (!kIsWeb) {
      _sub = linkStream.listen((String? link) {
        if (link != null) _handleLink(link);
      }, onError: (err) {
        debugPrint('Deep Link Error: $err');
      });
    }
  }

  void _handleLink(String link) async {
    // Check if it matches our Strava redirect scheme (host might vary like custom vs localhost)
    if (link.contains('strava-callback')) {
      final uri = Uri.parse(link);
      final code = uri.queryParameters['code'];
      final error = uri.queryParameters['error'];

      if (error != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Strava connection failed: $error')),
          );
        }
        return;
      }

      if (code != null) {
        final success = await StravaService().handleAuthCallback(code);
        if (mounted) {
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Successfully connected to Strava!')),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to exchange Strava token.')),
            );
          }
        }
      }
    }
  }

  final List<Widget> _screens = [
    const HomeScreen(),
    const RoutesScreen(),
    const Scaffold(
        body: Center(child: Text('Start'))), // Floating button placeholder
    const CommunityScreen(),
    const ChallengesScreen(),
  ];

  void _onItemTapped(int index) {
    if (index == 2) {
      // Handle Start Button Tap
      return;
    }
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CruizrTheme.background,
      body: _screens[_selectedIndex],
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const StartActivityScreen(),
              fullscreenDialog: true,
            ),
          );
        },
        backgroundColor: CruizrTheme.accentPink,
        elevation: 4,
        child: const Icon(Icons.add, color: Colors.white, size: 32),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        color: Colors.white,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.home_rounded, 'Home'),
              _buildNavItem(1, Icons.map_outlined, 'Routes'),
              const SizedBox(width: 48), // Space for FAB
              _buildNavItem(3, Icons.people_outline, 'Community'),
              _buildNavItem(4, Icons.emoji_events_outlined, 'Challenges'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _selectedIndex == index;
    return InkWell(
      onTap: () => _onItemTapped(index),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected
                  ? CruizrTheme.primaryDark
                  : CruizrTheme.textSecondary,
              size: 26,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected
                    ? CruizrTheme.primaryDark
                    : CruizrTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
