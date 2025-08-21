import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// 交通模式
enum TransportMode {
  driving,       // ORS: driving-car
  walking,       // ORS: foot-walking
  cycling,       // ORS: cycling-regular
}

class DistanceService {
  // Matrix & Directions 的 base URLs
  static const _matrixBase    = 'https://api.openrouteservice.org/v2/matrix';
  static const _directionsBase= 'https://api.openrouteservice.org/v2/directions';

  // 你的 ORS Basic Key
  static const String _apiKey = 'eyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6IjkxMzljMjI5NmY0ZDQzMTg5NTg5MTAyYmE2OTZjOGQ4IiwiaCI6Im11cm11cjY0In0=';

  // 快取避免重複查詢
  static final Map<String, double> _cache = {};

  /// 1️⃣ 距離矩陣：origin -> 多 destinations（公里）
  ///    支援 driving/walking/cycling
  static Future<Map<LatLng, double>> getDistances({
    required LatLng origin,
    required List<LatLng> destinations,
    TransportMode mode = TransportMode.driving,
  }) async {
    final result = <LatLng, double>{};

    // A. 快取過濾
    final toQuery = <LatLng>[];
    for (var dest in destinations) {
      final key = _buildCacheKey(origin, dest, mode);
      if (_cache.containsKey(key)) {
        result[dest] = _cache[key]!;
      } else {
        toQuery.add(dest);
      }
    }
    if (toQuery.isEmpty) return result;
    if (toQuery.length > 10) toQuery.removeRange(10, toQuery.length);

    // B. 準備 locations
    final locations = [
      [origin.longitude, origin.latitude],
      for (var d in toQuery) [d.longitude, d.latitude],
    ];

    // C. 挑 profile 名稱
    final profile = {
      TransportMode.driving: 'driving-car',
      TransportMode.walking: 'foot-walking',
      TransportMode.cycling: 'cycling-regular',
    }[mode]!;

    // D. 呼叫 ORS Matrix
    final uri = Uri.parse('$_matrixBase/$profile');
    final response = await http.post(
      uri,
      headers: {
        'Authorization': _apiKey,
        'Content-Type': 'application/json; charset=utf-8',
      },
      body: jsonEncode({
        'locations': locations,
        'metrics': ['distance'], // 只要距離，若要時間加 'duration'
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('ORS Matrix Error ${response.statusCode}: ${response.body}');
    }

    // E. 解析矩陣
    final data   = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final matrix = (data['distances'] as List).cast<List<dynamic>>();
    final row0   = matrix[0];
    for (var i = 0; i < toQuery.length; i++) {
      final meter = (row0[i + 1] as num).toDouble(); // [0][0] 跳過自己
      final km    = meter / 1000.0;
      final dest  = toQuery[i];
      final key   = _buildCacheKey(origin, dest, mode);
      _cache[key] = km;
      result[dest] = km;
    }

    return result;
  }

  /// 2️⃣ 多路線備選：origin -> single destination
  ///    回傳每條候選路線的 distance(km) + duration(min) + polyline
  static Future<List<RouteOption>> getRouteOptions({
    required LatLng origin,
    required LatLng destination,
    TransportMode mode = TransportMode.driving,
    bool alternatives = true,
  }) async {
    final profile = {
      TransportMode.driving: 'driving-car',
      TransportMode.walking: 'foot-walking',
      TransportMode.cycling: 'cycling-regular',
    }[mode]!;

    // 組 URL
    final coords = '${origin.longitude},${origin.latitude};'
                   '${destination.longitude},${destination.latitude}';
    final uri = Uri.parse(
      '$_directionsBase/$profile/$coords'
      '?alternatives=$alternatives'
      '&overview=full'
      '&geometries=polyline'
    );

    final resp = await http.get(uri, headers: {
      'Authorization': _apiKey
    });
    if (resp.statusCode != 200) {
      throw Exception('ORS Directions Error ${resp.statusCode}');
    }

    final data   = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    final routes = data['routes'] as List<dynamic>;

    return routes.map((r) {
      final dist = (r['distance'] as num).toDouble() / 1000.0;
      final dur  = (r['duration'] as num).toDouble() / 60.0;
      final poly = r['geometry'] as String;
      return RouteOption(
        distanceKm: dist,
        durationMin: dur,
        polyline: _decodePolyline(poly),
      );
    }).toList();
  }

  static String _buildCacheKey(
    LatLng o, LatLng d, TransportMode m
  ) => '${m.name}|${o.latitude},${o.longitude}-${d.latitude},${d.longitude}';

  // polyline 解碼（同你原本函式）
  static List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> coords = [];
    int idx = 0, lat = 0, lng = 0;
    while (idx < encoded.length) {
      int shift = 0, result = 0, b;
      do {
        b = encoded.codeUnitAt(idx++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      lat += ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
      shift = 0; result = 0;
      do {
        b = encoded.codeUnitAt(idx++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      lng += ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
      coords.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return coords;
  }
}

/// 多路線顯示用 DTO
class RouteOption {
  final double distanceKm;
  final double durationMin;
  final List<LatLng> polyline;
  RouteOption({
    required this.distanceKm,
    required this.durationMin,
    required this.polyline,
  });
}




