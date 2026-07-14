import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../data/repositories/user_repository.dart';
import 'auth_destination.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmController = TextEditingController();

  final UserRepository _userRepository = UserRepository();

  bool isLoading = false;
  bool obscurePassword = true;
  bool obscureConfirmPassword = true;

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    confirmController.dispose();
    super.dispose();
  }

  Future<void> register() async {
    FocusScope.of(context).unfocus();

    final String name = nameController.text.trim();
    final String email = emailController.text.trim();
    final String phone = phoneController.text.trim();
    final String password = passwordController.text;
    final String passwordConfirmation = confirmController.text;

    if (name.isEmpty) {
      _showErrorSnackBar('Nama lengkap tidak boleh kosong');
      return;
    }

    if (name.length < 3) {
      _showErrorSnackBar('Nama lengkap minimal 3 karakter');
      return;
    }

    if (email.isEmpty) {
      _showErrorSnackBar('Email tidak boleh kosong');
      return;
    }

    if (!_isValidEmail(email)) {
      _showErrorSnackBar('Format email tidak valid');
      return;
    }

    if (phone.isEmpty) {
      _showErrorSnackBar('Nomor telepon tidak boleh kosong');
      return;
    }

    if (!_isValidPhone(phone)) {
      _showErrorSnackBar(
        'Nomor telepon harus berisi 10 sampai 15 digit',
      );
      return;
    }

    if (password.isEmpty) {
      _showErrorSnackBar('Password tidak boleh kosong');
      return;
    }

    if (password.length < 6) {
      _showErrorSnackBar('Password minimal 6 karakter');
      return;
    }

    if (password != passwordConfirmation) {
      _showErrorSnackBar('Konfirmasi password tidak cocok');
      return;
    }

    if (isLoading) {
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final session = await _userRepository.register(
        name: name,
        email: email,
        phone: phone,
        password: password,
        passwordConfirmation: passwordConfirmation,
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

      _showSuccessSnackBar(
        'Registrasi berhasil. Selamat datang, ${session.user.name}!',
      );

      await Future<void>.delayed(
        const Duration(milliseconds: 500),
      );

      if (!mounted) {
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
        'Terjadi kesalahan saat registrasi. Silakan coba kembali.',
      );
      debugPrint('REGISTER ERROR: $error');
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

  bool _isValidPhone(String phone) {
    final String normalized = phone.replaceAll(
      RegExp(r'[\s\-\(\)\+]'),
      '',
    );

    return RegExp(r'^[0-9]{10,15}$').hasMatch(normalized);
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

  void _showSuccessSnackBar(String message) {
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
          backgroundColor: Colors.green.shade500,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          duration: const Duration(seconds: 2),
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
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          Container(
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
          ),
          Positioned(
            top: -120,
            right: -80,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -100,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 20,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 560,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconButton(
                        onPressed: isLoading
                            ? null
                            : () {
                                Navigator.pop(context);
                              },
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Create Account',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: isTablet ? 48 : 38,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Daftarkan akun customer untuk mulai\n'
                        'berbelanja produk Kanzza Frozen Food.',
                        style: GoogleFonts.inter(
                          color: Colors.white70,
                          fontSize: 15,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 30),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.96),
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 40,
                              offset: const Offset(0, 20),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Registration',
                              style: GoogleFonts.poppins(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF1F2937),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Akun baru otomatis terdaftar sebagai customer',
                              style: GoogleFonts.inter(
                                color: Colors.grey.shade600,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 24),
                            AppTextField(
                              controller: nameController,
                              hintText: 'Nama Lengkap',
                              prefixIcon: Icons.person_outline,
                              textInputAction: TextInputAction.next,
                              enabled: !isLoading,
                            ),
                            const SizedBox(height: 16),
                            AppTextField(
                              controller: emailController,
                              hintText: 'Email',
                              prefixIcon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              enabled: !isLoading,
                            ),
                            const SizedBox(height: 16),
                            AppTextField(
                              controller: phoneController,
                              hintText: 'Nomor Telepon',
                              prefixIcon: Icons.phone_outlined,
                              keyboardType: TextInputType.phone,
                              textInputAction: TextInputAction.next,
                              enabled: !isLoading,
                            ),
                            const SizedBox(height: 16),
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
                              textInputAction: TextInputAction.next,
                            ),
                            const SizedBox(height: 16),
                            AppTextField(
                              controller: confirmController,
                              hintText: 'Konfirmasi Password',
                              obscureText: obscureConfirmPassword,
                              prefixIcon: Icons.lock_outline,
                              enabled: !isLoading,
                              suffixIcon: IconButton(
                                onPressed: isLoading
                                    ? null
                                    : () {
                                        setState(() {
                                          obscureConfirmPassword =
                                              !obscureConfirmPassword;
                                        });
                                      },
                                icon: Icon(
                                  obscureConfirmPassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  size: 20,
                                  color: Colors.grey,
                                ),
                              ),
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) {
                                register();
                              },
                            ),
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF7132F5)
                                    .withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.info_outline,
                                    color: Color(0xFF7132F5),
                                    size: 19,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Akun cashier dan driver dibuat serta '
                                      'dikelola oleh owner.',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: const Color(0xFF5B21B6),
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 28),
                            AppButton(
                              text: 'Create Account',
                              onPressed: register,
                              isLoading: isLoading,
                            ),
                            const SizedBox(height: 12),
                            Center(
                              child: TextButton(
                                onPressed: isLoading
                                    ? null
                                    : () {
                                        Navigator.pop(context);
                                      },
                                child: Text(
                                  'Already have an account? Login',
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFF7132F5),
                                    fontWeight: FontWeight.w600,
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
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
