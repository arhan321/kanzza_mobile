import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/network/api_exception.dart';
import '../../../data/repositories/user_repository.dart';
import 'auth_destination.dart';
import 'login_page.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  final UserRepository _userRepository = UserRepository();

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final user = await _userRepository.restoreSession();

      if (!mounted) {
        return;
      }

      if (user == null) {
        _goToLogin();
        return;
      }

      final destination = destinationForUser(user);

      if (destination == null) {
        await _userRepository.clearLocalSession();

        if (!mounted) {
          return;
        }

        setState(() {
          _isLoading = false;
          _errorMessage = "Role '${user.role}' tidak dikenali oleh aplikasi.";
        });
        return;
      }

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => destination),
        (route) => false,
      );
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = error.firstValidationError;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = 'Gagal memeriksa sesi login. Silakan coba kembali.';
      });

      debugPrint('RESTORE SESSION ERROR: $error');
    }
  }

  void _goToLogin() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  Future<void> _clearSessionAndLogin() async {
    await _userRepository.clearLocalSession();

    if (!mounted) {
      return;
    }

    _goToLogin();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF8B5CF6),
              Color(0xFF5B21B6),
              Color(0xFF312E81),
              Color(0xFF111827),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 104,
                    height: 104,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.ac_unit_rounded,
                      color: Colors.white,
                      size: 54,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'KANZZA',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 40,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Text(
                    'FROZEN FOOD',
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 42),
                  if (_isLoading) ...[
                    const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.6,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Memeriksa sesi login...',
                      style: GoogleFonts.inter(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ] else ...[
                    Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxWidth: 460),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.16),
                        ),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.wifi_off_rounded,
                            color: Colors.white,
                            size: 34,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _errorMessage ??
                                'Tidak dapat memeriksa sesi login.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _restoreSession,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF5B21B6),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text('Coba Lagi'),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _clearSessionAndLogin,
                            child: Text(
                              'Kembali ke halaman login',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
