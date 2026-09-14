import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart'; 
import 'package:project_uas/login_page.dart';
import 'package:project_uas/checkout_page.dart';
import 'package:project_uas/riwayat_page.dart';
import 'package:project_uas/update_profile_page.dart';
import 'package:project_uas/product_detail_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  List _products = [];
  bool _isLoading = true;
  List<Map<String, dynamic>> _cart = [];
  int _totalJual = 0;

  // Pastikan IP Address Sesuai dengan Ngrok Anda
  final String _baseUrl = 'https://warungajibuas.my.id/warung_api_uas';

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/read.php'));
      if (response.statusCode == 200) {
        setState(() {
          _products = jsonDecode(response.body);
        });
      } else {
        print("Gagal mengambil data: ${response.statusCode}");
      }
    } catch (e) {
      print("Error Fetch Products: $e");
    } finally {
      // PERBAIKAN PENTING: Matikan loading apapun hasilnya (Sukses/Gagal)
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _addToCart(Map product) {
    setState(() {
      String nama = product['nmbrg'] ?? 'Produk';
      // Safety parsing untuk harga (biar tidak error jika data string/int)
      int harga = int.tryParse(product['hrgjual']?.toString() ?? '0') ?? 0;
      int berat = 1000;
      String gambar = product['gambar'] ?? '';

      _cart.add({
        'id': product['id'],
        'nama_barang': nama,
        'harga': harga,
        'berat': berat,
        'gambar': gambar
      });
      _totalJual += harga;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("${product['nmbrg']} masuk keranjang!"),
        duration: const Duration(milliseconds: 500)));
  }

  // --- LOGIKA MENU LENGKAP ---
  Future<void> _handleMenu(String value) async {
    if (value == 'Logout') {
      // Clear session (Opsional jika pakai SharedPreferences)
      // final prefs = await SharedPreferences.getInstance();
      // await prefs.clear();
      
      if (!mounted) return;
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (context) => const LoginPage()));
    } else if (value == 'Riwayat') {
      Navigator.push(context,
          MaterialPageRoute(builder: (context) => const RiwayatPage()));
    } else if (value == 'Update User') {
      Navigator.push(context,
          MaterialPageRoute(builder: (context) => const UpdateProfilePage()));
    } else {
      // --- LOGIKA CALL / SMS / MAPS ---
      Uri url;
      
      if (value == 'Call Center') {
        url = Uri.parse("tel:08123456789"); 
      } else if (value == 'SMS Center') {
        url = Uri.parse("sms:08123456789"); 
      } else if (value == 'Lokasi') {
        url = Uri.parse("https://maps.google.com/?q=-6.9823797,110.4095627"); // Contoh koordinat Semarang
      } else {
        return;
      }

      try {
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        } else {
          throw 'Could not launch $url';
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Gagal membuka fitur $value: $e")));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text("Warung Ajib"),
          backgroundColor: Colors.orange[800],
          foregroundColor: Colors.white, 
          actions: [
            // --- POPUP MENU (TITIK TIGA) ---
            PopupMenuButton<String>(
              onSelected: _handleMenu,
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'Riwayat', child: Text("Riwayat Belanja")),
                const PopupMenuItem(value: 'Call Center', child: Text("Call Center")),
                const PopupMenuItem(value: 'SMS Center', child: Text("SMS Center")),
                const PopupMenuItem(value: 'Lokasi', child: Text("Lokasi / Maps")),
                const PopupMenuItem(value: 'Update User', child: Text("Update User & Password")),
                const PopupMenuItem(value: 'Logout', child: Text("Logout")),
              ],
            ),
          ]),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _products.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.shopping_bag_outlined, size: 80, color: Colors.grey),
                    const SizedBox(height: 10),
                    const Text("Tidak ada produk / Gagal koneksi server", style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: _fetchProducts, 
                      child: const Text("Coba Lagi")
                    )
                  ],
                ),
              )
            : Column(
              children: [
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(10),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.75,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10),
                    itemCount: _products.length,
                    itemBuilder: (context, index) {
                      final product = _products[index];
                      String gambar = product['gambar'] ?? '';
                      String imageUrl = "$_baseUrl/gambar/$gambar"; // Sesuaikan folder uploads di server

                      return Card(
                        elevation: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => _addToCart(product),
                                child: Image.network(
                                  imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (ctx, err, stack) => Container(
                                    color: Colors.grey[200],
                                    child: const Center(
                                        child: Icon(Icons.broken_image,
                                            size: 40, color: Colors.grey)),
                                  ),
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: () async {
                                // Pastikan ProductDetailPage Anda menerima parameter ini
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ProductDetailPage(
                                      product: product,
                                      // Hapus baris di bawah jika ProductDetailPage tidak butuh baseUrl
                                      baseUrl: _baseUrl, 
                                    ),
                                  ),
                                );

                                if (result == true) {
                                  _addToCart(product);
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(product['nmbrg'] ?? '-',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                    Text("Rp ${product['hrgjual']}",
                                        style: const TextStyle(
                                            color: Colors.deepOrange)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                // --- KERANJANG BAWAH ---
                InkWell(
                  onTap: () async {
                    if (_cart.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Keranjang kosong")));
                      return;
                    }

                    final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => CheckoutPage(
                                productTotal: _totalJual, cartItems: _cart)));

                    if (result == true) {
                      setState(() {
                        _cart.clear(); 
                        _totalJual = 0; 
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Transaksi Selesai")));
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    color: Colors.orange[800],
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Total Penjualan:",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold)),
                          Text("Rp $_totalJual",
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold)),
                        ]),
                  ),
                ),
              ],
            ),
    );
  }
}