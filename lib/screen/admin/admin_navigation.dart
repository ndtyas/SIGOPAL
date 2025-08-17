import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sigopal/provider/auth_provider.dart' as custom_auth;
import 'admin_accounts_screen.dart';
import 'admin_billing_screen.dart';
import 'admin_monitoring_screen.dart';

class AdminNavigation extends StatefulWidget {
  const AdminNavigation({super.key});

  @override
  State<AdminNavigation> createState() => _AdminNavigationState();
}

class _AdminNavigationState extends State<AdminNavigation> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const AdminAccountsScreen(),
    const AdminBillingScreen(),
    const AdminMonitoringScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer<custom_auth.AuthProvider>(
      builder: (context, auth, child) {
        if (!auth.isAdmin) {
          // Redirect ke login jika bukan admin
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.of(context).pushReplacementNamed('/login');
            }
          });
          
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        return Scaffold(
          body: IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            selectedItemColor: Colors.white,
            unselectedItemColor: Colors.white70,
            backgroundColor: const Color.fromARGB(255, 11, 58, 70),
            type: BottomNavigationBarType.fixed,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.people),
                label: 'Akun Pengguna',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.receipt_long),
                label: 'Riwayat Tagihan',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.monitor_heart),
                label: 'Pemantauan',
              ),
            ],
          ),
          drawer: _buildAdminDrawer(context, auth),
        );
      },
    );
  }

  Widget _buildAdminDrawer(BuildContext context, custom_auth.AuthProvider auth) {
    final user = FirebaseAuth.instance.currentUser;
    
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.fromARGB(255, 11, 58, 70),
                  Color.fromARGB(255, 98, 195, 208),
                ],
              ),
            ),
            accountName: Text(
              user?.displayName ?? 'Admin',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            accountEmail: Text(
              user?.email ?? 'admin@sigopal.com',
              style: const TextStyle(fontSize: 14),
            ),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(
                Icons.admin_panel_settings,
                size: 40,
                color: Color.fromARGB(255, 11, 58, 70),
              ),
            ),
          ),
          
          // Menu Items
          ListTile(
            leading: const Icon(Icons.people),
            title: const Text('Akun Pengguna'),
            selected: _currentIndex == 0,
            onTap: () {
              setState(() {
                _currentIndex = 0;
              });
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.receipt_long),
            title: const Text('Riwayat Tagihan'),
            selected: _currentIndex == 1,
            onTap: () {
              setState(() {
                _currentIndex = 1;
              });
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.monitor_heart),
            title: const Text('Pemantauan'),
            selected: _currentIndex == 2,
            onTap: () {
              setState(() {
                _currentIndex = 2;
              });
              Navigator.pop(context);
            },
          ),
          
          const Divider(),
          
          // Settings & Info
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Pengaturan'),
            onTap: () {
              Navigator.pop(context);
              _showSettingsDialog();
            },
          ),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('Informasi Sistem'),
            onTap: () {
              Navigator.pop(context);
              _showSystemInfo();
            },
          ),
          
          const Spacer(),
          
          // Logout
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text(
              'Keluar',
              style: TextStyle(color: Colors.red),
            ),
            onTap: () => _showLogoutDialog(context, auth),
          ),
          
          // App Version
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'SIGOPAL Admin v1.0.0',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, custom_auth.AuthProvider auth) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi Keluar'),
        content: const Text('Apakah Anda yakin ingin keluar dari panel admin?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              
              navigator.pop();
              
              final loadingContext = context;
              showDialog(
                context: loadingContext,
                barrierDismissible: false,
                builder: (context) => const Center(
                  child: CircularProgressIndicator(),
                ),
              );
              
              try {
                await auth.signOut();
                if (mounted) {
                  navigator.pop();
                  navigator.pushReplacementNamed('/welcome');
                }
              } catch (e) {
                if (mounted) {
                  navigator.pop();
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text('Error saat logout: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
  }

  void _showSettingsDialog() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pengaturan Admin'),
        content: const Text(
          'Panel pengaturan admin akan segera hadir!\n\n'
          'Fitur yang akan tersedia:\n'
          '• Pengaturan notifikasi sistem\n'
          '• Konfigurasi database\n'
          '• Backup & restore data\n'
          '• Manajemen role pengguna',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSystemInfo() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Informasi Sistem'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Aplikasi', 'SIGOPAL Admin'),
            _buildInfoRow('Versi', '1.0.0'),
            _buildInfoRow('Platform', 'Flutter'),
            _buildInfoRow('Database', 'Firebase Firestore'),
            _buildInfoRow('Authentication', 'Firebase Auth'),
            const SizedBox(height: 16),
            const Text(
              'Status Sistem:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Text('Database: Online'),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Text('Authentication: Online'),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$label:',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(value),
        ],
      ),
    );
  }
}