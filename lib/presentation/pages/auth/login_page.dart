import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../data/repositories/user_repository.dart';
import 'auth_destination.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  final UserRepository _userRepository = UserRepository();

  bool isLoading = false;
  bool obscurePassword = true;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> login() async {
    FocusScope.of(context).unfocus();

    final String email = emailController.text.trim();
    final String password = passwordController.text;

    if (email.isEmpty) {
      _showErrorSnackBar('Email tidak boleh kosong');
      return;
    }

    if (!_isValidEmail(email)) {
      _showErrorSnackBar('Format email tidak valid');
      return;
    }

    if (password.trim().isEmpty) {
      _showErrorSnackBar('Password tidak boleh kosong');
      return;
    }

    if (isLoading) {
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final session = await _userRepository.login(
        email: email,
        password: password,
        deviceName: 'Kanzza Flutter Mobile',
      );

      if (!mounted) {
        return;
      }

      final destination = destinationForUser(session.user);

      if (destination == null) {
        await _userRepository.clearLocalSession();

        if (!mounted) {
          return;
        }

        _showErrorSnackBar(
          "Role '${session.user.role}' tidak dikenali oleh aplikasi.",
        );
        return;
      }

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => destination,
        ),
        (route) => false,
      );
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      _showErrorSnackBar(error.firstValidationError);
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showErrorSnackBar(
        'Terjadi kesalahan saat login. Silakan coba kembali.',
      );
      debugPrint('LOGIN ERROR: $error');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  bool _isValidEmail(String email) {
    return RegExp(
      r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
    ).hasMatch(email);
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final bool isTablet = MediaQuery.of(context).size.width > 600;

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: [0.0, 0.35, 0.7, 1.0],
            colors: [
              Color(0xFF8B5CF6),
              Color(0xFF5B21B6),
              Color(0xFF312E81),
              Color(0xFF111827),
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -120,
              right: -80,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.06),
                ),
              ),
            ),
            Positioned(
              bottom: -60,
              left: -100,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.04),
                ),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.only(
                  left: 24,
                  right: 24,
                  top: MediaQuery.of(context).padding.top + 20,
                  bottom: MediaQuery.of(context).padding.bottom + 20,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 560,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'KANZZA',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: isTablet ? 52 : 40,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                      Text(
                        'FROZEN FOOD',
                        style: GoogleFonts.poppins(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: isTablet ? 24 : 18,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Manage sales, inventory,\n'
                        'delivery and business insights.',
                        style: GoogleFonts.inter(
                          color: Colors.white70,
                          fontSize: isTablet ? 16 : 14,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 40),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 40,
                              offset: const Offset(0, 20),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome Back',
                              style: GoogleFonts.poppins(
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF1F2937),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Login menggunakan akun Kanzza Anda',
                              style: GoogleFonts.inter(
                                color: Colors.grey.shade600,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 28),
                            AppTextField(
                              controller: emailController,
                              hintText: 'Email',
                              prefixIcon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              enabled: !isLoading,
                            ),
                            const SizedBox(height: 18),
                            AppTextField(
                              controller: passwordController,
                              hintText: 'Password',
                              obscureText: obscurePassword,
                              prefixIcon: Icons.lock_outline,
                              enabled: !isLoading,
                              suffixIcon: IconButton(
                                onPressed: isLoading
                                    ? null
                                    : () {
                                        setState(() {
                                          obscurePassword = !obscurePassword;
                                        });
                                      },
                                icon: Icon(
                                  obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  size: 20,
                                  color: Colors.grey,
                                ),
                              ),
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) {
                                login();
                              },
                            ),
                            const SizedBox(height: 30),
                            AppButton(
                              text: 'Login',
                              onPressed: login,
                              isLoading: isLoading,
                            ),
                            const SizedBox(height: 14),
                            Center(
                              child: TextButton(
                                onPressed: isLoading
                                    ? null
                                    : () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const RegisterPage(),
                                          ),
                                        );
                                      },
                                child: Text(
                                  'Create New Account',
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFF7132F5),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Center(
                        child: Text(
                          '© 2026 Kanzza Sales Apps',
                          style: GoogleFonts.inter(
                            color: Colors.white60,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
