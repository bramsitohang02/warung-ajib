import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:project_uas/dashboard_page.dart';
import 'package:project_uas/admin/admin_dashboard_page.dart';
import 'package:project_uas/register_page.dart';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  bool _isLoading = false; 

  final String _baseUrl = 'https://warungajibuas.my.id/warung_api_uas';

  @override
  void initState() {
    super.initState();
    _initializeGoogleSignIn();
  }

  // --- INISIALISASI GOOGLE SIGN IN ---
  Future<void> _initializeGoogleSignIn() async {
    try {
      await GoogleSignIn.instance.initialize();
    } catch (e) {
      print("Error initializing Google Sign-In: $e");
    }
  }

  // --- FUNGSI LOGIN GOOGLE (VERSI 7.x FINAL) ---
  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    
    try {
      GoogleSignInAccount googleUser;
      
      // Gunakan authenticate() untuk versi 7.x
      if (GoogleSignIn.instance.supportsAuthenticate()) {
        googleUser = await GoogleSignIn.instance.authenticate();
      } else {
        throw Exception("Platform tidak support Google Sign-In");
      }
      
      // Dapatkan idToken
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      // Login ke Firebase (HANYA pakai idToken, tanpa accessToken)
      if (googleAuth.idToken != null) {
        final AuthCredential credential = GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
          // TIDAK pakai accessToken karena tidak ada di versi 7.x
        );

        UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
        User? user = userCredential.user;

        if (user != null) {
          await _loginGoogleToMyServer(
            user.email!, 
            user.displayName ?? "User Google", 
            user.photoURL ?? ""
          );
        }
      } else {
        throw Exception("Gagal mendapatkan ID Token Google");
      }

    } on GoogleSignInException catch (e) {
      print("GoogleSignInException: ${e.code}");
      if (!mounted) return;
      
      String errorMessage = "Gagal Login Google: ${e.code}";
      
      // Berikan petunjuk jika error konfigurasi
      if (e.code == GoogleSignInExceptionCode.clientConfigurationError) {
        errorMessage = """
Error Konfigurasi Google Sign-In!

""";
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          duration: const Duration(seconds: 8),
        )
      );
    } catch (e) {
      print("Error Google: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal Login Google: $e"))
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- LOGIN KE DATABASE SENDIRI VIA PHP ---
  Future<void> _loginGoogleToMyServer(String email, String nama, String foto) async {
    try {
      final response = await http.post(
        Uri.parse("$_baseUrl/login_google.php"),
        body: {
          "email": email,
          "nama": nama,
          "foto": foto, 
        },
      );

      final data = jsonDecode(response.body);

      if (data['success'] == true) {
        String id = data['id'];
        String role = 'user';

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('id_user', id); 
        await prefs.setString('nama_user', nama);
        await prefs.setString('role_user', role);
        await prefs.setBool('is_login', true);

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const DashboardPage()),
        );
      } else {
        throw Exception(data['message']);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error Server: $e"))
      );
    }
  }

  // --- LOGIN BIASA (MANUAL) ---
  Future<void> _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Email dan Password harus diisi!"))
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse("$_baseUrl/login.php"),
        body: {
          "email": _emailController.text,
          "password": _passwordController.text,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['success'] == true) {
          String id = data['id'];
          String nama = data['nama'];
          String role = data['role'] ?? 'user';

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('id_user', id); 
          await prefs.setString('nama_user', nama);
          await prefs.setString('role_user', role);
          await prefs.setBool('is_login', true);

          if (!mounted) return;
          
          if (role == 'admin') {
            Navigator.pushReplacement(
              context, 
              MaterialPageRoute(builder: (context) => const AdminDashboardPage())
            );
          } else {
            Navigator.pushReplacement(
              context, 
              MaterialPageRoute(builder: (context) => const DashboardPage())
            );
          }
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Gagal: ${data['message']}"))
          );
        }
      } 
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error Koneksi: $e"))
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Login User")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Image.asset(
              'assets/images/logo_icon.png', 
              height: 100, 
              width: 100,
            ),
            
            const SizedBox(height: 20),
            const Text("WARUNG AJIB", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 30),
            
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: "Email", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 15),
            
            TextFormField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: "Password", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 25),
            
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _login,
                child: _isLoading 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("MASUK"),
              ),
            ),
            const SizedBox(height: 15),
            
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : _handleGoogleSignIn,
                icon: Image.asset('assets/images/google_logo.png', height: 24),
                label: const Text("Masuk dengan Google"),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.grey),
                ),
              ),
            ),
            const SizedBox(height: 15),
            
            TextButton(
              onPressed: () {
                Navigator.push(
                  context, 
                  MaterialPageRoute(builder: (context) => const RegisterPage())
                );
              },
              child: const Text("Belum punya akun? Daftar disini"),
            ),
          ],
        ),
      ),
    );
  }
}
