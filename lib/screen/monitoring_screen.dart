import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MonitoringScreen extends StatelessWidget {
  const MonitoringScreen({super.key});

  void _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.pushReplacementNamed(context, '/checkauth');
    }
  }

  Widget buildMonitoringBox(String title, String value, String unit, IconData? icon) {
    const Color boxContentColor = Color(0xFF17778F);

    return Container(
      width: 100,
      height: 120,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(2, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) Icon(icon, color: boxContentColor),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: boxContentColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: boxContentColor,
            ),
          ),
          if (unit.isNotEmpty)
            Text(
              unit,
              style: const TextStyle(
                fontSize: 12,
                color: boxContentColor,
              ),
            ),
        ],
      ),
    );
  }

  Widget buildHorizontalSection(String sectionTitle, List<Widget> boxes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          sectionTitle,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 140,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: boxes,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF62C3D0),
      body: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.3,
              child: Image.asset(
                'images/air.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      "Pemantauan",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF17778F),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.logout, color: Color(0xFF17778F)),
                      onPressed: () => _logout(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  color: const Color(0xFF17778F),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 60,
                            height: 60,
                            child: ClipRect(
                              child: Image.asset(
                                'images/logoPutih.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            "Solusi Digital Pengelolaan Air PAMSIMAS Rumah Anda",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                buildHorizontalSection("Hasil Monitoring", [
                  buildMonitoringBox("Kadar PH", "7", "", Icons.water),
                  buildMonitoringBox("Kadar TDS", "150", "ppm", Icons.science),
                  buildMonitoringBox("Kadar DO", "7", "", Icons.bubble_chart),
                  buildMonitoringBox("Turbidity", "31", "NTU", Icons.opacity),
                  buildMonitoringBox("Suhu", "2.8", "°C", Icons.thermostat),
                  buildMonitoringBox("Water Level", "75%", "", Icons.water_drop),
                ]),
                const SizedBox(height: 16),
                buildHorizontalSection("Nilai Batas SNI", [
                  buildMonitoringBox("Kadar PH", "6.5 - 8.5", "", Icons.water),
                  buildMonitoringBox("Kadar TDS", "\u2264 500", "ppm", Icons.science),
                  buildMonitoringBox("Kadar DO", "\u2265 6", "", Icons.bubble_chart),
                  buildMonitoringBox("Turbidity", "< 25", "NTU", Icons.opacity),
                  buildMonitoringBox("Suhu", "26 - 30", "°C", Icons.thermostat),
                  buildMonitoringBox("Water Level", "100%", "", Icons.water_drop),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
