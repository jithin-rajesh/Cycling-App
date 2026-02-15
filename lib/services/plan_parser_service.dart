import 'dart:convert';
import '../models/plan_event_model.dart';

/// Parses AI-generated training plan text into structured [PlanEvent] objects.
///
/// Supports TWO input formats:
/// 1. **JSON Lines** – one JSON object per line (from the Mistral executor):
///    `{"day":"Day 1","activity":"Easy Recovery","duration":"45 min",...}`
/// 2. **Markdown text** – traditional "**Day 1 – Monday: …**" format.
class PlanParserService {
  /// Parse raw plan text into a list of [PlanEvent]s starting from [startDate].
  /// If [startDate] is null defaults to the next Monday from today.
  static List<PlanEvent> parse(String planText, {DateTime? startDate}) {
    if (planText.trim().isEmpty) return [];

    startDate ??= _nextMonday();

    // 1. Try JSON Lines first (primary format from executor)
    final jsonEvents = _tryParseJsonLines(planText, startDate);
    if (jsonEvents.isNotEmpty) return jsonEvents;

    // 2. Fall back to Markdown parsing
    return _parseMarkdown(planText, startDate);
  }

  // ── JSON Lines parser ───────────────────────────────────────────────────

  static List<PlanEvent> _tryParseJsonLines(String text, DateTime startDate) {
    final events = <PlanEvent>[];
    final lines = text.split('\n');
    int dayIndex = 0;

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      // Quick check: must start with '{'
      if (!trimmed.startsWith('{')) continue;

      try {
        final Map<String, dynamic> data = jsonDecode(trimmed);

        final dayStr = data['day']?.toString() ?? '';
        final activity = data['activity']?.toString() ?? 'Training';
        final duration = data['duration']?.toString() ?? '';
        final intensity = data['intensity']?.toString() ?? '';
        final notes = data['notes']?.toString() ?? '';

        // Try to extract day number from "Day 1", "Day 2" etc.
        final dayMatch = RegExp(r'(\d+)').firstMatch(dayStr);
        if (dayMatch != null) {
          dayIndex = int.parse(dayMatch.group(1)!) - 1;
        }

        // Build description from available fields
        final descParts = <String>[];
        if (intensity.isNotEmpty) descParts.add('Intensity: $intensity');
        if (duration.isNotEmpty) descParts.add('Duration: $duration');
        if (notes.isNotEmpty) descParts.add(notes);

        // Determine the title
        String title = dayStr.isNotEmpty ? '$dayStr – $activity' : activity;

        events.add(PlanEvent(
          id: 'plan_$dayIndex',
          title: title,
          description: descParts.join('\n'),
          date: startDate.add(Duration(days: dayIndex)),
          startHour: 7,
          startMinute: 0,
          durationMinutes: _extractDuration(duration) ?? 60,
        ));

        dayIndex++; // increment for next item if no explicit day number
      } catch (_) {
        // Not valid JSON — skip this line, maybe mixed content
        continue;
      }
    }

    return events;
  }

  // ── Markdown parser (legacy) ────────────────────────────────────────────

  static List<PlanEvent> _parseMarkdown(String planText, DateTime startDate) {
    final events = <PlanEvent>[];
    final lines = planText.split('\n');
    String currentTitle = '';
    StringBuffer currentDescription = StringBuffer();
    int dayIndex = -1;
    int currentWeek = 1;
    int? durationMinutes;

    final weekHeaderRegex =
        RegExp(r'^\*{0,3}\s*#{0,4}\s*Week\s+(\d+)', caseSensitive: false);
    final dayHeaderRegex = RegExp(r'Day\s+(\d+)', caseSensitive: false);

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      // Detect Week Header (e.g. "Week 2")
      final weekMatch = weekHeaderRegex.firstMatch(line);
      if (weekMatch != null) {
        if (line.length < 20) {
          currentWeek = int.parse(weekMatch.group(1)!);
          continue;
        }
      }

      // Detect day/session headers
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

        // Calculate new day index
        final dayMatch = dayHeaderRegex.firstMatch(line);
        if (dayMatch != null) {
          int dayNum = int.parse(dayMatch.group(1)!);
          if (dayNum > 7) {
            dayIndex = dayNum - 1;
          } else {
            dayIndex = (currentWeek - 1) * 7 + (dayNum - 1);
          }
        } else {
          dayIndex++;
        }

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

    // Explicit "Day X" pattern
    if (RegExp(r'^\*{0,3}\s*#{0,4}\s*\**\s*day\s+\d+', caseSensitive: false)
        .hasMatch(line)) {
      return true;
    }

    // Week + Day pattern (e.g. "Week 1 Day 1")
    if (lower.contains('week') && lower.contains('day')) {
      if (RegExp(r'week\s+\d+.*day\s+\d+', caseSensitive: false)
          .hasMatch(line)) {
        return true;
      }
    }

    // Day of week names (Monday, etc.)
    if (RegExp(
            r'^\*{0,3}\s*#{0,4}\s*\**\s*(monday|tuesday|wednesday|thursday|friday|saturday|sunday)',
            caseSensitive: false)
        .hasMatch(line)) {
      return true;
    }

    // "Session X" pattern
    if (RegExp(r'^\*{0,3}\s*#{0,4}\s*\**\s*session\s+\d+', caseSensitive: false)
        .hasMatch(line)) {
      return true;
    }

    // "### Category" headers (Markdown headers likely denoting a new section if they contain keywords)
    if (line.trim().startsWith('###')) {
      if (lower.contains('ride') ||
          lower.contains('training') ||
          lower.contains('rest') ||
          lower.contains('recovery') ||
          lower.contains('interval') ||
          lower.contains('endurance')) {
        return true;
      }
    }

    return false;
  }

  static String _cleanHeader(String line) {
    // Remove markdown formatting (*, #)
    var cleaned = line.replaceAll(RegExp(r'[*#]+'), '').trim();
    // Remove "Header:" style
    if (cleaned.endsWith(':')) {
      cleaned = cleaned.substring(0, cleaned.length - 1).trim();
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

    final hourMatch = RegExp(r'(\d+)\s*(?:hour|hr|h)', caseSensitive: false)
        .firstMatch(lower);
    if (hourMatch != null) {
      final hours = int.tryParse(hourMatch.group(1)!) ?? 1;
      // Check for additional minutes like "1h30m"
      final additionalMin = RegExp(r'(\d+)\s*m(?:in)?', caseSensitive: false)
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
    final nextMon =
        now.add(Duration(days: daysUntilMonday == 0 ? 7 : daysUntilMonday));
    return DateTime(nextMon.year, nextMon.month, nextMon.day);
  }
}
