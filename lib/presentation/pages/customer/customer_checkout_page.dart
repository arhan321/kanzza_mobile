// lib/presentation/pages/customer/customer_checkout_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'package:location/location.dart';
import 'package:permission_handler/permission_handler.dart' as permission;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:kanzza_sales_app_fe/core/theme/theme_provider.dart';

import '../../../data/models/cart_item.dart';
import '../../../data/models/location_model.dart';

class CustomerCheckoutPage extends StatefulWidget {
  final int totalPrice;
  final List<CartItem> cartItems;

  const CustomerCheckoutPage({
    super.key,
    this.totalPrice = 0,
    this.cartItems = const [],
  });

  @override
  State<CustomerCheckoutPage> createState() => _CustomerCheckoutPageState();
}

class _CustomerCheckoutPageState extends State<CustomerCheckoutPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _detailAddressController = TextEditingController();
  
  late final LatLng _storeLocation;
  
  LatLng? _userLocation;
  List<LatLng> _routePoints = [];
  
  double _distance = 0;
  int _shippingCost = 0;
  bool _isCalculating = false;
  bool _isGettingLocation = false;
  String _statusMessage = "";
  String _errorMessage = "";
  String _currentAddress = "";
  
  String _deliveryMethod = "delivery";
  String _paymentMethod = "cod";
  
  final MapController _mapController = MapController();
  bool _isMapReady = false;
  bool _isFirstLoad = true;
  bool _isLocationRetrying = false;

  final Location _location = Location();

  @override
  void initState() {
    super.initState();
    _storeLocation = LatLng(StoreLocation.latitude, StoreLocation.longitude);
    print("📍 Store Location: ${_storeLocation.latitude}, ${_storeLocation.longitude}");
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkGPSAndLocation();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _detailAddressController.dispose();
    super.dispose();
  }

  // ============ FUNGSI BUKA WHATSAPP ============
  void _openWhatsApp() {
    final String phoneNumber = "6289652731947"; // 089653731947
    final String message = "Min, saya mau order tapi ada masalah nih...";
    
    String encodedMessage = Uri.encodeComponent(message);
    final String whatsappUrl = "https://wa.me/$phoneNumber?text=$encodedMessage";
    
    try {
      launchUrl(Uri.parse(whatsappUrl), mode: LaunchMode.externalApplication);
    } catch (e) {
      _showSnackBar("Tidak dapat membuka WhatsApp", Colors.orange);
    }
  }

  // ============ CEK GPS DAN LOKASI ============
  Future<void> _checkGPSAndLocation() async {
    if (_isLocationRetrying) return;
    _isLocationRetrying = true;
    
    try {
      bool serviceEnabled = await _location.serviceEnabled();
      
      if (!serviceEnabled) {
        _showGPSDialog();
        _isLocationRetrying = false;
        return;
      }
      
      permission.PermissionStatus status = await permission.Permission.location.status;
      
      if (status.isDenied) {
        permission.PermissionStatus result = await permission.Permission.location.request();
        if (result.isGranted) {
          await _getCurrentLocation();
        } else {
          setState(() {
            _errorMessage = "Izin lokasi diperlukan untuk menampilkan rute pengiriman.";
          });
          _showPermissionDialog();
        }
      } else if (status.isGranted) {
        await _getCurrentLocation();
      } else if (status.isPermanentlyDenied) {
        setState(() {
          _errorMessage = "Izin lokasi ditolak permanen. Silakan aktifkan di pengaturan.";
        });
        _showPermissionDialog();
      }
    } catch (e) {
      print("❌ Error checking location: $e");
      setState(() {
        _errorMessage = "Terjadi kesalahan. Silakan coba lagi.";
      });
    }
    
    _isLocationRetrying = false;
  }

  // ============ DIALOG GPS ============
  void _showGPSDialog() {
    final isDark = Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
    final theme = Theme.of(context);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: theme.cardTheme.color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isDark ? const Color(0xFF1E1E35) : const Color(0xFFE8E8F0),
          ),
        ),
        title: Row(
          children: [
            Icon(Icons.gps_not_fixed, color: Colors.orange.shade400, size: 28),
            const SizedBox(width: 12),
            Text(
              "Aktifkan GPS",
              style: GoogleFonts.poppins(
                color: isDark ? const Color(0xFFF0EAFF) : const Color(0xFF1F2937),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Untuk menggunakan fitur pengiriman, kami perlu mengetahui lokasi Anda.",
              style: GoogleFonts.inter(
                color: isDark ? const Color(0xFF9B97B8) : const Color(0xFF6B7280),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E35) : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStepItem("1", "Aktifkan GPS di pengaturan HP Anda", isDark),
                  const SizedBox(height: 8),
                  _buildStepItem("2", "Kembali ke aplikasi", isDark),
                  const SizedBox(height: 8),
                  _buildStepItem("3", "Lokasi akan otomatis terdeteksi", isDark),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showManualAddressDialog();
            },
            child: Text(
              "Masukkan Manual",
              style: GoogleFonts.inter(
                color: isDark ? const Color(0xFF9B97B8) : const Color(0xFF6B7280),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _location.requestService();
              Future.delayed(const Duration(seconds: 2), () {
                _checkGPSAndLocation();
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9B5EFF),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              "Buka Pengaturan GPS",
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepItem(String number, String text, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: const Color(0xFF9B5EFF).withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: GoogleFonts.inter(
                color: const Color(0xFF9B5EFF),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              color: isDark ? const Color(0xFFF0EAFF) : const Color(0xFF1F2937),
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  // ============ DIALOG IZIN ============
  void _showPermissionDialog() {
    final isDark = Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
    final theme = Theme.of(context);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: theme.cardTheme.color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isDark ? const Color(0xFF1E1E35) : const Color(0xFFE8E8F0),
          ),
        ),
        title: Row(
          children: [
            Icon(Icons.location_off, color: Colors.red.shade400, size: 28),
            const SizedBox(width: 12),
            Text(
              "Izin Lokasi Diperlukan",
              style: GoogleFonts.poppins(
                color: isDark ? const Color(0xFFF0EAFF) : const Color(0xFF1F2937),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Aplikasi memerlukan izin lokasi untuk menghitung jarak dan ongkos kirim.",
              style: GoogleFonts.inter(
                color: isDark ? const Color(0xFF9B97B8) : const Color(0xFF6B7280),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E35) : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStepItem("1", "Klik 'Buka Pengaturan'", isDark),
                  const SizedBox(height: 8),
                  _buildStepItem("2", "Aktifkan izin lokasi untuk aplikasi ini", isDark),
                  const SizedBox(height: 8),
                  _buildStepItem("3", "Kembali ke aplikasi", isDark),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showManualAddressDialog();
            },
            child: Text(
              "Masukkan Manual",
              style: GoogleFonts.inter(
                color: isDark ? const Color(0xFF9B97B8) : const Color(0xFF6B7280),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await permission.openAppSettings();
              Future.delayed(const Duration(seconds: 2), () {
                _checkGPSAndLocation();
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9B5EFF),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              "Buka Pengaturan",
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============ MANUAL ADDRESS DIALOG ============
  void _showManualAddressDialog() {
    final isDark = Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
    final theme = Theme.of(context);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: theme.cardTheme.color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isDark ? const Color(0xFF1E1E35) : const Color(0xFFE8E8F0),
          ),
        ),
        title: Text(
          "Masukkan Alamat Manual",
          style: GoogleFonts.poppins(
            color: isDark ? const Color(0xFFF0EAFF) : const Color(0xFF1F2937),
            fontWeight: FontWeight.w600,
          ),
        ),
        content: TextField(
          controller: _addressController,
          style: GoogleFonts.inter(
            color: isDark ? const Color(0xFFF0EAFF) : const Color(0xFF1F2937),
            fontSize: 14,
          ),
          maxLines: 3,
          decoration: InputDecoration(
            hintText: "Masukkan alamat lengkap Anda",
            hintStyle: GoogleFonts.inter(
              color: isDark ? const Color(0xFF5C5878) : const Color(0xFF9CA3AF),
              fontSize: 14,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? const Color(0xFF1E1E35) : const Color(0xFFE5E7EB),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF9B5EFF), width: 1.5),
            ),
            filled: true,
            fillColor: isDark ? const Color(0xFF1E1E35) : const Color(0xFFF3F4F6),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "Batal",
              style: GoogleFonts.inter(
                color: isDark ? const Color(0xFF9B97B8) : const Color(0xFF6B7280),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (_addressController.text.isNotEmpty) {
                _showSnackBar("✅ Alamat manual telah disimpan", Colors.green);
                setState(() {
                  _distance = 5.0 + Random().nextDouble() * 10;
                  _shippingCost = (_distance * 5000).round();
                  _statusMessage = "✅ Alamat manual diterima";
                });
              } else {
                _showSnackBar("Silakan masukkan alamat", Colors.orange);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9B5EFF),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              "Simpan",
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============ FUNGSI BUKA GOOGLE MAPS ============
  Future<void> _openGoogleMaps(String address) async {
    String encodedAddress = Uri.encodeComponent(address);
    
    final String googleMapsUrl = "https://www.google.com/maps/search/?api=1&query=$encodedAddress";
    final String googleMapsIntent = "geo:0,0?q=$encodedAddress";
    
    try {
      final Uri intentUri = Uri.parse(googleMapsIntent);
      if (await canLaunchUrl(intentUri)) {
        await launchUrl(intentUri, mode: LaunchMode.externalApplication);
        return;
      }
      
      final Uri webUri = Uri.parse(googleMapsUrl);
      if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      } else {
        _showSnackBar("Tidak dapat membuka Google Maps", Colors.red);
      }
    } catch (e) {
      print("❌ Error opening Google Maps: $e");
      final Uri webUri = Uri.parse(googleMapsUrl);
      if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      } else {
        _showSnackBar("Tidak dapat membuka Google Maps. Silakan buka manual.", Colors.orange);
      }
    }
  }

  // ============ GET CURRENT LOCATION ============
  Future<void> _getCurrentLocation() async {
    setState(() {
      _isGettingLocation = true;
      _statusMessage = "📍 Mendapatkan lokasi Anda...";
      _errorMessage = "";
    });

    try {
      bool serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _isGettingLocation = false;
          _statusMessage = "";
          _errorMessage = "GPS tidak aktif. Silakan aktifkan GPS.";
        });
        _showGPSDialog();
        return;
      }

      permission.PermissionStatus status = await permission.Permission.location.status;
      if (!status.isGranted) {
        setState(() {
          _isGettingLocation = false;
          _errorMessage = "Izin lokasi belum diberikan.";
        });
        _showPermissionDialog();
        return;
      }

      LocationData? locationData = await _getLocationWithRetry();
      
      if (locationData == null) {
        setState(() {
          _isGettingLocation = false;
          _statusMessage = "";
          _errorMessage = "Tidak dapat mendapatkan lokasi. Pastikan GPS aktif dan Anda di luar ruangan.";
        });
        _showRetryLocationDialog();
        return;
      }

      print("📍 Lokasi GPS didapatkan:");
      print("   Latitude: ${locationData.latitude}");
      print("   Longitude: ${locationData.longitude}");

      LatLng userLocation = LatLng(locationData.latitude!, locationData.longitude!);
      
      String address = await _getAddressFromCoordinates(userLocation);
      
      setState(() {
        _userLocation = userLocation;
        _currentAddress = address;
        _addressController.text = address;
        _isGettingLocation = false;
        _statusMessage = "✅ Lokasi ditemukan!";
        _errorMessage = "";
      });

      _showSnackBar("✅ Lokasi berhasil didapatkan!", Colors.green);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_isMapReady && mounted) {
          _mapController.move(userLocation, 16.0);
        }
      });

      await _checkRoute();

    } catch (e) {
      print("❌ Error getting location: $e");
      setState(() {
        _isGettingLocation = false;
        _statusMessage = "";
        _errorMessage = "Gagal mendapatkan lokasi. Silakan coba lagi.\n\nPastikan GPS aktif dan Anda berada di luar ruangan.";
      });
      _showSnackBar("❌ Gagal mendapatkan lokasi", Colors.red);
      _showRetryLocationDialog();
    }
  }

  // ============ GET LOCATION WITH RETRY ============
  Future<LocationData?> _getLocationWithRetry() async {
    int maxAttempts = 5;
    int attempt = 0;
    
    while (attempt < maxAttempts) {
      try {
        print("📍 Mencoba mendapatkan lokasi (attempt ${attempt + 1}/$maxAttempts)...");
        
        LocationData locationData = await _location.getLocation();
        
        if (locationData.latitude != null && 
            locationData.longitude != null &&
            locationData.latitude != 0 && 
            locationData.longitude != 0) {
          return locationData;
        }
        
        attempt++;
        if (attempt < maxAttempts) {
          await Future.delayed(const Duration(seconds: 2));
        }
        
      } catch (e) {
        print("❌ Attempt ${attempt + 1} failed: $e");
        attempt++;
        if (attempt < maxAttempts) {
          await Future.delayed(const Duration(seconds: 2));
        }
      }
    }
    
    return null;
  }

  // ============ RETRY LOCATION DIALOG ============
  void _showRetryLocationDialog() {
    final isDark = Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
    final theme = Theme.of(context);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: theme.cardTheme.color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isDark ? const Color(0xFF1E1E35) : const Color(0xFFE8E8F0),
          ),
        ),
        title: Text(
          "Gagal Mendapatkan Lokasi",
          style: GoogleFonts.poppins(
            color: isDark ? const Color(0xFFF0EAFF) : const Color(0xFF1F2937),
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Tidak dapat mendapatkan lokasi Anda. Pastikan:",
              style: GoogleFonts.inter(
                color: isDark ? const Color(0xFF9B97B8) : const Color(0xFF6B7280),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            _buildStepItem("✓", "GPS aktif", isDark),
            _buildStepItem("✓", "Izin lokasi diberikan", isDark),
            _buildStepItem("✓", "Berada di luar ruangan", isDark),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showManualAddressDialog();
            },
            child: Text(
              "Masukkan Manual",
              style: GoogleFonts.inter(
                color: isDark ? const Color(0xFF9B97B8) : const Color(0xFF6B7280),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _getCurrentLocation();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9B5EFF),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              "Coba Lagi",
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============ REVERSE GEOCODING ============
  Future<String> _getAddressFromCoordinates(LatLng coordinates) async {
    try {
      final url = "https://nominatim.openstreetmap.org/reverse?"
          "lat=${coordinates.latitude}"
          "&lon=${coordinates.longitude}"
          "&format=json"
          "&addressdetails=1"
          "&accept-language=id";
      
      print("🔍 Reverse Geocoding URL: $url");
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'KanzzaSalesApp/1.0',
          'Accept-Language': 'id,en',
        },
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['display_name'] != null) {
          String fullAddress = data['display_name'];
          List<String> parts = fullAddress.split(', ');
          if (parts.length > 3) {
            return parts.sublist(0, 3).join(', ');
          }
          return fullAddress;
        }
      }
      return "Lokasi saat ini (${coordinates.latitude.toStringAsFixed(6)}, ${coordinates.longitude.toStringAsFixed(6)})";
    } catch (e) {
      print("❌ Reverse geocoding error: $e");
      return "Lokasi saat ini";
    }
  }

  // ============ ROUTING ============
  Future<List<LatLng>> _getRouteFromOSRM(LatLng start, LatLng end) async {
    try {
      final url = "https://router.project-osrm.org/route/v1/driving/"
          "${start.longitude},${start.latitude};${end.longitude},${end.latitude}"
          "?overview=full&geometries=geojson&steps=false&alternatives=false";
      
      print("🗺️ OSRM URL: $url");
      
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 20),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final geometry = route['geometry'];
          final coordinates = geometry['coordinates'] as List;
          
          List<LatLng> routePoints = [];
          for (var coord in coordinates) {
            routePoints.add(LatLng(coord[1], coord[0]));
          }
          
          final distanceInKm = (route['distance'] as num).toDouble() / 1000;
          
          setState(() {
            _distance = double.parse(distanceInKm.toStringAsFixed(2));
            _shippingCost = (_distance * 5000).round();
          });
          
          return routePoints;
        }
      }
    } catch (e) {
      print("❌ OSRM error: $e");
    }
    return [];
  }

  // ============ CHECK ROUTE ============
  Future<void> _checkRoute() async {
    if (_userLocation == null) return;
    
    setState(() {
      _isCalculating = true;
      _statusMessage = "🗺️ Mendapatkan rute perjalanan...";
      _errorMessage = "";
      _routePoints = [];
    });
    
    try {
      List<LatLng> routePoints = await _getRouteFromOSRM(_storeLocation, _userLocation!);
      
      if (routePoints.isNotEmpty && routePoints.length > 1) {
        setState(() {
          _routePoints = routePoints;
          _statusMessage = "✅ Rute ditemukan! Jarak: ${_distance.toStringAsFixed(2)} km";
          _isCalculating = false;
        });
        _zoomToRoute();
        _showSnackBar(
          "✅ Rute ditemukan!\nJarak: ${_distance.toStringAsFixed(2)} km | Ongkir: Rp ${_formatPrice(_shippingCost)}",
          Colors.green,
        );
      } else {
        double distance = _calculateStraightDistance(_storeLocation, _userLocation!);
        setState(() {
          _distance = distance;
          _shippingCost = (distance * 5000).round();
          _routePoints = [_storeLocation, _userLocation!];
          _statusMessage = "⚠️ Menggunakan estimasi garis lurus";
          _isCalculating = false;
        });
        _zoomToRoute();
        _showSnackBar(
          "⚠️ Estimasi garis lurus\nJarak: ${distance.toStringAsFixed(2)} km | Ongkir: Rp ${_formatPrice(_shippingCost)}",
          Colors.orange,
        );
      }
    } catch (e) {
      setState(() {
        _isCalculating = false;
        _statusMessage = "";
        _errorMessage = "Gagal mendapatkan rute. Periksa koneksi internet.";
      });
      _showSnackBar("❌ Gagal mendapatkan rute", Colors.red);
      
      if (_userLocation != null) {
        double distance = _calculateStraightDistance(_storeLocation, _userLocation!);
        setState(() {
          _distance = distance;
          _shippingCost = (distance * 5000).round();
          _routePoints = [_storeLocation, _userLocation!];
        });
        _zoomToRoute();
      }
    }
  }

  double _calculateStraightDistance(LatLng start, LatLng end) {
    const double R = 6371;
    double dLat = _toRadians(end.latitude - start.latitude);
    double dLon = _toRadians(end.longitude - start.longitude);
    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(start.latitude)) * cos(_toRadians(end.latitude)) *
        sin(dLon / 2) * sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _toRadians(double degree) {
    return degree * pi / 180;
  }

  void _zoomToRoute() {
    if (_routePoints.isEmpty || _userLocation == null) return;
    
    try {
      double minLat = _storeLocation.latitude, maxLat = _storeLocation.latitude;
      double minLng = _storeLocation.longitude, maxLng = _storeLocation.longitude;
      
      for (var point in _routePoints) {
        if (point.latitude < minLat) minLat = point.latitude;
        if (point.latitude > maxLat) maxLat = point.latitude;
        if (point.longitude < minLng) minLng = point.longitude;
        if (point.longitude > maxLng) maxLng = point.longitude;
      }
      
      final centerLat = (minLat + maxLat) / 2;
      final centerLng = (minLng + maxLng) / 2;
      final maxDiff = max(maxLat - minLat, maxLng - minLng);
      
      double zoom = 12.0;
      if (maxDiff > 0.5) zoom = 10.0;
      else if (maxDiff > 0.2) zoom = 12.0;
      else if (maxDiff > 0.05) zoom = 14.0;
      else zoom = 15.0;
      
      if (_isMapReady && mounted) {
        _mapController.move(LatLng(centerLat, centerLng), zoom);
      }
    } catch (e) {
      if (_isMapReady && mounted) {
        _mapController.move(_userLocation!, 14.0);
      }
    }
  }

  // ============ HANDLER ============
  Future<void> _handleGetLocation() async {
    await _getCurrentLocation();
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter(color: Colors.white)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  int get _totalWithShipping {
    if (_deliveryMethod == "pickup") return widget.totalPrice;
    return widget.totalPrice + _shippingCost;
  }

  void _proceedToPayment() {
    if (_nameController.text.isEmpty) {
      _showSnackBar("Nama lengkap harus diisi", Colors.orange);
      return;
    }
    if (_phoneController.text.isEmpty) {
      _showSnackBar("Nomor telepon harus diisi", Colors.orange);
      return;
    }
    if (_deliveryMethod == "delivery" && _addressController.text.isEmpty) {
      _showSnackBar("Alamat harus diisi", Colors.orange);
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) {
        final isDark = Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
        final theme = Theme.of(context);
        
        return AlertDialog(
          backgroundColor: theme.cardTheme.color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: isDark ? const Color(0xFF1E1E35) : const Color(0xFFE8E8F0),
            ),
          ),
          title: Text(
            "Konfirmasi Pesanan",
            style: GoogleFonts.poppins(
              color: isDark ? const Color(0xFFF0EAFF) : const Color(0xFF1F2937),
              fontWeight: FontWeight.w600,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildConfirmItem("Nama", _nameController.text, isDark),
                _buildConfirmItem("Alamat", _addressController.text, isDark),
                if (_detailAddressController.text.isNotEmpty)
                  _buildConfirmItem("Detail", _detailAddressController.text, isDark),
                const SizedBox(height: 8),
                _buildConfirmItem("Pengiriman", 
                  _deliveryMethod == "delivery" ? "Di Antar" : "Ambil di Toko", isDark),
                _buildConfirmItem("Pembayaran",
                  _paymentMethod == "cod" ? "Bayar di Tempat" : "Transfer Bank", isDark),
                if (_deliveryMethod == "delivery") ...[
                  _buildConfirmItem("Jarak", "${_distance.toStringAsFixed(2)} km", isDark),
                  _buildConfirmItem("Ongkir", "Rp ${_formatPrice(_shippingCost)}", isDark),
                ],
                const SizedBox(height: 8),
                Divider(color: isDark ? const Color(0xFF1E1E35) : const Color(0xFFE5E7EB)),
                const SizedBox(height: 8),
                _buildConfirmItem("Total", "Rp ${_formatPrice(_totalWithShipping)}", isDark, isBold: true),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Batal", style: GoogleFonts.inter(
                color: isDark ? const Color(0xFF9B97B8) : const Color(0xFF6B7280))),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _showSnackBar("✅ Pesanan berhasil dibuat!", Colors.green);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9B5EFF),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text("Konfirmasi", style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildConfirmItem(String label, String value, bool isDark, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(
            color: isDark ? const Color(0xFF9B97B8) : const Color(0xFF6B7280), fontSize: 13)),
          Text(value, style: GoogleFonts.inter(
            color: isDark ? const Color(0xFFF0EAFF) : const Color(0xFF1F2937), fontSize: 13,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500)),
        ],
      ),
    );
  }

  String _formatPrice(int price) {
    return price.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final theme = Theme.of(context);
    final sw = MediaQuery.of(context).size.width;
    final hPad = sw * 0.04;

    SystemChrome.setSystemUIOverlayStyle(
      isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
    );

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [const Color(0xFF13102A), const Color(0xFF0D0D12)]
                : [const Color(0xFFF5F5FA), const Color(0xFFE8E8F0)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ============ HEADER ============
              Container(
                padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 16),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF16162A) : const Color(0xFFF5F5FA),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? const Color(0xFF1E1E35) : const Color(0xFFE8E8F0),
                          ),
                        ),
                        child: Icon(
                          Icons.arrow_back_rounded,
                          color: isDark ? const Color(0xFFF0EAFF) : const Color(0xFF1F2937),
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Checkout",
                        style: GoogleFonts.poppins(
                          color: isDark ? const Color(0xFFF0EAFF) : const Color(0xFF1F2937),
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    // ============ TOMBOL WHATSAPP DI HEADER ============
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "Hubungi Admin",
                            style: GoogleFonts.inter(
                              color: isDark ? const Color(0xFF9B97B8) : const Color(0xFF6B7280),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: _openWhatsApp,
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFF25D366),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF25D366).withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.chat,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ============ CONTENT ============
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.symmetric(horizontal: hPad),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDeliveryMethodCard(isDark),
                      const SizedBox(height: 24),

                      if (_deliveryMethod == "delivery") ...[
                        _buildAddressForm(isDark),
                        const SizedBox(height: 16),
                        _buildLocationButton(isDark),
                        const SizedBox(height: 16),
                        
                        if (_statusMessage.isNotEmpty)
                          _buildStatusCard(isDark),
                        
                        if (_errorMessage.isNotEmpty)
                          _buildErrorCard(isDark),
                        
                        if (_userLocation != null && _routePoints.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          _buildMapCard(isDark),
                          const SizedBox(height: 16),
                          _buildShippingInfoCard(isDark),
                          const SizedBox(height: 24),
                        ],
                      ],

                      if (_deliveryMethod == "pickup") ...[
                        _buildPickupInfoCard(isDark),
                        const SizedBox(height: 24),
                      ],

                      _buildPaymentMethodCard(isDark),
                      const SizedBox(height: 24),
                      _buildOrderSummaryCard(isDark),
                      const SizedBox(height: 30),
                      _buildCheckoutButton(isDark),
                      const SizedBox(height: 16),
                      
                      // ============ WHATSAPP HELP CARD ============
                      _buildWhatsAppHelpCard(isDark),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============ WHATSAPP HELP CARD ============
  Widget _buildWhatsAppHelpCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16162A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF25D366).withOpacity(0.3),
          width: 1,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFF25D366).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.chat,
              color: Color(0xFF25D366),
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Hubungi Admin",
                  style: GoogleFonts.poppins(
                    color: isDark ? const Color(0xFFF0EAFF) : const Color(0xFF1F2937),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Ada kendala? Klik tombol di samping untuk chat admin",
                  style: GoogleFonts.inter(
                    color: isDark ? const Color(0xFF9B97B8) : const Color(0xFF6B7280),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _openWhatsApp,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF25D366),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF25D366).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.chat,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    "Chat",
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============ BUILD WIDGETS ============
  
  Widget _buildDeliveryMethodCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16162A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isDark ? Border.all(color: const Color(0xFF1E1E35)) : Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: isDark ? null : [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          _buildRadioOption("Di Antar ke Alamat", "Pesanan akan diantar ke lokasi Anda", "delivery", _deliveryMethod, Icons.delivery_dining, isDark),
          Divider(color: isDark ? const Color(0xFF1E1E35) : const Color(0xFFE5E7EB), height: 16),
          _buildRadioOption("Ambil di Toko", "Ambil pesanan langsung di toko kami", "pickup", _deliveryMethod, Icons.storefront, isDark),
          if (_deliveryMethod == "pickup") ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF9B5EFF).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFF9B5EFF).withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: const Color(0xFF9B5EFF),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Klik alamat toko untuk membuka Google Maps",
                      style: GoogleFonts.inter(
                        color: isDark ? const Color(0xFF9B97B8) : const Color(0xFF6B7280),
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRadioOption(String title, String subtitle, String value, String groupValue, IconData icon, bool isDark) {
    return GestureDetector(
      onTap: () => setState(() => _deliveryMethod = value),
      child: Row(
        children: [
          Radio<String>(
            value: value,
            groupValue: groupValue,
            onChanged: (val) => setState(() => _deliveryMethod = val!),
            activeColor: const Color(0xFF9B5EFF),
          ),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E35) : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF9B5EFF), size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.poppins(color: isDark ? const Color(0xFFF0EAFF) : const Color(0xFF1F2937), fontSize: 14, fontWeight: FontWeight.w600)),
                Text(subtitle, style: GoogleFonts.inter(color: isDark ? const Color(0xFF9B97B8) : const Color(0xFF6B7280), fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressForm(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16162A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isDark ? Border.all(color: const Color(0xFF1E1E35)) : Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: isDark ? null : [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          _buildTextField(_nameController, "Nama Lengkap", "Masukkan nama lengkap Anda", Icons.person_outline, isDark),
          const SizedBox(height: 16),
          _buildTextField(_phoneController, "Nomor Telepon", "Contoh: 081234567890", Icons.phone_outlined, isDark, keyboardType: TextInputType.phone),
          const SizedBox(height: 16),
          _buildTextField(_addressController, "Alamat (Otomatis dari GPS)", "Klik 'Cek Lokasi' untuk mendapatkan alamat", Icons.location_on_outlined, isDark, maxLines: 2, readOnly: true),
          const SizedBox(height: 16),
          _buildTextField(_detailAddressController, "Detail Alamat (Opsional)", "Nama gedung, nomor rumah, RT/RW, dll", Icons.home_outlined, isDark),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, String hint, IconData icon, bool isDark,
      {bool readOnly = false, int maxLines = 1, TextInputType keyboardType = TextInputType.text}) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: GoogleFonts.inter(color: isDark ? const Color(0xFFF0EAFF) : const Color(0xFF1F2937), fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(color: isDark ? const Color(0xFF9B97B8) : const Color(0xFF6B7280), fontSize: 12),
        hintText: hint,
        hintStyle: GoogleFonts.inter(color: isDark ? const Color(0xFF5C5878) : const Color(0xFF9CA3AF), fontSize: 12),
        prefixIcon: Icon(icon, color: const Color(0xFF9B5EFF), size: 20),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? const Color(0xFF1E1E35) : const Color(0xFFE5E7EB), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF9B5EFF), width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? const Color(0xFF1E1E35) : const Color(0xFFE5E7EB), width: 1),
        ),
        filled: true,
        fillColor: isDark ? const Color(0xFF1E1E35) : const Color(0xFFF3F4F6),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildLocationButton(bool isDark) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isGettingLocation ? null : _handleGetLocation,
        icon: _isGettingLocation
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.my_location, size: 18, color: Colors.white),
        label: Text(
          _isGettingLocation ? "Mendapatkan lokasi..." : "📍 Cek Lokasi & Tampilkan Rute",
          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF9B5EFF),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildStatusCard(bool isDark) {
    final isSuccess = _statusMessage.contains("✅");
    final isWarning = _statusMessage.contains("⚠️");
    final color = isSuccess ? Colors.green : isWarning ? Colors.orange : const Color(0xFF9B5EFF);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(isSuccess ? Icons.check_circle : isWarning ? Icons.warning_amber_rounded : Icons.location_searching, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(_statusMessage, style: GoogleFonts.inter(color: isDark ? const Color(0xFFF0EAFF) : const Color(0xFF1F2937), fontSize: 12))),
        ],
      ),
    );
  }

  Widget _buildErrorCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(_errorMessage, style: GoogleFonts.inter(color: Colors.red.shade300, fontSize: 12))),
        ],
      ),
    );
  }

  Widget _buildMapCard(bool isDark) {
    return Container(
      height: 320,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF1E1E35) : const Color(0xFFE5E7EB)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _userLocation ?? _storeLocation,
            initialZoom: 15.0,
            interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
            onMapReady: () {
              setState(() {
                _isMapReady = true;
                if (_userLocation != null) _mapController.move(_userLocation!, 15.0);
              });
            },
          ),
          children: [
            TileLayer(
              urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
              userAgentPackageName: "com.kanzza.sales.app",
              tileProvider: NetworkTileProvider(),
            ),
            MarkerLayer(
              markers: [
                Marker(
                  width: 45, height: 45, point: _storeLocation,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.orange.shade500, shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))],
                    ),
                    child: const Icon(Icons.store, color: Colors.white, size: 24),
                  ),
                ),
                if (_userLocation != null)
                  Marker(
                    width: 45, height: 45, point: _userLocation!,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.red.shade500, shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))],
                      ),
                      child: const Icon(Icons.location_on, color: Colors.white, size: 24),
                    ),
                  ),
              ],
            ),
            if (_routePoints.isNotEmpty && _routePoints.length > 1)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _routePoints,
                    color: const Color(0xFF9B5EFF),
                    strokeWidth: 5,
                    borderColor: Colors.white.withOpacity(0.2),
                    borderStrokeWidth: 1,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildShippingInfoCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16162A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isDark ? Border.all(color: const Color(0xFF1E1E35)) : Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: isDark ? null : [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [const Icon(Icons.route, color: Color(0xFF9B5EFF), size: 16), const SizedBox(width: 4),
                Text("Jarak Tempuh", style: GoogleFonts.inter(color: isDark ? const Color(0xFF9B97B8) : const Color(0xFF6B7280), fontSize: 13))]),
              Text("${_distance.toStringAsFixed(2)} km", style: GoogleFonts.poppins(color: isDark ? const Color(0xFFF0EAFF) : const Color(0xFF1F2937), fontWeight: FontWeight.w600, fontSize: 14)),
            ]),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [const Icon(Icons.motorcycle, color: Color(0xFF9B5EFF), size: 16), const SizedBox(width: 4),
                Text("Ongkos Kirim (Rp5.000/km)", style: GoogleFonts.inter(color: isDark ? const Color(0xFF9B97B8) : const Color(0xFF6B7280), fontSize: 13))]),
              Text("Rp ${_formatPrice(_shippingCost)}", style: GoogleFonts.poppins(color: const Color(0xFF9B5EFF), fontWeight: FontWeight.w600, fontSize: 14)),
            ]),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF9B5EFF).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF9B5EFF).withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Color(0xFF9B5EFF), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Lokasi diambil dari GPS perangkat Anda. Rute mengikuti jalur jalan raya.",
                    style: GoogleFonts.inter(color: isDark ? const Color(0xFF9B97B8) : const Color(0xFF6B7280), fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============ PICKUP INFO CARD ============
  Widget _buildPickupInfoCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16162A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isDark
            ? Border.all(color: const Color(0xFF1E1E35), width: 1)
            : Border.all(color: const Color(0xFFE5E7EB), width: 1),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E35) : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.storefront, color: Color(0xFF9B5EFF), size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  StoreLocation.storeName,
                  style: GoogleFonts.poppins(
                    color: isDark ? const Color(0xFFF0EAFF) : const Color(0xFF1F2937),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                // Alamat - Bisa diklik untuk Google Maps
                GestureDetector(
                  onTap: () => _openGoogleMaps(StoreLocation.address),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF9B5EFF).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: const Color(0xFF9B5EFF).withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.location_on,
                          color: const Color(0xFF9B5EFF),
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            StoreLocation.address,
                            style: GoogleFonts.inter(
                              color: const Color(0xFF9B5EFF),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.open_in_new,
                          color: const Color(0xFF9B5EFF),
                          size: 12,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                // Telepon - Bisa diklik untuk menelepon
                GestureDetector(
                  onTap: () async {
                    final Uri phoneUri = Uri.parse("tel:${StoreLocation.phone.replaceAll('-', '').replaceAll(' ', '')}");
                    if (await canLaunchUrl(phoneUri)) {
                      await launchUrl(phoneUri);
                    } else {
                      _showSnackBar("Tidak dapat melakukan panggilan", Colors.orange);
                    }
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.phone,
                        color: isDark ? const Color(0xFF5C5878) : const Color(0xFF9CA3AF),
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "Telp: ${StoreLocation.phone}",
                        style: GoogleFonts.inter(
                          color: isDark ? const Color(0xFF5C5878) : const Color(0xFF9CA3AF),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16162A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isDark ? Border.all(color: const Color(0xFF1E1E35)) : Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: isDark ? null : [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          _buildPaymentRadioOption("Bayar di Tempat (COD)", "Bayar saat pesanan sampai", "cod", _paymentMethod, Icons.money, isDark),
          Divider(color: isDark ? const Color(0xFF1E1E35) : const Color(0xFFE5E7EB), height: 16),
          _buildPaymentRadioOption("Transfer Bank", "Bayar via transfer bank", "transfer", _paymentMethod, Icons.account_balance, isDark),
        ],
      ),
    );
  }

  Widget _buildPaymentRadioOption(String title, String subtitle, String value, String groupValue, IconData icon, bool isDark) {
    return GestureDetector(
      onTap: () => setState(() => _paymentMethod = value),
      child: Row(
        children: [
          Radio<String>(
            value: value,
            groupValue: groupValue,
            onChanged: (val) => setState(() => _paymentMethod = val!),
            activeColor: const Color(0xFF9B5EFF),
          ),
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: isDark ? const Color(0xFF1E1E35) : const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: const Color(0xFF9B5EFF), size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.poppins(color: isDark ? const Color(0xFFF0EAFF) : const Color(0xFF1F2937), fontSize: 14, fontWeight: FontWeight.w600)),
                Text(subtitle, style: GoogleFonts.inter(color: isDark ? const Color(0xFF9B97B8) : const Color(0xFF6B7280), fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderSummaryCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16162A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isDark ? Border.all(color: const Color(0xFF1E1E35)) : Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: isDark ? null : [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Total Belanja", style: GoogleFonts.inter(color: isDark ? const Color(0xFF9B97B8) : const Color(0xFF6B7280), fontSize: 14)),
              Text("Rp ${_formatPrice(widget.totalPrice)}", style: GoogleFonts.poppins(color: isDark ? const Color(0xFFF0EAFF) : const Color(0xFF1F2937), fontWeight: FontWeight.w600, fontSize: 14)),
            ]),
          if (_deliveryMethod == "delivery" && _shippingCost > 0) ...[
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Ongkos Kirim", style: GoogleFonts.inter(color: isDark ? const Color(0xFF9B97B8) : const Color(0xFF6B7280), fontSize: 14)),
                Text("Rp ${_formatPrice(_shippingCost)}", style: GoogleFonts.poppins(color: isDark ? const Color(0xFFF0EAFF) : const Color(0xFF1F2937), fontWeight: FontWeight.w600, fontSize: 14)),
              ]),
          ],
          const Divider(color: Color(0xFF1E1E35), height: 24),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Total Pembayaran", style: GoogleFonts.poppins(color: isDark ? const Color(0xFFF0EAFF) : const Color(0xFF1F2937), fontWeight: FontWeight.w600, fontSize: 16)),
              Text("Rp ${_formatPrice(_totalWithShipping)}", style: GoogleFonts.poppins(color: const Color(0xFF9B5EFF), fontSize: 20, fontWeight: FontWeight.w700)),
            ]),
        ],
      ),
    );
  }

  Widget _buildCheckoutButton(bool isDark) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _proceedToPayment,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF9B5EFF),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Text(
          "Lanjutkan ke Pembayaran",
          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
        ),
      ),
    );
  }
}