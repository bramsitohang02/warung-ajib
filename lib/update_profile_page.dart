import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart'; // Import SharedPrefs

class UpdateProfilePage extends StatefulWidget {
  const UpdateProfilePage({super.key});

  @override
  State<UpdateProfilePage> createState() => _UpdateProfilePageState();
}

class _UpdateProfilePageState extends State<UpdateProfilePage> {
  final TextEditingController _namaController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  bool _isLoading = true;
  final String _baseUrl = 'https://warungajibuas.my.id/warung_api_uas'; 

  // Variabel untuk menyimpan ID User yang sedang login
  String _currentUserId = "";

  @override
  void initState() {
    super.initState();
    _loadSession(); // Langkah 1: Cari tahu siapa saya
  }

  // 1. Ambil ID dari Shared Preferences
  Future<void> _loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentUserId = prefs.getString('id_user') ?? "";
    });

    if (_currentUserId.isNotEmpty) {
      _fetchUserData(); // Langkah 2: Ambil data dari database
    } else {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Sesi login tidak ditemukan, silakan login ulang."))
      );
    }
  }

  // 2. Ambil Data User dari Database
  Future<void> _fetchUserData() async {
    try {
      // Gunakan _currentUserId yang didapat dari Login
      final response = await http.get(Uri.parse('$_baseUrl/get_user.php?id=$_currentUserId'));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['nama'] != null) {
          setState(() {
            _namaController.text = data['nama'];
            _emailController.text = data['email'];
            _passwordController.text = data['password'];
          });
        }
      }
    } catch (e) {
      print("Error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // 3. Proses Update
  Future<void> _updateProfile() async {
    if (_currentUserId.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/update_user.php'),
        body: {
          "id": _currentUserId, // Gunakan ID Dinamis
          "nama": _namaController.text,
          "email": _emailController.text,
          "password": _passwordController.text,
        },
      );

      final data = jsonDecode(response.body);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(data['message']))
      );

      if (data['success'] == true) {
        // Update juga nama di sesi lokal biar sinkron
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('nama_user', _namaController.text);
        
        Navigator.pop(context); 
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Update Profil"),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Icon(Icons.account_circle, size: 100, color: Colors.blue),
                  const SizedBox(height: 20),
                  
                  TextFormField(
                    controller: _namaController,
                    decoration: const InputDecoration(labelText: "Nama Lengkap", border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 15),

                  TextFormField(
                    controller: _emailController,
                    readOnly: true, 
                    decoration: const InputDecoration(
                      labelText: "Email (Tidak bisa diubah)", 
                      border: OutlineInputBorder(),
                      fillColor: Colors.black12,
                      filled: true
                    ),
                  ),
                  const SizedBox(height: 15),

                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(labelText: "Password", border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 30),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _updateProfile,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                      child: const Text("SIMPAN PERUBAHAN", style: TextStyle(color: Colors.white, fontSize: 16)),
                    ),
                  )
                ],
              ),
            ),
    );
  }
}