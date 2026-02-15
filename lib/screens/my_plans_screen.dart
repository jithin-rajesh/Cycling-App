import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/calendar_service.dart';
import '../theme/app_theme.dart';
import 'plan_calendar_screen.dart';

class MyPlansScreen extends StatefulWidget {
  const MyPlansScreen({super.key});

  @override
  State<MyPlansScreen> createState() => _MyPlansScreenState();
}

class _MyPlansScreenState extends State<MyPlansScreen> {
  final CalendarService _calendarService = CalendarService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _plans = [];

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    setState(() => _isLoading = true);
    try {
      final plans = await _calendarService.loadPlans();
      if (mounted) {
        setState(() {
          _plans = plans;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load plans: $e')),
        );
      }
    }
  }

  Future<void> _deletePlan(String planId) async {
    try {
      await _calendarService.deletePlan(planId);
      _loadPlans(); // Refresh list
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Plan deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete plan: $e')),
        );
      }
    }
  }

  void _confirmDelete(String planId, String title) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Plan?',
            style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold)),
        content: Text(
            'Are you sure you want to delete "$title"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.lato(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deletePlan(planId);
            },
            child: Text('Delete',
                style: GoogleFonts.lato(
                    color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _openPlan(Map<String, dynamic> planData) {
    final String title = planData['title'] ?? 'Training Plan';

    // Open the unified calendar — it loads ALL plans from Firestore
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlanCalendarScreen(
          planTitle: title,
        ),
      ),
    ).then((_) => _loadPlans());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CruizrTheme.background,
      appBar: AppBar(
        title: Text(
          'My Plans',
          style: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.bold,
            color: CruizrTheme.textPrimary,
          ),
        ),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: CruizrTheme.textPrimary),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _plans.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.calendar_today_outlined,
                          size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        'No saved plans yet.',
                        style: GoogleFonts.lato(
                          fontSize: 16,
                          color: CruizrTheme.textPrimary, // Fixed color
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Ask the AI Coach to create one!',
                        style: GoogleFonts.lato(
                          fontSize: 14,
                          color: CruizrTheme.textSecondary
                              .withValues(alpha: 0.7), // Fixed withOpacity
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _plans.length,
                  itemBuilder: (context, index) {
                    final plan = _plans[index];
                    final title = plan['title'] ?? 'Untitled Plan';
                    final count = plan['eventCount'] ?? 0;

                    DateTime date = DateTime.now();
                    if (plan['createdAt'] is Timestamp) {
                      date = (plan['createdAt'] as Timestamp).toDate();
                    }

                    final dateStr = DateFormat.yMMMd().format(date);
                    final colorValue = plan['colorValue'] as int?;
                    final color = colorValue != null
                        ? Color(colorValue)
                        : CruizrTheme.primaryDark;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black
                                  .withValues(alpha: 0.04), // Fixed withOpacity
                              blurRadius: 8,
                              offset: const Offset(0, 2))
                        ],
                      ),
                      child: InkWell(
                        onTap: () => _openPlan(plan),
                        onLongPress: () => _confirmDelete(plan['id'], title),
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: color.withValues(
                                      alpha: 0.15), // Fixed withOpacity
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.date_range, color: color),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: GoogleFonts.lato(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: CruizrTheme.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '$dateStr • $count sessions',
                                      style: GoogleFonts.lato(
                                        fontSize: 13,
                                        color: CruizrTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: Colors.grey),
                                onPressed: () =>
                                    _confirmDelete(plan['id'], title),
                              )
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
