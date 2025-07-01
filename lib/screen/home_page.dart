import 'package:flutter/material.dart';
import 'monitoring_screen.dart';
import 'controlling_screen.dart'; // Still importing controlling_screen as the file name is not changed
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
    ControllingScreen(), // Still using ControllingScreen as the widget
    BillingScreen(),
  ];

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
          BottomNavigationBarItem(icon: Icon(Icons.settings_remote), label: "Pengawasan"), // Changed 'Pengontrolan' to 'Pengawasan'
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: "Tagihan"),
        ],
        onTap: _onItemTapped,
      ),
    );
  }
}