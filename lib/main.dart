import 'package:flutter/material.dart';
// IMPORT WAJIB FIREBASE
import 'package:firebase_core/firebase_core.dart';

// Pastikan import ini sesuai dengan nama project Anda
import 'package:project_uas/splash_screen.dart';

// UBAH JADI ASYNC UNTUK MENUNGGU FIREBASE
void main() async {
  // 1. Wajib dipanggil agar Flutter siap sebelum menjalankan kode native
  WidgetsFlutterBinding.ensureInitialized(); 

  // 2. Inisialisasi Firebase
  try {
    await Firebase.initializeApp();
    print("Firebase Berhasil Terhubung!");
  } catch (e) {
    print("Error Inisialisasi Firebase: $e");
  }

  // 3. Jalankan Aplikasi
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // --- SETTING WARNA (Sesuai kode Anda) ---
    final Color colorUtama = const Color(0xFFE45518); 
    final Color colorAksen = const Color(0xFFFFC107); 

    return MaterialApp(
      title: 'Warung Ajib',
      debugShowCheckedModeBanner: false,
      
      // --- TEMA APLIKASI ---
      theme: ThemeData(
        // Skema warna utama
        colorScheme: ColorScheme.fromSeed(
          seedColor: colorUtama,
          primary: colorUtama,
          secondary: colorAksen,
        ),

        // Tema AppBar
        appBarTheme: AppBarTheme(
          backgroundColor: colorUtama,
          foregroundColor: Colors.white,
          elevation: 4.0,
          centerTitle: true,
        ),

        // Tema ElevatedButton
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: colorUtama,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          ),
        ),

        // Tema Card
        cardTheme: CardThemeData( 
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          clipBehavior: Clip.antiAlias,
        ),

        // Tema Input Field
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide(color: colorUtama, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        ),

        // Aktifkan Material 3
        useMaterial3: true,
      ),
      
      home: const SplashScreen(),
    );
  }
}