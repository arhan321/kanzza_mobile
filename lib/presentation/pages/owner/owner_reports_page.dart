import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/network/api_exception.dart';
import '../../../data/models/owner_sales_report.dart';
import '../../../data/repositories/owner_repository.dart';

class OwnerReportsPage extends StatefulWidget {
  const OwnerReportsPage({super.key});

  @override
  State<OwnerReportsPage> createState() => _OwnerReportsPageState();
}

class _OwnerReportsPageState extends State<OwnerReportsPage> {
  static const _primary = Color(0xFF9B5EFF);
  final OwnerRepository _repository = OwnerRepository();

  DateTime _startDate = DateUtils.dateOnly(
    DateTime.now().subtract(const Duration(days: 30)),
  );
  DateTime _endDate = DateUtils.dateOnly(DateTime.now());
  String? _channel;
  OwnerSalesReportModel? _report;
  bool _isLoading = true;
  bool _isDownloading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }
    try {
      final report = await _repository.getSalesReport(
        startDate: _startDate,
        endDate: _endDate,
        channel: _channel,
      );
      if (!mounted) return;
      setState(() {
        _report = report;
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
        _errorMessage = 'Laporan belum dapat dimuat: $error';
      });
    }
  }

  Future<void> _pickDate({required bool start}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: start ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked == null || !mounted) return;
    if (start && picked.isAfter(_endDate)) {
      _showMessage('Tanggal awal tidak boleh melewati tanggal akhir.', true);
      return;
    }
    if (!start && picked.isBefore(_startDate)) {
      _showMessage('Tanggal akhir tidak boleh sebelum tanggal awal.', true);
      return;
    }
    setState(() {
      if (start) {
        _startDate = DateUtils.dateOnly(picked);
      } else {
        _endDate = DateUtils.dateOnly(picked);
      }
    });
    await _loadReport();
  }

  Future<void> _chooseExport() async {
    if (_isDownloading) return;
    final format = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Download Rekap Penjualan',
                style: GoogleFonts.poppins(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'File mengikuti filter kanal dan tanggal yang sedang dipilih.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              _ExportTile(
                icon: Icons.picture_as_pdf_rounded,
                color: const Color(0xFFEF5350),
                title: 'Dokumen PDF',
                subtitle: 'Cocok untuk dicetak atau dikirim',
                onTap: () => Navigator.pop(context, 'pdf'),
              ),
              const SizedBox(height: 10),
              _ExportTile(
                icon: Icons.table_view_rounded,
                color: const Color(0xFF39A96B),
                title: 'Microsoft Excel (.xls)',
                subtitle: 'Cocok untuk pengolahan data lanjutan',
                onTap: () => Navigator.pop(context, 'excel'),
              ),
            ],
          ),
        ),
      ),
    );
    if (format == null || !mounted) return;
    await _download(format);
  }

  Future<void> _download(String format) async {
    setState(() => _isDownloading = true);
    try {
      final download = await _repository.downloadSalesReport(
        startDate: _startDate,
        endDate: _endDate,
        channel: _channel,
        format: format,
      );
      if (download.bytes.isEmpty) {
        throw const FileSystemException('Server mengirim file kosong.');
      }
      final directory = await _downloadDirectory();
      final name = _safeFileName(
        download.fileName.contains('.')
            ? download.fileName
            : '${download.fileName}.${format == 'excel' ? 'xls' : 'pdf'}',
      );
      final file = File('${directory.path}${Platform.pathSeparator}$name');
      await file.writeAsBytes(download.bytes, flush: true);
      if (!mounted) return;
      _showMessage('Laporan berhasil disimpan di ${file.path}', false);
    } on ApiException catch (error) {
      _showMessage(error.firstValidationError, true);
    } catch (error) {
      _showMessage('File laporan gagal disimpan: $error', true);
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Future<Directory> _downloadDirectory() async {
    try {
      final downloads = await getDownloadsDirectory();
      if (downloads != null) {
        await downloads.create(recursive: true);
        return downloads;
      }
    } catch (error) {
      debugPrint('DOWNLOAD DIRECTORY FALLBACK: $error');
    }
    if (Platform.isAndroid) {
      final external = await getExternalStorageDirectory();
      if (external != null) {
        await external.create(recursive: true);
        return external;
      }
    }
    final documents = await getApplicationDocumentsDirectory();
    await documents.create(recursive: true);
    return documents;
  }

  String _safeFileName(String value) {
    return value.replaceAll(RegExp(r'[\\/:*?"<>|]'), '-');
  }

  void _showMessage(String message, bool error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error ? const Color(0xFFD84343) : const Color(0xFF2E9B62),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark ? const Color(0xFF080817) : const Color(0xFFF5F4FA);
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Column(
          children: [
            _header(isDark),
            Expanded(
              child: RefreshIndicator(
                color: _primary,
                onRefresh: _loadReport,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                  children: [
                    _filterCard(isDark),
                    const SizedBox(height: 16),
                    _summary(isDark),
                    const SizedBox(height: 20),
                    _transactions(isDark),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          _SquareButton(
            icon: Icons.arrow_back_rounded,
            tooltip: 'Kembali',
            isDark: isDark,
            onTap: () => Navigator.maybePop(context),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Laporan Penjualan',
              style: GoogleFonts.poppins(fontSize: 21, fontWeight: FontWeight.w700),
            ),
          ),
          _SquareButton(
            icon: _isDownloading ? null : Icons.download_rounded,
            tooltip: 'Download laporan',
            isDark: isDark,
            primary: true,
            loading: _isDownloading,
            onTap: _chooseExport,
          ),
          const SizedBox(width: 8),
          _SquareButton(
            icon: Icons.refresh_rounded,
            tooltip: 'Muat ulang',
            isDark: isDark,
            onTap: _loadReport,
          ),
        ],
      ),
    );
  }

  Widget _filterCard(bool isDark) {
    return _Panel(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Tipe:', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              const SizedBox(width: 10),
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _channelChip('Semua', null),
                    _channelChip('Online', 'online'),
                    _channelChip('Offline', 'cashier'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _DateField(
                  label: 'Dari',
                  value: _startDate,
                  onTap: () => _pickDate(start: true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DateField(
                  label: 'Sampai',
                  value: _endDate,
                  onTap: () => _pickDate(start: false),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _channelChip(String label, String? value) {
    final selected = _channel == value;
    return ChoiceChip(
      selected: selected,
      label: Text(label),
      selectedColor: _primary,
      labelStyle: TextStyle(
        color: selected ? Colors.white : null,
        fontWeight: FontWeight.w600,
      ),
      showCheckmark: false,
      onSelected: (_) {
        if (_channel == value) return;
        setState(() => _channel = value);
        _loadReport();
      },
    );
  }

  Widget _summary(bool isDark) {
    if (_isLoading && _report == null) {
      return const SizedBox(height: 130, child: Center(child: CircularProgressIndicator()));
    }
    if (_errorMessage != null && _report == null) {
      return _ErrorPanel(message: _errorMessage!, onRetry: _loadReport);
    }
    final summary = _report?.summary;
    if (summary == null) return const SizedBox.shrink();
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                label: 'Total Transaksi',
                value: '${summary.totalTransactions}',
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SummaryCard(
                label: 'Total Pendapatan',
                value: _rupiah(summary.totalRevenue),
                isDark: isDark,
                primary: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                label: 'Item Terjual',
                value: '${summary.totalItems}',
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SummaryCard(
                label: 'Rata-rata Pesanan',
                value: _rupiah(summary.averageOrder),
                isDark: isDark,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _transactions(bool isDark) {
    final transactions = _report?.transactions ?? const <OwnerSalesTransactionModel>[];
    if (_isLoading && _report != null) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(30),
        child: CircularProgressIndicator(),
      ));
    }
    if (_errorMessage != null) {
      return _ErrorPanel(message: _errorMessage!, onRetry: _loadReport);
    }
    if (transactions.isEmpty) {
      return _Panel(
        isDark: isDark,
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 30),
          child: Center(child: Text('Belum ada transaksi pada filter ini.')),
        ),
      );
    }
    return Column(
      children: transactions
          .map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _TransactionCard(item: item, isDark: isDark),
              ))
          .toList(growable: false),
    );
  }

  String _rupiah(int value) => NumberFormat.currency(
        locale: 'id_ID',
        symbol: 'Rp ',
        decimalDigits: 0,
      ).format(value);
}

class _Panel extends StatelessWidget {
  const _Panel({required this.isDark, required this.child});
  final bool isDark;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16162A) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: isDark ? null : [
          BoxShadow(
            color: const Color(0xFF251354).withValues(alpha: .05),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.isDark,
    this.primary = false,
  });
  final String label;
  final String value;
  final bool isDark;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              color: primary ? _OwnerReportsPageState._primary : null,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.label, required this.value, required this.onTap});
  final String label;
  final DateTime value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.calendar_month_rounded, size: 18),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    DateFormat('dd/MM/yyyy').format(value),
                    maxLines: 1,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  const _TransactionCard({required this.item, required this.isDark});
  final OwnerSalesTransactionModel item;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final color = item.isOnline ? const Color(0xFF9B5EFF) : const Color(0xFFF4A62A);
    return _Panel(
      isDark: isDark,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(item.isOnline ? Icons.wifi_rounded : Icons.point_of_sale_rounded, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 5,
                  children: [
                    Text(item.orderNumber, style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
                    _MiniBadge(label: _status(item.orderStatus), color: const Color(0xFF43A667)),
                    _MiniBadge(label: item.isOnline ? 'Online' : 'Offline', color: color),
                  ],
                ),
                const SizedBox(height: 8),
                Text('${item.customerName} • ${_payment(item.paymentMethod)} • ${item.totalQuantity} item'),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(item.grandTotal),
                style: GoogleFonts.poppins(color: _OwnerReportsPageState._primary, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 5),
              Text(
                item.paidAt == null ? '-' : DateFormat('dd/MM HH:mm').format(item.paidAt!.toLocal()),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _status(String value) {
    return value.split('_').map((word) => word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}').join(' ');
  }

  static String _payment(String value) => value == 'cash' ? 'Tunai' : 'Midtrans';
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
      );
}

class _SquareButton extends StatelessWidget {
  const _SquareButton({
    required this.icon,
    required this.tooltip,
    required this.isDark,
    required this.onTap,
    this.primary = false,
    this.loading = false,
  });
  final IconData? icon;
  final String tooltip;
  final bool isDark;
  final VoidCallback onTap;
  final bool primary;
  final bool loading;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Material(
          color: primary
              ? _OwnerReportsPageState._primary
              : (isDark ? const Color(0xFF16162A) : Colors.white),
          borderRadius: BorderRadius.circular(15),
          child: InkWell(
            onTap: loading ? null : onTap,
            borderRadius: BorderRadius.circular(15),
            child: SizedBox(
              width: 48,
              height: 48,
              child: Center(
                child: loading
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Icon(icon, color: primary ? Colors.white : null),
              ),
            ),
          ),
        ),
      );
}

class _ExportTile extends StatelessWidget {
  const _ExportTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        tileColor: color.withValues(alpha: .08),
        leading: Icon(icon, color: color, size: 30),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
      );
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Icon(Icons.cloud_off_rounded, size: 42),
              const SizedBox(height: 10),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Coba lagi'),
              ),
            ],
          ),
        ),
      );
}
