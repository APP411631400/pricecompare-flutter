import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';

enum RouteMode { driving, walking, cycling }

class DirectionsService {
  static const String _orsBase = 'https://api.openrouteservice.org/v2/directions';
  static const String _osrmDemo = 'https://router.project-osrm.org/route/v1/driving';
  static String apiKey = 'eyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6IjkxMzljMjI5NmY0ZDQzMTg5NTg5MTAyYmE2OTZjOGQ4IiwiaCI6Im11cm11cjY0In0=';
  static RouteMode _defaultMode = RouteMode.driving;
  static void setDefaultMode(RouteMode m) => _defaultMode = m;

  static Future<List<LatLng>> getRoutePolyline({
    required LatLng origin,
    required LatLng destination,
    RouteMode? mode,
  }) async {
    final m = mode ?? _defaultMode;

    // ① 先試 ORS（支援 driving/walking/cycling）
    final orsPoints = await _tryORS(origin, destination, m);
    if (orsPoints.isNotEmpty) return orsPoints;

    // ② ORS 失敗或回空 → 退回 OSRM demo（只支援 driving）
    if (m == RouteMode.driving) {
      final osrmPoints = await _tryOSRM(origin, destination);
      if (osrmPoints.isNotEmpty) return osrmPoints;
    }

    // ③ 都沒拿到 → 回空（呼叫端就不畫）
    return const <LatLng>[];
  }

  // --- ORS ---
  static Future<List<LatLng>> _tryORS(
      LatLng origin, LatLng destination, RouteMode m) async {
    final profile = switch (m) {
      RouteMode.driving => 'driving-car',
      RouteMode.walking => 'foot-walking',
      RouteMode.cycling => 'cycling-regular',
    };

    final resp = await http.post(
      Uri.parse('$_orsBase/$profile'),
      headers: {
        'Authorization': apiKey,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'coordinates': [
          [origin.longitude, origin.latitude],
          [destination.longitude, destination.latitude],
        ],
        'instructions': false,
        'geometry_format': 'encodedpolyline',
        'geometry_simplify': false,
      }),
    );

    if (resp.statusCode != 200) return const <LatLng>[];
    final data = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    final routes = (data['routes'] as List?) ?? [];
    if (routes.isEmpty) return const <LatLng>[];
    final encoded = routes.first['geometry'] as String;
    return _decodePolyline(encoded);
  }

  // --- OSRM demo（driving only）---
  static Future<List<LatLng>> _tryOSRM(
      LatLng origin, LatLng destination) async {
    final url =
        '$_osrmDemo/'
        '${origin.longitude},${origin.latitude};'
        '${destination.longitude},${destination.latitude}'
        '?overview=full&geometries=polyline';
    final r = await http.get(Uri.parse(url));
    if (r.statusCode != 200) return const <LatLng>[];
    final data = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    final routes = (data['routes'] as List?) ?? [];
    if (routes.isEmpty) return const <LatLng>[];
    final encoded = routes.first['geometry'] as String;
    return _decodePolyline(encoded);
  }

  // polyline decoder (precision 5)
  static List<LatLng> _decodePolyline(String encoded) {
    final pts = <LatLng>[];
    int index = 0, lat = 0, lng = 0;
    while (index < encoded.length) {
      int b, shift = 0, result = 0;
      do { b = encoded.codeUnitAt(index++) - 63; result |= (b & 0x1F) << shift; shift += 5; }
      while (b >= 0x20);
      final dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dlat;
      shift = 0; result = 0;
      do { b = encoded.codeUnitAt(index++) - 63; result |= (b & 0x1F) << shift; shift += 5; }
      while (b >= 0x20);
      final dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dlng;
      pts.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return pts;
  }
}




