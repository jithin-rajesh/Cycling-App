import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'privacy_safety_screen.dart';

class ActivityLevelScreen extends StatefulWidget {
  final Map<String, dynamic> profileData;
  final List<String> selectedActivities;

  const ActivityLevelScreen({
    super.key,
    required this.profileData,
    required this.selectedActivities,
  });

  @override
  State<ActivityLevelScreen> createState() => _ActivityLevelScreenState();
}

class _ActivityLevelScreenState extends State<ActivityLevelScreen> {
  String? _selectedLevel;
  String _measurementSystem = 'metric';

  final List<Map<String, String>> _levels = [
    {
      'id': 'starting',
      'emoji': '🌱',
      'name': 'Starting',
      'description': 'New to regular activity',
    },
    {
      'id': 'building',
      'emoji': '🌿',
      'name': 'Building',
      'description': 'Developing consistency',
    },
    {
      'id': 'active',
      'emoji': '🌳',
      'name': 'Active',
      'description': 'Regular movement',
    },
    {
      'id': 'athletic',
      'emoji': '⚡',
      'name': 'Athletic',
      'description': 'Performance focused',
    },
  ];

  void _goToNextStep() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PrivacySafetyScreen(
          profileData: widget.profileData,
          selectedActivities: widget.selectedActivities,
          activityLevel: _selectedLevel ?? 'starting',
          measurementSystem: _measurementSystem,
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
          'Activity\nLevel',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontStyle: FontStyle.italic,
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
              'Step 2 of 3',
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
                    'Your current\nactivity level',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontSize: 32,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'This helps us personalize your experience',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 32),

                  // Level Grid
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.0,
                    ),
                    itemCount: _levels.length,
                    itemBuilder: (context, index) {
                      final level = _levels[index];
                      final isSelected = _selectedLevel == level['id'];
                      
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedLevel = level['id'];
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.white : CruizrTheme.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected ? CruizrTheme.accentPink : Colors.transparent,
                              width: 2,
                            ),
                            boxShadow: isSelected ? [
                              BoxShadow(
                                color: CruizrTheme.accentPink.withValues(alpha: 0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ] : null,
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                level['emoji']!,
                                style: const TextStyle(fontSize: 36),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                level['name']!,
                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: isSelected ? CruizrTheme.accentPink : CruizrTheme.primaryDark,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                level['description']!,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontSize: 12,
                                  color: isSelected ? CruizrTheme.accentPink.withValues(alpha: 0.7) : CruizrTheme.textSecondary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 32),

                  // Measurement System
                  Text(
                    'Preferred Measurement System',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: CruizrTheme.surface,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _measurementSystem = 'metric'),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: _measurementSystem == 'metric' ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(26),
                                boxShadow: _measurementSystem == 'metric' ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 5,
                                    offset: const Offset(0, 2),
                                  ),
                                ] : null,
                              ),
                              child: Center(
                                child: Text(
                                  'Metric',
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    fontWeight: _measurementSystem == 'metric' ? FontWeight.w600 : FontWeight.w400,
                                    color: _measurementSystem == 'metric' ? CruizrTheme.primaryDark : CruizrTheme.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _measurementSystem = 'imperial'),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: _measurementSystem == 'imperial' ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(26),
                                boxShadow: _measurementSystem == 'imperial' ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 5,
                                    offset: const Offset(0, 2),
                                  ),
                                ] : null,
                              ),
                              child: Center(
                                child: Text(
                                  'Imperial',
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    fontWeight: _measurementSystem == 'imperial' ? FontWeight.w600 : FontWeight.w400,
                                    color: _measurementSystem == 'imperial' ? CruizrTheme.primaryDark : CruizrTheme.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
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
