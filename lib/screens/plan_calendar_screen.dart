import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:table_calendar/table_calendar.dart';
import '../theme/app_theme.dart';
import '../models/plan_event_model.dart';
import '../services/calendar_service.dart';

class PlanCalendarScreen extends StatefulWidget {
  final List<PlanEvent> events;
  final String planTitle;

  const PlanCalendarScreen({
    super.key,
    required this.events,
    required this.planTitle,
  });

  @override
  State<PlanCalendarScreen> createState() => _PlanCalendarScreenState();
}

class _PlanCalendarScreenState extends State<PlanCalendarScreen>
    with SingleTickerProviderStateMixin {
  late DateTime _focusedDay;
  DateTime? _selectedDay;
  late Map<DateTime, List<PlanEvent>> _eventsByDay;
  bool _isSyncing = false;
  bool _isSynced = false;
  late AnimationController _syncIconController;

  @override
  void initState() {
    super.initState();
    _buildEventMap();
    _focusedDay = widget.events.isNotEmpty
        ? widget.events.first.date
        : DateTime.now();
    _selectedDay = _focusedDay;
    _syncIconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    // Check if already synced
    _isSynced = widget.events.any((e) => e.googleCalendarEventId != null);
  }

  @override
  void dispose() {
    _syncIconController.dispose();
    super.dispose();
  }

  void _buildEventMap() {
    _eventsByDay = {};
    for (final event in widget.events) {
      final key = DateTime(event.date.year, event.date.month, event.date.day);
      _eventsByDay.putIfAbsent(key, () => []).add(event);
    }
  }

  List<PlanEvent> _getEventsForDay(DateTime day) {
    final key = DateTime(day.year, day.month, day.day);
    return _eventsByDay[key] ?? [];
  }

  Future<void> _syncToGoogle() async {
    setState(() => _isSyncing = true);
    _syncIconController.repeat();

    try {
      final service = CalendarService();
      final synced = await service.syncToGoogleCalendar(widget.events);

      if (mounted) {
        setState(() {
          _isSyncing = false;
          _isSynced = synced > 0;
        });
        _syncIconController.stop();
        _syncIconController.reset();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              synced > 0
                  ? '✅ $synced events synced to Google Calendar!'
                  : '⚠️ No events were synced',
            ),
            backgroundColor:
                synced > 0 ? const Color(0xFF5DB894) : Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
            content: Text('Failed to sync: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedEvents = _selectedDay != null
        ? _getEventsForDay(_selectedDay!)
        : <PlanEvent>[];

    return Scaffold(
      backgroundColor: CruizrTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon:
              const Icon(Icons.arrow_back_ios, color: CruizrTheme.primaryDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Training Calendar',
          style: GoogleFonts.playfairDisplay(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: CruizrTheme.primaryDark,
          ),
        ),
        centerTitle: true,
        actions: [
          // Sync to Google Calendar button
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _isSyncing
                ? Padding(
                    padding: const EdgeInsets.all(12),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: RotationTransition(
                        turns: _syncIconController,
                        child: const Icon(Icons.sync,
                            color: CruizrTheme.accentPink),
                      ),
                    ),
                  )
                : IconButton(
                    icon: Icon(
                      _isSynced ? Icons.cloud_done : Icons.cloud_upload,
                      color: _isSynced
                          ? const Color(0xFF5DB894)
                          : CruizrTheme.accentPink,
                    ),
                    tooltip: _isSynced
                        ? 'Synced to Google Calendar'
                        : 'Sync to Google Calendar',
                    onPressed: _isSynced ? null : _syncToGoogle,
                  ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Plan info card
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    CruizrTheme.accentPink.withValues(alpha: 0.12),
                    CruizrTheme.primaryDark.withValues(alpha: 0.06),
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
                      color: CruizrTheme.accentPink.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.directions_bike,
                        color: CruizrTheme.accentPink, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.planTitle,
                          style: GoogleFonts.lato(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: CruizrTheme.primaryDark,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.events.length} training sessions',
                          style: GoogleFonts.lato(
                            fontSize: 12,
                            color: CruizrTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!_isSynced)
                    GestureDetector(
                      onTap: _isSyncing ? null : _syncToGoogle,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: CruizrTheme.accentPink,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.sync, color: Colors.white, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              'Sync',
                              style: GoogleFonts.lato(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
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
                markerDecoration: const BoxDecoration(
                  color: CruizrTheme.accentPink,
                  shape: BoxShape.circle,
                ),
                markerSize: 6,
                markersMaxCount: 3,
                markerMargin: const EdgeInsets.symmetric(horizontal: 1.5),
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

          // Events list
          Expanded(
            child: selectedEvents.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.event_available,
                          size: 48,
                          color: CruizrTheme.textSecondary.withValues(alpha: 0.3),
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
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Color accent bar
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: CruizrTheme.accentPink,
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
                    color: CruizrTheme.accentPink.withValues(alpha: 0.7),
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
    );
  }
}
