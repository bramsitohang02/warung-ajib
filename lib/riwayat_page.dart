import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart'; 
import 'package:shared_preferences/shared_preferences.dart';

// --- IMPORT UNTUK PDF (Sama seperti Checkout) ---
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class RiwayatPage extends StatefulWidget {
  const RiwayatPage({super.key});

  @override
  State<RiwayatPage> createState() => _RiwayatPageState();
}

class _RiwayatPageState extends State<RiwayatPage> {
  List _history = [];
  bool _isLoading = true;
  File? _selectedImage; 
  
  // Link Ngrok Static Anda (Update jika perlu)
  final String _baseUrl = 'https://warungajibuas.my.id/warung_api_uas';

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString('id_user');

    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final response = await http.get(Uri.parse('$_baseUrl/history.php?id_user=$userId'));
      if (response.statusCode == 200) {
        setState(() {
          _history = jsonDecode(response.body);
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error: $e");
      setState(() => _isLoading = false);
    }
  }

  // --- LOGIKA CETAK NOTA (BARU) ---
  Future<void> _fetchAndPrintNota(String idJual, String totalBayarStr) async {
    // 1. Ambil Detail Barang dari Server
    try {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Menyiapkan Nota...")));
      
      final response = await http.get(Uri.parse('$_baseUrl/get_detail.php?id_jual=$idJual'));
      final List items = jsonDecode(response.body);

      // 2. Generate PDF
      final doc = pw.Document();
      final currency = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);
      
      // Konversi total bayar ke int
      int grandTotal = int.tryParse(totalBayarStr) ?? 0;
      String tanggal = DateFormat('dd-MM-yyyy HH:mm').format(DateTime.now());

      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.roll80, 
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text("WARUNG AJIB", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18)),
                pw.Text("REPRINT NOTA", style: const pw.TextStyle(fontSize: 10)),
                pw.Divider(),
                pw.Text("NOTA PEMBELIAN", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text("No: #$idJual"),
                pw.Text(tanggal),
                pw.Divider(),
                
                // List Barang dari Database
                ...items.map((item) {
                  int harga = int.tryParse(item['harga'].toString()) ?? 0;
                  return pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Expanded(child: pw.Text(item['nm_brg'], style: const pw.TextStyle(fontSize: 10))),
                      pw.Text(currency.format(harga), style: const pw.TextStyle(fontSize: 10)),
                    ]
                  );
                }).toList(),
                
                pw.Divider(),
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

    } catch (e) {
      print("Gagal cetak: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal cetak: $e")));
    }
  }

  Future<void> _pickImage(String idJual) async {
    final returnedImage = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (returnedImage != null) {
      setState(() => _selectedImage = File(returnedImage.path));
      _uploadBukti(idJual); 
    }
  }

  Future<void> _uploadBukti(String idJual) async {
    if (_selectedImage == null) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sedang mengupload...")));
    try {
      var request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/upload_bukti.php'));
      request.fields['id_jual'] = idJual;
      request.files.add(await http.MultipartFile.fromPath('image', _selectedImage!.path));
      var response = await request.send();
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Berhasil Upload!")));
        _fetchHistory(); 
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Gagal Upload")));
      }
    } catch (e) {
      print("Error upload: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Riwayat Belanja")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _history.isEmpty
              ? const Center(child: Text("Belum ada transaksi"))
              : ListView.builder(
                  itemCount: _history.length,
                  itemBuilder: (context, index) {
                    final item = _history[index];
                    String status = item['status'];
                    String metode = item['metode'];
                    String? bukti = item['bukti_bayar'];
                    String idJual = item['id_jual'].toString();
                    String total = item['total_bayar'].toString();

                    return Card(
                      margin: const EdgeInsets.all(10),
                      elevation: 3,
                      child: Padding(
                        padding: const EdgeInsets.all(15.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("Order #$idJual", style: const TextStyle(fontWeight: FontWeight.bold)),
                                
                                // --- TOMBOL PRINT (POJOK KANAN ATAS) ---
                                IconButton(
                                  icon: const Icon(Icons.print, color: Colors.blue),
                                  onPressed: () => _fetchAndPrintNota(idJual, total),
                                  tooltip: "Cetak Nota",
                                ),
                              ],
                            ),
                            Text(item['tgl_jual'], style: const TextStyle(color: Colors.grey)),
                            const Divider(),
                            Text("Total: Rp $total", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            Text("Metode: $metode"),
                            const SizedBox(height: 10),
                            
                            // Badge Status
                            Row(
                              children: [
                                const Text("Status: "),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: status == 'pending' ? Colors.orange : Colors.green,
                                    borderRadius: BorderRadius.circular(5)
                                  ),
                                  child: Text(
                                    status.toUpperCase(), 
                                    style: const TextStyle(color: Colors.white, fontSize: 12)
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 15),

                            // Tombol Upload (Hanya jika Transfer Manual & Belum ada bukti)
                            if (metode == 'manual' && (bukti == null || bukti.isEmpty))
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () => _pickImage(idJual),
                                  icon: const Icon(Icons.upload_file),
                                  label: const Text("UPLOAD BUKTI TRANSFER"),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[800], foregroundColor: Colors.white),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}