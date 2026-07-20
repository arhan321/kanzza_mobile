import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_exception.dart';
import '../../../data/models/user.dart';
import '../../../data/repositories/owner_repository.dart';

class OwnerManageRolePage extends StatefulWidget {
  const OwnerManageRolePage({super.key});

  @override
  State<OwnerManageRolePage> createState() => _OwnerManageRolePageState();
}

class _OwnerManageRolePageState extends State<OwnerManageRolePage> {
  static const _primary = Color(0xFF9B5EFF);
  final OwnerRepository _repository = OwnerRepository();
  final TextEditingController _search = TextEditingController();
  List<UserModel> _allUsers = const [];
  List<UserModel> _visibleUsers = const [];
  Timer? _debounce;
  bool _isLoading = true;
  int? _processingId;
  String? _errorMessage;
  String? _roleFilter;
  String? _statusFilter;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }
    try {
      final users = await _repository.getUsers(perPage: 100, staffOnly: true);
      if (!mounted) return;
      setState(() {
        _allUsers = users;
        _isLoading = false;
      });
      _applyFilters();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = error.firstValidationError;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Daftar pengguna belum dapat dimuat: $error';
      });
    }
  }

  void _applyFilters() {
    final query = _search.text.trim().toLowerCase();
    setState(() {
      _visibleUsers = _allUsers.where((user) {
        final matchesQuery = query.isEmpty ||
            user.name.toLowerCase().contains(query) ||
            user.email.toLowerCase().contains(query) ||
            (user.phone ?? '').toLowerCase().contains(query);
        return matchesQuery &&
            (_roleFilter == null || user.role == _roleFilter) &&
            (_statusFilter == null || user.status == _statusFilter);
      }).toList(growable: false);
    });
  }

  void _onSearch(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), _applyFilters);
  }

  Future<void> _createUser() async {
    final result = await showDialog<_StaffFormResult>(
      context: context,
      builder: (_) => const _CreateStaffDialog(),
    );
    if (result == null || !mounted) return;
    setState(() => _processingId = -1);
    try {
      await _repository.createStaff(
        name: result.name,
        email: result.email,
        phone: result.phone,
        password: result.password,
        role: result.role,
        status: result.status,
      );
      _message('Akun ${result.name} berhasil dibuat.');
      await _loadUsers();
    } on ApiException catch (error) {
      _message(error.firstValidationError, error: true);
    } catch (error) {
      _message('Akun belum berhasil dibuat: $error', error: true);
    } finally {
      if (mounted) setState(() => _processingId = null);
    }
  }

  Future<void> _openUserActions(UserModel user) async {
    if (user.isOwner || _processingId != null) return;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(user.name, style: GoogleFonts.poppins(fontSize: 19, fontWeight: FontWeight.w700)),
              Text(user.email, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 14),
              ListTile(
                leading: const Icon(Icons.point_of_sale_rounded),
                title: const Text('Ubah role menjadi Kasir'),
                enabled: !user.isCashier,
                onTap: () => Navigator.pop(context, 'cashier'),
              ),
              ListTile(
                leading: const Icon(Icons.delivery_dining_rounded),
                title: const Text('Ubah role menjadi Driver'),
                enabled: !user.isDriver,
                onTap: () => Navigator.pop(context, 'driver'),
              ),
              ListTile(
                leading: Icon(user.isActive ? Icons.person_off_rounded : Icons.person_rounded),
                title: Text(user.isActive ? 'Nonaktifkan akun' : 'Aktifkan akun'),
                onTap: () => Navigator.pop(context, 'status'),
              ),
            ],
          ),
        ),
      ),
    );
    if (action == null || !mounted) return;
    setState(() => _processingId = user.id);
    try {
      if (action == 'status') {
        await _repository.updateUserStatus(
          userId: user.id,
          status: user.isActive ? 'inactive' : 'active',
        );
      } else {
        await _repository.updateUserRole(userId: user.id, role: action);
      }
      _message('Data ${user.name} berhasil diperbarui.');
      await _loadUsers();
    } on ApiException catch (error) {
      _message(error.firstValidationError, error: true);
    } finally {
      if (mounted) setState(() => _processingId = null);
    }
  }

  void _resetFilters() {
    _debounce?.cancel();
    _search.clear();
    FocusScope.of(context).unfocus();
    setState(() {
      _roleFilter = null;
      _statusFilter = null;
    });
    _applyFilters();
  }

  void _message(String value, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(value),
        behavior: SnackBarBehavior.floating,
        backgroundColor: error ? const Color(0xFFD84343) : const Color(0xFF2E9B62),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF080817) : const Color(0xFFF5F4FA),
      body: SafeArea(
        child: Column(
          children: [
            _header(isDark),
            Expanded(
              child: RefreshIndicator(
                color: _primary,
                onRefresh: _loadUsers,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                  children: [
                    _stats(isDark),
                    const SizedBox(height: 16),
                    _filters(isDark),
                    const SizedBox(height: 20),
                    _body(isDark),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(bool isDark) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          children: [
            _HeaderButton(icon: Icons.arrow_back_rounded, isDark: isDark, onTap: () => Navigator.maybePop(context)),
            const SizedBox(width: 14),
            Expanded(
              child: Text('Manajemen User', style: GoogleFonts.poppins(fontSize: 21, fontWeight: FontWeight.w700)),
            ),
            _HeaderButton(
              icon: _processingId == -1 ? null : Icons.add_rounded,
              loading: _processingId == -1,
              primary: true,
              isDark: isDark,
              onTap: _createUser,
            ),
          ],
        ),
      );

  Widget _stats(bool isDark) {
    final active = _allUsers.where((user) => user.isActive).length;
    return Row(
      children: [
        Expanded(child: _StatCard(label: 'Total User', value: '${_allUsers.length}', color: null, isDark: isDark)),
        const SizedBox(width: 10),
        Expanded(child: _StatCard(label: 'Aktif', value: '$active', color: const Color(0xFF3EAE68), isDark: isDark)),
        const SizedBox(width: 10),
        Expanded(child: _StatCard(label: 'Nonaktif', value: '${_allUsers.length - active}', color: const Color(0xFFEF5350), isDark: isDark)),
      ],
    );
  }

  Widget _filters(bool isDark) => _Surface(
        isDark: isDark,
        child: Column(
          children: [
            TextField(
              controller: _search,
              onChanged: _onSearch,
              decoration: const InputDecoration(
                hintText: 'Cari user...',
                prefixIcon: Icon(Icons.search_rounded),
                border: InputBorder.none,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _FilterDropdown(
                    value: _roleFilter,
                    hint: 'Semua role',
                    items: const {'owner': 'Owner', 'cashier': 'Kasir', 'driver': 'Driver', 'customer': 'Customer'},
                    onChanged: (value) {
                      setState(() => _roleFilter = value);
                      _applyFilters();
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _FilterDropdown(
                    value: _statusFilter,
                    hint: 'Semua status',
                    items: const {'active': 'Aktif', 'inactive': 'Nonaktif'},
                    onChanged: (value) {
                      setState(() => _statusFilter = value);
                      _applyFilters();
                    },
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.outlined(
                  tooltip: 'Reset filter',
                  onPressed: _resetFilters,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
          ],
        ),
      );

  Widget _body(bool isDark) {
    if (_isLoading && _allUsers.isEmpty) {
      return const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()));
    }
    if (_errorMessage != null && _allUsers.isEmpty) {
      return Center(child: FilledButton.icon(onPressed: _loadUsers, icon: const Icon(Icons.refresh_rounded), label: Text(_errorMessage!)));
    }
    if (_visibleUsers.isEmpty) {
      return const Padding(padding: EdgeInsets.all(40), child: Center(child: Text('Pengguna tidak ditemukan.')));
    }
    return Column(
      children: _visibleUsers.map((user) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _UserCard(
          user: user,
          isDark: isDark,
          loading: _processingId == user.id,
          onTap: () => _openUserActions(user),
        ),
      )).toList(growable: false),
    );
  }
}

class _Surface extends StatelessWidget {
  const _Surface({required this.isDark, required this.child});
  final bool isDark;
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF16162A) : Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: isDark ? null : [BoxShadow(color: Colors.black.withValues(alpha: .045), blurRadius: 18, offset: const Offset(0, 7))],
        ),
        child: child,
      );
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.color, required this.isDark});
  final String label;
  final String value;
  final Color? color;
  final bool isDark;
  @override
  Widget build(BuildContext context) => _Surface(
        isDark: isDark,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, maxLines: 1, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          Text(value, style: GoogleFonts.poppins(fontSize: 23, fontWeight: FontWeight.w700, color: color)),
        ]),
      );
}

