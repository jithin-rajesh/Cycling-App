
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class ShareService {
  final ScreenshotController _screenshotController = ScreenshotController();

  ScreenshotController get screenshotController => _screenshotController;

  /// Captures the widget associated with the screenshotController and shares it.
  Future<void> shareCapturedWidget({String subject = 'Check out my ride!'}) async {
    try {
      // 1. Capture image
      final Uint8List? imageBytes = await _screenshotController.capture(
        pixelRatio: 2.0,
      );

      if (imageBytes != null) {
        await _shareImageBytes(imageBytes, subject);
      }
    } catch (e) {
      debugPrint('Error sharing activity: $e');
    }
  }

  Future<void> _shareImageBytes(Uint8List bytes, String text) async {
    try {
      final String fileName = 'activity_share_${DateTime.now().millisecondsSinceEpoch}.png';

      // 2. Share
      if (kIsWeb) {
        // On Web, persistent storage is restricted. Use XFile.fromData directly.
        // Share_plus on web might trigger a download or share dialog depending on the browser.
        await Share.shareXFiles(
          [XFile.fromData(bytes, name: fileName, mimeType: 'image/png')],
          text: text,
        );
      } else {
        // On Mobile/Desktop, save to temporary file for better compatibility with other apps
        final directory = await getTemporaryDirectory();
        final File file = File('${directory.path}/$fileName');
        await file.writeAsBytes(bytes);

        await Share.shareXFiles(
          [XFile(file.path, name: fileName)],
          text: text,
        );
      }
    } catch (e) {
      debugPrint('Error sharing: $e');
      rethrow;
    }
  }
}
