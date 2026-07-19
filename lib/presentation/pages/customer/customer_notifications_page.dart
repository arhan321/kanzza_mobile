import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../data/models/customer_notification.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../routes.dart';
import '../../providers/customer_notification_provider.dart';
import 'customer_orders_page.dart';

class CustomerNotificationsPage extends StatefulWidget {
  const CustomerNotificationsPage({super.key});

  @override
  State<CustomerNotificationsPage> createState() =>
      _CustomerNotificationsPageState();
}

class _CustomerNotificationsPageState
    extends State<CustomerNotificationsPage> {
  final UserRepository _userRepository = UserRepository();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadNotifications();
    });
  }

  Future<void> _loadNotifications() async {
    try {
      await context.read<CustomerNotificationProvider>().loadNotifications();
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        await _handleUnauthorized();
      }
    } catch (error) {
      debugPrint('LOAD CUSTOMER NOTIFICATIONS ERROR: $error');
    }
  }

  Future<void> _handleUnauthorized() async {
    await _userRepository.clearLocalSession();

    if (!mounted) {
      return;
    }

    context.read<CustomerNotificationProvider>().clear();
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
  }

  Future<void> _markAllAsRead() async {
    try {
      await context.read<CustomerNotificationProvider>().markAllAsRead();
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        await _handleUnauthorized();
        return;
      }

      _showSnackBar(error.firstValidationError, Colors.red.shade400);
    } catch (error) {
      debugPrint('MARK ALL NOTIFICATIONS ERROR: $error');
      _showSnackBar(
        'Notifikasi belum dapat diperbarui.',
        Colors.red.shade400,
      );
    }
  }

  Future<void> _openNotification(
    CustomerNotificationModel notification,
  ) async {
    try {
      if (!notification.isRead) {
        await context
            .read<CustomerNotificationProvider>()
            .markAsRead(notification.id);
      }
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        await _handleUnauthorized();
        return;
      }

      _showSnackBar(error.firstValidationError, Colors.red.shade400);
      return;
    } catch (error) {
      debugPrint('MARK NOTIFICATION ERROR: $error');
      _showSnackBar(
        'Notifikasi belum dapat diperbarui.',
        Colors.red.shade400,
      );
      return;
    }

    if (!mounted || notification.orderId == null) {
      return;
    }

    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => const CustomerOrdersPage()),
    );

    if (mounted) {
      await _loadNotifications();
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final notificationProvider =
        context.watch<CustomerNotificationProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark
            ? const Color(0xFF13102A)
            : const Color(0xFFF5F5FA),
        leading: IconButton(
          tooltip: 'Kembali',
          onPressed: () => Navigator.pop(context),
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: theme.textTheme.titleLarge?.color,
          ),
        ),
        title: Text(
          'Notifikasi',
          style: GoogleFonts.poppins(
            color: theme.textTheme.titleLarge?.color,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          if (notificationProvider.unreadCount > 0)
            TextButton(
              onPressed: notificationProvider.isLoading
                  ? null
                  : _markAllAsRead,
              child: Text(
                'Baca semua',
                style: GoogleFonts.inter(
                  color: const Color(0xFF9B5EFF),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          const SizedBox(width: 6),
        ],
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
          top: false,
          child: _buildBody(notificationProvider, isDark),
        ),
      ),
    );
  }

  Widget _buildBody(
    CustomerNotificationProvider provider,
    bool isDark,
  ) {
    if (provider.isLoading && provider.notifications.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF9B5EFF)),
      );
    }

    if (provider.errorMessage != null && provider.notifications.isEmpty) {
      return _buildErrorState(provider.errorMessage!);
    }

    if (provider.notifications.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadNotifications,
        color: const Color(0xFF9B5EFF),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.2),
            _buildEmptyState(),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadNotifications,
      color: const Color(0xFF9B5EFF),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        itemCount: provider.notifications.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          return _buildNotificationCard(
            provider.notifications[index],
            isDark,
          );
        },
      ),
    );
  }

  Widget _buildNotificationCard(
    CustomerNotificationModel notification,
    bool isDark,
  ) {
    final theme = Theme.of(context);
    final accentColor = notification.isPaymentConfirmed
        ? const Color(0xFF22C55E)
        : const Color(0xFF9B5EFF);

    return Material(
      color: notification.isRead
          ? (isDark ? const Color(0xFF16162A) : Colors.white)
          : accentColor.withValues(alpha: isDark ? 0.13 : 0.08),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => _openNotification(notification),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: notification.isRead
                  ? (isDark
                        ? const Color(0xFF24243D)
                        : const Color(0xFFE5E7EB))
                  : accentColor.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.13),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  notification.isPaymentConfirmed
                      ? Icons.payments_rounded
                      : Icons.shopping_bag_rounded,
                  color: accentColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: GoogleFonts.poppins(
                              color: theme.textTheme.titleLarge?.color,
                              fontSize: 13,
                              fontWeight: notification.isRead
                                  ? FontWeight.w600
                                  : FontWeight.w700,
                            ),
                          ),
                        ),
                        if (!notification.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(top: 4, left: 8),
                            decoration: BoxDecoration(
                              color: accentColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.message,
                      style: GoogleFonts.inter(
                        color: theme.textTheme.bodyMedium?.color,
                        fontSize: 12,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 13,
                          color: theme.textTheme.bodySmall?.color,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(notification.createdAt),
                          style: GoogleFonts.inter(
                            color: theme.textTheme.bodySmall?.color,
                            fontSize: 10,
                          ),
                        ),
                        const Spacer(),
                        if (notification.orderId != null)
                          Text(
                            'Lihat pesanan',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF9B5EFF),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: const Color(0xFF9B5EFF).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              color: Color(0xFF9B5EFF),
              size: 42,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Belum ada notifikasi',
            style: GoogleFonts.poppins(
              color: theme.textTheme.titleLarge?.color,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            'Informasi pesanan dan pembayaran Anda akan muncul di sini.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: theme.textTheme.bodyMedium?.color,
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_off_outlined,
              color: Colors.red.shade400,
              size: 54,
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: theme.textTheme.bodyMedium?.color,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: _loadNotifications,
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
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) {
      return '-';
    }

    final localDate = date.toLocal();
    final difference = DateTime.now().difference(localDate);

    if (difference.inMinutes < 1) {
      return 'Baru saja';
    }

    if (difference.inHours < 1) {
      return '${difference.inMinutes} menit lalu';
    }

    if (difference.inDays < 1) {
      return '${difference.inHours} jam lalu';
    }

    if (difference.inDays < 7) {
      return '${difference.inDays} hari lalu';
    }

    final day = localDate.day.toString().padLeft(2, '0');
    final month = localDate.month.toString().padLeft(2, '0');
    final hour = localDate.hour.toString().padLeft(2, '0');
    final minute = localDate.minute.toString().padLeft(2, '0');

    return '$day/$month/${localDate.year} $hour:$minute';
  }
}
