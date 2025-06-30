import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';
import 'dart:developer' as developer;

class VolumePage extends StatefulWidget {
  const VolumePage({super.key});

  @override
  State<VolumePage> createState() => _VolumePageState();
}

class _VolumePageState extends State<VolumePage> {
  // Constants
  static const String _waterLevelPath = 'water_level';

  // State variables to hold the fetched water level value
  double _currentWaterLevel = -1.0;
  String _waterLevelCategory = 'UNKNOWN';
  Color _statusColor = Colors.grey;
  bool _isLoading = true;
  bool _hasData = false; // Track if we have received any data

  // Firebase Realtime Database reference
  late DatabaseReference _databaseRef;
  StreamSubscription<DatabaseEvent>? _dataSubscription;

  @override
  void initState() {
    super.initState();
    _initializeFirebase();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Pindahkan fetch data ke sini setelah context tersedia
    if (_isLoading) {
      _fetchWaterLevel();
    }
  }

  @override
  void dispose() {
    _dataSubscription?.cancel();
    super.dispose();
  }

  // Initialize Firebase Database reference menggunakan default instance
  void _initializeFirebase() {
    try {
      _databaseRef = FirebaseDatabase.instance.ref();
      developer.log('Firebase Database initialized successfully', name: 'VolumePage');
    } catch (e) {
      developer.log('Error initializing Firebase: $e', name: 'VolumePage');
      // Tunda error dialog sampai context tersedia
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showErrorDialog('Gagal menginisialisasi Firebase: $e');
        }
      });
    }
  }

  // Real-time data fetching from Firebase Realtime Database
  Future<void> _fetchWaterLevel() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _hasData = false;
      _currentWaterLevel = -1.0;
      _waterLevelCategory = 'UNKNOWN';
      _statusColor = Colors.grey;
    });

    try {
      _dataSubscription?.cancel();

      // Listen to real-time updates from Firebase
      _dataSubscription = _databaseRef.child(_waterLevelPath).onValue.listen(
        (event) {
          if (mounted) {
            if (event.snapshot.exists) {
              final data = event.snapshot.value;
              developer.log('Received data: $data', name: 'VolumePage');

              double? level;

              // Handle different data structures for 'water_level'
              if (data is Map<dynamic, dynamic>) {
                if (data['level_cm'] != null) {
                  level = (data['level_cm'] as num).toDouble();
                } else if (data['value'] != null) {
                  level = (data['value'] as num).toDouble();
                } else if (data['level'] != null) {
                  level = (data['level'] as num).toDouble();
                } else if (data['percentage'] != null) {
                  // Convert percentage to cm (assuming 100cm max height for calculation example)
                  level = ((data['percentage'] as num).toDouble() * 100);
                  developer.log('Converted percentage to cm: $level',
                      name: 'VolumePage');
                }
              } else if (data is num) {
                level = data.toDouble();
              }

              if (level != null) {
                setState(() {
                  _currentWaterLevel = level!;
                  _hasData = true;
                  _updateWaterLevelCategory();
                  _isLoading = false;
                });
                developer.log(
                    'Water level updated: $_currentWaterLevel cm, Category: $_waterLevelCategory',
                    name: 'VolumePage');
              } else {
                // Data exists but is unparseable
                setState(() {
                  _currentWaterLevel = -1.0;
                  _waterLevelCategory = 'UNKNOWN';
                  _statusColor = Colors.grey;
                  _hasData = false;
                  _isLoading = false;
                });
                developer.log('Water level data is null or unparseable.',
                    name: 'VolumePage');
              }
            } else {
              // No data exists at the path
              setState(() {
                _currentWaterLevel = -1.0;
                _waterLevelCategory = 'UNKNOWN';
                _statusColor = Colors.grey;
                _hasData = false;
                _isLoading = false;
              });
              developer.log('No data found at $_waterLevelPath',
                  name: 'VolumePage');
            }
          }
        },
        onError: (error) {
          if (mounted) {
            developer.log('Error fetching data: $error', name: 'VolumePage');
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _showErrorDialog('Error mengambil data level air: $error');
              }
            });
            setState(() {
              _isLoading = false;
              _hasData = false;
              _currentWaterLevel = -1.0;
              _waterLevelCategory = 'UNKNOWN';
              _statusColor = Colors.grey;
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        developer.log('Error initiating data fetch: $e', name: 'VolumePage');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _showErrorDialog('Error menginisialisasi pengambilan data: $e');
          }
        });
        setState(() {
          _isLoading = false;
          _hasData = false;
          _currentWaterLevel = -1.0;
          _waterLevelCategory = 'UNKNOWN';
          _statusColor = Colors.grey;
        });
      }
    }
  }

  // Function to update water level category based on current level
  void _updateWaterLevelCategory() {
    // Define your water level thresholds here (example: assuming max tank height is 100 cm for categorization)
    if (_currentWaterLevel >= 80) {
      _waterLevelCategory = 'FULL';
      _statusColor = const Color(0xFF17778F);
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
  }

  // Manual refresh function - restart real-time listener
  void _refreshData() {
    _fetchWaterLevel();
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
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _refreshData();
            },
            child: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final double dynamicTopPadding = screenHeight * 0.03;

    return Scaffold(
      backgroundColor: const Color(0xFF62C3D0),
      body: SafeArea(
        child: Column(
          children: [
            // --- Header ---
            Padding(
              padding: EdgeInsets.fromLTRB(
                  20.0, dynamicTopPadding, 20.0, 20),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back,
                        color: Colors.white,
                        size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                  // Add refresh button here, next to the back button
                  IconButton(
                    icon: const Icon(Icons.refresh,
                        color: Colors.white,
                        size: 28),
                    onPressed: _refreshData,
                    tooltip: 'Refresh Data',
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Image.asset(
                        'images/logoPutih.png',
                        width: screenWidth * 0.09,
                        height: screenWidth * 0.09,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.image_not_supported,
                            size: 32,
                            color: Colors.white,
                          );
                        },
                      ),
                      const SizedBox(width: 10),
                      Image.asset(
                        'images/logoUndip.png',
                        width: screenWidth * 0.09,
                        height: screenWidth * 0.09,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.image_not_supported,
                            size: 32,
                            color: Colors.white,
                          );
                        },
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
                color: const Color(0xF2FFFFFF),
                borderRadius: BorderRadius.circular(15),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x26000000),
                    blurRadius: 10,
                    spreadRadius: 2,
                    offset: Offset(0, 5),
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
              child: SingleChildScrollView(
                child: Container(
                  margin: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xF2FFFFFF),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x26000000),
                        blurRadius: 10,
                        spreadRadius: 2,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          // Hitung ukuran responsif berdasarkan lebar container yang tersedia
                          final availableWidth = constraints.maxWidth;
                          final isSmallScreen = availableWidth < 350;
                          final isMediumScreen = availableWidth >= 350 && availableWidth < 500;
                          
                          // Tentukan ukuran gambar berdasarkan ukuran layar
                          double tankWidth;
                          double tankHeight;
                          double statusWidth;
                          
                          if (isSmallScreen) {
                            // Layar kecil (HP compact)
                            tankWidth = availableWidth * 0.5;
                            tankHeight = screenHeight * 0.35;
                            statusWidth = availableWidth * 0.4;
                          } else if (isMediumScreen) {
                            // Layar sedang (HP normal)
                            tankWidth = availableWidth * 0.45;
                            tankHeight = screenHeight * 0.4;
                            statusWidth = availableWidth * 0.35;
                          } else {
                            // Layar besar (tablet)
                            tankWidth = availableWidth * 0.4;
                            tankHeight = screenHeight * 0.45;
                            statusWidth = availableWidth * 0.3;
                          }
                          
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Tank Image - Responsive berdasarkan ukuran layar
                              Flexible(
                                flex: isSmallScreen ? 6 : 5,
                                child: Container(
                                  constraints: BoxConstraints(
                                    maxWidth: tankWidth,
                                    maxHeight: tankHeight,
                                  ),
                                  child: Image.asset(
                                    'images/tank3.png',
                                    width: tankWidth,
                                    height: tankHeight,
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        width: tankWidth,
                                        height: tankHeight,
                                        decoration: BoxDecoration(
                                          color: Colors.grey[300],
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          Icons.water_drop,
                                          size: isSmallScreen ? 60 : 80,
                                          color: const Color(0xFF17778F),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),

                              SizedBox(width: isSmallScreen ? 5 : 10),

                              // Status indicators and labels dengan lebar yang fleksibel
                              Flexible(
                                flex: isSmallScreen ? 4 : 4,
                                child: Container(
                                  constraints: BoxConstraints(
                                    maxWidth: statusWidth,
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      // Show loading indicator when loading or no data
                                      if (_isLoading || !_hasData)
                                        SizedBox(
                                          width: isSmallScreen ? 25 : 30,
                                          height: isSmallScreen ? 25 : 30,
                                          child: const CircularProgressIndicator(
                                            color: Color(0xFF17778F),
                                            strokeWidth: 3,
                                          ),
                                        )
                                      // Show status when we have data
                                      else
                                        _buildCategoryStatusRow(
                                            _waterLevelCategory,
                                            true,
                                            isSmallScreen
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper widget to build the category status row (e.g., "FULL", "MEDIUM", "LOW" with arrow)
  Widget _buildCategoryStatusRow(String statusText, bool isCurrentStatus, bool isSmallScreen) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.arrow_right,
          color: _statusColor,
          size: isSmallScreen ? 20 : 24,
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            statusText,
            style: TextStyle(
              fontSize: isSmallScreen ? 16 : 18,
              fontWeight: FontWeight.bold,
              color: _statusColor,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}