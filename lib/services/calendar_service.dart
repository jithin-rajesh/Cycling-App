import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as gcal;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../models/plan_event_model.dart';

/// Service handling:
/// 1. Saving plan events to Firestore
/// 2. Syncing plan events to Google Calendar via the Calendar API
class CalendarService {
  static const String _calendarScope =
      'https://www.googleapis.com/auth/calendar.events';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ── Firestore operations ─────────────────────────────────────────────

  /// Save a list of plan events to Firestore under the current user.
  /// Returns the planId used to group them.
  Future<String> savePlanToFirestore({
    required List<PlanEvent> events,
    required String planTitle,
    required String rawPlanText,
    int? colorValue,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('User not signed in');

    final planRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('plans')
        .doc(); // auto-generated ID

    // Save plan metadata
    await planRef.set({
      'title': planTitle,
      'rawText': rawPlanText,
      'createdAt': FieldValue.serverTimestamp(),
      'eventCount': events.length,
      'synced': false,
      'colorValue': colorValue,
    });

    // Save each event as a sub-document
    final batch = _firestore.batch();
    for (final event in events) {
      final eventRef = planRef.collection('events').doc(event.id);
      batch.set(eventRef, event.toMap());
    }
    await batch.commit();

    return planRef.id;
  }

  /// Load all plans for the current user.
  Future<List<Map<String, dynamic>>> loadPlans() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return [];

    final snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('plans')
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
  }

  /// Load events for a specific plan.
  Future<List<PlanEvent>> loadPlanEvents(String planId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return [];

    final snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('plans')
        .doc(planId)
        .collection('events')
        .orderBy('date')
        .get();

    return snapshot.docs.map((doc) => PlanEvent.fromMap(doc.data())).toList();
  }

  /// Load ALL events across ALL plans for the current user.
  /// Returns a flat list of PlanEvents, each with its colorValue set from the parent plan.
  Future<List<PlanEvent>> loadAllPlanEvents() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return [];

    final plansSnapshot =
        await _firestore.collection('users').doc(uid).collection('plans').get();

    final allEvents = <PlanEvent>[];

    for (final planDoc in plansSnapshot.docs) {
      final planData = planDoc.data();
      final colorValue = planData['colorValue'] as int?;

      final eventsSnapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('plans')
          .doc(planDoc.id)
          .collection('events')
          .orderBy('date')
          .get();

      for (final eventDoc in eventsSnapshot.docs) {
        final event = PlanEvent.fromMap(eventDoc.data());
        // Stamp the color from the parent plan
        event.colorValue = colorValue;
        // Store planId for deletion reference
        event.planId = planDoc.id;
        allEvents.add(event);
      }
    }

