import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sigopal/provider/auth_provider.dart';
import 'monitoring_screen.dart';
import 'controlling_screen.dart';
import 'billing_screen.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    MonitoringScreen(),
    ControllingScreen(),  
    BillingScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _setupNotificationListener();
  }

  void _setupNotificationListener() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      // Listen untuk perubahan notification message
      authProvider.addListener(_handleNotificationChange);
    });
  }

  void _handleNotificationChange() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final message = authProvider.inAppNotificationMessage;

    if (message != null && mounted) {
      _showInAppNotification(message);
      // Clear notification setelah ditampilkan
      authProvider.clearInAppNotification();
    }
  }

  void _showInAppNotification(String message) {
    // Pastikan tidak ada SnackBar lain yang aktif
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    
    final snackBar = SnackBar(
      content: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Colors.white,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white, 
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: Colors.red.shade600,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      action: SnackBarAction(
        label: 'TUTUP',
        textColor: Colors.white,
        backgroundColor: Colors.red.shade800,
        onPressed: () {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
        },
      ),
      duration: const Duration(seconds: 8),
      elevation: 6,
    );
    
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  @override
  void dispose() {
    // Remove listener saat widget di-dispose
    if (mounted) {
      Provider.of<AuthProvider>(context, listen: false)
          .removeListener(_handleNotificationChange);
    }
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white70,
        backgroundColor: const Color.fromARGB(255, 11, 58, 70),
        type: BottomNavigationBarType.fixed, // Untuk memastikan semua tab terlihat
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.monitor), 
            label: "Pemantauan"
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_remote), 
            label: "Pengawasan"
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long), 
            label: "Tagihan"
          ),
        ],
        onTap: _onItemTapped,
      ),
    );
  }
}