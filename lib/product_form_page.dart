import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart'; // Plugin Kamera/Galeri

class ProductFormPage extends StatefulWidget {
  final Map? product; // Jika null = Mode Tambah, Jika ada isi = Mode Edit

  const ProductFormPage({super.key, this.product});

  @override
  State<ProductFormPage> createState() => _ProductFormPageState();
}

class _ProductFormPageState extends State<ProductFormPage> {
  final _formKey = GlobalKey<FormState>();
  
  // Controller Input Teks
  final TextEditingController _namaController = TextEditingController();
  final TextEditingController _hargaController = TextEditingController();
  final TextEditingController _stokController = TextEditingController();
  final TextEditingController _deskripsiController = TextEditingController();
  
  // Variabel untuk Gambar
  File? _imageFile; // Menyimpan file gambar dari HP
  final ImagePicker _picker = ImagePicker();
  
  // IP Address
  final String _baseUrl = 'https://warungajibuas.my.id/warung_api_uas'; 
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Jika Mode Edit, isi form dengan data yang sudah ada
    if (widget.product != null) {
      _namaController.text = widget.product!['nmbrg'];
      _hargaController.text = widget.product!['hrgjual'].toString();
      _stokController.text = widget.product!['stok'].toString();
      _deskripsiController.text = widget.product!['deskripsi'] ?? '';
    }
  }

  // Fungsi Membuka Galeri atau Kamera
  Future<void> _pickImage(ImageSource source) async {
    final XFile? picked = await _picker.pickImage(source: source);
    if (picked != null) {
      setState(() {
        _imageFile = File(picked.path);
      });
    }
  }

  // Fungsi Simpan Data (Multipart Request)
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      // Gunakan MultipartRequest karena kita kirim File
      var request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/product_action.php'));
      
      // Tentukan ini Create atau Update
      String action = widget.product == null ? 'create' : 'update';
      request.fields['action'] = action;

      // Masukkan Data Teks
      request.fields['nm_brg'] = _namaController.text;
      request.fields['harga'] = _hargaController.text;
      request.fields['stok'] = _stokController.text;
      request.fields['deskripsi'] = _deskripsiController.text;

      // Jika Edit, kirim ID produk dan Nama Gambar Lama (sebagai cadangan jika tidak ganti foto)
      if (widget.product != null) {
        request.fields['id'] = widget.product!['id'].toString();
        request.fields['old_image'] = widget.product!['gambar'] ?? '';
      }

      // Masukkan File Gambar (Jika User memilih gambar baru)
      if (_imageFile != null) {
        request.files.add(await http.MultipartFile.fromPath('image', _imageFile!.path));
      }

      // Kirim ke Server
      var response = await request.send();
      var responseData = await response.stream.bytesToString();
      var data = jsonDecode(responseData);

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'])));

      if (data['success'] == true) {
        Navigator.pop(context); // Kembali ke Dashboard Admin
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    String title = widget.product == null ? "Tambah Produk" : "Edit Produk";

    return Scaffold(
      appBar: AppBar(
        title: Text(title), 
        backgroundColor: Colors.red[700], 
        foregroundColor: Colors.white
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // --- AREA PILIH GAMBAR (BARU) ---
              GestureDetector(
                onTap: () {
                  // Munculkan pilihan Kamera / Galeri
                  showModalBottomSheet(
                    context: context, 
                    builder: (ctx) => Wrap(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.camera_alt), 
                          title: const Text("Kamera"), 
                          onTap: () { Navigator.pop(ctx); _pickImage(ImageSource.camera); }
                        ),
                        ListTile(
                          leading: const Icon(Icons.photo), 
                          title: const Text("Galeri"), 
                          onTap: () { Navigator.pop(ctx); _pickImage(ImageSource.gallery); }
                        ),
                      ],
                    )
                  );
                },
                child: Container(
                  height: 180, 
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[200], 
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(10)
                  ),
                  // Logika Tampilan Gambar:
                  // 1. Jika user pilih gambar baru dari HP -> Tampilkan
                  // 2. Jika mode Edit & ada gambar di server -> Tampilkan dari Server
                  // 3. Jika kosong -> Tampilkan Icon Tambah
                  child: _imageFile != null 
                    ? Image.file(_imageFile!, fit: BoxFit.cover) 
                    : (widget.product != null && widget.product!['gambar'] != '')
                        ? Image.network(
                            "$_baseUrl/gambar/${widget.product!['gambar']}", 
                            fit: BoxFit.cover,
                            errorBuilder: (ctx, err, stack) => const Icon(Icons.broken_image),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.add_a_photo, size: 50, color: Colors.grey),
                              Text("Ketuk untuk upload foto")
                            ],
                          ),
                ),
              ),
              const SizedBox(height: 10),
              const Text("Pastikan orientasi gambar Portrait/Kotak agar rapi", style: TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 20),

              // --- FORM INPUT ---
              TextFormField(
                controller: _namaController,
                decoration: const InputDecoration(labelText: "Nama Barang", border: OutlineInputBorder()),
                validator: (val) => val!.isEmpty ? "Harus diisi" : null,
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _hargaController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Harga", border: OutlineInputBorder()),
                validator: (val) => val!.isEmpty ? "Harus diisi" : null,
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _stokController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Stok", border: OutlineInputBorder()),
                validator: (val) => val!.isEmpty ? "Harus diisi" : null,
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _deskripsiController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: "Deskripsi", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 30),
              
              // --- TOMBOL SIMPAN ---
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700]),
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("SIMPAN PRODUK", style: TextStyle(color: Colors.white, fontSize: 18)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}