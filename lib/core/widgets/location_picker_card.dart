import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../location/location_service.dart';

class LocationPickerCard extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;
  final bool autoDetect;
  final ValueChanged<DetectedLocation> onLocationChanged;

  const LocationPickerCard({
    super.key,
    required this.onLocationChanged,
    this.initialLatitude,
    this.initialLongitude,
    this.autoDetect = false,
  });

  @override
  State<LocationPickerCard> createState() => _LocationPickerCardState();
}

class _LocationPickerCardState extends State<LocationPickerCard> {
  final LocationService _locationService = const LocationService();

  double? _latitude;
  double? _longitude;
  double? _accuracy;
  bool _isDetecting = false;
  String? _errorMessage;
  LocationFailureType? _failureType;

  bool get _hasCoordinates => _latitude != null && _longitude != null;

  @override
  void initState() {
    super.initState();
    _latitude = widget.initialLatitude;
    _longitude = widget.initialLongitude;

    if (widget.autoDetect && !_hasCoordinates) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 450));

        if (mounted) {
          await _detectLocation();
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant LocationPickerCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.initialLatitude != widget.initialLatitude ||
        oldWidget.initialLongitude != widget.initialLongitude) {
      _latitude = widget.initialLatitude;
      _longitude = widget.initialLongitude;
      _accuracy = null;
    }
  }

  Future<void> _detectLocation() async {
    if (_isDetecting) {
      return;
    }

    setState(() {
      _isDetecting = true;
      _errorMessage = null;
      _failureType = null;
    });

    try {
      final location = await _locationService.detectCurrentLocation();

      if (!mounted) {
        return;
      }

      setState(() {
        _latitude = location.latitude;
        _longitude = location.longitude;
        _accuracy = location.accuracy;
      });

      widget.onLocationChanged(location);
    } on LocationFailure catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.message;
        _failureType = error.type;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'Lokasi gagal dideteksi: $error';
        _failureType = LocationFailureType.unavailable;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isDetecting = false;
        });
      }
    }
  }

  Future<void> _openRequiredSettings() async {
    if (_failureType == LocationFailureType.serviceDisabled) {
      await LocationService.openLocationSettings();
      return;
    }

    await LocationService.openAppSettings();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D0D12) : const Color(0xFFF7F7FB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _hasCoordinates
              ? const Color(0xFF9B5EFF)
              : isDark
                  ? const Color(0xFF1E1E35)
                  : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFF9B5EFF).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.my_location_rounded,
                  color: Color(0xFF9B5EFF),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lokasi otomatis',
                      style: GoogleFonts.poppins(
                        color: theme.textTheme.titleLarge?.color,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'GPS akan mengisi alamat dan koordinat.',
                      style: GoogleFonts.inter(
                        color: theme.textTheme.bodySmall?.color,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isDetecting ? null : _detectLocation,
              icon: _isDetecting
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.gps_fixed_rounded),
              label: Text(
                _isDetecting
                    ? 'Mendeteksi lokasi...'
                    : _hasCoordinates
                        ? 'Perbarui Lokasi Saat Ini'
                        : 'Gunakan Lokasi Saat Ini',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9B5EFF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.10),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.orange.shade600,
                        size: 19,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: GoogleFonts.inter(
                            color: Colors.orange.shade700,
                            fontSize: 10,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_failureType == LocationFailureType.serviceDisabled ||
                      _failureType ==
                          LocationFailureType.permissionDeniedForever) ...[
                    const SizedBox(height: 7),
                    TextButton.icon(
                      onPressed: _openRequiredSettings,
                      icon: const Icon(Icons.settings_outlined, size: 17),
                      label: Text(
                        _failureType == LocationFailureType.serviceDisabled
                            ? 'Buka Pengaturan GPS'
                            : 'Buka Pengaturan Aplikasi',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          if (_hasCoordinates) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 175,
                child: FlutterMap(
                  key: ValueKey<String>('$_latitude,$_longitude'),
                  options: MapOptions(
                    initialCenter: LatLng(_latitude!, _longitude!),
                    initialZoom: 16,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.kanzza.sales',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(_latitude!, _longitude!),
                          width: 48,
                          height: 48,
                          child: const Icon(
                            Icons.location_pin,
                            color: Color(0xFF7C3AED),
                            size: 46,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Koordinat: ${_latitude!.toStringAsFixed(6)}, '
              '${_longitude!.toStringAsFixed(6)}'
              '${_accuracy == null ? '' : ' • Akurasi ±${_accuracy!.round()} m'}',
              style: GoogleFonts.inter(
                color: theme.textTheme.bodySmall?.color,
                fontSize: 9,
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
          const SizedBox(height: 8),
          Text(
            'Alamat hasil GPS tetap dapat Anda perbaiki sebelum disimpan.',
            style: GoogleFonts.inter(
              color: theme.textTheme.bodySmall?.color,
              fontSize: 9,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
