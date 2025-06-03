import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class MonitoringScreen extends StatefulWidget {
  const MonitoringScreen({super.key});

  @override
  State<MonitoringScreen> createState() => _MonitoringScreenState();
}

class _MonitoringScreenState extends State<MonitoringScreen> {
  // State variables to hold the fetched data
  String _tdsValue = 'N/A';
  String _phValue = 'N/A';

  @override
  void initState() {
    super.initState();
    _fetchWaterQualityData(); // Fetch data when the screen initializes
  }

  // Function to fetch data from your API
  Future<void> _fetchWaterQualityData() async {
    try {
      // Replace with your actual API endpoint. This is a placeholder.
      // Example: 'https://your-backend.com/api/water_data'
      final response = await http.get(Uri.parse('YOUR_API_ENDPOINT_FOR_WATER_QUALITY_DATA'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          // Assuming your API returns a JSON like: {"tds": 150, "ph": 7.2}
          _tdsValue = data['tds']?.toString() ?? 'N/A'; // Use null-safe access
          _phValue = data['ph']?.toString() ?? 'N/A';      // Use null-safe access
        });
      } else {
        // Handle non-200 responses, e.g., server errors
        _showErrorDialog('Failed to load data. Status code: ${response.statusCode}');
      }
    } catch (e) {
      // Handle network errors (no internet, host unreachable, etc.) or parsing errors
      _showErrorDialog('Error fetching data: $e');
    }
  }

  void _showErrorDialog(String message) {
    if (!mounted) return; // Ensure the widget is still mounted before showing dialog
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
            child: const Text('Okay'),
          ),
        ],
      ),
    );
  }

  void _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      // Ensure the navigation happens after the widget is mounted
      Navigator.pushReplacementNamed(context, '/checkauth');
    }
  }

  // Widget to display data in a box, already responsive with GridView
  Widget dataBox(String imagePath, String value, String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xE617778F),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 12,
            spreadRadius: 3,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            imagePath,
            width: 50,
            height: 50,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // Widget to display SNI information, with added units
  Widget sniBox() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xE617778F),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 12,
            spreadRadius: 3,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Image.asset(
            'images/sni.png',
            width: 60,
            height: 60,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Standar SNI",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: const [
                    SizedBox(
                      width: 50,
                      child: Text("TDS",
                          style: TextStyle(fontSize: 17, color: Colors.white)),
                    ),
                    Text(
                      ": 1000 mg/L",
                      style: TextStyle(fontSize: 17, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: const [
                    SizedBox(
                      width: 50,
                      child: Text("pH",
                          style: TextStyle(fontSize: 17, color: Colors.white)),
                    ),
                    Text(
                      ": 6 - 9 pH",
                      style: TextStyle(fontSize: 17, color: Colors.white),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final double topPadding = screenHeight * 0.03;

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
                  fit: BoxFit.cover,
                ),
              ),
            ),
            SafeArea( // Ensures content is not obscured by system UI
              child: Column( // Main column to hold all content vertically
                children: [
                  // --- Header (fixed at top, not scrolling) ---
                  Padding(
                    padding: EdgeInsets.fromLTRB(20, topPadding, 20, 30), // Consistent padding
                    child: Row(
                      children: [
                        const Text(
                          "Pemantauan",
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
                    child: SingleChildScrollView( // Allows content to scroll if needed
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20), // Adjust padding for scrollable area
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // --- Data Monitoring Grid ---
                          GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: 2,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 1.0,
                            children: [
                              dataBox("images/tds.png", _tdsValue, "Kadar TDS"),
                              dataBox("images/ph.png", _phValue, "Kadar pH"),
                            ],
                          ),
                          const SizedBox(height: 15),

                          // --- SNI Box ---
                          sniBox(),

                          const SizedBox(height: 15),

                          // --- Circular "Cek Volume Air" Button ---
                          Center(
                            child: GestureDetector(
                              onTap: () {
                                Navigator.pushNamed(context, '/volume');
                              },
                              child: Container(
                                width: screenWidth * 0.5,
                                height: screenWidth * 0.5,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.3),
                                      blurRadius: 15,
                                      spreadRadius: 3,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: const Center(
                                  child: Text(
                                    "Cek\nVolume Air",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Color(0xE617778F),
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 15),
                          // You can add a Spacer here if you want the content to be pushed
                          // to the top and fill remaining space (if any) before scrolling.
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