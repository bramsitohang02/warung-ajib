import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:dropdown_search/dropdown_search.dart';
import 'package:project_uas/city.dart';
import 'package:project_uas/rajaongkir_repository.dart';
import 'package:project_uas/payment_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --- IMPORT UNTUK PDF & PRINTING ---
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class CheckoutPage extends StatefulWidget {
  final int productTotal;
  final List<Map<String, dynamic>> cartItems;

  const CheckoutPage({super.key, required this.productTotal, required this.cartItems});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final RajaOngkirRepository _repository = RajaOngkirRepository();
  City? _selectedOrigin;
  City? _selectedDestination;
  String _selectedCourier = 'jne'; 
  int _totalWeight = 0;
  List<dynamic> _shippingCosts = [];
  int _selectedShippingCost = 0;
  String _paymentMethod = 'manual';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _calculateTotalWeight();
  }

  void _calculateTotalWeight() {
    int total = 0;
    for (var item in widget.cartItems) {
      total += (item['berat'] as int);
    }
    setState(() => _totalWeight = total > 0 ? total : 1000);
  }

  void _cekOngkir() async {
    if (_selectedOrigin == null || _selectedDestination == null) return;
    setState(() => _isLoading = true);
    try {
      final results = await _repository.checkCost(
        originId: _selectedOrigin!.id,
        destinationId: _selectedDestination!.id,
        weight: _totalWeight,
        courier: _selectedCourier,
      );
      setState(() {
        _shippingCosts = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  // --- FUNGSI CETAK NOTA (PDF) ---
  Future<void> _cetakNota(int idJual, int grandTotal) async {
    final doc = pw.Document();
    
    final currency = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);
    String tanggal = DateFormat('dd-MM-yyyy HH:mm').format(DateTime.now());

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80, 
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text("WARUNG AJIB", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18)),
              pw.Text("Jl. Kampus No. 123", style: pw.TextStyle(fontSize: 10)),
              pw.Divider(),
              pw.Text("NOTA PEMBELIAN", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text("No: #$idJual"),
              pw.Text(tanggal),
              pw.Divider(),
              
              ...widget.cartItems.map((item) {
                return pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Expanded(child: pw.Text(item['nama_barang'], style: pw.TextStyle(fontSize: 10))),
                    pw.Text(currency.format(item['harga']), style: pw.TextStyle(fontSize: 10)),
                  ]
                );
              }).toList(),
              
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("Ongkir:", style: pw.TextStyle(fontSize: 10)),
                  pw.Text(currency.format(_selectedShippingCost), style: pw.TextStyle(fontSize: 10)),
                ]
              ),
              pw.SizedBox(height: 5),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("TOTAL BAYAR:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text(currency.format(grandTotal), style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ]
              ),
              pw.SizedBox(height: 20),
              pw.Text("Terima Kasih!", style: pw.TextStyle(fontSize: 12, fontStyle: pw.FontStyle.italic)),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => doc.save());
  }

  // --- POPUP SUKSES DENGAN TOMBOL PRINT ---
  void _showSuccessDialog(int idJual) {
    int grandTotal = widget.productTotal + _selectedShippingCost;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text("Pesanan Berhasil!"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 60),
            const SizedBox(height: 10),
            Text("Order ID: #$idJual"),
            const Text("Silakan simpan nota ini."),
          ],
        ),
        actions: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[800]),
            onPressed: () => _cetakNota(idJual, grandTotal),
            icon: const Icon(Icons.print, color: Colors.white),
            label: const Text("CETAK NOTA", style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx); 
              Navigator.pop(context, true); 
            },
            child: const Text("TUTUP"),
          )
        ],
      ),
    );
  }

  // --- PROSES ORDER (FIXED) ---
  void _processOrder() async {
    if (_selectedShippingCost == 0) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pilih ongkir dulu!")));
       return;
    }

    setState(() => _isLoading = true);
    
    final prefs = await SharedPreferences.getInstance();
    String userId = prefs.getString('id_user') ?? "0"; 

    if (userId == "0") {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sesi login error, silakan login ulang")));
      return;
    }

    int grandTotal = widget.productTotal + _selectedShippingCost;

    try {
      final response = await http.post(
        Uri.parse("https://warungajibuas.my.id/warung_api_uas/transaksi.php"),
        body: jsonEncode({
          "id_user": userId,
          "total_bayar": grandTotal,
          "metode_pembayaran": _paymentMethod,
          "items": widget.cartItems
        }),
      );
      final data = jsonDecode(response.body);
      
      if (data['success'] == true) {
        int idJualBaru = data['id_jual'];

        if (_paymentMethod == 'midtrans') {
          // --- PERBAIKAN LOGIKA NAVIGASI DI SINI ---
          // Gunakan push (tunggu hasil), bukan pushReplacement
          final result = await Navigator.push(
            context, 
            MaterialPageRoute(
              builder: (context) => PaymentPage(
                totalPrice: grandTotal, 
                idJual: idJualBaru 
              )
            )
          );

          // Jika PaymentPage mengirim sinyal 'true' (sukses)
          if (result == true) {
            // Tutup halaman Checkout dan kirim sinyal 'true' ke Dashboard
            if (mounted) Navigator.pop(context, true);
          }
        } else {
          // Manual Transfer
          _showSuccessDialog(idJualBaru);
        }
      } else {
        throw Exception(data['message']);
      }
    } catch (e) {
      print(e);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Checkout")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // DROPDOWN LOKASI
          DropdownSearch<City>(
            popupProps: const PopupProps.menu(showSearchBox: true, isFilterOnline: true),
            asyncItems: (String filter) => _repository.fetchCities(filter),
            itemAsString: (City u) => u.name,
            onChanged: (data) => setState(() => _selectedOrigin = data),
            dropdownDecoratorProps: const DropDownDecoratorProps(dropdownSearchDecoration: InputDecoration(labelText: "Asal", border: OutlineInputBorder())),
          ),
          const SizedBox(height: 10),
          DropdownSearch<City>(
            popupProps: const PopupProps.menu(showSearchBox: true, isFilterOnline: true),
            asyncItems: (String filter) => _repository.fetchCities(filter),
            itemAsString: (City u) => u.name,
            onChanged: (data) => setState(() => _selectedDestination = data),
            dropdownDecoratorProps: const DropDownDecoratorProps(dropdownSearchDecoration: InputDecoration(labelText: "Tujuan", border: OutlineInputBorder())),
          ),
          const SizedBox(height: 10),
          
          // PILIHAN KURIR
          DropdownButtonFormField<String>(
            value: _selectedCourier,
            decoration: const InputDecoration(labelText: "Pilih Jasa Kirim", border: OutlineInputBorder()),
            items: [
              DropdownMenuItem(value: 'jne', child: Text("JNE")),
              DropdownMenuItem(value: 'pos', child: Text("POS Indonesia")),
              DropdownMenuItem(value: 'tiki', child: Text("TIKI")),
            ],
            onChanged: (val) => setState(() => _selectedCourier = val!),
          ),
          const SizedBox(height: 10),

          ElevatedButton(onPressed: _cekOngkir, child: const Text("CEK ONGKIR")),
          
          if (_shippingCosts.isNotEmpty) 
             ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _shippingCosts.length,
                itemBuilder: (context, index) {
                  final item = _shippingCosts[index];
                  int cost = item['cost'] ?? 0;
                  return Card(
                    color: (cost == _selectedShippingCost) ? Colors.green[100] : null,
                    child: ListTile(
                      onTap: () => setState(() => _selectedShippingCost = cost),
                      title: Text("${item['service']} - Rp $cost"),
                    ),
                  );
                },
              ),
          
          const Divider(),
          const Text("Metode Bayar:", style: TextStyle(fontWeight: FontWeight.bold)),
          RadioListTile(title: const Text("Transfer Manual"), value: 'manual', groupValue: _paymentMethod, onChanged: (val) => setState(() => _paymentMethod = val.toString())),
          RadioListTile(title: const Text("Midtrans"), value: 'midtrans', groupValue: _paymentMethod, onChanged: (val) => setState(() => _paymentMethod = val.toString())),
          
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _processOrder, child: const Text("BUAT PESANAN"))),
        ]),
      ),
    );
  }
}