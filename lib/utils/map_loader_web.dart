// web implementation
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:async';
import 'package:flutter/foundation.dart';

import '../config/secrets.dart';

Future<void> loadGoogleMaps() async {
  const apiKey = googleMapsApiKey;

  if (apiKey.isEmpty) {
    debugPrint('GOOGLE_MAPS_API_KEY is missing!');
    return;
  }

  final completer = Completer<void>();

  // Check if script is already present
  if (html.document.getElementById('google-maps-sdk') != null) {
    return;
  }

  final script = html.ScriptElement()
    ..id = 'google-maps-sdk'
    ..src =
        'https://maps.googleapis.com/maps/api/js?key=$apiKey' // Removed libraries=drawing,places if not needed, add if needed
    ..async = true
    ..defer = true;

  script.onLoad.listen((_) => completer.complete());
  script.onError
      .listen((_) => completer.completeError('Failed to load Google Maps SDK'));

  html.document.head!.append(script);

  return completer.future;
}
