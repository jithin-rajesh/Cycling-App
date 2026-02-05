import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../services/activity_service.dart';
import '../models/activity_model.dart';
import 'start_activity_screen.dart';
import 'activity_history_screen.dart';
import 'activity_details_screen.dart';

import '../services/user_service.dart';
import '../widgets/profile_drawer.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late AnimationController _menuAnimController;
  final String _greeting = 'Welcome back!';
  String _activitySuggestion = 'Ready to move?';

  Map<String, dynamic> _stats = {
    'count': 0,
    'time': Duration.zero,
    'calories': 0.0,
  };
  List<ActivityModel> _recentActivities = [];

  @override
  void initState() {
    super.initState();
    _menuAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _loadData();
  }

  @override
  void dispose() {
    _menuAnimController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await _loadUserProfile();
    await _loadStats();
    await _loadRecentActivities();
  }

  Future<void> _loadStats() async {
    final stats = await ActivityService().getWeeklyStats();
    setState(() {
      _stats = stats;
    });
  }

  Future<void> _loadRecentActivities() async {
    final activities = await ActivityService().getRecentActivities();
    setState(() {
      _recentActivities = activities;
    });
  }

  Future<void> _loadUserProfile() async {
    // Existing logic...
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null && data.containsKey('activities')) {
          final List<dynamic> activities = data['activities'];
          if (activities.isNotEmpty) {
            final favorite = activities.first.toString();
            setState(() {
              _activitySuggestion = "Hey, let's go $favorite";
            });
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateString = DateFormat('EEEE, MMMM d').format(now);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: CruizrTheme.background,
      drawer: const ProfileDrawer(),
      onDrawerChanged: (isOpened) {
        if (isOpened) {
          _menuAnimController.forward();
        } else {
          _menuAnimController.reverse();
        }
      },
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.search,
                                size: 16, color: CruizrTheme.textSecondary),
                            const SizedBox(width: 8),
                            Text(
                              'Search activities, routes...',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                      color: CruizrTheme.textSecondary,
                                      fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () {
                      final isOpen =
                          _scaffoldKey.currentState?.isDrawerOpen ?? false;
                      if (isOpen) {
                        _scaffoldKey.currentState?.closeDrawer();
                      } else {
                        _scaffoldKey.currentState?.openDrawer();
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: AnimatedIcon(
                        icon: AnimatedIcons.menu_close,
                        progress: _menuAnimController,
                        color: CruizrTheme.textPrimary,
                        size: 28,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              Text(
                _greeting,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: CruizrTheme.primaryDark,
                    ),
              ),
              Text(
                dateString,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: CruizrTheme.textSecondary,
                    ),
              ),
              const SizedBox(height: 32),

              // Main Action Card
              Container(
                height: 220,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: CruizrTheme.accentPink.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: Stack(
                    children: [
                      // Background Gradient
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(0xFF4A2545),
                              Color(0xFF2E1A25)
                            ], // Deep Violet/Brown mix
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                      // Decorative Circles
                      Positioned(
                        top: -50,
                        right: -50,
                        child: Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.05),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: -30,
                        left: -30,
                        child: Container(
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFD97D84).withValues(
                                alpha: 0.1), // Accent pink low opacity
                          ),
                        ),
                      ),
                      // Content
                      Padding(
                        padding: const EdgeInsets.all(28.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'Daily Goal',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _activitySuggestion == 'Ready to move?'
                                  ? "Hey, let's go cycling!"
                                  : _activitySuggestion,
                              style: const TextStyle(
                                color: Color(0xFFFFF6F5), // Creamy White
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Playfair Display',
                                height: 1.1,
                              ),
                            ),
                            const Spacer(),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.of(context).push(MaterialPageRoute(
                                      builder: (_) =>
                                          const StartActivityScreen()));
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: const Color(0xFF5D4037),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16)),
                                  elevation: 0,
                                ),
                                child: const Text(
                                  'Start Activity',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
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
              ),
              const SizedBox(height: 32),

              // Stats Row
              Text(
                "This Week's Rhythm",
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontSize: 18),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                      child: _buildStatCard(
                          Icons.local_activity,
                          '${_stats['count']}',
                          'Activities',
                          CruizrTheme.accentPink)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _buildStatCard(
                          Icons.timer,
                          _formatDuration(_stats['time'] as Duration),
                          'Time',
                          const Color(0xFF5D4037))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _buildStatCard(
                          Icons.local_fire_department,
                          (_stats['calories'] as double).toStringAsFixed(0),
                          'Calories',
                          Colors.orange)),
                ],
              ),
              const SizedBox(height: 32),

              // Active Goals Section (Streamed)
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: UserService().getActiveGoalsStream(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const SizedBox.shrink();
                  }

                  final goals = snapshot.data!;

                  return Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Active Goals",
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  fontSize: 18,
                                  fontStyle: FontStyle.italic,
                                  color: CruizrTheme.textPrimary,
                                ),
                          ),
                          Text(
                            "${goals.length} running",
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: CruizrTheme.textSecondary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ActiveGoalsList(goals: goals),
                      const SizedBox(height: 32),
                    ],
                  );
                },
              ),

              // Recent Activities
              if (_recentActivities.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Recent Activities",
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontSize: 18, fontStyle: FontStyle.italic),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const ActivityHistoryScreen(),
                          ),
                        );
                      },
                      child: Text('See all →',
                          style: TextStyle(color: CruizrTheme.accentPink)),
                    )
                  ],
                ),
                const SizedBox(height: 8),
                ..._recentActivities.map((activity) => GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) =>
                                ActivityDetailsScreen(activity: activity),
                          ),
                        );
                      },
                      child: Column(
                        children: [
                          _buildActivityRow(
                              Icons.directions_bike,
                              activity.type,
                              '${activity.distance.toStringAsFixed(1)} km • ${_formatDurationShort(activity.duration)} • ${activity.calories.toStringAsFixed(0)} cal',
                              _getRelativeTime(activity.startTime)),
                          const SizedBox(height: 12),
                        ],
                      ),
                    )),
              ] else ...[
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text("No recent activities yet. Start moving!",
                        style: TextStyle(color: CruizrTheme.textSecondary)),
                  ),
                )
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    if (d.inHours > 0) {
      return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    }
    return '${d.inMinutes}m';
  }

  String _formatDurationShort(Duration d) {
    if (d.inHours > 0) {
      return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    }
    return '${d.inMinutes}m';
  }

  String _getRelativeTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays} days ago';
  }

  Widget _buildStatCard(
      IconData icon, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 5))
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(value,
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildActivityRow(
      IconData icon, String title, String subtitle, String time) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: CruizrTheme.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: CruizrTheme.textPrimary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          Text(time,
              style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }
}

