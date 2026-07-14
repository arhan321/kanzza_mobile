import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../data/models/user.dart';
import '../../../data/repositories/owner_repository.dart';

class OwnerManageRolePage extends StatefulWidget {
  const OwnerManageRolePage({super.key});

  @override
  State<OwnerManageRolePage> createState() => _OwnerManageRolePageState();
}

class _OwnerManageRolePageState extends State<OwnerManageRolePage> {
  final OwnerRepository _repository = OwnerRepository();
  final TextEditingController _searchController = TextEditingController();

  final List<UserModel> _users = [];
  Timer? _searchDebounce;
  bool _isLoading = true;
  int? _updatingUserId;
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
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final users = await _repository.getUsers(
        search: _searchController.text,
        role: _roleFilter,
        status: _statusFilter,
      );

      if (!mounted) return;
      setState(() {
        _users
          ..clear()
          ..addAll(users);
        _isLoading = false;
      });
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
        _errorMessage = 'Daftar pengguna gagal dimuat: $error';
      });
    }
  }

  void _onSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 450), _loadUsers);
  }

  Future<void> _updateRole(UserModel user, String role) async {
    if (_updatingUserId != null || role == user.role) return;
    setState(() => _updatingUserId = user.id);

    try {
      final updated = await _repository.updateUserRole(
        userId: user.id,
        role: role,
      );
      _replaceUser(updated);
      _showMessage('Role ${user.name} berhasil diperbarui.');
    } on ApiException catch (error) {
      _showMessage(error.firstValidationError, isError: true);
    } finally {
      if (mounted) setState(() => _updatingUserId = null);
    }
  }

  Future<void> _toggleStatus(UserModel user) async {
    if (_updatingUserId != null || user.isOwner) return;
    setState(() => _updatingUserId = user.id);

    try {
      final updated = await _repository.updateUserStatus(
        userId: user.id,
        status: user.isActive ? 'inactive' : 'active',
      );
      _replaceUser(updated);
      _showMessage('Status ${user.name} berhasil diperbarui.');
    } on ApiException catch (error) {
      _showMessage(error.firstValidationError, isError: true);
    } finally {
      if (mounted) setState(() => _updatingUserId = null);
    }
  }

  void _replaceUser(UserModel updated) {
    if (!mounted) return;
    final index = _users.indexWhere((item) => item.id == updated.id);
    if (index >= 0) setState(() => _users[index] = updated);
  }

  Future<void> _showCreateStaffDialog() async {
    final result = await showDialog<_StaffFormResult>(
      context: context,
      builder: (_) => const _CreateStaffDialog(),
    );
    if (result == null || !mounted) return;

    setState(() => _isLoading = true);
    try {
      await _repository.createStaff(
        name: result.name,
        email: result.email,
        phone: result.phone,
        password: result.password,
        role: result.role,
      );
      _showMessage('Akun staff berhasil dibuat.');
      await _loadUsers();
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showMessage(error.firstValidationError, isError: true);
      }
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manajemen User'),
        actions: [
          IconButton(
            tooltip: 'Tambah staff',
            onPressed: _isLoading ? null : _showCreateStaffDialog,
            icon: const Icon(Icons.person_add_alt_1_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Cari nama atau email',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                _FilterMenu(
                  label: 'Role',
                  value: _roleFilter,
                  values: const ['customer', 'cashier', 'driver', 'owner'],
                  onChanged: (value) {
                    setState(() => _roleFilter = value);
                    _loadUsers();
                  },
                ),
                const SizedBox(width: 8),
                _FilterMenu(
                  label: 'Status',
                  value: _statusFilter,
                  values: const ['active', 'inactive'],
                  onChanged: (value) {
                    setState(() => _statusFilter = value);
                    _loadUsers();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(child: _buildBody()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading ? null : _showCreateStaffDialog,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tambah Staff'),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _users.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null && _users.isEmpty) {
      return Center(
        child: FilledButton.icon(
          onPressed: _loadUsers,
          icon: const Icon(Icons.refresh_rounded),
          label: Text(_errorMessage!),
        ),
      );
    }
    if (_users.isEmpty) {
      return const Center(child: Text('Pengguna tidak ditemukan.'));
    }

    return RefreshIndicator(
      onRefresh: _loadUsers,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 90),
        itemCount: _users.length,
        separatorBuilder: (_, _) => const SizedBox(height: 6),
        itemBuilder: (context, index) {
          final user = _users[index];
          final updating = _updatingUserId == user.id;
          return Card(
            child: ListTile(
              leading: CircleAvatar(
                child: Text(
                  user.name.trim().isEmpty
                      ? '?'
                      : user.name.trim()[0].toUpperCase(),
                ),
              ),
              title: Text(user.name),
              subtitle: Text(
                '${user.email}\n${_roleLabel(user.role)} • ${user.isActive ? 'Aktif' : 'Nonaktif'}',
              ),
              isThreeLine: true,
              trailing: updating
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : PopupMenuButton<String>(
                      onSelected: (action) {
                        if (action == 'toggle') {
                          _toggleStatus(user);
                        } else {
                          _updateRole(user, action);
                        }
                      },
                      itemBuilder: (_) => [
                        if (!user.isOwner) ...[
                          const PopupMenuItem(
                            value: 'cashier',
                            child: Text('Jadikan Kasir'),
                          ),
                          const PopupMenuItem(
                            value: 'driver',
                            child: Text('Jadikan Driver'),
                          ),
                          PopupMenuItem(
                            value: 'toggle',
                            child: Text(
                              user.isActive ? 'Nonaktifkan' : 'Aktifkan',
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
          );
        },
      ),
    );
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'cashier':
        return 'Kasir';
      case 'driver':
        return 'Driver';
      case 'owner':
        return 'Owner';
      default:
        return 'Customer';
    }
  }
}

class _FilterMenu extends StatelessWidget {
  const _FilterMenu({
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final List<String> values;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButton<String?>(
      value: value,
      hint: Text('Semua $label'),
      items: [
        DropdownMenuItem<String?>(value: null, child: Text('Semua $label')),
        ...values.map(
          (item) => DropdownMenuItem(value: item, child: Text(item)),
        ),
      ],
      onChanged: onChanged,
    );
  }
}

class _StaffFormResult {
  const _StaffFormResult({
    required this.name,
    required this.email,
    required this.phone,
    required this.password,
    required this.role,
  });

  final String name;
  final String email;
  final String phone;
  final String password;
  final String role;
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

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tambah Staff'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Nama'),
                validator: _required,
              ),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (value) {
                  if (value == null || !value.contains('@')) {
                    return 'Email belum valid.';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Nomor telepon (opsional)',
                ),
              ),
              TextFormField(
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
                validator: (value) {
                  if ((value ?? '').length < 6) {
                    return 'Password minimal 6 karakter.';
                  }
                  return null;
                },
              ),
              DropdownButtonFormField<String>(
                initialValue: _role,
                decoration: const InputDecoration(labelText: 'Role'),
                items: const [
                  DropdownMenuItem(value: 'cashier', child: Text('Kasir')),
                  DropdownMenuItem(value: 'driver', child: Text('Driver')),
                ],
                onChanged: (value) =>
                    setState(() => _role = value ?? 'cashier'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState?.validate() != true) return;
            Navigator.pop(
              context,
              _StaffFormResult(
                name: _name.text.trim(),
                email: _email.text.trim(),
                phone: _phone.text.trim(),
                password: _password.text,
                role: _role,
              ),
            );
          },
          child: const Text('Simpan'),
        ),
      ],
    );
  }

  String? _required(String? value) {
    return value == null || value.trim().isEmpty ? 'Wajib diisi.' : null;
  }
}