class _UserCard extends StatelessWidget {
  const _UserCard({required this.user, required this.isDark, required this.loading, required this.onTap});
  final UserModel user;
  final bool isDark;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final roleColor = _roleColor(user.role);
    return _Surface(
      isDark: isDark,
      child: InkWell(
        onTap: user.isOwner ? null : onTap,
        child: Row(children: [
          Container(
            width: 54,
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: roleColor.withValues(alpha: .13), borderRadius: BorderRadius.circular(15)),
            child: Text(user.name.isEmpty ? '?' : user.name[0].toUpperCase(), style: GoogleFonts.poppins(color: roleColor, fontSize: 24, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 13),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(user.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Row(children: [
              Flexible(child: Text(user.email, maxLines: 1, overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 7),
              _Tag(label: _roleLabel(user.role), color: roleColor),
            ]),
            const SizedBox(height: 3),
            Text('Bergabung: ${user.createdAt == null ? '-' : DateFormat('dd MMM yyyy').format(user.createdAt!.toLocal())}', style: Theme.of(context).textTheme.bodySmall),
          ])),
          const SizedBox(width: 8),
          if (loading)
            const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
          else
            _Tag(label: user.isActive ? 'Aktif' : 'Nonaktif', color: user.isActive ? const Color(0xFF3EAE68) : const Color(0xFFEF5350)),
        ]),
      ),
    );
  }

  static Color _roleColor(String role) => switch (role) {
    'owner' => const Color(0xFF9B5EFF),
    'cashier' => const Color(0xFF3EAE68),
    'driver' => const Color(0xFFF4A62A),
    _ => const Color(0xFF3C9FE8),
  };
  static String _roleLabel(String role) => switch (role) {
    'owner' => 'Owner',
    'cashier' => 'Kasir',
    'driver' => 'Driver',
    _ => 'Customer',
  };
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(7), border: Border.all(color: color.withValues(alpha: .25))),
        child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
      );
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({required this.value, required this.hint, required this.items, required this.onChanged});
  final String? value;
  final String hint;
  final Map<String, String> items;
  final ValueChanged<String?> onChanged;
  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
        hint: Text(hint, maxLines: 1),
        items: [
          DropdownMenuItem<String>(value: null, child: Text(hint)),
          ...items.entries.map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value))),
        ],
        onChanged: onChanged,
      );
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({required this.icon, required this.isDark, required this.onTap, this.primary = false, this.loading = false});
  final IconData? icon;
  final bool isDark;
  final VoidCallback onTap;
  final bool primary;
  final bool loading;
  @override
  Widget build(BuildContext context) => Material(
        color: primary ? _OwnerManageRolePageState._primary : (isDark ? const Color(0xFF16162A) : Colors.white),
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          onTap: loading ? null : onTap,
          borderRadius: BorderRadius.circular(15),
          child: SizedBox(width: 50, height: 50, child: Center(child: loading
              ? const SizedBox.square(dimension: 19, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Icon(icon, color: primary ? Colors.white : null, size: 27))),
        ),
      );
}

