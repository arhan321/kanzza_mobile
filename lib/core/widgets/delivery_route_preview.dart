import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../location/location_service.dart';
import '../location/store_location.dart';

class DeliveryRoutePreview extends StatefulWidget {
  final double customerLatitude;
  final double customerLongitude;
  final ValueChanged<double>? onDistanceChanged;

  const DeliveryRoutePreview({
    super.key,
    required this.customerLatitude,
    required this.customerLongitude,
    this.onDistanceChanged,
  });

  @override
  State<DeliveryRoutePreview> createState() => _DeliveryRoutePreviewState();
}

class _DeliveryRoutePreviewState extends State<DeliveryRoutePreview> {
  bool _isLoading = true;
  bool _usesRoadRoute = false;
  double? _distanceKm;
  List<LatLng> _routePoints = const [];

  LatLng get _storePoint =>
      const LatLng(StoreLocation.latitude, StoreLocation.longitude);

  LatLng get _customerPoint =>
      LatLng(widget.customerLatitude, widget.customerLongitude);

  @override
  void initState() {
    super.initState();
    _loadRoute();
  }

  @override
  void didUpdateWidget(covariant DeliveryRoutePreview oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.customerLatitude != widget.customerLatitude ||
        oldWidget.customerLongitude != widget.customerLongitude) {
      _loadRoute();
    }
  }

  Future<void> _loadRoute() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final uri = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${StoreLocation.longitude},${StoreLocation.latitude};'
        '${widget.customerLongitude},${widget.customerLatitude}'
        '?overview=full&geometries=geojson&steps=false&alternatives=false',
      );

      final response = await http
          .get(
            uri,
            headers: const {
              'Accept': 'application/json',
              'User-Agent': 'KanzzaSalesApp/1.0',
            },
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final decoded = jsonDecode(response.body);
      final routes = decoded is Map<String, dynamic> ? decoded['routes'] : null;

      if (routes is! List || routes.isEmpty) {
        throw Exception('Rute tidak tersedia');
      }

      final route = routes.first;
      final geometry = route is Map<String, dynamic> ? route['geometry'] : null;
      final coordinates = geometry is Map<String, dynamic>
          ? geometry['coordinates']
          : null;

      if (coordinates is! List || coordinates.length < 2) {
        throw Exception('Koordinat rute tidak tersedia');
      }

      final points = coordinates
          .whereType<List>()
          .where((item) => item.length >= 2)
          .map(
            (item) => LatLng(
              (item[1] as num).toDouble(),
              (item[0] as num).toDouble(),
            ),
          )
          .toList();

      final distanceMeters = route['distance'];

      if (!mounted) {
        return;
      }

      final distanceKm = distanceMeters is num
          ? distanceMeters.toDouble() / 1000
          : _straightDistance();

      setState(() {
        _routePoints = points;
        _distanceKm = distanceKm;
        _usesRoadRoute = true;
        _isLoading = false;
      });

      widget.onDistanceChanged?.call(distanceKm);
    } catch (_) {
      if (!mounted) {
        return;
      }

      final distanceKm = _straightDistance();

      setState(() {
        _routePoints = [_storePoint, _customerPoint];
        _distanceKm = distanceKm;
        _usesRoadRoute = false;
        _isLoading = false;
      });

      widget.onDistanceChanged?.call(distanceKm);
    }
  }

  double _straightDistance() {
    return LocationService.distanceInKilometers(
      startLatitude: StoreLocation.latitude,
      startLongitude: StoreLocation.longitude,
      endLatitude: widget.customerLatitude,
      endLongitude: widget.customerLongitude,
    );
  }

  double _initialZoom() {
    final distance = _distanceKm ?? _straightDistance();

    if (distance > 80) return 8;
    if (distance > 40) return 9;
    if (distance > 20) return 10;
    if (distance > 10) return 11;
    if (distance > 5) return 12;
    return 13;
  }

  Future<void> _openGoogleMaps() async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&origin=${StoreLocation.latitude},${StoreLocation.longitude}'
      '&destination=${widget.customerLatitude},${widget.customerLongitude}'
      '&travelmode=driving',
    );

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final midpoint = LatLng(
      (StoreLocation.latitude + widget.customerLatitude) / 2,
      (StoreLocation.longitude + widget.customerLongitude) / 2,
    );

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D0D12) : const Color(0xFFF7F7FB),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: isDark ? const Color(0xFF1E1E35) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.route_outlined,
                color: Color(0xFF9B5EFF),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Rute Pengiriman',
                  style: GoogleFonts.poppins(
                    color: theme.textTheme.titleLarge?.color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (_isLoading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF9B5EFF),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: SizedBox(
              height: 190,
              child: FlutterMap(
                key: ValueKey<String>(
                  '${widget.customerLatitude},${widget.customerLongitude},'
                  '${_routePoints.length}',
                ),
                options: MapOptions(
                  initialCenter: midpoint,
                  initialZoom: _initialZoom(),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.kanzza.sales',
                  ),
                  if (_routePoints.length >= 2)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: _routePoints,
                          strokeWidth: 4,
                          color: const Color(0xFF9B5EFF),
                        ),
                      ],
                    ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _storePoint,
                        width: 46,
                        height: 46,
                        child: const Icon(
                          Icons.storefront_rounded,
                          color: Color(0xFF5B21B6),
                          size: 35,
                        ),
                      ),
                      Marker(
                        point: _customerPoint,
                        width: 48,
                        height: 48,
                        child: const Icon(
                          Icons.location_pin,
                          color: Color(0xFFEF4444),
                          size: 45,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 9),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  _isLoading
                      ? 'Sedang mencari rute dari toko...'
                      : '${_usesRoadRoute ? 'Jarak rute' : 'Estimasi garis lurus'}: '
                            '${(_distanceKm ?? 0).toStringAsFixed(2)} km',
                  style: GoogleFonts.inter(
                    color: theme.textTheme.titleLarge?.color,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _openGoogleMaps,
                icon: const Icon(Icons.map_outlined, size: 16),
                label: const Text('Google Maps'),
              ),
            ],
          ),
          Text(
            'Ongkos kirim dihitung Rp5.000 per kilometer dari toko Kanzza.',
            style: GoogleFonts.inter(
              color: theme.textTheme.bodySmall?.color,
              fontSize: 9,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '© OpenStreetMap contributors',
            style: GoogleFonts.inter(
              color: theme.textTheme.bodySmall?.color,
              fontSize: 8,
            ),
          ),
        ],
      ),
    );
  }
}
