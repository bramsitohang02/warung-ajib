import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class LaporanPage extends StatefulWidget {
  const LaporanPage({super.key});

  @override
  State<LaporanPage> createState() => _LaporanPageState();
}

class _LaporanPageState extends State<LaporanPage> {
  List _laporan = [];
  bool _isLoading = true;
  
  // Filter Tanggal
  DateTime? _tglAwal;
  DateTime? _tglAkhir;

  // IP Address (Update jika berubah)
  final String _baseUrl = 'https://warungajibuas.my.id/warung_api_uas';

  @override
  void initState() {
    super.initState();
    _fetchLaporan(); // Load data global saat pertama buka
  }

  // 1. Ambil Data dari API
  Future<void> _fetchLaporan() async {
    setState(() => _isLoading = true);
    try {
      String url = '$_baseUrl/laporan.php';
      
      // Jika filter tanggal aktif, tambahkan parameter
      if (_tglAwal != null && _tglAkhir != null) {
        String start = DateFormat('yyyy-MM-dd').format(_tglAwal!);
        String end = DateFormat('yyyy-MM-dd').format(_tglAkhir!);
        url += '?tgl_awal=$start&tgl_akhir=$end';
      }

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        setState(() {
          _laporan = jsonDecode(response.body);
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error: $e");
      setState(() => _isLoading = false);
    }
  }

  // 2. Fungsi Pilih Tanggal
  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isStart) _tglAwal = picked;
        else _tglAkhir = picked;
      });
    }
  }

  // 3. FUNGSI UTAMA: GENERATE PDF
  Future<void> _cetakPdf() async {
    final doc = pw.Document();
    
    // Hitung Total Pendapatan
    int grandTotal = 0;
    for (var item in _laporan) {
      grandTotal += int.parse(item['total_bayar'].toString());
    }

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // HEADER PDF
              pw.Text("LAPORAN PENJUALAN WARUNG AJIB", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 20)),
              pw.SizedBox(height: 5),
              pw.Text("Periode: ${_tglAwal != null ? DateFormat('dd/MM/yyyy').format(_tglAwal!) : 'Awal'} s/d ${_tglAwal != null ? DateFormat('dd/MM/yyyy').format(_tglAkhir!) : 'Sekarang'}"),
              pw.Divider(),
              pw.SizedBox(height: 10),

              // TABEL DATA
              pw.Table.fromTextArray(
                headers: ['No', 'Tanggal', 'Pelanggan', 'Metode', 'Status', 'Total'],
                data: List<List<dynamic>>.generate(
                  _laporan.length,
                  (index) {
                    final item = _laporan[index];
                    return [
                      (index + 1).toString(),
                      item['tgl_jual'],
                      item['nama_user'],
                      item['metode_pembayaran'],
                      item['status'],
                      NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(int.parse(item['total_bayar'])),
                    ];
                  },
                ),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blue),
                rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300))),
                cellAlignments: {
                  0: pw.Alignment.center,
                  5: pw.Alignment.centerRight,
                }
              ),
              
              pw.SizedBox(height: 20),
              
              // TOTAL BAWAH
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Text("GRAND TOTAL: ", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
                  pw.Text(
                    NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(grandTotal),
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16, color: PdfColors.red)
                  ),
                ]
              )
            ],
          );
        },
      ),
    );

    // Buka Preview PDF
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Laporan Penjualan"), backgroundColor: Colors.red[700], foregroundColor: Colors.white),
      body: Column(
        children: [
          // FILTER AREA
          Card(
            margin: const EdgeInsets.all(10),
            child: Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.date_range),
                          label: Text(_tglAwal == null ? "Tgl Awal" : DateFormat('dd/MM/yy').format(_tglAwal!)),
                          onPressed: () => _pickDate(true),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text("s/d"),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.date_range),
                          label: Text(_tglAkhir == null ? "Tgl Akhir" : DateFormat('dd/MM/yy').format(_tglAkhir!)),
                          onPressed: () => _pickDate(false),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                      onPressed: _fetchLaporan,
                      child: const Text("TAMPILKAN DATA", style: TextStyle(color: Colors.white)),
                    ),
                  )
                ],
              ),
            ),
          ),

          // LIST DATA
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator()) 
              : _laporan.isEmpty 
                  ? const Center(child: Text("Tidak ada data penjualan"))
                  : ListView.builder(
                      itemCount: _laporan.length,
                      itemBuilder: (context, index) {
                        final item = _laporan[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.green[100],
                              child: Text((index+1).toString()),
                            ),
                            title: Text("${item['nama_user']} (${item['tgl_jual']})"),
                            subtitle: Text("${item['metode_pembayaran']} - ${item['status']}"),
                            trailing: Text(
                              "Rp ${item['total_bayar']}",
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                            ),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
      
      // TOMBOL CETAK PDF
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _laporan.isEmpty ? null : _cetakPdf,
        backgroundColor: Colors.red[700],
        icon: const Icon(Icons.print, color: Colors.white),
        label: const Text("CETAK PDF", style: TextStyle(color: Colors.white)),
      ),
    );
  }
}