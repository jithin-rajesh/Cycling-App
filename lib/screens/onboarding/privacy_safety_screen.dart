import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_theme.dart';
import '../../widgets/cruizr_switch.dart';
import '../main_navigation_screen.dart';

class PrivacySafetyScreen extends StatefulWidget {
  final Map<String, dynamic> profileData;
  final List<String> selectedActivities;
  final String activityLevel;
  final String measurementSystem;

  const PrivacySafetyScreen({
    super.key,
    required this.profileData,
    required this.selectedActivities,
    required this.activityLevel,
    required this.measurementSystem,
  });

  @override
  State<PrivacySafetyScreen> createState() => _PrivacySafetyScreenState();
}

class _PrivacySafetyScreenState extends State<PrivacySafetyScreen> {
  String _profileVisibility = 'public';
  String _activitySharing = 'followers';
  bool _liveActivitySharing = true;
  bool _activityReminders = true;
  bool _communityUpdates = true;
  bool _achievementCelebrations = false;
  bool _isLoading = false;

  Future<void> _completeSetup() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('No user found');

      // Save all data to Firestore
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        // Profile data from step 1
        'preferredName': widget.profileData['preferredName'],
        'pronouns': widget.profileData['pronouns'],
        'birthYear': widget.profileData['birthYear'],
        'location': widget.profileData['location'],
        'photoUrl': widget.profileData['photoUrl'],
        'email': user.email,

        // Activities from step 2
        'activities': widget.selectedActivities,

        // Activity level from step 2
        'activityLevel': widget.activityLevel,
        'measurementSystem': widget.measurementSystem,

        // Privacy settings from step 3
        'profileVisibility': _profileVisibility,
        'activitySharing': _activitySharing,
        'liveActivitySharing': _liveActivitySharing,
        'notifications': {
          'activityReminders': _activityReminders,
          'communityUpdates': _communityUpdates,
          'achievementCelebrations': _achievementCelebrations,
        },

        'createdAt': FieldValue.serverTimestamp(),
      });

      // Update display name if provided
      final preferredName = widget.profileData['preferredName'] as String?;
      if (preferredName != null && preferredName.isNotEmpty) {
        await user.updateDisplayName(preferredName);
      }

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const MainNavigationScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving profile: $e')),
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Privacy &\nSafety',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontSize: 18,
                height: 1.2,
              ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: CruizrTheme.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: CruizrTheme.surface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Step 3 of 3',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: CruizrTheme.accentPink,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Curved header accent
          Container(
            height: 20,
            decoration: const BoxDecoration(
              color: CruizrTheme.surface,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  // Header
                  Text(
                    'Your safety &\nprivacy choices',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontSize: 32,
                          height: 1.2,
                        ),
                  ),
                  const SizedBox(height: 32),

                  // Profile Visibility
                  Text(
                    'Profile Visibility',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                  const SizedBox(height: 12),
                  _buildThreeWayToggle(
                    options: ['Public', 'Community', 'Private'],
                    values: ['public', 'community', 'private'],
                    selectedValue: _profileVisibility,
                    onChanged: (value) =>
                        setState(() => _profileVisibility = value),
                  ),
                  const SizedBox(height: 24),

                  // Activity Sharing
                  Text(
                    'Activity Sharing',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                  const SizedBox(height: 12),
                  _buildThreeWayToggle(
                    options: ['Everyone', 'Followers', 'Only Me'],
                    values: ['everyone', 'followers', 'only_me'],
                    selectedValue: _activitySharing,
                    onChanged: (value) =>
                        setState(() => _activitySharing = value),
                  ),
                  const SizedBox(height: 24),

                  // Safety Features
                  Text(
                    'Safety Features',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: CruizrTheme.surface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Live Activity Sharing',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.w500,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Share real-time location with selected contacts',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      fontSize: 12,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        CruizrSwitch(
                          value: _liveActivitySharing,
                          onChanged: (value) =>
                              setState(() => _liveActivitySharing = value),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Stay Connected
                  Text(
                    'Stay Connected',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: CruizrTheme.surface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        _buildCheckboxTile(
                          'Activity reminders',
                          _activityReminders,
                          (value) => setState(
                              () => _activityReminders = value ?? false),
                        ),
                        const Divider(height: 1),
                        _buildCheckboxTile(
                          'Community updates',
                          _communityUpdates,
                          (value) => setState(
                              () => _communityUpdates = value ?? false),
                        ),
                        const Divider(height: 1),
                        _buildCheckboxTile(
                          'Achievement celebrations',
                          _achievementCelebrations,
                          (value) => setState(
                              () => _achievementCelebrations = value ?? false),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
          // Bottom Button
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: FilledButton(
              onPressed: _isLoading ? null : _completeSetup,
              child: _isLoading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Complete Setup'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThreeWayToggle({
    required List<String> options,
    required List<String> values,
    required String selectedValue,
    required ValueChanged<String> onChanged,
  }) {
    final selectedIndex = values.indexOf(selectedValue);
    return LayoutBuilder(
      builder: (context, constraints) {
        final segmentWidth = (constraints.maxWidth - 8) / options.length;
        return Container(
          height: 44,
          decoration: BoxDecoration(
            color: CruizrTheme.surface,
            borderRadius: BorderRadius.circular(30),
          ),
          padding: const EdgeInsets.all(4),
          child: Stack(
            children: [
              // Sliding Indicator
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                left: selectedIndex * segmentWidth,
                top: 0,
                bottom: 0,
                child: Container(
                  width: segmentWidth,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
              // Labels
              Row(
                children: List.generate(options.length, (index) {
                  final isSelected = values[index] == selectedValue;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => onChanged(values[index]),
                      behavior: HitTestBehavior.opaque,
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                          style: TextStyle(
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.w400,
                            color: isSelected
                                ? CruizrTheme.primaryDark
                                : CruizrTheme.textSecondary,
                            fontSize: 13,
                          ),
                          child: Text(options[index]),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCheckboxTile(
      String title, bool value, ValueChanged<bool?> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            height: 24,
            width: 24,
            child: Checkbox(
              value: value,
              onChanged: onChanged,
              activeColor: CruizrTheme.primaryDark,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4)),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}
