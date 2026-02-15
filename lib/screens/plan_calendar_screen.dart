import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:table_calendar/table_calendar.dart';
import '../theme/app_theme.dart';
import '../models/plan_event_model.dart';
import '../services/calendar_service.dart';

/// A unified calendar that displays events from ALL saved plans.
/// Each plan's events are color-coded.
/// Can optionally be seeded with events (e.g. right after saving a new plan).
class PlanCalendarScreen extends StatefulWidget {
  /// Optional seed events (shown immediately while Firestore loads).
  final List<PlanEvent>? events;
  final String planTitle;
  final String? planId;
  final Color? color;

  const PlanCalendarScreen({
    super.key,
    this.events,
    this.planTitle = 'My Calendar',
    this.planId,
    this.color,
  });

  @override
  State<PlanCalendarScreen> createState() => _PlanCalendarScreenState();
}

class _PlanCalendarScreenState extends State<PlanCalendarScreen>
    with SingleTickerProviderStateMixin {
  late DateTime _focusedDay;
  DateTime? _selectedDay;
  Map<DateTime, List<PlanEvent>> _eventsByDay = {};
  List<PlanEvent> _allEvents = [];
  bool _isLoading = true;
  bool _isSyncing = false;
  bool _isSynced = false;
  late AnimationController _syncIconController;

  final CalendarService _calendarService = CalendarService();

  static const List<Color> _defaultPlanColors = [
    Color(0xFF5DB894),
    Color(0xFF9B7DDB),
    Color(0xFFE88D67),
    Color(0xFF6BA3D6),
    Color(0xFFDB7D9B),
    Color(0xFFD6C16B),
    Color(0xFF67C2E8),
  ];

  @override
  void initState() {
    super.initState();
    _syncIconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // If seed events are provided, show them immediately
    if (widget.events != null && widget.events!.isNotEmpty) {
      // Stamp color on seed events if provided
      if (widget.color != null) {
        for (final e in widget.events!) {
          e.colorValue ??= widget.color!.value;
          e.planId ??= widget.planId;
        }
      }
      _allEvents = List.from(widget.events!);
      _buildEventMap();
      _focusedDay = widget.events!.first.date;
      _selectedDay = _focusedDay;
    } else {
      _focusedDay = DateTime.now();
      _selectedDay = _focusedDay;
    }

    // Load all events from Firestore (merges with seed)
    _loadAllEvents();
  }

  @override
  void dispose() {
    _syncIconController.dispose();
    super.dispose();
  }

  Future<void> _loadAllEvents() async {
    try {
      final firestoreEvents = await _calendarService.loadAllPlanEvents();

      if (mounted) {
        setState(() {
          _allEvents = firestoreEvents;
          _buildEventMap();
          _isLoading = false;
          _isSynced = _allEvents.any((e) => e.googleCalendarEventId != null);

          // If we have events and no focused day set to a meaningful date
          if (_allEvents.isNotEmpty && _selectedDay == null) {
            _focusedDay = _allEvents.first.date;
            _selectedDay = _focusedDay;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load events: $e')),
        );
      }
    }
  }

  void _buildEventMap() {
    _eventsByDay = {};
    for (final event in _allEvents) {
      final key = DateTime(event.date.year, event.date.month, event.date.day);
      _eventsByDay.putIfAbsent(key, () => []).add(event);
    }
  }

  List<PlanEvent> _getEventsForDay(DateTime day) {
    final key = DateTime(day.year, day.month, day.day);
    return _eventsByDay[key] ?? [];
  }

  Color _getEventColor(PlanEvent event) {
    if (event.colorValue != null) return Color(event.colorValue!);
    // Fallback: use hash of planId for consistent color
    if (event.planId != null) {
      return _defaultPlanColors[
          event.planId.hashCode % _defaultPlanColors.length];
    }
    return CruizrTheme.accentPink;
  }

  Future<void> _syncToGoogle() async {
    setState(() => _isSyncing = true);
    _syncIconController.repeat();

    try {
      final service = CalendarService();
      final synced = await service.syncToGoogleCalendar(_allEvents);

      if (mounted) {
        setState(() {
          _isSyncing = false;
          _isSynced = true;
        });
        _syncIconController.stop();
        _syncIconController.reset();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Synced $synced events to Google Calendar'),
            backgroundColor: const Color(0xFF5DB894),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSyncing = false);
        _syncIconController.stop();
        _syncIconController.reset();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedEvents =
        _selectedDay != null ? _getEventsForDay(_selectedDay!) : <PlanEvent>[];

    return Scaffold(
      backgroundColor: CruizrTheme.background,
      appBar: AppBar(
        title: Text(
          widget.planTitle,
          style: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.bold,
            color: CruizrTheme.textPrimary,
          ),
        ),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: CruizrTheme.textPrimary),
        elevation: 0,
        actions: [
          if (_isSyncing)
            Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: 24,
                height: 24,
                child: RotationTransition(
                  turns: _syncIconController,
                  child: const Icon(Icons.sync, color: CruizrTheme.accentPink),
                ),
              ),
            )
          else
            IconButton(
              icon: Icon(
                _isSynced ? Icons.cloud_done : Icons.cloud_upload,
                color: _isSynced
                    ? const Color(0xFF5DB894)
                    : CruizrTheme.accentPink,
              ),
              tooltip: _isSynced
                  ? 'Synced to Google Calendar'
                  : 'Sync to Google Calendar',
              onPressed: _isSyncing ? null : _syncToGoogle,
            ),
        ],
      ),
      body: _isLoading && _allEvents.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Summary header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          CruizrTheme.primaryDark.withValues(alpha: 0.08),
                          CruizrTheme.accentPink.withValues(alpha: 0.06),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color:
                                CruizrTheme.primaryDark.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.directions_bike,
                              color: CruizrTheme.primaryDark, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Training Calendar',
                                style: GoogleFonts.lato(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: CruizrTheme.primaryDark,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_allEvents.length} sessions across all plans',
                                style: GoogleFonts.lato(
                                  fontSize: 12,
                                  color: CruizrTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Calendar widget
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
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
                  child: TableCalendar<PlanEvent>(
                    firstDay: DateTime.now().subtract(const Duration(days: 30)),
                    lastDay: DateTime.now().add(const Duration(days: 365)),
                    focusedDay: _focusedDay,
                    selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                    eventLoader: _getEventsForDay,
                    calendarFormat: CalendarFormat.month,
                    startingDayOfWeek: StartingDayOfWeek.monday,
                    headerStyle: HeaderStyle(
                      titleCentered: true,
                      formatButtonVisible: false,
                      titleTextStyle: GoogleFonts.playfairDisplay(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: CruizrTheme.primaryDark,
                      ),
                      leftChevronIcon: const Icon(Icons.chevron_left,
                          color: CruizrTheme.accentPink),
                      rightChevronIcon: const Icon(Icons.chevron_right,
                          color: CruizrTheme.accentPink),
                    ),
                    daysOfWeekStyle: DaysOfWeekStyle(
                      weekdayStyle: GoogleFonts.lato(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: CruizrTheme.textSecondary,
                      ),
                      weekendStyle: GoogleFonts.lato(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: CruizrTheme.accentPink.withValues(alpha: 0.7),
                      ),
                    ),
                    calendarStyle: CalendarStyle(
                      outsideDaysVisible: false,
                      todayDecoration: BoxDecoration(
                        color: CruizrTheme.primaryDark.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      todayTextStyle: GoogleFonts.lato(
                        color: CruizrTheme.primaryDark,
                        fontWeight: FontWeight.w600,
                      ),
                      selectedDecoration: const BoxDecoration(
                        color: CruizrTheme.accentPink,
                        shape: BoxShape.circle,
                      ),
                      selectedTextStyle: GoogleFonts.lato(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                      defaultTextStyle: GoogleFonts.lato(
                        color: CruizrTheme.textPrimary,
                      ),
                      weekendTextStyle: GoogleFonts.lato(
                        color: CruizrTheme.textSecondary,
                      ),
                      markerSize: 6,
                      markersMaxCount: 3,
                      markerMargin: const EdgeInsets.symmetric(horizontal: 1.5),
                    ),
                    // Custom marker builder to show each event's plan color
                    calendarBuilders: CalendarBuilders(
                      markerBuilder: (context, date, events) {
                        if (events.isEmpty) return null;
                        return Positioned(
                          bottom: 4,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: events.take(3).map((event) {
                              return Container(
                                width: 6,
                                height: 6,
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 1.5),
                                decoration: BoxDecoration(
                                  color: _getEventColor(event),
                                  shape: BoxShape.circle,
                                ),
                              );
                            }).toList(),
                          ),
                        );
                      },
                    ),
                    onDaySelected: (selectedDay, focusedDay) {
                      setState(() {
                        _selectedDay = selectedDay;
                        _focusedDay = focusedDay;
                      });
                    },
                    onPageChanged: (focusedDay) {
                      _focusedDay = focusedDay;
                    },
                  ),
                ),

                const SizedBox(height: 16),

                // Events list for selected day
                Expanded(
                  child: selectedEvents.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.event_available,
                                size: 48,
                                color: CruizrTheme.textSecondary
                                    .withValues(alpha: 0.3),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'No sessions on this day',
                                style: GoogleFonts.lato(
                                  fontSize: 14,
                                  color: CruizrTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: selectedEvents.length,
                          itemBuilder: (context, index) {
                            return _buildEventCard(selectedEvents[index]);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildEventCard(PlanEvent event) {
    final color = _getEventColor(event);
    final hasTime = event.startHour != null;
    final timeStr = hasTime
        ? '${event.startHour!.toString().padLeft(2, '0')}:${(event.startMinute ?? 0).toString().padLeft(2, '0')}'
        : 'Flexible';
    final durationStr = event.durationMinutes != null
        ? '${event.durationMinutes} min'
        : '~1 hour';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onLongPress: () => _showDeleteEventDialog(event),
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Color accent bar
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Time column
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.schedule,
                      size: 16,
                      color: color.withValues(alpha: 0.7),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      timeStr,
                      style: GoogleFonts.lato(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: CruizrTheme.primaryDark,
                      ),
                    ),
                    Text(
                      durationStr,
                      style: GoogleFonts.lato(
                        fontSize: 10,
                        color: CruizrTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Divider
              Container(
                width: 1,
                color: CruizrTheme.border.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              event.title,
                              style: GoogleFonts.lato(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: CruizrTheme.primaryDark,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (event.googleCalendarEventId != null)
                            Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Icon(
                                Icons.cloud_done,
                                size: 14,
                                color: const Color(0xFF5DB894)
                                    .withValues(alpha: 0.7),
                              ),
                            ),
                        ],
                      ),
                      if (event.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          event.description,
                          style: GoogleFonts.lato(
                            fontSize: 12,
                            color: CruizrTheme.textSecondary,
                            height: 1.4,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteEventDialog(PlanEvent event) {
    final planId = event.planId ?? widget.planId;
    if (planId == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Session?',
            style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold)),
        content: Text('Delete "${event.title}" from the plan?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.lato(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _calendarService.deleteEvent(planId, event.id);
                setState(() {
                  _allEvents.remove(event);
                  _buildEventMap();
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Session deleted')));
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to delete: $e')));
                }
              }
            },
            child: Text('Delete',
                style: GoogleFonts.lato(
                    color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
