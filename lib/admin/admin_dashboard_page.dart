import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:project_uas/login_page.dart';
import 'package:project_uas/product_form_page.dart';
import 'package:project_uas/admin/laporan_page.dart';
import 'package:project_uas/admin/konsumen_page.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  List _products = [];
  bool _isLoading = true;
  
  // Pastikan IP Address Sesuai
  final String _baseUrl = 'https://warungajibuas.my.id/warung_api_uas';

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  // Ambil Data Produk
  Future<void> _fetchProducts() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(Uri.parse('$_baseUrl/read.php'));
      if (response.statusCode == 200) {
        setState(() {
          _products = jsonDecode(response.body);
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error: $e");
    }
  }

  // Fungsi Hapus Produk
  Future<void> _deleteProduct(String id) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/delete.php'),
        body: {"id": id},
      );
      final data = jsonDecode(response.body);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(data['message']))
      );

      if (data['success'] == true) {
        _fetchProducts(); // Refresh list setelah hapus
      }
    } catch (e) {
      print("Error Delete: $e");
    }
  }

  // Konfirmasi Hapus
  void _confirmDelete(String id, String nama) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Hapus Produk?"),
        content: Text("Yakin ingin menghapus $nama?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Batal")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              _deleteProduct(id);
            }, 
            child: const Text("Hapus", style: TextStyle(color: Colors.white))
          )
        ],
      ),
    );
  }

  // Menu Logout
  void _logout() {
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginPage()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Dashboard"),
        backgroundColor: Colors.red[700], 
        foregroundColor: Colors.white,
        actions: [
          // --- TOMBOL LAPORAN (BARU) ---
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: "Laporan Penjualan",
            onPressed: () {
              Navigator.push(
                context, 
                MaterialPageRoute(builder: (context) => const LaporanPage())
              );
            },
          ),

          IconButton(
            icon: const Icon(Icons.people), // Icon Orang
            tooltip: "Kelola Konsumen",
            onPressed: () {
              Navigator.push(
                context, 
                MaterialPageRoute(builder: (context) => const KonsumenPage())
              );
            },
          ),
          
          // Tombol Logout
          IconButton(onPressed: _logout, icon: const Icon(Icons.logout))
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(10),
              itemCount: _products.length,
              itemBuilder: (context, index) {
                final product = _products[index];
                return Card(
                  elevation: 3,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.red[100],
                      backgroundImage: NetworkImage("$_baseUrl/gambar/${product['gambar']}"),
                      onBackgroundImageError: (exception, stackTrace) => const Icon(Icons.broken_image),
                      child: product['gambar'] == null ? const Icon(Icons.inventory) : null,
                    ),
                    title: Text(product['nmbrg'] ?? 'Tanpa Nama', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text("Rp ${product['hrgjual']} | Stok: ${product['stok']}"),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // TOMBOL EDIT
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () async {
                            await Navigator.push(
                              context, 
                              MaterialPageRoute(builder: (context) => ProductFormPage(product: product))
                            );
                            _fetchProducts(); 
                          },
                        ),
                        // TOMBOL HAPUS
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _confirmDelete(product['id'], product['nmbrg']),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      // TOMBOL TAMBAH PRODUK (+)
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.red[700],
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () async {
          await Navigator.push(
            context, 
            MaterialPageRoute(builder: (context) => const ProductFormPage())
          );
          _fetchProducts(); 
        },
      ),
    );
  }
}