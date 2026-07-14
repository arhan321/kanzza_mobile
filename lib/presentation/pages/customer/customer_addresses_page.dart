// lib/presentation/pages/customer/customer_addresses_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/location/location_service.dart';
import '../../../core/widgets/location_picker_card.dart';
import '../../../data/models/address.dart';
import '../../../data/models/user.dart';
import '../../../data/repositories/address_repository.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../routes.dart';

class CustomerAddressesPage extends StatefulWidget {
  const CustomerAddressesPage({super.key});

  @override
  State<CustomerAddressesPage> createState() => _CustomerAddressesPageState();
}

class _CustomerAddressesPageState extends State<CustomerAddressesPage> {
  final AddressRepository _addressRepository = AddressRepository();
  final UserRepository _userRepository = UserRepository();

  final List<AddressModel> _addresses = [];

  UserModel? _currentUser;
  bool _isLoading = true;
  bool _isRefreshing = false;
  int? _processingAddressId;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData({bool isRefresh = false}) async {
    if (mounted) {
      setState(() {
        if (isRefresh) {
          _isRefreshing = true;
        } else {
          _isLoading = true;
        }

        _errorMessage = null;
      });
    }

    try {
      final results = await Future.wait<dynamic>([
        _userRepository.getProfile(),
        _addressRepository.getAddresses(),
      ]);

      final user = results[0] as UserModel;
      final addresses = results[1] as List<AddressModel>;

      if (!mounted) {
        return;
      }

      setState(() {
        _currentUser = user;
        _addresses
          ..clear()
          ..addAll(addresses);

        _isLoading = false;
        _isRefreshing = false;
        _errorMessage = null;
      });
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        await _handleUnauthorized();
        return;
      }

      _handleError(error.firstValidationError);
    } catch (error) {
      debugPrint('LOAD CUSTOMER ADDRESSES ERROR: $error');

      _handleError('Alamat gagal dimuat. Silakan coba kembali.');
    }
  }

  void _handleError(String message) {
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = false;
      _isRefreshing = false;
      _errorMessage = message;
    });
  }

  Future<void> _handleUnauthorized() async {
    await _userRepository.clearLocalSession();

    if (!mounted) {
      return;
    }

    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
  }

  Future<void> _refresh() async {
    if (_isRefreshing) {
      return;
    }

    await _loadData(isRefresh: true);
  }

  Future<void> _openAddressForm({AddressModel? address}) async {
    final formResult = await showModalBottomSheet<_AddressFormResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddressFormSheet(
        address: address,
        defaultRecipientName: _currentUser?.name ?? '',
        defaultPhone: _currentUser?.phone ?? '',
      ),
    );

    if (formResult == null || !mounted) {
      return;
    }

    setState(() {
      _processingAddressId = address?.id ?? -1;
    });

    try {
      if (address == null) {
        await _addressRepository.createAddress(
          label: formResult.label,
          recipientName: formResult.recipientName,
          phone: formResult.phone,
          fullAddress: formResult.fullAddress,
          province: formResult.province,
          city: formResult.city,
          district: formResult.district,
          postalCode: formResult.postalCode,
          latitude: formResult.latitude,
          longitude: formResult.longitude,
          isDefault: formResult.isDefault,
        );
      } else {
        await _addressRepository.updateAddress(
          addressId: address.id,
          label: formResult.label,
          recipientName: formResult.recipientName,
          phone: formResult.phone,
          fullAddress: formResult.fullAddress,
          province: formResult.province,
          city: formResult.city,
          district: formResult.district,
          postalCode: formResult.postalCode,
          latitude: formResult.latitude,
          longitude: formResult.longitude,
          isDefault: formResult.isDefault,
        );
      }

      if (!mounted) {
        return;
      }

      _showSnackBar(
        address == null
            ? 'Alamat berhasil ditambahkan.'
            : 'Alamat berhasil diperbarui.',
        Colors.green.shade500,
      );

      await _loadData(isRefresh: true);
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        await _handleUnauthorized();
        return;
      }

      if (!mounted) {
        return;
      }

      _showSnackBar(error.firstValidationError, Colors.red.shade400);
    } catch (error) {
      debugPrint('SAVE CUSTOMER ADDRESS ERROR: $error');

      if (!mounted) {
        return;
      }

      _showSnackBar('Alamat gagal disimpan.', Colors.red.shade400);
    } finally {
      if (mounted) {
        setState(() {
          _processingAddressId = null;
        });
      }
    }
  }

  Future<void> _setAsDefault(AddressModel address) async {
    if (address.isDefault || _processingAddressId != null) {
      return;
    }

    setState(() {
      _processingAddressId = address.id;
    });

    try {
      await _addressRepository.updateAddress(
        addressId: address.id,
        label: address.label,
        recipientName: address.recipientName,
        phone: address.phone,
        fullAddress: address.fullAddress,
        province: address.province,
        city: address.city,
        district: address.district,
        postalCode: address.postalCode,
        latitude: address.latitude,
        longitude: address.longitude,
        isDefault: true,
      );

      if (!mounted) {
        return;
      }

      _showSnackBar(
        '${address.label} dijadikan alamat utama.',
        Colors.green.shade500,
      );

      await _loadData(isRefresh: true);
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        await _handleUnauthorized();
        return;
      }

      if (!mounted) {
        return;
      }

      _showSnackBar(error.firstValidationError, Colors.red.shade400);
    } catch (error) {
      debugPrint('SET DEFAULT ADDRESS ERROR: $error');

      if (!mounted) {
        return;
      }

      _showSnackBar('Alamat utama gagal diperbarui.', Colors.red.shade400);
    } finally {
      if (mounted) {
        setState(() {
          _processingAddressId = null;
        });
      }
    }
  }

  Future<void> _deleteAddress(AddressModel address) async {
    final confirmed = await _showDeleteConfirmation(address);

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _processingAddressId = address.id;
    });

    try {
      await _addressRepository.deleteAddress(address.id);

      if (!mounted) {
        return;
      }

      _showSnackBar(
        'Alamat ${address.label} berhasil dihapus.',
        Colors.green.shade500,
      );

      await _loadData(isRefresh: true);
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        await _handleUnauthorized();
        return;
      }

      if (!mounted) {
        return;
      }

      _showSnackBar(error.firstValidationError, Colors.red.shade400);
    } catch (error) {
      debugPrint('DELETE CUSTOMER ADDRESS ERROR: $error');

      if (!mounted) {
        return;
      }

      _showSnackBar('Alamat gagal dihapus.', Colors.red.shade400);
    } finally {
      if (mounted) {
        setState(() {
          _processingAddressId = null;
        });
      }
    }
  }

  Future<bool?> _showDeleteConfirmation(AddressModel address) {
    final theme = Theme.of(context);
    final isDark = Provider.of<ThemeProvider>(
      context,
      listen: false,
    ).isDarkMode;

    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: theme.cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: isDark ? const Color(0xFF1E1E35) : const Color(0xFFE5E7EB),
            ),
          ),
          title: Text(
            'Hapus Alamat',
            style: GoogleFonts.poppins(
              color: theme.textTheme.titleLarge?.color,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            'Hapus alamat ${address.label}? '
            'Tindakan ini tidak dapat dibatalkan.',
            style: GoogleFonts.inter(
              color: theme.textTheme.bodyMedium?.color,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade400,
                foregroundColor: Colors.white,
              ),
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );
  }

  void _showSnackBar(String message, Color color) {
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
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final theme = Theme.of(context);
    final width = MediaQuery.of(context).size.width;
    final horizontalPadding = width * 0.04;

    SystemChrome.setSystemUIOverlayStyle(
      isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
    );

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      floatingActionButton: _isLoading
          ? null
          : FloatingActionButton.extended(
              onPressed: _processingAddressId == null
                  ? () {
                      _openAddressForm();
                    }
                  : null,
              backgroundColor: const Color(0xFF9B5EFF),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_location_alt_outlined),
              label: Text(
                'Tambah Alamat',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
              ),
            ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? const [Color(0xFF13102A), Color(0xFF0D0D12)]
                : const [Color(0xFFF5F5FA), Color(0xFFE8E8F0)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(
                horizontalPadding: horizontalPadding,
                isDark: isDark,
              ),
              Expanded(
                child: _buildBody(
                  horizontalPadding: horizontalPadding,
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader({
    required double horizontalPadding,
    required bool isDark,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        14,
        horizontalPadding,
        14,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13102A) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF1E1E35) : const Color(0xFFE5E7EB),
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              Navigator.maybePop(context);
            },
            style: IconButton.styleFrom(
              backgroundColor: isDark
                  ? const Color(0xFF16162A)
                  : const Color(0xFFF5F5FA),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: Icon(
              Icons.arrow_back_rounded,
              color: theme.textTheme.titleLarge?.color,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Alamat Saya',
                  style: GoogleFonts.poppins(
                    color: theme.textTheme.titleLarge?.color,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${_addresses.length} alamat tersimpan',
                  style: GoogleFonts.inter(
                    color: theme.textTheme.bodySmall?.color,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: _isLoading || _isRefreshing ? null : _refresh,
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFF9B5EFF).withValues(alpha: 0.12),
              foregroundColor: const Color(0xFF9B5EFF),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: _isRefreshing
                ? const SizedBox(
                    width: 19,
                    height: 19,
                    child: CircularProgressIndicator(
                      color: Color(0xFF9B5EFF),
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildBody({required double horizontalPadding, required bool isDark}) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF9B5EFF)),
      );
    }

    if (_errorMessage != null && _addresses.isEmpty) {
      return _buildErrorState();
    }

    if (_addresses.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      color: const Color(0xFF9B5EFF),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          16,
          horizontalPadding,
          100,
        ),
        itemCount: _addresses.length + (_errorMessage == null ? 0 : 1),
        itemBuilder: (context, index) {
          if (_errorMessage != null && index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildInlineError(),
            );
          }

          final actualIndex = _errorMessage == null ? index : index - 1;
          final address = _addresses[actualIndex];

          return _buildAddressCard(address: address, isDark: isDark);
        },
      ),
    );
  }

  Widget _buildAddressCard({
    required AddressModel address,
    required bool isDark,
  }) {
    final theme = Theme.of(context);
    final processing = _processingAddressId == address.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: address.isDefault
              ? const Color(0xFF9B5EFF)
              : isDark
              ? const Color(0xFF1E1E35)
              : const Color(0xFFE5E7EB),
          width: address.isDefault ? 1.5 : 1,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 9,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF9B5EFF).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.location_on_outlined,
                  color: Color(0xFF9B5EFF),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 7,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          address.label,
                          style: GoogleFonts.poppins(
                            color: theme.textTheme.titleLarge?.color,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (address.isDefault)
                          _badge(text: 'Utama', color: Colors.green.shade500),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${address.recipientName} • ${address.phone}',
                      style: GoogleFonts.inter(
                        color: theme.textTheme.bodyMedium?.color,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (processing)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: Color(0xFF9B5EFF),
                    strokeWidth: 2,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 11),
          Text(
            address.fullAddress,
            style: GoogleFonts.inter(
              color: theme.textTheme.bodyMedium?.color,
              fontSize: 11,
              height: 1.45,
            ),
          ),
          if (address.locationSummary.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              address.locationSummary,
              style: GoogleFonts.inter(
                color: theme.textTheme.bodySmall?.color,
                fontSize: 9,
              ),
            ),
          ],
          const Divider(height: 22),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              if (!address.isDefault)
                _actionButton(
                  label: 'Jadikan Utama',
                  icon: Icons.star_outline_rounded,
                  color: Colors.green.shade500,
                  onTap: processing
                      ? null
                      : () {
                          _setAsDefault(address);
                        },
                ),
              _actionButton(
                label: 'Edit',
                icon: Icons.edit_outlined,
                color: const Color(0xFF9B5EFF),
                onTap: processing
                    ? null
                    : () {
                        _openAddressForm(address: address);
                      },
              ),
              _actionButton(
                label: 'Hapus',
                icon: Icons.delete_outline_rounded,
                color: Colors.red.shade400,
                onTap: processing
                    ? null
                    : () {
                        _deleteAddress(address);
                      },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: color.withValues(alpha: 0.22)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: onTap == null ? color.withValues(alpha: 0.45) : color,
              size: 15,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.inter(
                color: onTap == null ? color.withValues(alpha: 0.45) : color,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge({required String text, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildInlineError() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange.shade500),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              _errorMessage!,
              style: GoogleFonts.inter(
                color: Colors.orange.shade600,
                fontSize: 11,
              ),
            ),
          ),
          TextButton(onPressed: _refresh, child: const Text('Ulangi')),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: _refresh,
      color: const Color(0xFF9B5EFF),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.68,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_location_alt_outlined,
                      color: theme.textTheme.bodySmall?.color,
                      size: 64,
                    ),
                    const SizedBox(height: 17),
                    Text(
                      'Belum Ada Alamat',
                      style: GoogleFonts.poppins(
                        color: theme.textTheme.titleLarge?.color,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      'Tambahkan alamat untuk mempermudah proses checkout.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: theme.textTheme.bodySmall?.color,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 18),
                    ElevatedButton.icon(
                      onPressed: () {
                        _openAddressForm();
                      },
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Tambah Alamat'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF9B5EFF),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: _refresh,
      color: const Color(0xFF9B5EFF),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.68,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.cloud_off_rounded,
                      color: Colors.red.shade300,
                      size: 64,
                    ),
                    const SizedBox(height: 17),
                    Text(
                      'Alamat gagal dimuat',
                      style: GoogleFonts.poppins(
                        color: theme.textTheme.titleLarge?.color,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage ??
                          'Terjadi kesalahan saat mengambil alamat.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: theme.textTheme.bodySmall?.color,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 18),
                    ElevatedButton.icon(
                      onPressed: () {
                        _loadData();
                      },
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Coba Lagi'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF9B5EFF),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddressFormSheet extends StatefulWidget {
  final AddressModel? address;
  final String defaultRecipientName;
  final String defaultPhone;

  const _AddressFormSheet({
    required this.address,
    required this.defaultRecipientName,
    required this.defaultPhone,
  });

  @override
  State<_AddressFormSheet> createState() => _AddressFormSheetState();
}

class _AddressFormSheetState extends State<_AddressFormSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _labelController;
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  late final TextEditingController _districtController;
  late final TextEditingController _cityController;
  late final TextEditingController _provinceController;
  late final TextEditingController _postalCodeController;

  double? _latitude;
  double? _longitude;
  late bool _isDefault;

  @override
  void initState() {
    super.initState();

    final address = widget.address;

    _labelController = TextEditingController(text: address?.label ?? 'Rumah');
    _nameController = TextEditingController(
      text: address?.recipientName ?? widget.defaultRecipientName,
    );
    _phoneController = TextEditingController(
      text: address?.phone ?? widget.defaultPhone,
    );
    _addressController = TextEditingController(
      text: address?.fullAddress ?? '',
    );
    _districtController = TextEditingController(text: address?.district ?? '');
    _cityController = TextEditingController(text: address?.city ?? '');
    _provinceController = TextEditingController(text: address?.province ?? '');
    _postalCodeController = TextEditingController(
      text: address?.postalCode ?? '',
    );
    _latitude = address?.latitude;
    _longitude = address?.longitude;
    _isDefault = address?.isDefault ?? false;
  }

  @override
  void dispose() {
    _labelController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _districtController.dispose();
    _cityController.dispose();
    _provinceController.dispose();
    _postalCodeController.dispose();
    super.dispose();
  }

  void _applyDetectedLocation(DetectedLocation location) {
    setState(() {
      _latitude = location.latitude;
      _longitude = location.longitude;
      _addressController.text = location.fullAddress;
      _districtController.text = location.district ?? '';
      _cityController.text = location.city ?? '';
      _provinceController.text = location.province ?? '';
      _postalCodeController.text = location.postalCode ?? '';
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    Navigator.pop(
      context,
      _AddressFormResult(
        label: _labelController.text.trim(),
        recipientName: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        fullAddress: _addressController.text.trim(),
        district: _districtController.text.trim(),
        city: _cityController.text.trim(),
        province: _provinceController.text.trim(),
        postalCode: _postalCodeController.text.trim(),
        latitude: _latitude,
        longitude: _longitude,
        isDefault: _isDefault,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.92,
        ),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF16162A) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isDark
                          ? const Color(0xFF1E1E35)
                          : const Color(0xFFE5E7EB),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.address == null
                            ? 'Tambah Alamat'
                            : 'Edit Alamat',
                        style: GoogleFonts.poppins(
                          color: theme.textTheme.titleLarge?.color,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        _field(
                          controller: _labelController,
                          label: 'Label alamat',
                          hint: 'Rumah, Kantor, Kost',
                          icon: Icons.bookmark_outline,
                          validator: _required,
                        ),
                        const SizedBox(height: 12),
                        _field(
                          controller: _nameController,
                          label: 'Nama penerima',
                          hint: 'Nama lengkap penerima',
                          icon: Icons.person_outline,
                          validator: _required,
                        ),
                        const SizedBox(height: 12),
                        _field(
                          controller: _phoneController,
                          label: 'Nomor telepon',
                          hint: 'Contoh: 081234567890',
                          icon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                          validator: _validatePhone,
                        ),
                        const SizedBox(height: 12),
                        LocationPickerCard(
                          initialLatitude: _latitude,
                          initialLongitude: _longitude,
                          autoDetect: widget.address == null,
                          onLocationChanged: _applyDetectedLocation,
                        ),
                        const SizedBox(height: 12),
                        _field(
                          controller: _addressController,
                          label: 'Alamat lengkap',
                          hint: 'Jalan, nomor rumah, RT/RW, patokan',
                          icon: Icons.location_on_outlined,
                          maxLines: 3,
                          validator: _required,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _field(
                                controller: _districtController,
                                label: 'Kecamatan',
                                hint: 'Opsional',
                                icon: Icons.map_outlined,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _field(
                                controller: _cityController,
                                label: 'Kota/Kabupaten',
                                hint: 'Opsional',
                                icon: Icons.location_city_outlined,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _field(
                                controller: _provinceController,
                                label: 'Provinsi',
                                hint: 'Opsional',
                                icon: Icons.public_outlined,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _field(
                                controller: _postalCodeController,
                                label: 'Kode pos',
                                hint: 'Opsional',
                                icon: Icons.markunread_mailbox_outlined,
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          value: _isDefault,
                          activeThumbColor: const Color(0xFF9B5EFF),
                          onChanged: (value) {
                            setState(() {
                              _isDefault = value;
                            });
                          },
                          title: Text(
                            'Jadikan alamat utama',
                            style: GoogleFonts.inter(
                              color: theme.textTheme.titleLarge?.color,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            'Alamat utama dipilih otomatis saat checkout.',
                            style: GoogleFonts.inter(
                              color: theme.textTheme.bodySmall?.color,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _submit,
                            icon: const Icon(Icons.save_outlined),
                            label: Text(
                              widget.address == null
                                  ? 'Simpan Alamat'
                                  : 'Simpan Perubahan',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF9B5EFF),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(13),
                              ),
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
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    final theme = Theme.of(context);
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: GoogleFonts.inter(
        color: theme.textTheme.titleLarge?.color,
        fontSize: 12,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: const Color(0xFF9B5EFF), size: 19),
        filled: true,
        fillColor: isDark ? const Color(0xFF0D0D12) : const Color(0xFFF7F7FB),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF9B5EFF), width: 1.5),
        ),
      ),
    );
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Field ini wajib diisi.';
    }

    return null;
  }

  String? _validatePhone(String? value) {
    final requiredError = _required(value);

    if (requiredError != null) {
      return requiredError;
    }

    final normalized = value!.replaceAll(RegExp(r'[\s\-\(\)\+]'), '');

    if (!RegExp(r'^[0-9]{10,15}$').hasMatch(normalized)) {
      return 'Nomor telepon harus 10–15 digit.';
    }

    return null;
  }
}

class _AddressFormResult {
  final String label;
  final String recipientName;
  final String phone;
  final String fullAddress;
  final String district;
  final String city;
  final String province;
  final String postalCode;
  final double? latitude;
  final double? longitude;
  final bool isDefault;

  const _AddressFormResult({
    required this.label,
    required this.recipientName,
    required this.phone,
    required this.fullAddress,
    required this.district,
    required this.city,
    required this.province,
    required this.postalCode,
    this.latitude,
    this.longitude,
    required this.isDefault,
  });
}
