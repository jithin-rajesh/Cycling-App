import 'package:google_maps_flutter/google_maps_flutter.dart';

class PolylineEncoder {
  static String encode(List<LatLng> points) {
    var result = StringBuffer();
    int lastLat = 0;
    int lastLng = 0;

    for (final point in points) {
      int lat = (point.latitude * 1e5).round();
      int lng = (point.longitude * 1e5).round();

      int dLat = lat - lastLat;
      int dLng = lng - lastLng;

      _encodeInt(dLat, result);
      _encodeInt(dLng, result);

      lastLat = lat;
      lastLng = lng;
    }

    return result.toString();
  }

  static void _encodeInt(int value, StringBuffer result) {
    int v = value < 0 ? ~(value << 1) : (value << 1);
    while (v >= 0x20) {
      result.writeCharCode((0x20 | (v & 0x1f)) + 63);
      v >>= 5;
    }
    result.writeCharCode(v + 63);
  }
}
