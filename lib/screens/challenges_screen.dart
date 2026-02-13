import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../theme/app_theme.dart';
import 'package:flutter/gestures.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'dart:convert';
import '../services/user_service.dart';
import '../services/coach_service.dart';
import '../services/plan_parser_service.dart';
import '../services/calendar_service.dart';
import 'challenge_routes_screen.dart';
import 'main_navigation_screen.dart';
import 'plan_calendar_screen.dart';
import '../widgets/goal_fly_animation.dart';

class ChallengesScreen extends StatefulWidget {
  const ChallengesScreen({super.key});

  @override
  State<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends State<ChallengesScreen>
    with TickerProviderStateMixin {
  // Goal Setter State
  int _selectedTargetIndex = 0;
  int _selectedMetricIndex = 0;
  int _selectedDurationAmountIndex = 0;
  int _selectedDurationUnitIndex = 1;

  List<String> _targets = [];
  final List<String> _metrics = ['km', 'miles', 'cal', 'steps'];
  final List<String> _durationUnits = ['Day', 'Week', 'Month'];
  final List<String> _durationAmounts =
      List.generate(100, (index) => '${index + 1}');

  final GlobalKey _goalPickerKey = GlobalKey();

  late FixedExtentScrollController _targetController;
  late FixedExtentScrollController _metricController;
  late FixedExtentScrollController _durationAmountController;
  late FixedExtentScrollController _durationUnitController;

  // AI Coach State
  final TextEditingController _coachInputController = TextEditingController();
  bool _isCoachLoading = false;
  String _activeNode = ''; // "planner", "executor", "done", "error"
  String _plannerOutput = '';
  String _executorOutput = '';
  String _errorMessage = '';
  bool _showPlannerDetails = false;
  StreamSubscription<CoachEvent>? _coachSubscription;

  // Animation for the coach section
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _targetController = FixedExtentScrollController();
    _metricController = FixedExtentScrollController();
    _durationAmountController = FixedExtentScrollController();
    _durationUnitController =
        FixedExtentScrollController(initialItem: _selectedDurationUnitIndex);
    _updateTargets();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  void _updateTargets() {
    final metric = _metrics[_selectedMetricIndex];
    List<String> newTargets = [];

    if (metric == 'km' || metric == 'miles') {
      for (int i = 1; i <= 25; i++) {
        newTargets.add(i.toString());
      }
      for (int i = 30; i <= 1000; i += 5) {
        newTargets.add(i.toString());
      }
    } else if (metric == 'cal') {
      for (int i = 100; i <= 10000; i += 50) {
        newTargets.add(i.toString());
      }
    } else if (metric == 'steps') {
      for (int i = 1000; i <= 50000; i += 1000) {
        newTargets.add(i.toString());
      }
    }

    setState(() {
      _targets = newTargets;
      _selectedTargetIndex = 0;
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
    _coachInputController.dispose();
    _coachSubscription?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  /// Triggers the fly animation from goal picker to home icon
  void _triggerGoalFlyAnimation(String goalText) {
    final goalPickerContext = _goalPickerKey.currentContext;
    if (goalPickerContext == null) return;

    final goalPickerBox = goalPickerContext.findRenderObject() as RenderBox;
    final goalPickerPosition = goalPickerBox.localToGlobal(Offset.zero);
    final goalPickerSize = goalPickerBox.size;

    final startRect = Rect.fromLTWH(
      goalPickerPosition.dx,
      goalPickerPosition.dy,
      goalPickerSize.width,
      goalPickerSize.height,
    );

    final homeIconContext = MainNavigationScreen.homeIconKey.currentContext;
    if (homeIconContext == null) return;

    final homeIconBox = homeIconContext.findRenderObject() as RenderBox;
    final homeIconPosition = homeIconBox.localToGlobal(Offset.zero);
    final homeIconSize = homeIconBox.size;

    final endPosition = Offset(
      homeIconPosition.dx + homeIconSize.width / 2,
      homeIconPosition.dy + homeIconSize.height / 2,
    );

    GoalFlyAnimation.show(
      context: context,
      startRect: startRect,
      endPosition: endPosition,
      goalText: goalText,
    );
  }

  /// Generate a coaching plan via the AI backend
  void _generateCoachPlan(String query) {
    if (query.trim().isEmpty) return;

    setState(() {
      _isCoachLoading = true;
      _activeNode = 'planner';
      _plannerOutput = '';
      _executorOutput = '';
      _errorMessage = '';
      _showPlannerDetails = false;
    });

    _coachSubscription?.cancel();
    _coachSubscription = CoachService.generatePlan(query).listen(
      (event) {
        if (!mounted) return;
        setState(() {
          switch (event.node) {
            // Planner lifecycle
            case 'planner_start':
              _activeNode = 'planner';
              break;
            case 'planner_token':
              _activeNode = 'planner';
              _plannerOutput += event.token ?? '';
              break;
            case 'planner_done':
              _activeNode = 'executor';
              // Use full plan text if available, otherwise keep streamed text
              if (event.plan != null && event.plan!.isNotEmpty) {
                _plannerOutput = event.plan!;
              }
              break;

            // Executor lifecycle
            case 'executor_start':
              _activeNode = 'executor';
              break;
            case 'executor_token':
              _activeNode = 'executor';
              _executorOutput += event.token ?? '';
              break;
            case 'executor_done':
              _activeNode = 'done';
              if (event.finalResponse != null &&
                  event.finalResponse!.isNotEmpty) {
                _executorOutput = event.finalResponse!;
              }
              _isCoachLoading = false;
              break;

            // Terminal states
            case 'done':
              _activeNode = 'done';
              _isCoachLoading = false;
              break;
            case 'error':
              _activeNode = 'error';
              _errorMessage = event.status;
              _isCoachLoading = false;
              break;
          }
        });
      },
      onError: (e) {
        if (!mounted) return;
        setState(() {
          _activeNode = 'error';
          _errorMessage = e.toString();
          _isCoachLoading = false;
        });
      },
    );
  }

  /// Save generated plan to calendar and navigate to calendar view
  Future<void> _saveToCalendar() async {
    try {
      // Parse the AI output into structured events
      final events = PlanParserService.parse(_executorOutput);
      if (events.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not parse plan into calendar events'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Save to Firestore
      final calendarService = CalendarService();
      final planTitle = _coachInputController.text.isNotEmpty
          ? _coachInputController.text
          : 'Training Plan';
      await calendarService.savePlanToFirestore(
        events: events,
        planTitle: planTitle,
        rawPlanText: _executorOutput,
      );

      // Navigate to calendar screen
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => PlanCalendarScreen(
              events: events,
              planTitle: planTitle,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save plan: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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

              // AI Coach Section (replaces Recommended for You)
              _buildCoachSection(),
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
                      Expanded(
                        flex: 2,
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
                color: const Color(0xFF4CAF50),
              ),
              const SizedBox(height: 16),
              _buildChallengeCard(
                context,
                title: 'Speed',
                description:
                    'Flat, fast routes designed for high-intensity interval training.',
                icon: Icons.speed_outlined,
                color: const Color(0xFFFF5722),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  // ── AI Coach Section ────────────────────────────────────────────────────
  Widget _buildCoachSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header with badge
        Row(
          children: [
            _buildSectionTitle('AI Coach'),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: CruizrTheme.accentPink.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Beta',
                style: GoogleFonts.lato(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: CruizrTheme.accentPink,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Kimi plans your strategy, Mistral builds the schedule',
          style: GoogleFonts.lato(
            fontSize: 12,
            color: CruizrTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 16),

        // Prompt chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildPromptChip('Plan my 100km week'),
              const SizedBox(width: 8),
              _buildPromptChip('4-week race prep'),
              const SizedBox(width: 8),
              _buildPromptChip('Weekend only 60km'),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Input card
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
                child: TextField(
                  controller: _coachInputController,
                  maxLines: 2,
                  minLines: 1,
                  style: GoogleFonts.lato(
                    fontSize: 14,
                    color: CruizrTheme.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Describe your training goal...',
                    hintStyle: GoogleFonts.lato(
                      fontSize: 14,
                      color: CruizrTheme.textSecondary.withValues(alpha: 0.6),
                    ),
                    border: InputBorder.none,
                    filled: false,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                child: Row(
                  children: [
                    // Model indicators
                    _buildModelTag('🧠 Kimi', const Color(0xFF9B7DDB)),
                    const SizedBox(width: 6),
                    _buildModelTag('⚡ Mistral', const Color(0xFF5DB894)),
                    const Spacer(),
                    // Generate button
                    SizedBox(
                      height: 36,
                      child: ElevatedButton(
                        onPressed: _isCoachLoading
                            ? null
                            : () =>
                                _generateCoachPlan(_coachInputController.text),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: CruizrTheme.primaryDark,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              CruizrTheme.primaryDark.withValues(alpha: 0.5),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isCoachLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : Text(
                                'Generate',
                                style: GoogleFonts.lato(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Pipeline status & output
        if (_activeNode.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildPipelineStatus(),
        ],

        // Error message
        if (_activeNode == 'error') ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red.shade400, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _errorMessage,
                    style: GoogleFonts.lato(
                      fontSize: 13,
                      color: Colors.red.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        // Planner output (collapsible)
        if (_plannerOutput.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildOutputCard(
            title: 'Strategy',
            subtitle: 'Kimi',
            icon: Icons.psychology_outlined,
            color: const Color(0xFF9B7DDB),
            content: _plannerOutput,
            isCollapsible: true,
            isExpanded: _showPlannerDetails,
            onToggle: () =>
                setState(() => _showPlannerDetails = !_showPlannerDetails),
          ),
        ],

        // Executor output (main result)
        if (_executorOutput.isNotEmpty) ...[
          const SizedBox(height: 12),
          if (_tryParsePlan(_executorOutput).isNotEmpty)
            _buildPlanList(_tryParsePlan(_executorOutput))
          else
            _buildOutputCard(
              title: 'Your Training Plan',
              subtitle: 'Mistral',
              icon: Icons.calendar_month_outlined,
              color: const Color(0xFF5DB894),
              content: _executorOutput,
              isCollapsible: false,
            ),
        ],

        // Save to Calendar button (after plan is done)
        if (_activeNode == 'done' && _executorOutput.isNotEmpty) ...[
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _saveToCalendar,
              icon: const Icon(Icons.calendar_month, size: 20),
              label: Text(
                'Save to Calendar',
                style: GoogleFonts.lato(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5DB894),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ── Pipeline Status Indicator ───────────────────────────────────────────
  Widget _buildPipelineStatus() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildPipelineNode(
            label: 'Plan',
            icon: Icons.psychology_outlined,
            isActive: _activeNode == 'planner',
            isDone: _activeNode == 'executor' || _activeNode == 'done',
          ),
          _buildPipelineConnector(
            isDone: _activeNode == 'executor' || _activeNode == 'done',
          ),
          _buildPipelineNode(
            label: 'Schedule',
            icon: Icons.event_note_outlined,
            isActive: _activeNode == 'executor',
            isDone: _activeNode == 'done',
          ),
          _buildPipelineConnector(isDone: _activeNode == 'done'),
          _buildPipelineNode(
            label: 'Done',
            icon: Icons.check_circle_outline,
            isActive: false,
            isDone: _activeNode == 'done',
          ),
        ],
      ),
    );
  }

  Widget _buildPipelineNode({
    required String label,
    required IconData icon,
    required bool isActive,
    required bool isDone,
  }) {
    final color = isDone
        ? const Color(0xFF5DB894)
        : isActive
            ? CruizrTheme.accentPink
            : CruizrTheme.textSecondary.withValues(alpha: 0.4);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return Opacity(
              opacity: isActive ? 0.5 + (_pulseController.value * 0.5) : 1.0,
              child: child,
            );
          },
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isDone
                  ? color.withValues(alpha: 0.15)
                  : isActive
                      ? color.withValues(alpha: 0.12)
                      : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color: color,
                width: isDone || isActive ? 2 : 1,
              ),
            ),
            child: Icon(
              isDone ? Icons.check : icon,
              size: 16,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.lato(
            fontSize: 10,
            fontWeight: isDone || isActive ? FontWeight.w600 : FontWeight.w400,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildPipelineConnector({required bool isDone}) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: isDone
              ? const Color(0xFF5DB894).withValues(alpha: 0.4)
              : CruizrTheme.border,
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }

  // ── Output Card ─────────────────────────────────────────────────────────
  Widget _buildOutputCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String content,
    required bool isCollapsible,
    bool isExpanded = true,
    VoidCallback? onToggle,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          InkWell(
            onTap: isCollapsible ? onToggle : null,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 15, color: color),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: CruizrTheme.textPrimary,
                          ),
                        ),
                        Text(
                          subtitle,
                          style: GoogleFonts.lato(
                            fontSize: 11,
                            color: color,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isCollapsible)
                    Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: CruizrTheme.textSecondary,
                      size: 20,
                    ),
                ],
              ),
            ),
          ),
          // Content
          if (!isCollapsible || isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: CruizrTheme.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: MarkdownBody(
                  data: content,
                  selectable: true,
                  softLineBreak: true,
                  styleSheet: MarkdownStyleSheet(
                    p: GoogleFonts.lato(
                      fontSize: 13,
                      height: 1.6,
                      color: CruizrTheme.textPrimary,
                    ),
                    strong: GoogleFonts.lato(
                      fontWeight: FontWeight.bold,
                      color: CruizrTheme.textPrimary,
                    ),
                    tableBody: GoogleFonts.sourceCodePro(
                      fontSize: 11,
                      color: CruizrTheme.textPrimary,
                    ),
                    tableHead: GoogleFonts.sourceCodePro(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: CruizrTheme.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _tryParsePlan(String raw) {
    final List<Map<String, dynamic>> items = [];
    final lines = raw.split('\n');
    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      try {
        final Map<String, dynamic> data = jsonDecode(line);
        items.add(data);
      } catch (e) {
        // Ignore non-JSON lines (partial streams)
      }
    }
    return items;
  }

  Widget _buildPlanList(List<Map<String, dynamic>> plan) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFF5DB894).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.calendar_month_outlined,
                    size: 15, color: Color(0xFF5DB894)),
              ),
              const SizedBox(width: 10),
              Text(
                'Your Training Plan',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: CruizrTheme.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              _buildModelTag('Mistral', const Color(0xFF5DB894)),
            ],
          ),
        ),
        ...plan.map((day) => _buildDayCard(day)),
      ],
    );
  }

  Widget _buildDayCard(Map<String, dynamic> day) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: CruizrTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                day['day'] ?? 'Day',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: CruizrTheme.textPrimary,
                ),
              ),
              if (day['duration'] != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: CruizrTheme.background,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.timer_outlined,
                          size: 12, color: CruizrTheme.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        day['duration'],
                        style: GoogleFonts.lato(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: CruizrTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            day['activity'] ?? 'Rest',
            style: GoogleFonts.lato(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF5DB894),
            ),
          ),
          if (day['intensity'] != null &&
              day['intensity'].toString().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              "Intensity: ${day['intensity']}",
              style: GoogleFonts.lato(
                fontSize: 12,
                color: CruizrTheme.textSecondary,
              ),
            ),
          ],
          if (day['notes'] != null && day['notes'].toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF5DB894).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline,
                      size: 14, color: Color(0xFF5DB894)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      day['notes'],
                      style: GoogleFonts.lato(
                        fontSize: 12,
                        height: 1.4,
                        color: CruizrTheme.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Helper Widgets ──────────────────────────────────────────────────────
  Widget _buildPromptChip(String label) {
    return GestureDetector(
      onTap: () {
        _coachInputController.text = label;
        _generateCoachPlan(label);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: CruizrTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: CruizrTheme.border),
        ),
        child: Text(
          label,
          style: GoogleFonts.lato(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: CruizrTheme.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildModelTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: GoogleFonts.lato(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
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
