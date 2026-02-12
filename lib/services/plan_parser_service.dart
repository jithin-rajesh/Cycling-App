import '../models/plan_event_model.dart';

/// Parses AI-generated training plan text into structured [PlanEvent] objects.
///
/// The AI output typically looks like:
///   **Day 1 – Monday: Easy Recovery**
///   Distance: 15km | Duration: ~45 min
///   Description text ...
///
///   **Day 2 – Tuesday: Interval Training**
///   ...
class PlanParserService {
  /// Parse raw plan text into a list of [PlanEvent]s starting from [startDate].
  /// If [startDate] is null defaults to the next Monday from today.
  static List<PlanEvent> parse(String planText, {DateTime? startDate}) {
    final events = <PlanEvent>[];
    if (planText.trim().isEmpty) return events;

    startDate ??= _nextMonday();

    // Split into lines and process
    final lines = planText.split('\n');
    String currentTitle = '';
    StringBuffer currentDescription = StringBuffer();
    int dayIndex = -1;
    int? durationMinutes;

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      // Detect day/session headers
      // Patterns: "**Day 1 ...**", "### Day 1", "Day 1:", "**Monday:**"
      if (_isDayHeader(line)) {
        // Save previous event if any
        if (dayIndex >= 0 && currentTitle.isNotEmpty) {
          events.add(_createEvent(
            dayIndex: dayIndex,
            startDate: startDate,
            title: currentTitle,
            description: currentDescription.toString().trim(),
            durationMinutes: durationMinutes,
          ));
        }

        dayIndex++;
        currentTitle = _cleanHeader(line);
        currentDescription = StringBuffer();
        durationMinutes = null;
        continue;
      }

      // Try to extract duration from line
      final extractedDuration = _extractDuration(line);
      if (extractedDuration != null) {
        durationMinutes = extractedDuration;
      }

      // Accumulate description
      if (dayIndex >= 0) {
        currentDescription.writeln(line);
      }
    }

    // Save last event
    if (dayIndex >= 0 && currentTitle.isNotEmpty) {
      events.add(_createEvent(
        dayIndex: dayIndex,
        startDate: startDate,
        title: currentTitle,
        description: currentDescription.toString().trim(),
        durationMinutes: durationMinutes,
      ));
    }

    // Fallback: if no events parsed, create a single event with full text
    if (events.isEmpty && planText.trim().isNotEmpty) {
      events.add(PlanEvent(
        id: 'plan_0',
        title: 'Training Plan',
        description: planText.trim(),
        date: startDate,
        startHour: 7,
        startMinute: 0,
        durationMinutes: 60,
      ));
    }

    return events;
  }

  static bool _isDayHeader(String line) {
    final lower = line.toLowerCase();
    // **Day 1 ...** or ### Day 1 or Day 1: ... or **Monday:** etc.
    if (RegExp(r'^\*{0,3}\s*#{0,4}\s*\**\s*day\s+\d+', caseSensitive: false)
        .hasMatch(line)) {
      return true;
    }
    // **Monday**, **Tuesday**, etc.
    if (RegExp(
            r'^\*{0,3}\s*\**\s*(monday|tuesday|wednesday|thursday|friday|saturday|sunday)',
            caseSensitive: false)
        .hasMatch(line)) {
      return true;
    }
    // "Week X, Day Y" pattern
    if (RegExp(r'^\*{0,3}\s*\**\s*week\s+\d+.*day\s+\d+',
            caseSensitive: false)
        .hasMatch(line)) {
      return true;
    }
    // "Session X" pattern
    if (RegExp(r'^\*{0,3}\s*\**\s*session\s+\d+', caseSensitive: false)
        .hasMatch(line)) {
      return true;
    }
    // "### " markdown header with ride/training keywords
    if (line.startsWith('###') &&
        (lower.contains('ride') ||
            lower.contains('training') ||
            lower.contains('rest') ||
            lower.contains('recovery') ||
            lower.contains('workout'))) {
      return true;
    }
    return false;
  }

  static String _cleanHeader(String line) {
    // Remove markdown formatting
    var cleaned = line.replaceAll(RegExp(r'[*#]+'), '').trim();
    // Remove trailing colons
    if (cleaned.endsWith(':')) {
      cleaned = cleaned.substring(0, cleaned.length - 1).trim();
    }
    // Truncate if too long
    if (cleaned.length > 80) {
      cleaned = '${cleaned.substring(0, 77)}...';
    }
    return cleaned;
  }

  static int? _extractDuration(String line) {
    final lower = line.toLowerCase();
    // "Duration: ~45 min" or "45 minutes" or "1 hour" or "1h30m"
    final minMatch =
        RegExp(r'(\d+)\s*(?:min(?:utes?)?|mins)', caseSensitive: false)
            .firstMatch(lower);
    if (minMatch != null) {
      return int.tryParse(minMatch.group(1)!);
    }

    final hourMatch =
        RegExp(r'(\d+)\s*(?:hour|hr|h)', caseSensitive: false)
            .firstMatch(lower);
    if (hourMatch != null) {
      final hours = int.tryParse(hourMatch.group(1)!) ?? 1;
      // Check for additional minutes like "1h30m"
      final additionalMin =
          RegExp(r'(\d+)\s*m(?:in)?', caseSensitive: false)
              .firstMatch(lower.substring(hourMatch.end));
      final mins = additionalMin != null
          ? (int.tryParse(additionalMin.group(1)!) ?? 0)
          : 0;
      return hours * 60 + mins;
    }

    return null;
  }

  static PlanEvent _createEvent({
    required int dayIndex,
    required DateTime startDate,
    required String title,
    required String description,
    int? durationMinutes,
  }) {
    return PlanEvent(
      id: 'plan_$dayIndex',
      title: title,
      description: description,
      date: startDate.add(Duration(days: dayIndex)),
      startHour: 7,
      startMinute: 0,
      durationMinutes: durationMinutes ?? 60,
    );
  }

  static DateTime _nextMonday() {
    final now = DateTime.now();
    // Find next Monday (or tomorrow if today is Sunday)
    final daysUntilMonday = (DateTime.monday - now.weekday + 7) % 7;
    final nextMon = now.add(Duration(days: daysUntilMonday == 0 ? 7 : daysUntilMonday));
    return DateTime(nextMon.year, nextMon.month, nextMon.day);
  }
}
