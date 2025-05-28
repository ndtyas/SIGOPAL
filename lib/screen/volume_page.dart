import 'package:flutter/material.dart';

class VolumePage extends StatelessWidget {
  const VolumePage({super.key});

  @override
  Widget build(BuildContext context) {
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
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20), // Consistent padding
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28), // Consistent white icon, larger
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Spacer(), // Pushes icons to the right
                        Row(
                          children: [
                            Image.asset(
                              'images/logoPutih.png',
                              width: 35, // Consistent logo size
                              height: 35,
                            ),
                            const SizedBox(width: 10), // Consistent spacing
                            Image.asset(
                              'images/logoUndip.png',
                              width: 35, // Consistent logo size
                              height: 35,
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
                      color: const Color(0xF2FFFFFF), // 95% opacity white, consistent with ControllingScreen
                      borderRadius: BorderRadius.circular(15), // Consistent border radius
                      boxShadow: [ // Consistent shadow
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
                  Expanded( // Use Expanded to allow the card to take available space
                    child: SingleChildScrollView( // Add SingleChildScrollView for potential overflow if content becomes too large
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xF2FFFFFF), // 95% opacity white, consistent with ControllingScreen
                          borderRadius: BorderRadius.circular(15), // Consistent border radius
                          boxShadow: [ // Consistent shadow
                            BoxShadow(
                              color: const Color(0x26000000), // Approx 15% opacity black
                              blurRadius: 10,
                              spreadRadius: 2,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column( // Use Column to wrap content and allow mainAxisSize.min
                          mainAxisSize: MainAxisSize.min, // This makes the box adjust its height
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center, // Center vertically within the row
                              children: [
                                // Tank Image
                                Image.asset(
                                  'images/tank3.png',
                                  width: 200,
                                  height: 300, // Adjusted height for better fit within the card
                                  fit: BoxFit.contain,
                                ),

                                const SizedBox(width: 10),

                                // Arrow indicators and labels
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: const [
                                        Icon(Icons.arrow_right, color: Color(0xFF17778F)),
                                        SizedBox(width: 5),
                                        Text(
                                          "FULL",
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF17778F),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 50),
                                    Row(
                                      children: const [
                                        Icon(Icons.arrow_right, color: Color(0xFF17778F)),
                                        SizedBox(width: 5),
                                        Text(
                                          "MEDIUM",
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.orange,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 50),
                                    Row(
                                      children: const [
                                        Icon(Icons.arrow_right, color: Color(0xFF17778F)),
                                        SizedBox(width: 5),
                                        Text(
                                          "LOW",
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.red,
                                          ),
                                        ),
                                      ],
                                    ),
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
}