import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart'; 

import 'firebase_options.dart';
import 'provider/auth_provider.dart' as local_auth;
import 'provider/imagepick_provider.dart';
import 'notification_service.dart';

import 'screen/welcome.dart';
import 'screen/about_screen.dart';
import 'screen/login_screen.dart';
import 'screen/home_page.dart';
import 'screen/volume_page.dart';
import 'screen/monitoring_screen.dart';
import 'screen/controlling_screen.dart';
import 'screen/billing_screen.dart';
import 'screen/node_screen.dart';
import 'screen/admin/admin_navigation.dart';

void main() async {
  // Pastikan widget Flutter diinisialisasi sebelum Firebase.
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // PERBAIKAN: Tambahkan baris ini untuk memuat data format tanggal Indonesia
  await initializeDateFormatting('id_ID', null);

  // Inisialisasi layanan notifikasi
  NotificationService.initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => local_auth.AuthProvider()),
        ChangeNotifierProvider(create: (_) => ImagePickProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'SIGOPAL',
        theme: ThemeData.dark().copyWith(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.teal,
            brightness: Brightness.dark,
          ),
        ),
        // PERUBAHAN: Rute awal diarahkan ke welcome, lalu ke checkauth
        initialRoute: '/welcome',
        routes: {
          '/welcome': (context) => const WelcomeScreen(),
          '/about': (context) => const AboutPage(),
          '/checkauth': (context) => const AuthWrapper(),
          '/login': (context) => const LoginScreen(),
          '/home': (context) => const HomePage(),
          '/volume': (context) => const VolumePage(),
          '/monitoring': (context) => const MonitoringScreen(),
          '/controlling': (context) => const ControllingScreen(),
          '/billing': (context) => const BillingScreen(),
          '/node_screen': (context) => const NodeScreen(),
          // PERUBAHAN: Tambahkan rute untuk admin
          '/admin_home': (context) => const AdminNavigation(),
        },
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // PERUBAHAN: Menggunakan Consumer untuk mendapatkan data role dari AuthProvider
    final authProvider = Provider.of<local_auth.AuthProvider>(context);
    
    return StreamBuilder<firebase_auth.User?>(
      stream: firebase_auth.FirebaseAuth.instance.authStateChanges(),
      builder: (ctx, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData && snapshot.data!.emailVerified) {
          // User sudah login dan verifikasi email
          // Cek apakah data user (termasuk role) sudah diinisialisasi
          if (!authProvider.isUserInitialized) {
            // Jika belum, tampilkan loading sambil AuthProvider mengambil data
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          
          // Jika data sudah ada, arahkan berdasarkan role
          if (authProvider.isAdmin) {
            // Jika admin, langsung ke halaman admin
            return const AdminNavigation();
          } else {
            // Jika user biasa, lanjutkan ke alur verifikasi node
            return const NodeScreen();
          }
        }

        // Jika user belum login atau email belum diverifikasi, arahkan ke LoginScreen
        return const LoginScreen();
      },
    );
  }
}