    return allEvents;
  }

  /// Delete an entire plan and its events.
  Future<void> deletePlan(String planId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final planRef =
        _firestore.collection('users').doc(uid).collection('plans').doc(planId);

    // 1. Delete all sub-collection events
    final events = await planRef.collection('events').get();
    final batch = _firestore.batch();
    for (final doc in events.docs) {
      batch.delete(doc.reference);
    }

    // 2. Delete the plan document itself
    batch.delete(planRef);

    await batch.commit();
  }

  /// Delete a single event from a plan.
  Future<void> deleteEvent(String planId, String eventId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final eventRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('plans')
        .doc(planId)
        .collection('events')
        .doc(eventId);

    await eventRef.delete();

    // Optionally update eventCount in parent plan
    final planRef =
        _firestore.collection('users').doc(uid).collection('plans').doc(planId);

    // We can't easily decrement atomically without a transaction or reading count first.
    // Making it simple for now: valid decrement if it exists.
    try {
      await planRef.update({'eventCount': FieldValue.increment(-1)});
    } catch (e) {
      // Ignore if plan doesn't exist or other error
    }
  }

  // ── Google Calendar operations ─────────────────────────────────────────

  /// Sync events to Google Calendar.
  /// Returns the number of events synced successfully.
  Future<int> syncToGoogleCalendar(List<PlanEvent> events) async {
    // Get Google auth with calendar scope
    final httpClient = await _getAuthenticatedClient();
    if (httpClient == null) {
      throw Exception('Failed to authenticate with Google Calendar');
    }

    try {
      final calendarApi = gcal.CalendarApi(httpClient);
      int synced = 0;

      for (final event in events) {
        try {
          final gEvent = gcal.Event()
            ..summary = '🚴 ${event.title}'
            ..description = event.description
            ..start = gcal.EventDateTime(
              dateTime: event.startDateTime,
              timeZone: _getLocalTimezone(),
            )
            ..end = gcal.EventDateTime(
              dateTime: event.endDateTime,
              timeZone: _getLocalTimezone(),
            )
            ..reminders = gcal.EventReminders(useDefault: false, overrides: [
              gcal.EventReminder(method: 'popup', minutes: 30),
            ]);

          final created = await calendarApi.events.insert(gEvent, 'primary');
          event.googleCalendarEventId = created.id;
          synced++;
        } catch (e) {
          debugPrint('Failed to sync event "${event.title}": $e');
        }
      }

      // Update Firestore with Google Calendar event IDs
      await _updateSyncStatus(events);

      return synced;
    } finally {
      httpClient.close();
    }
  }

  /// Get an authenticated HTTP client with Calendar scope.
  ///
  /// Reuses the existing GoogleSignIn session from login.
  /// Only requests the additional calendar scope if not already granted.
  Future<http.Client?> _getAuthenticatedClient() async {
    try {
      // Reuse the same GoogleSignIn instance — do NOT create a new one
      // with a different clientId or scope list, as it conflicts on web.
      final googleSignIn = GoogleSignIn(
        scopes: [_calendarScope],
      );

      // Get the currently signed-in account (from the login flow)
      GoogleSignInAccount? account = googleSignIn.currentUser;
      account ??= await googleSignIn.signInSilently();

      if (account == null) {
        debugPrint('Calendar sync: No signed-in Google account found');
        // As a fallback, prompt interactive sign-in
        account = await googleSignIn.signIn();
        if (account == null) return null;
      }

      // Request the calendar scope if not already granted
      final hasCalendarScope =
          await googleSignIn.requestScopes([_calendarScope]);
      if (!hasCalendarScope) {
        debugPrint('Calendar sync: User denied calendar scope');
        return null;
      }

      final googleAuth = await account.authentication;
      final accessToken = googleAuth.accessToken;
      if (accessToken == null) {
        debugPrint('Calendar sync: No access token received');
        return null;
      }

      return _GoogleAuthClient(accessToken);
    } catch (e) {
      debugPrint('Google Calendar auth error: $e');
      return null;
    }
  }

  /// Update Firestore with synced Google Calendar event IDs.
  Future<void> _updateSyncStatus(List<PlanEvent> events) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    // Find the plan these events belong to and update sync status
    // We look for events by their date to find matching plan
    final plansSnapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('plans')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();

    if (plansSnapshot.docs.isEmpty) return;

    final planId = plansSnapshot.docs.first.id;
    final planRef =
        _firestore.collection('users').doc(uid).collection('plans').doc(planId);

    await planRef.update({'synced': true});

    final batch = _firestore.batch();
    for (final event in events) {
      if (event.googleCalendarEventId != null) {
        final eventRef = planRef.collection('events').doc(event.id);
        batch.update(
            eventRef, {'googleCalendarEventId': event.googleCalendarEventId});
      }
    }
    await batch.commit();
  }

  String _getLocalTimezone() {
    final offset = DateTime.now().timeZoneOffset;
    final hours = offset.inHours.abs().toString().padLeft(2, '0');
    final minutes = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
    final sign = offset.isNegative ? '-' : '+';
    return 'UTC$sign$hours:$minutes';
  }
}

/// A simple authenticated HTTP client that adds the Bearer token.
class _GoogleAuthClient extends http.BaseClient {
  final String _accessToken;
  final http.Client _inner = http.Client();

  _GoogleAuthClient(this._accessToken);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['Authorization'] = 'Bearer $_accessToken';
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}
