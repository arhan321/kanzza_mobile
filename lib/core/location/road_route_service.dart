import 'dart:convert';

import 'package:http/http.dart' as http;

class RoadRoutePoint {
  final double latitude;
  final double longitude;

  const RoadRoutePoint({required this.latitude, required this.longitude});
}

class RoadRouteResult {
  final double distanceKm;
  final List<RoadRoutePoint> points;

  const RoadRouteResult({required this.distanceKm, required this.points});
}

class RoadRouteException implements Exception {
  final String message;

  const RoadRouteException(this.message);

  @override
  String toString() => message;
}

class RoadRouteService {
  RoadRouteService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<RoadRouteResult> getDrivingRoute({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
  }) async {
    final uri = Uri.https(
      'router.project-osrm.org',
      '/route/v1/driving/'
          '$startLongitude,$startLatitude;$endLongitude,$endLatitude',
      const {
        'overview': 'full',
        'geometries': 'geojson',
        'steps': 'false',
        'alternatives': 'false',
      },
    );

    try {
      final response = await _client
          .get(
            uri,
            headers: const {
              'Accept': 'application/json',
              'User-Agent': 'KanzzaSalesApp/1.0',
            },
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw RoadRouteException(
          'Server rute merespons HTTP ${response.statusCode}.',
        );
      }

      final decoded = jsonDecode(response.body);
      final routes = decoded is Map<String, dynamic> ? decoded['routes'] : null;

      if (routes is! List || routes.isEmpty || routes.first is! Map) {
        throw const RoadRouteException('Rute jalan tidak ditemukan.');
      }

      final route = Map<String, dynamic>.from(routes.first as Map);
      final distanceMeters = route['distance'];
      final geometry = route['geometry'];
      final coordinates = geometry is Map ? geometry['coordinates'] : null;

      if (distanceMeters is! num || distanceMeters <= 0) {
        throw const RoadRouteException('Jarak rute dari server tidak valid.');
      }

      if (coordinates is! List || coordinates.length < 2) {
        throw const RoadRouteException('Titik rute dari server tidak lengkap.');
      }

      final points = coordinates
          .whereType<List>()
          .where((coordinate) => coordinate.length >= 2)
          .map(
            (coordinate) => RoadRoutePoint(
              latitude: (coordinate[1] as num).toDouble(),
              longitude: (coordinate[0] as num).toDouble(),
            ),
          )
          .toList(growable: false);

      if (points.length < 2) {
        throw const RoadRouteException('Titik rute dari server tidak valid.');
      }

      return RoadRouteResult(
        distanceKm: distanceMeters.toDouble() / 1000,
        points: points,
      );
    } on RoadRouteException {
      rethrow;
    } catch (_) {
      throw const RoadRouteException(
        'Rute jalan belum dapat dihitung. Periksa koneksi lalu coba lagi.',
      );
    }
  }

  void close() => _client.close();
}
