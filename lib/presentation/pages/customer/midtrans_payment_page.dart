import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';

class MidtransPaymentPage extends StatefulWidget {
  final String redirectUrl;
  final String orderNumber;

  const MidtransPaymentPage({
    super.key,
    required this.redirectUrl,
    required this.orderNumber,
  });

  @override
  State<MidtransPaymentPage> createState() =>
      _MidtransPaymentPageState();
}

class _MidtransPaymentPageState
    extends State<MidtransPaymentPage> {
  late final WebViewController _controller;

  bool _isLoading = true;
  double _progress = 0;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(
        JavaScriptMode.unrestricted,
      )
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (!mounted) {
              return;
            }

            setState(() {
              _progress = progress / 100;
            });
          },
          onPageStarted: (_) {
            if (!mounted) {
              return;
            }

            setState(() {
              _isLoading = true;
              _errorMessage = null;
            });
          },
          onPageFinished: (_) {
            if (!mounted) {
              return;
            }

            setState(() {
              _isLoading = false;
              _progress = 1;
            });
          },
          onWebResourceError: (error) {
            if (!mounted || error.isForMainFrame == false) {
              return;
            }

            setState(() {
              _isLoading = false;
              _errorMessage =
                  'Halaman pembayaran gagal dimuat: '
                  '${error.description}';
            });
          },
          onNavigationRequest: (request) {
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(
        Uri.parse(widget.redirectUrl),
      );
  }

  Future<bool> _handleBack() async {
    if (await _controller.canGoBack()) {
      await _controller.goBack();
      return false;
    }

    return true;
  }

  void _closePayment() {
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (
        didPop,
        result,
      ) async {
        if (didPop) {
          return;
        }

        final canClose = await _handleBack();

        if (!mounted || !canClose) {
          return;
        }

        _closePayment();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: const Color(0xFF5B21B6),
          foregroundColor: Colors.white,
          elevation: 0,
          titleSpacing: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pembayaran Midtrans',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                widget.orderNumber,
                style: GoogleFonts.inter(
                  color: Colors.white70,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Muat ulang',
              onPressed: () {
                _controller.reload();
              },
              icon: const Icon(
                Icons.refresh_rounded,
              ),
            ),
            TextButton(
              onPressed: _closePayment,
              child: Text(
                'Selesai',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          bottom: _isLoading
              ? PreferredSize(
                  preferredSize:
                      const Size.fromHeight(3),
                  child: LinearProgressIndicator(
                    value:
                        _progress > 0 ? _progress : null,
                    minHeight: 3,
                    backgroundColor:
                        Colors.white24,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(
                      Colors.white,
                    ),
                  ),
                )
              : null,
        ),
        body: Stack(
          children: [
            WebViewWidget(
              controller: _controller,
            ),
            if (_errorMessage != null)
              Positioned.fill(
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.cloud_off_rounded,
                        color: Colors.red.shade300,
                        size: 64,
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Pembayaran gagal dimuat',
                        style: GoogleFonts.poppins(
                          color:
                              const Color(0xFF1F2937),
                          fontSize: 18,
                          fontWeight:
                              FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color:
                              const Color(0xFF6B7280),
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _errorMessage = null;
                          });
                          _controller.reload();
                        },
                        icon: const Icon(
                          Icons.refresh_rounded,
                        ),
                        label: const Text(
                          'Coba Lagi',
                        ),
                        style:
                            ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color(0xFF5B21B6),
                          foregroundColor:
                              Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _closePayment,
                        child: const Text(
                          'Tutup dan cek status',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
