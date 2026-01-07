import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'activity_level_screen.dart';

class ActivitiesScreen extends StatefulWidget {
  final Map<String, dynamic> profileData;

  const ActivitiesScreen({super.key, required this.profileData});

  @override
  State<ActivitiesScreen> createState() => _ActivitiesScreenState();
}

class _ActivitiesScreenState extends State<ActivitiesScreen> {
  final Set<String> _selectedActivities = {};

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
    {'id': 'gymnastics', 'emoji': '🤸', 'name': 'Gymnastics'},
    {'id': 'dance', 'emoji': '💃', 'name': 'Dance'},
  ];

  void _goToNextStep() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ActivityLevelScreen(
          profileData: widget.profileData,
          selectedActivities: _selectedActivities.toList(),
        ),
      ),
    );
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
            fontStyle: FontStyle.italic,
            fontSize: 20,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: CruizrTheme.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
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
                    'What moves you?',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontSize: 32,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Select all activities that match your rhythm',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 32),

                  // Activity Grid
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.2,
                    ),
                    itemCount: _activities.length,
                    itemBuilder: (context, index) {
                      final activity = _activities[index];
                      final isSelected = _selectedActivities.contains(activity['id']);
                      
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
                            color: CruizrTheme.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected ? CruizrTheme.accentPink : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                activity['emoji']!,
                                style: const TextStyle(fontSize: 40),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                activity['name']!,
                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                  color: isSelected ? CruizrTheme.primaryDark : CruizrTheme.textSecondary,
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
          // Bottom Button
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: FilledButton(
              onPressed: _goToNextStep,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Next Step'),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
