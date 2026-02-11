import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Event emitted during the AI coaching pipeline
class CoachEvent {
  final String node; // planner_start, planner_token, planner_done,
  //                    executor_start, executor_token, executor_done,
  //                    done, error
  final String status;
  final String? token;
  final String? plan;
  final String? finalResponse;

  CoachEvent({
    required this.node,
    required this.status,
    this.token,
    this.plan,
    this.finalResponse,
  });

  factory CoachEvent.fromJson(Map<String, dynamic> json) {
    return CoachEvent(
      node: json['node'] ?? '',
      status: json['status'] ?? '',
      token: json['token'],
      plan: json['plan'],
      finalResponse: json['final_response'],
    );
  }
}

/// Service to communicate with the AI cycling coach backend
class CoachService {
  /// Returns the base URL for the API.
  /// In production (Vercel), uses relative path (same origin).
  /// In local dev (localhost), points to the local Python dev server.
  static String get _baseUrl {
    if (kIsWeb) {
      final uri = Uri.base;
      if (uri.host == 'localhost' || uri.host == '127.0.0.1') {
        return 'http://localhost:8000';
      }
      return '';
    }
    return 'http://localhost:8000';
  }

  /// Streams coaching events from the planner→executor pipeline.
  /// Yields token-level events for real-time display.
  static Stream<CoachEvent> generatePlan(String query) async* {
    final url = Uri.parse('$_baseUrl/api/plan');

    try {
      final request = http.Request('POST', url);
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode({'query': query});

      final client = http.Client();
      final response = await client.send(request);

      if (response.statusCode != 200) {
        yield CoachEvent(
          node: 'error',
          status: 'Server returned ${response.statusCode}',
        );
        client.close();
        return;
      }

      // Parse SSE stream
      String buffer = '';
      await for (final chunk in response.stream.transform(utf8.decoder)) {
        buffer += chunk;

        // Process complete SSE messages (delimited by \n\n)
        while (buffer.contains('\n\n')) {
          final endIndex = buffer.indexOf('\n\n');
          final message = buffer.substring(0, endIndex);
          buffer = buffer.substring(endIndex + 2);

          for (final line in message.split('\n')) {
            if (line.startsWith('data: ')) {
              final jsonStr = line.substring(6);
              try {
                final data = jsonDecode(jsonStr) as Map<String, dynamic>;
                yield CoachEvent.fromJson(data);
              } catch (e) {
                debugPrint('Failed to parse SSE data: $e');
              }
            }
          }
        }
      }

      client.close();
    } catch (e) {
      yield CoachEvent(
        node: 'error',
        status: 'Connection failed: $e',
      );
    }
  }
}
