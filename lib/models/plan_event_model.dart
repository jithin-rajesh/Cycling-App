import 'package:cloud_firestore/cloud_firestore.dart';

class PlanEvent {
  final String id;
  final String title;
  final String description;
  final DateTime date;
  final int? startHour; // 0-23
  final int? startMinute; // 0-59
  final int? durationMinutes;
  String? googleCalendarEventId;

  PlanEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    this.startHour,
    this.startMinute,
    this.durationMinutes,
    this.googleCalendarEventId,
  });

  /// Start time as a DateTime (defaults to 7:00 AM if not set)
  DateTime get startDateTime {
    return DateTime(
      date.year,
      date.month,
      date.day,
      startHour ?? 7,
      startMinute ?? 0,
    );
  }

  /// End time as a DateTime (defaults to 1 hour duration)
  DateTime get endDateTime {
    return startDateTime.add(Duration(minutes: durationMinutes ?? 60));
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'date': Timestamp.fromDate(date),
      'startHour': startHour,
      'startMinute': startMinute,
      'durationMinutes': durationMinutes,
      'googleCalendarEventId': googleCalendarEventId,
    };
  }

  factory PlanEvent.fromMap(Map<String, dynamic> map) {
    return PlanEvent(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      date: (map['date'] as Timestamp).toDate(),
      startHour: map['startHour'],
      startMinute: map['startMinute'],
      durationMinutes: map['durationMinutes'],
      googleCalendarEventId: map['googleCalendarEventId'],
    );
  }
}
