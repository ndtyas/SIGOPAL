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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AuthProvider>(context, listen: false)
          .addListener(_showInAppNotification);
    });
  }

  @override
  void dispose() {
    Provider.of<AuthProvider>(context, listen: false)
        .removeListener(_showInAppNotification);
    super.dispose();
  }

  void _showInAppNotification() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final message = auth.inAppNotificationMessage;

    if (message != null) {
      // Buat dan tampilkan SnackBar (pop-up)
      final snackBar = SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        action: SnackBarAction(
          label: 'TUTUP',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
        duration: const Duration(seconds: 10),
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(snackBar);
      }
 
      auth.clearInAppNotification();
    }
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
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.monitor), label: "Pemantauan"),
          BottomNavigationBarItem(icon: Icon(Icons.settings_remote), label: "Pengawasan"),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: "Tagihan"),
        ],
        onTap: _onItemTapped,
      ),
    );
  }
}