import 'package:flutter/material.dart';
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
        backgroundColor: const Color(0xFF17778F),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.monitor), label: "Monitoring"),
          BottomNavigationBarItem(icon: Icon(Icons.settings_remote), label: "Controlling"),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: "Billing"),
        ],
        onTap: _onItemTapped,
      ),
    );
  }
}
