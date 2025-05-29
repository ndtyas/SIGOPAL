import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ControllingScreen extends StatefulWidget {
  const ControllingScreen({super.key});

  @override
  State<ControllingScreen> createState() => _ControllingScreenState();
}

class _ControllingScreenState extends State<ControllingScreen> {
  bool valveOpen = false;

  void toggleValve() {
    setState(() {
      valveOpen = !valveOpen;
    });
    // In a real application, you would send this state change to your hardware (e.g., via Firebase, MQTT, etc.)
    // For example:
    // if (valveOpen) {
    //   // Command to open valve
    // } else {
    //   // Command to close valve
    // }
  }

  void _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.pushReplacementNamed(context, '/checkauth');
    }
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
              child: SingleChildScrollView( // Allows content to scroll on smaller screens
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
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
                    const SizedBox(height: 40),

                    // Row wrapped with Expanded cards makes them responsive
                    Row(
                      children: [
                        buildInfoCard(Icons.water_drop, "9", "Debit Air"),
                        buildInfoCard(Icons.flash_on, "9", "Tegangan"),
                        buildInfoCard(Icons.swap_vert, "9", "Arus"),
                      ],
                    ),
                    const SizedBox(height: 30),

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
                              width: 150, // Fixed size for the button, consider dynamic if needed for very small screens
                              height: 150,
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
                    const SizedBox(height: 20), // Bottom spacing
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}