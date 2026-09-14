import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class KonsumenPage extends StatefulWidget {
  const KonsumenPage({super.key});

  @override
  State<KonsumenPage> createState() => _KonsumenPageState();
}

class _KonsumenPageState extends State<KonsumenPage> {
  List _users = [];
  bool _isLoading = true;

  // Sesuaikan IP Laptop Anda
  final String _baseUrl = 'https://warungajibuas.my.id/warung_api_uas';

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(Uri.parse('$_baseUrl/read_users.php'));
      if (response.statusCode == 200) {
        setState(() {
          _users = jsonDecode(response.body);
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error: $e");
    }
  }

  Future<void> _deleteUser(String id) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/delete_user.php'),
        body: {"id": id},
      );
      final data = jsonDecode(response.body);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(data['message']))
      );

      if (data['success'] == true) {
        _fetchUsers(); // Refresh list
      }
    } catch (e) {
      print("Error: $e");
    }
  }

  void _confirmDelete(String id, String nama) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Hapus User?"),
        content: Text("Yakin ingin menghapus $nama? Data belanjaan mereka mungkin akan error."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Batal")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              _deleteUser(id);
            }, 
            child: const Text("Hapus", style: TextStyle(color: Colors.white))
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Kelola Konsumen"),
        backgroundColor: Colors.red[700],
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _users.isEmpty
              ? const Center(child: Text("Belum ada konsumen"))
              : ListView.builder(
                  itemCount: _users.length,
                  itemBuilder: (context, index) {
                    final user = _users[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue[100],
                          child: Text(user['nama'][0].toUpperCase()), // Inisial Nama
                        ),
                        title: Text(user['nama'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user['email']),
                            if(user['telp'] != null) Text(user['telp']),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _confirmDelete(user['id'], user['nama']),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}