class ActiveGoalsList extends StatefulWidget {
  final List<Map<String, dynamic>> goals;
  const ActiveGoalsList({super.key, required this.goals});

  @override
  State<ActiveGoalsList> createState() => _ActiveGoalsListState();
}

class _ActiveGoalsListState extends State<ActiveGoalsList> {
  late List<Map<String, dynamic>> _goals;

  @override
  void initState() {
    super.initState();
    _goals = List.from(widget.goals);
  }

  @override
  void didUpdateWidget(ActiveGoalsList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.goals.length != _goals.length) {
      _goals = List.from(widget.goals);
    } else {
      final newIds = widget.goals.map((e) => e['id']).toSet();
      final currentIds = _goals.map((e) => e['id']).toSet();
      if (!newIds.containsAll(currentIds)) {
        _goals = List.from(widget.goals);
      }
    }
  }

  Future<void> _deleteGoal(String goalId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Goal?'),
        content: const Text('Are you sure you want to remove this goal?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await UserService().deleteGoal(goalId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Goal deleted')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 140,
      child: ReorderableListView.builder(
        scrollDirection: Axis.horizontal,
        onReorder: (oldIndex, newIndex) {
          setState(() {
            if (oldIndex < newIndex) {
              newIndex -= 1;
            }
            final item = _goals.removeAt(oldIndex);
            _goals.insert(newIndex, item);
          });
        },
        proxyDecorator: (child, index, animation) {
          return Material(
            color: Colors.transparent,
            child: Transform.scale(scale: 1.05, child: child),
          );
        },
        itemCount: _goals.length,
        itemBuilder: (context, index) {
          final goal = _goals[index];
          return Container(
            key: ValueKey(goal['id']),
            margin: const EdgeInsets.only(right: 12),
            child: _buildGoalCard(goal),
          );
        },
      ),
    );
  }

  Widget _buildGoalCard(Map<String, dynamic> goal) {
    if (!goal.containsKey('endDate')) return const SizedBox.shrink();
    final endDate = (goal['endDate'] as Timestamp).toDate();
    final daysLeft = endDate.difference(DateTime.now()).inDays;
    final timeLeft = daysLeft > 0 ? '$daysLeft days left' : 'Ending soon';
    final progress = (goal['progress'] as num?)?.toDouble() ?? 0.0;

    return Container(
      width: 240,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: CruizrTheme.accentPink.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.flag_outlined,
                        color: CruizrTheme.accentPink, size: 20),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${goal['target']} ${goal['metric']}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Goal: ${goal['durationLabel']}',
                style:
                    TextStyle(color: CruizrTheme.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                timeLeft,
                style: const TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.w600,
                    fontSize: 13),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: CruizrTheme.background,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(CruizrTheme.accentPink),
                  minHeight: 6,
                ),
              ),
            ],
          ),
          Positioned(
            top: -12,
            right: -12,
            child: IconButton(
              icon: const Icon(Icons.close, size: 18, color: Colors.grey),
              onPressed: () => _deleteGoal(goal['id']),
              splashRadius: 20,
            ),
          ),
        ],
      ),
    );
  }
}
