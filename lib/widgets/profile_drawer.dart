import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import '../screens/profile_screen.dart';
import '../services/strava_service.dart';

class ProfileDrawer extends StatefulWidget {
  const ProfileDrawer({super.key});

  @override
  State<ProfileDrawer> createState() => _ProfileDrawerState();
}

class _ProfileDrawerState extends State<ProfileDrawer> {
  bool _isLoading = true;
  Map<String, dynamic>? _userData;
  bool _isStravaConnected = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    _checkStravaStatus();
  }

  Future<void> _checkStravaStatus() async {
    final connected = await StravaService().isAuthenticated();
    if (mounted) {
      setState(() => _isStravaConnected = connected);
    }
  }

  Future<void> _loadData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (mounted) {
        setState(() {
          _userData = doc.data();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading profile drawer data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final photoUrl = _userData?['photoUrl'] ?? user?.photoURL;
    final displayName =
        _userData?['preferredName'] ?? user?.displayName ?? 'User';
    final email = user?.email ?? '';
    final badgeTier = _userData?['badgeTier'] ?? 'Relaxed';

    return Drawer(
      backgroundColor: CruizrTheme.background,
      child: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  const SizedBox(height: 24),
                  // Avatar & Name
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: CruizrTheme.border, width: 2),
                      image: photoUrl != null
                          ? DecorationImage(
                              image: NetworkImage(photoUrl),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: photoUrl == null
                        ? const Icon(Icons.person,
                            size: 50, color: CruizrTheme.textSecondary)
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    displayName,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontFamily: 'Playfair Display',
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Text(
                    email,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: CruizrTheme.textSecondary),
                  ),
                  const SizedBox(height: 24),

                  const Divider(),

                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        _buildSectionHeader('Current Status'),
                        _buildInfoTile(
                          _getTierIcon(badgeTier),
                          'Tier',
                          badgeTier,
                        ),
                        // Activity Level Logic
                        Builder(builder: (context) {
                          final levelId =
                              _userData?['activityLevel'] ?? 'starting';
                          final emoji = _getActivityEmoji(levelId);
                          final label =
                              levelId[0].toUpperCase() + levelId.substring(1);
                          return _buildInfoTile(
                            Text(emoji, style: const TextStyle(fontSize: 20)),
                            'Activity Level',
                            label,
                          );
                        }),

                        const SizedBox(height: 16),
                        _buildSectionHeader('Personal Info'),
                        _buildInfoTile(
                          const Icon(Icons.cake,
                              size: 20, color: CruizrTheme.textSecondary),
                          'Birth Year',
                          _userData?['birthYear']?.toString() ?? '-',
                        ),
                        _buildInfoTile(
                          const Icon(Icons.location_on,
                              size: 20, color: CruizrTheme.textSecondary),
                          'Location',
                          _userData?['location'] ?? '-',
                        ),

                        const SizedBox(height: 16),
                        _buildSectionHeader('Privacy & Safety'),
                        _buildInfoTile(
                          const Icon(Icons.lock_outline,
                              size: 20, color: CruizrTheme.textSecondary),
                          'Profile',
                          _userData?['profileVisibility'] ?? 'Public',
                        ),
                        _buildInfoTile(
                          const Icon(Icons.share,
                              size: 20, color: CruizrTheme.textSecondary),
                          'Activity Sharing',
                          _userData?['activitySharing'] ?? 'Followers',
                        ),

                        const SizedBox(height: 24),
                        // Connect Strava
                        Container(
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFFFC4C02).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: const Color(0xFFFC4C02)
                                    .withValues(alpha: 0.3)),
                          ),
                          child: ListTile(
                            leading: const Icon(
                                Icons
                                    .compare_arrows, // Using generic icon if brand icon not avail
                                color: Color(0xFFFC4C02)),
                            title: const Text(
                              'Connect Strava',
                              style: TextStyle(
                                  color: Color(0xFFFC4C02),
                                  fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              _isStravaConnected
                                  ? 'Connected'
                                  : 'Tap to connect',
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: _isStravaConnected
                                ? const Icon(Icons.check_circle,
                                    color: Colors.green)
                                : const Icon(Icons.arrow_forward_ios,
                                    size: 16, color: Color(0xFFFC4C02)),
                            onTap: () async {
                              if (!_isStravaConnected) {
                                await StravaService().authenticate();
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Bottom Edit Button
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // Close drawer then navigate? Or just push?
                        // Better to just push, so back button returns to drawer/home state
                        Navigator.pop(context); // Close drawer
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const ProfileScreen()),
                        ).then((_) => _loadData()); // Refresh on return
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: CruizrTheme.surface,
                        foregroundColor: CruizrTheme.primaryDark,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: CruizrTheme.border),
                        ),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit Profile'),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: CruizrTheme.textSecondary,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildInfoTile(Widget leading, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Center(child: leading),
          ),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: CruizrTheme.textSecondary)),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: CruizrTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _getTierIcon(String tier) {
    IconData icon;
    Color color;
    switch (tier) {
      case 'Hypertraining':
        icon = Icons.flash_on;
        color = Colors.purple;
        break;
      case 'Athletic':
        icon = Icons.fitness_center;
        color = Colors.orange;
        break;
      case 'Intermediate':
        icon = Icons.directions_run;
        color = Colors.blue;
        break;
      case 'Relaxed':
      default:
        icon = Icons.weekend;
        color = Colors.green;
        break;
    }
    return Icon(icon, size: 20, color: color);
  }

  String _getActivityEmoji(String levelId) {
    switch (levelId) {
      case 'building':
        return '🌿';
      case 'active':
        return '🌳';
      case 'athletic':
        return '⚡';
      case 'starting':
      default:
        return '🌱';
    }
  } // End of helper methods
}
