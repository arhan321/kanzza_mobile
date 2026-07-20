import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_exception.dart';
import '../../../data/models/cashier_notification.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../routes.dart';
import '../../providers/cashier_notification_provider.dart';

class CashierNotificationsPage extends StatefulWidget {
  const CashierNotificationsPage({super.key});

  @override
  State<CashierNotificationsPage> createState() =>
      _CashierNotificationsPageState();
}

class _CashierNotificationsPageState
    extends State<CashierNotificationsPage> {
  static const Color _primary = Color(0xFF9B5EFF);
  final UserRepository _userRepository = UserRepository();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadNotifications());
  }

  Future<void> _loadNotifications() async {
    try {
      await context.read<CashierNotificationProvider>().loadNotifications();
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        await _handleUnauthorized();
      }
    } catch (error) {
      debugPrint('LOAD CASHIER NOTIFICATIONS ERROR: $error');
    }
  }

  Future<void> _handleUnauthorized() async {
    await _userRepository.clearLocalSession();
    if (!mounted) {
      return;
    }

    context.read<CashierNotificationProvider>().clear();
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.login,
      (route) => false,
    );
  }

  Future<void> _markAllAsRead() async {
    try {
      await context.read<CashierNotificationProvider>().markAllAsRead();
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        await _handleUnauthorized();
        return;
      }
      _showMessage(error.firstValidationError, isError: true);
    } catch (error) {
      debugPrint('MARK ALL CASHIER NOTIFICATIONS ERROR: $error');
      _showMessage('Notifikasi belum dapat diperbarui.', isError: true);
    }
  }

  Future<void> _openNotification(
    CashierNotificationModel notification,
  ) async {
    try {
      if (!notification.isRead) {
        await context
            .read<CashierNotificationProvider>()
            .markAsRead(notification.id);
      }
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        await _handleUnauthorized();
        return;
      }
      _showMessage(error.firstValidationError, isError: true);
      return;
    } catch (error) {
      debugPrint('MARK CASHIER NOTIFICATION ERROR: $error');
      _showMessage('Notifikasi belum dapat diperbarui.', isError: true);
      return;
    }

    if (!mounted || notification.orderId == null) {
      return;
    }

    await Navigator.pushNamed(context, AppRoutes.cashierOrders);
    if (mounted) {
      await _loadNotifications();
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: isError
              ? const Color(0xFFD84343)
              : const Color(0xFF2E9B62),
          content: Text(message),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CashierNotificationProvider>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark
            ? const Color(0xFF13102A)
            : Colors.white,
        leading: IconButton(
          tooltip: 'Kembali',
          onPressed: () => Navigator.pop(context),
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: theme.textTheme.titleLarge?.color,
          ),
        ),
        titleSpacing: 4,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Notifikasi Kasir',
              style: GoogleFonts.poppins(
                color: theme.textTheme.titleLarge?.color,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              '${provider.unreadCount} belum dibaca',
              style: GoogleFonts.inter(
                color: theme.textTheme.bodySmall?.color,
                fontSize: 10,
              ),
            ),
          ],
        ),
        actions: [
          if (provider.unreadCount > 0)
            TextButton(
              onPressed: provider.isLoading ? null : _markAllAsRead,
              child: Text(
                'Baca semua',
                style: GoogleFonts.inter(
                  color: _primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          const SizedBox(width: 5),
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
          child: _buildBody(provider, isDark),
        ),
      ),
    );
  }

  Widget _buildBody(CashierNotificationProvider provider, bool isDark) {
    if (provider.isLoading && provider.notifications.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: _primary),
      );
    }

    if (provider.errorMessage != null && provider.notifications.isEmpty) {
      return _ErrorState(
        message: provider.errorMessage!,
        onRetry: _loadNotifications,
      );
    }

    if (provider.notifications.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadNotifications,
        color: _primary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.sizeOf(context).height * 0.2),
            const _EmptyState(),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadNotifications,
      color: _primary,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
        itemCount: provider.notifications.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) => _NotificationCard(
          notification: provider.notifications[index],
          isDark: isDark,
          onTap: () => _openNotification(provider.notifications[index]),
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.isDark,
    required this.onTap,
  });

  final CashierNotificationModel notification;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = notification.isPaymentConfirmed
        ? const Color(0xFF22C55E)
        : const Color(0xFF9B5EFF);
    final cardColor = notification.isRead
        ? (isDark ? const Color(0xFF16162A) : Colors.white)
        : accent.withValues(alpha: isDark ? 0.14 : 0.08);

    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
              color: notification.isRead
                  ? (isDark
                        ? const Color(0xFF24243D)
                        : const Color(0xFFE5E7EB))
                  : accent.withValues(alpha: 0.38),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  notification.isPaymentConfirmed
                      ? Icons.payments_rounded
                      : Icons.shopping_bag_rounded,
                  color: accent,
                  size: 23,
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
                              color: accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    if (notification.orderNumber != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        notification.orderNumber!,
                        style: GoogleFonts.inter(
                          color: accent,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 5),
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
                            'Buka pesanan',
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
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(
        children: [
          Container(
            width: 86,
            height: 86,
            decoration: BoxDecoration(
              color: const Color(0xFF9B5EFF).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              color: Color(0xFF9B5EFF),
              size: 43,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Belum ada notifikasi kasir',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: theme.textTheme.titleLarge?.color,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            'Pesanan online baru dan pembayaran customer akan muncul di sini.',
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
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
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
            FilledButton.icon(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF9B5EFF),
              ),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Coba lagi'),
            ),
          ],
        ),
      ),
    );
  }
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
