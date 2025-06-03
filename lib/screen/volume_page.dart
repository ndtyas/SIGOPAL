import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class VolumePage extends StatefulWidget {
  const VolumePage({super.key});

  @override
  State<VolumePage> createState() => _VolumePageState();
}

class _VolumePageState extends State<VolumePage> {
  // State variable to hold the fetched water level value (e.g., in cm or percentage)
  double _currentWaterLevel = -1.0; // Default to an invalid value
  String _waterLevelCategory = 'UNKNOWN'; // 'LOW', 'MEDIUM', 'FULL', 'UNKNOWN'
  Color _statusColor = Colors.grey; // Default color

  @override
  void initState() {
    super.initState();
    _fetchWaterLevel(); // Fetch water level data when the screen initializes
  }

  // Function to fetch water level data from your API
  Future<void> _fetchWaterLevel() async {
    try {
      // Replace with your actual API endpoint to GET water level status
      // Example: 'https://your-backend.com/api/water_level_sensor'
      // Assume the API returns a JSON like: {"level_cm": 75.5} or {"percentage": 0.85}
      final response = await http.get(Uri.parse('YOUR_API_ENDPOINT_FOR_CONTROL_DATA_GET'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Adjust this key based on your actual API response (e.g., 'level_cm', 'percentage', 'water_volume')
        final double? level = data['level_cm']?.toDouble();

        if (level != null) {
          setState(() {
            _currentWaterLevel = level;
            // Define your water level thresholds here
            // Example: Assuming max tank height is 100 cm
            if (_currentWaterLevel >= 80) {
              _waterLevelCategory = 'FULL';
              _statusColor = const Color(0xFF17778F); // Your primary blue
            } else if (_currentWaterLevel >= 30 && _currentWaterLevel < 80) {
              _waterLevelCategory = 'MEDIUM';
              _statusColor = Colors.orange;
            } else if (_currentWaterLevel >= 0 && _currentWaterLevel < 30) {
              _waterLevelCategory = 'LOW';
              _statusColor = Colors.red;
            } else {
              _waterLevelCategory = 'UNKNOWN';
              _statusColor = Colors.grey;
            }
          });
        } else {
          setState(() {
            _waterLevelCategory = 'UNKNOWN';
            _statusColor = Colors.grey;
          });
          _showErrorDialog('Data level air tidak ditemukan dalam respons API.');
        }
      } else {
        _showErrorDialog('Gagal memuat status air. Kode status: ${response.statusCode}');
      }
    } catch (e) {
      _showErrorDialog('Error mengambil status air: $e');
    }
  }

  void _showErrorDialog(String message) {
    if (!mounted) return; // Ensure the widget is still mounted
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

  @override
  Widget build(BuildContext context) {
    // Get screen dimensions for adaptive sizing
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Use screenHeight for proportional vertical padding
    final double dynamicTopPadding = screenHeight * 0.03;

    return Scaffold(
      body: Container(
        // Consistent Gradient Background
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF62C3D0), // Lighter blue
              Color(0xFF17778F), // Darker blue
            ],
          ),
        ),
        child: Stack(
          children: [
            // Background image with consistent opacity
            Positioned.fill(
              child: Opacity(
                opacity: 0.2, // Consistent with other screens
                child: Image.asset(
                  'images/air.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  // --- Header ---
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                        20.0, dynamicTopPadding, 20.0, 20), // Using dynamic top padding
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back,
                              color: Colors.white,
                              size: 28), // Consistent white icon, larger
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Spacer(), // Pushes icons to the right
                        Row(
                          children: [
                            Image.asset(
                              'images/logoPutih.png',
                              width: screenWidth * 0.09, // Responsive logo size
                              height: screenWidth * 0.09,
                            ),
                            const SizedBox(width: 10), // Consistent spacing
                            Image.asset(
                              'images/logoUndip.png',
                              width: screenWidth * 0.09, // Responsive logo size
                              height: screenWidth * 0.09,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Title box (first box) - consistent styling, height adjusts to content
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(
                          0xF2FFFFFF), // 95% opacity white, consistent with ControllingScreen
                      borderRadius:
                          BorderRadius.circular(15), // Consistent border radius
                      boxShadow: [
                        // Consistent shadow
                        BoxShadow(
                          color: const Color(0x26000000), // Approx 15% opacity black
                          blurRadius: 10,
                          spreadRadius: 2,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        "PANTAU STATUS BAK PENYIMPANAN AIR",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF17778F),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Tank and label container (second box) - height adjusts to content
                  Expanded(
                    // Use Expanded to allow the card to take available space
                    child: SingleChildScrollView(
                      // Add SingleChildScrollView for potential overflow if content becomes too large
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(
                              0xF2FFFFFF), // 95% opacity white, consistent with ControllingScreen
                          borderRadius:
                              BorderRadius.circular(15), // Consistent border radius
                          boxShadow: [
                            // Consistent shadow
                            BoxShadow(
                              color: const Color(0x26000000), // Approx 15% opacity black
                              blurRadius: 10,
                              spreadRadius: 2,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          // Use Column to wrap content and allow mainAxisSize.min
                          mainAxisSize:
                              MainAxisSize.min, // This makes the box adjust its height
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment
                                  .center, // Center vertically within the row
                              children: [
                                // Tank Image - Responsive width
                                Image.asset(
                                  'images/tank3.png',
                                  width: screenWidth *
                                      0.45, // About 45% of screen width
                                  height: screenHeight *
                                      0.4, // About 40% of screen height
                                  fit: BoxFit.contain,
                                ),

                                const SizedBox(width: 10),

                                // Arrow indicators and labels
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Dynamically show only the current status
                                    if (_waterLevelCategory == 'FULL')
                                      _buildStatusRow('FULL', true),
                                    if (_waterLevelCategory == 'MEDIUM') ...[
                                      SizedBox(
                                          height: screenHeight *
                                              0.05), // Space for FULL if it were there
                                      _buildStatusRow('MEDIUM', true),
                                    ],
                                    if (_waterLevelCategory == 'LOW') ...[
                                      SizedBox(
                                          height: screenHeight *
                                              0.05), // Space for FULL if it were there
                                      SizedBox(
                                          height: screenHeight *
                                              0.05), // Space for MEDIUM if it were there
                                      _buildStatusRow('LOW', true),
                                    ],
                                    if (_waterLevelCategory == 'UNKNOWN')
                                      _buildStatusRow('UNKNOWN', true),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
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

  // Helper widget to build each status row with dynamic highlighting
  Widget _buildStatusRow(String statusText, bool isCurrentStatus) {
    return Row(
      children: [
        Icon(
          Icons.arrow_right,
          color: isCurrentStatus
              ? _statusColor
              : const Color(0xFF17778F), // Highlight current status
        ),
        const SizedBox(width: 5),
        Text(
          statusText,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isCurrentStatus
                ? _statusColor
                : const Color(0xFF17778F), // Highlight current status
          ),
        ),
      ],
    );
  }
}