class _StaffFormResult {
  const _StaffFormResult({required this.name, required this.email, required this.phone, required this.password, required this.role, required this.status});
  final String name;
  final String email;
  final String phone;
  final String password;
  final String role;
  final String status;
}

class _CreateStaffDialog extends StatefulWidget {
  const _CreateStaffDialog();
  @override
  State<_CreateStaffDialog> createState() => _CreateStaffDialogState();
}

class _CreateStaffDialogState extends State<_CreateStaffDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  String _role = 'cashier';
  String _status = 'active';
  bool _obscure = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        title: Text('Tambah User', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Form(
          key: _formKey,
          child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Nama Lengkap', prefixIcon: Icon(Icons.person_outline_rounded)), validator: _required),
            const SizedBox(height: 12),
            TextFormField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)), validator: (value) => value != null && value.contains('@') ? null : 'Email belum valid.'),
            const SizedBox(height: 12),
            TextFormField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Nomor telepon (opsional)', prefixIcon: Icon(Icons.phone_outlined))),
            const SizedBox(height: 12),
            TextFormField(controller: _password, obscureText: _obscure, decoration: InputDecoration(labelText: 'Password', prefixIcon: const Icon(Icons.lock_outline_rounded), suffixIcon: IconButton(onPressed: () => setState(() => _obscure = !_obscure), icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined))), validator: (value) => (value ?? '').length < 6 ? 'Password minimal 6 karakter.' : null),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: DropdownButtonFormField<String>(initialValue: _role, decoration: const InputDecoration(labelText: 'Role'), items: const [DropdownMenuItem(value: 'cashier', child: Text('Kasir')), DropdownMenuItem(value: 'driver', child: Text('Driver'))], onChanged: (value) => setState(() => _role = value ?? 'cashier'))),
              const SizedBox(width: 10),
              Expanded(child: DropdownButtonFormField<String>(initialValue: _status, decoration: const InputDecoration(labelText: 'Status'), items: const [DropdownMenuItem(value: 'active', child: Text('Aktif')), DropdownMenuItem(value: 'inactive', child: Text('Nonaktif'))], onChanged: (value) => setState(() => _status = value ?? 'active'))),
            ]),
          ])),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          FilledButton(onPressed: () {
            if (_formKey.currentState?.validate() != true) return;
            Navigator.pop(context, _StaffFormResult(name: _name.text.trim(), email: _email.text.trim(), phone: _phone.text.trim(), password: _password.text, role: _role, status: _status));
          }, child: const Text('Simpan')),
        ],
      );

  String? _required(String? value) => value == null || value.trim().isEmpty ? 'Wajib diisi.' : null;
}
