import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'activity_level_screen.dart';
import '../sign_up_screen.dart';

class ActivitiesScreen extends StatefulWidget {
  final Map<String, dynamic>? profileData; // Mutable for explore mode flow
  final bool isExploreMode;
  final List<String> preSelectedActivities;

  const ActivitiesScreen({
    super.key,
    this.profileData,
    this.isExploreMode = false,
    this.preSelectedActivities = const [],
  });

  @override
  State<ActivitiesScreen> createState() => _ActivitiesScreenState();
}

class _ActivitiesScreenState extends State<ActivitiesScreen> {
  late Set<String> _selectedActivities;

  final List<Map<String, String>> _activities = [
    {'id': 'cycling', 'emoji': '🚴', 'name': 'Cycling'},
    {'id': 'running', 'emoji': '🏃', 'name': 'Running'},
    {'id': 'swimming', 'emoji': '🏊', 'name': 'Swimming'},
    {'id': 'yoga', 'emoji': '🧘', 'name': 'Yoga'},
    {'id': 'hiking', 'emoji': '🥾', 'name': 'Hiking'},
    {'id': 'strength', 'emoji': '🏋️', 'name': 'Strength'},
    {'id': 'tennis', 'emoji': '🎾', 'name': 'Tennis'},
    {'id': 'volleyball', 'emoji': '🏐', 'name': 'Volleyball'},
    {'id': 'soccer', 'emoji': '⚽', 'name': 'Soccer'},
    {'id': 'badminton', 'emoji': '🏸', 'name': 'Badminton'},
  ];

  @override
  void initState() {
    super.initState();
    _selectedActivities = widget.preSelectedActivities.toSet();
  }

  void _goToNextStep() {
    if (widget.isExploreMode) {
      // Navigate to Sign Up, passing selection
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => SignUpScreen(
            preSelectedActivities: _selectedActivities.toList(),
          ),
        ),
      );
    } else {
      // Standard Profile Setup Flow
      if (widget.profileData == null) return; // Should not happen in this flow

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ActivityLevelScreen(
            profileData: widget.profileData!,
            selectedActivities: _selectedActivities.toList(),
          ),
        ),
      );
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
          'Choose Activities',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontSize: 20,
                color: CruizrTheme.textPrimary,
              ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: CruizrTheme.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Text(
                    'What moves you?',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontSize: 28,
                          fontFamily: 'Playfair Display',
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Select all activities that match your rhythm',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: CruizrTheme.textSecondary,
                          fontSize: 16,
                        ),
                  ),
                  const SizedBox(height: 32),

                  // Activity Grid
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.1,
                    ),
                    itemCount: _activities.length,
                    itemBuilder: (context, index) {
                      final activity = _activities[index];
                      final isSelected =
                          _selectedActivities.contains(activity['id']);

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedActivities.remove(activity['id']);
                            } else {
                              _selectedActivities.add(activity['id']!);
                            }
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? CruizrTheme.surface
                                : const Color(
                                    0xFFFDF8F6), // Slightly lighter than bg
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: isSelected
                                  ? CruizrTheme.accentPink
                                  : Colors.transparent,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.brown.withValues(alpha: 0.03),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Image/Emoji
                              Text(
                                activity['emoji']!,
                                style: const TextStyle(fontSize: 48),
                              ),
                              const SizedBox(height: 12),
                              // Label
                              Text(
                                activity['name']!,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: CruizrTheme.textPrimary,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
          // Bottom Button should be sticky
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: CruizrTheme.background,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  CruizrTheme.background.withValues(alpha: 0),
                  CruizrTheme.background,
                ],
                stops: const [0.0, 0.3],
              ),
            ),
            child: FilledButton(
              onPressed: _selectedActivities.isNotEmpty ? _goToNextStep : null,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(widget.isExploreMode
                      ? 'Continue to Sign Up'
                      : 'Next Step'),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
