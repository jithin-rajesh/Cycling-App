import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../theme/app_theme.dart';
import 'package:flutter/gestures.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/user_service.dart';
import 'challenge_routes_screen.dart';
import 'main_navigation_screen.dart';
import '../widgets/goal_fly_animation.dart';

class ChallengesScreen extends StatefulWidget {
  const ChallengesScreen({super.key});

  @override
  State<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends State<ChallengesScreen> {
  // Goal Setter State
  int _selectedTargetIndex = 0;
  int _selectedMetricIndex = 0;
  int _selectedDurationAmountIndex = 0; // Default to 1
  int _selectedDurationUnitIndex = 1; // Default to Week

  List<String> _targets = [];
  final List<String> _metrics = ['km', 'miles', 'cal', 'steps'];
  final List<String> _durationUnits = ['Day', 'Week', 'Month'];
  final List<String> _durationAmounts =
      List.generate(100, (index) => '${index + 1}');

  // GlobalKey for the goal picker to get its position for animation
  final GlobalKey _goalPickerKey = GlobalKey();

  // Scroll Controllers for manual handling
  late FixedExtentScrollController _targetController;
  late FixedExtentScrollController _metricController;
  late FixedExtentScrollController _durationAmountController;
  late FixedExtentScrollController _durationUnitController;

  @override
  void initState() {
    super.initState();
    _targetController = FixedExtentScrollController();
    _metricController = FixedExtentScrollController();
    _durationAmountController = FixedExtentScrollController();
    _durationUnitController =
        FixedExtentScrollController(initialItem: _selectedDurationUnitIndex);
    _updateTargets(); // Initialize targets based on default metric
  }

  void _updateTargets() {
    final metric = _metrics[_selectedMetricIndex];
    List<String> newTargets = [];

    if (metric == 'km' || metric == 'miles') {
      // 1-25 (step 1), then 30-1000 (step 5)
      for (int i = 1; i <= 25; i++) {
        newTargets.add(i.toString());
      }
      for (int i = 30; i <= 1000; i += 5) {
        newTargets.add(i.toString());
      }
    } else if (metric == 'cal') {
      // 100-10000 (step 50)
      for (int i = 100; i <= 10000; i += 50) {
        newTargets.add(i.toString());
      }
    } else if (metric == 'steps') {
      // 1000-50000 (step 1000)
      for (int i = 1000; i <= 50000; i += 1000) {
        newTargets.add(i.toString());
      }
    }

    setState(() {
      _targets = newTargets;
      _selectedTargetIndex = 0; // Reset selection
      if (_targetController.hasClients) {
        _targetController.jumpToItem(0);
      }
    });
  }

  @override
  void dispose() {
    _targetController.dispose();
    _metricController.dispose();
    _durationAmountController.dispose();
    _durationUnitController.dispose();
    super.dispose();
  }

  /// Triggers the fly animation from goal picker to home icon
  void _triggerGoalFlyAnimation(String goalText) {
    // Get the goal picker's position
    final goalPickerContext = _goalPickerKey.currentContext;
    if (goalPickerContext == null) return;

    final goalPickerBox = goalPickerContext.findRenderObject() as RenderBox;
    final goalPickerPosition = goalPickerBox.localToGlobal(Offset.zero);
    final goalPickerSize = goalPickerBox.size;

    // Create the start rect (center of goal picker)
    final startRect = Rect.fromLTWH(
      goalPickerPosition.dx,
      goalPickerPosition.dy,
      goalPickerSize.width,
      goalPickerSize.height,
    );

    // Get the home icon's position
    final homeIconContext = MainNavigationScreen.homeIconKey.currentContext;
    if (homeIconContext == null) return;

    final homeIconBox = homeIconContext.findRenderObject() as RenderBox;
    final homeIconPosition = homeIconBox.localToGlobal(Offset.zero);
    final homeIconSize = homeIconBox.size;

    // Calculate center of home icon
    final endPosition = Offset(
      homeIconPosition.dx + homeIconSize.width / 2,
      homeIconPosition.dy + homeIconSize.height / 2,
    );

    // Trigger the animation
    GoalFlyAnimation.show(
      context: context,
      startRect: startRect,
      endPosition: endPosition,
      goalText: goalText,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CruizrTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'Challenges',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontFamily: 'Playfair Display',
                      fontWeight: FontWeight.bold,
                      color: CruizrTheme.textPrimary,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Push your limits today',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: CruizrTheme.textSecondary,
                    ),
              ),
              const SizedBox(height: 32),

              // Recommendations Section
              _buildSectionTitle('Recommended for You'),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildRecommendationCard('50km', 'in 20 days',
                        Icons.directions_bike, Colors.blue),
                    const SizedBox(width: 16),
                    _buildRecommendationCard('10k cal', 'in 30 days',
                        Icons.local_fire_department, Colors.orange),
                    const SizedBox(width: 16),
                    _buildRecommendationCard('Marathon', '42km run',
                        Icons.directions_run, Colors.purple),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Manual Goal Setter
              _buildSectionTitle('Set Your Goal'),
              const SizedBox(height: 16),
              Container(
                key: _goalPickerKey,
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context).copyWith(
                    dragDevices: {
                      PointerDeviceKind.touch,
                      PointerDeviceKind.mouse,
                    },
                  ),
                  child: Row(
                    children: [
                      // Target Values
                      Expanded(
                        flex: 2,
                        child: CupertinoPicker(
                          scrollController: _targetController,
                          itemExtent: 40,
                          magnification: 1.1,
                          diameterRatio: 1.5,
                          squeeze: 1.0,
                          selectionOverlay:
                              const CupertinoPickerDefaultSelectionOverlay(),
                          onSelectedItemChanged: (index) =>
                              setState(() => _selectedTargetIndex = index),
                          children: _targets
                              .map((e) => Center(
                                  child: Text(e,
                                      style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w500))))
                              .toList(),
                        ),
                      ),
                      // Metric (km, cal, etc)
                      Expanded(
                        flex: 2, // Wider for metric
                        child: CupertinoPicker(
                          scrollController: _metricController,
                          itemExtent: 40,
                          magnification: 1.1,
                          diameterRatio: 1.5,
                          squeeze: 1.0,
                          selectionOverlay:
                              const CupertinoPickerDefaultSelectionOverlay(),
                          onSelectedItemChanged: (index) {
                            setState(() => _selectedMetricIndex = index);
                            _updateTargets();
                          },
                          children: _metrics
                              .map((e) => Center(
                                  child: Text(e,
                                      style: const TextStyle(
                                          fontSize: 18, color: Colors.grey))))
                              .toList(),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Text('in',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                      // Duration Amount (1, 2, 3...)
                      Expanded(
                        flex: 1,
                        child: CupertinoPicker(
                          scrollController: _durationAmountController,
                          itemExtent: 40,
                          magnification: 1.1,
                          diameterRatio: 1.5,
                          squeeze: 1.0,
                          selectionOverlay:
                              const CupertinoPickerDefaultSelectionOverlay(),
                          onSelectedItemChanged: (index) => setState(
                              () => _selectedDurationAmountIndex = index),
                          children: _durationAmounts
                              .map((e) => Center(
                                  child: Text(e,
                                      style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w500))))
                              .toList(),
                        ),
                      ),
                      // Duration Unit (days, weeks)
                      Expanded(
                        flex: 2,
                        child: CupertinoPicker(
                          scrollController: _durationUnitController,
                          itemExtent: 40,
                          magnification: 1.1,
                          diameterRatio: 1.5,
                          squeeze: 1.0,
                          selectionOverlay:
                              const CupertinoPickerDefaultSelectionOverlay(),
                          onSelectedItemChanged: (index) => setState(
                              () => _selectedDurationUnitIndex = index),
                          children: _durationUnits
                              .map((e) => Center(
                                  child: Text(e,
                                      style: const TextStyle(
                                          fontSize: 18, color: Colors.grey))))
                              .toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (_targets.isEmpty) return;

                    final target = _targets[_selectedTargetIndex];
                    final metric = _metrics[_selectedMetricIndex];
                    final durationAmount = int.parse(
                        _durationAmounts[_selectedDurationAmountIndex]);
                    final durationUnit =
                        _durationUnits[_selectedDurationUnitIndex];

                    try {
                      await UserService().saveGoal(
                        target: target,
                        metric: metric,
                        durationAmount: durationAmount,
                        durationUnit: durationUnit,
                      );
                      if (context.mounted) {
                        // Trigger fly animation
                        _triggerGoalFlyAnimation(
                          '$target $metric in $durationAmount ${durationUnit.toLowerCase()}${durationAmount > 1 ? 's' : ''}',
                        );

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                'Goal set: $target $metric in $durationAmount $durationUnit${durationAmount > 1 ? 's' : ''}!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to set goal: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CruizrTheme.accentPink,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Start Goal'),
                ),
              ),

              const SizedBox(height: 32),

              // Specialized Routes
              _buildSectionTitle('Specialized Routes'),
              const SizedBox(height: 16),
              _buildChallengeCard(
                context,
                title: 'Endurance',
                description:
                    'Long distance routes with steady elevation to build stamina.',
                icon: Icons.timer_outlined,
                color: const Color(0xFF4CAF50), // Green for endurance
              ),
              const SizedBox(height: 16),
              _buildChallengeCard(
                context,
                title: 'Speed',
                description:
                    'Flat, fast routes designed for high-intensity interval training.',
                icon: Icons.speed_outlined,
                color: const Color(0xFFFF5722), // Orange for speed
              ),
              // Add padding at bottom for nav bar
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontFamily: 'Playfair Display',
            fontWeight: FontWeight.bold,
          ),
    );
  }

  Widget _buildRecommendationCard(
      String title, String subtitle, IconData icon, Color color) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 16),
          Text(title,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text(subtitle,
              style: const TextStyle(fontSize: 14, color: Colors.grey)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: CruizrTheme.background,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('Join',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  Widget _buildChallengeCard(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    ChallengeRoutesScreen(challengeType: title),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF2D2D2D),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 12,
                          color: CruizrTheme.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios,
                    size: 16, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
