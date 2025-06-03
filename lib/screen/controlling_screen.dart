import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ControllingScreen extends StatefulWidget {
  const ControllingScreen({super.key});

  @override
  State<ControllingScreen> createState() => _ControllingScreenState();
}

class _ControllingScreenState extends State<ControllingScreen> {
  bool valveOpen = false; // State for the valve (Open/Closed)

  // State variables to hold fetched data for info cards
  String _debitAirValue = 'N/A';
  String _teganganValue = 'N/A';
  String _arusValue = 'N/A';

  @override
  void initState() {
    super.initState();
    _fetchControlData(); // Fetch initial data when the screen starts
  }

  // --- API Integration Functions ---

  // Function to fetch data for the info cards
  Future<void> _fetchControlData() async {
    try {
      // Replace with your actual API endpoint to GET control data
      // Example: 'https://your-backend.com/api/control_data'
      final response = await http.get(Uri.parse('YOUR_API_ENDPOINT_FOR_CONTROL_DATA_GET'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          // Assuming API returns JSON like: {"debit_air": 10.5, "tegangan": 220, "arus": 5.1, "valve_open": true}
          _debitAirValue =
              data['debit_air']?.toStringAsFixed(1) ?? 'N/A'; // Format to 1 decimal place
          _teganganValue = data['tegangan']?.toString() ?? 'N/A';
          _arusValue =
              data['arus']?.toStringAsFixed(1) ?? 'N/A'; // Format to 1 decimal place
          // Also update the valve state if it's part of the GET response
          if (data.containsKey('valve_open')) {
            valveOpen = data['valve_open'] as bool;
          }
        });
      } else {
        _showErrorDialog('Gagal memuat data. Kode status: ${response.statusCode}');
      }
    } catch (e) {
      _showErrorDialog('Error mengambil data: $e');
    }
  }

  // Function to send valve state to the API
  Future<void> _sendValveState(bool isOpen) async {
    try {
      // Replace with your actual API endpoint to POST/PUT valve state
      // Example: 'https://your-backend.com/api/valve_control'
      final response = await http.post(
        Uri.parse('YOUR_API_ENDPOINT_FOR_VALVE_CONTROL_POST'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(<String, bool>{
          'valve_open': isOpen, // Send the new state
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Kran berhasil ${isOpen ? "dibuka" : "ditutup"}')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal mengirim perintah: ${response.statusCode}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error jaringan: $e')),
        );
      }
    }
  }

  void toggleValve() {
    setState(() {
      valveOpen = !valveOpen;
    });
    _sendValveState(valveOpen);
  }

  void _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.pushReplacementNamed(context, '/checkauth');
    }
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
            },
            child: const Text('Oke'),
          ),
        ],
      ),
    );
  }

  // This widget uses Expanded to be responsive within a Row
  Widget buildInfoCard(IconData icon, String value, String label) {
    return Expanded( // Ensures this card takes up equal available horizontal space
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8), // Keeps spacing between cards
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: const Color(0xF2FFFFFF), // 95% opacity white
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: const Color(0x26000000), // Approx 15% opacity black
              blurRadius: 10,
              spreadRadius: 2,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, size: 30, color: const Color(0xFF17778F)), // Fixed icon size, generally fine
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(
                fontSize: 26, // Fixed font size, scales well by default Flutter
                fontWeight: FontWeight.bold,
                color: Color(0xFF17778F),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16, // Fixed font size
                color: Color(0xFF17778F),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height; // Get screen height
    final double topPadding = screenHeight * 0.03; // Dynamic top padding

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF62C3D0),
              Color(0xFF17778F),
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Opacity(
                opacity: 0.2,
                child: Image.asset(
                  'images/air.png',
                  fit: BoxFit.cover, // Image covers the entire background
                ),
              ),
            ),
            SafeArea( // Ensures content is visible and not under system UI
              child: Column( // Main Column to hold all content vertically
                children: [
                  // --- Header (fixed at top, not scrolling) ---
                  Padding(
                    padding: EdgeInsets.fromLTRB(20, topPadding, 20, 40), // Adjusted padding
                    child: Row(
                      children: [
                        const Text(
                          "Pengontrolan",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const Spacer(), // Pushes logout button to the right
                        IconButton(
                          icon: const Icon(Icons.logout, color: Colors.white, size: 28),
                          onPressed: () => _logout(context),
                        ),
                      ],
                    ),
                  ),
                  // --- Expanded Scrollable Content Area ---
                  Expanded( // This Expanded widget makes the SingleChildScrollView take all remaining height
                    child: SingleChildScrollView( // Allows content to scroll on smaller screens
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20), // Adjusted padding
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // --- Info Cards ---
                          Row(
                            children: [
                              buildInfoCard(Icons.water_drop, _debitAirValue, "Debit Air"),
                              buildInfoCard(Icons.flash_on, _teganganValue, "Tegangan"),
                              buildInfoCard(Icons.swap_vert, _arusValue, "Arus"),
                            ],
                          ),
                          const SizedBox(height: 30),

                          // --- Valve Control Box ---
                          Container(
                            width: double.infinity, // Takes full available width
                            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                            decoration: BoxDecoration(
                              color: const Color(0xF2FFFFFF), // 95% white
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0x33000000), // Approx 20% opacity black
                                  blurRadius: 12,
                                  spreadRadius: 3,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min, // Column only takes space needed by children
                              children: [
                                const Text(
                                  "Ketuk Tombol Untuk\nBuka Tutup Kran",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 22,
                                    color: Color(0xFF17778F),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 25),
                                GestureDetector(
                                  onTap: toggleValve,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    width: screenWidth * 0.45, // Responsive size for the button
                                    height: screenWidth * 0.45, // Make it a circle based on width
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: valveOpen ? Colors.red : const Color(0xFF17778F),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0x4C000000), // Approx 30% opacity black
                                          blurRadius: 10,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: Text(
                                        valveOpen ? "OFF" : "ON",
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 30,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20), // Bottom spacing for the content
                          // You can add a Spacer() here if you want to push content to the top
                          // when there's extra space, or if the content is short.
                          // Spacer(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}