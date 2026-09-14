import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';

class PaymentPage extends StatefulWidget {
  final int totalPrice;
  final int idJual; // <--- INI PARAMETER BARU YANG DIPERLUKAN

  const PaymentPage({
    super.key, 
    required this.totalPrice, 
    required this.idJual
  });

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  late WebViewController _controller;
  bool _isLoading = true;
  String? _snapToken;
  
  // Pastikan IP Address Sesuai
  final String _baseUrl = 'https://warungajibuas.my.id/warung_api_uas';

  @override
  void initState() {
    super.initState();
    _getSnapToken();
  }

  // 1. Minta Token ke PHP
  Future<void> _getSnapToken() async {
    try {
      // Buat Order ID Unik untuk Midtrans (Gabungan ID Jual + Timestamp biar aman)
      String orderId = "TRX-${widget.idJual}-${DateTime.now().millisecondsSinceEpoch}";

      final response = await http.post(
        Uri.parse('$_baseUrl/midtrans.php'),
        body: jsonEncode({
          "order_id": orderId,
          "gross_amount": widget.totalPrice
        }),
      );

      final data = jsonDecode(response.body);

      if (data['token'] != null) {
        String redirectUrl = data['redirect_url']; 
        
        setState(() {
          _snapToken = data['token'];
          
          _controller = WebViewController()
            ..setJavaScriptMode(JavaScriptMode.unrestricted)
            ..setBackgroundColor(const Color(0x00000000))
            ..setNavigationDelegate(
              NavigationDelegate(
                onPageFinished: (String url) {
                  setState(() => _isLoading = false);
                },
                // Tangkap jika user selesai bayar
                onUrlChange: (UrlChange change) {
                  String url = change.url ?? "";
                  // Logic sederhana: Jika URL redirect Midtrans mengandung kata sukses
                  if (url.contains("finish") || url.contains("success") || url.contains("settlement")) {
                     _showSuccess();
                  }
                },
              ),
            )
            ..loadRequest(Uri.parse(redirectUrl));
        });
      } else {
        throw Exception("Gagal dapat token: ${data['error']}");
      }
    } catch (e) {
      print("Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      Navigator.pop(context); 
    }
  }

  // 2. Update Status di Database Server (PHP)
  Future<void> _updateStatusServer() async {
    try {
      await http.post(
        Uri.parse('$_baseUrl/update_status_midtrans.php'),
        body: {'id_jual': widget.idJual.toString()}
      );
    } catch (e) {
      print("Gagal update status: $e");
    }
  }

  // 3. Tampilkan Dialog Sukses
  void _showSuccess() async {
    await _updateStatusServer(); // Panggil update status ke PHP
    
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false, 
      builder: (ctx) => AlertDialog(
        title: const Text("Pembayaran Berhasil!"),
        content: const Text("Terima kasih sudah membayar via Midtrans."),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx); // Tutup dialog
              Navigator.pop(context, true); // Kembali ke Dashboard & Reset Cart
            },
            child: const Text("OK"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Pembayaran Midtrans")),
      body: _snapToken == null
          ? const Center(child: CircularProgressIndicator()) 
          : Stack(
              children: [
                WebViewWidget(controller: _controller),
                if (_isLoading)
                  const Center(child: CircularProgressIndicator()),
              ],
            ),
    );
  }
}