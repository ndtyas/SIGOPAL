import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';
import 'dart:developer' as developer;
import 'package:provider/provider.dart';
import 'package:sigopal/provider/auth_provider.dart';
import 'package:sigopal/notification_service.dart';

class VolumePage extends StatefulWidget {
  const VolumePage({super.key});

  @override
  State<VolumePage> createState() => _VolumePageState();
}

class _VolumePageState extends State<VolumePage> {
  static const String _lastDataPath = 'last_data';

  double _currentWaterLevel = -1.0;
  String _waterLevelCategory = 'UNKNOWN';
  Color _statusColor = Colors.grey;
  bool _isLoading = true;
  bool _hasData = false;

  late DatabaseReference _databaseRef;
  StreamSubscription<DatabaseEvent>? _dataSubscription;

  String? _activeNode;
  bool _isLowNotificationSent = false;

  @override
  void initState() {
    super.initState();
    _initializeFirebase();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final newNode = auth.getCurrentNode();

    developer.log(
        'didChangeDependencies: newNode retrieved from AuthProvider: $newNode, current _activeNode state: $_activeNode',
        name: 'VolumePage');

    if (newNode != _activeNode) {
      _activeNode = newNode;
      if (_activeNode != null) {
        _fetchWaterLevel();
      } else {
        setState(() {
          _currentWaterLevel = -1.0;
          _waterLevelCategory = 'UNKNOWN';
          _statusColor = Colors.grey;
          _isLoading = false;
          _hasData = false;
        });
        _showErrorDialog('Node belum dipilih atau tidak valid.');
      }
    }
  }

  @override
  void dispose() {
    _dataSubscription?.cancel();
    super.dispose();
  }

  void _initializeFirebase() {
    try {
      _databaseRef = FirebaseDatabase.instance.ref();
      developer.log('Firebase Database initialized successfully',
          name: 'VolumePage');
    } catch (e) {
      developer.log('Error initializing Firebase: $e', name: 'VolumePage');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showErrorDialog('Gagal menginisialisasi Firebase: $e');
        }
      });
    }
  }

  Future<void> _fetchWaterLevel() async {
    if (!mounted || _activeNode == null) {
      developer.log(
          'Skipping _fetchWaterLevel call: mounted=$mounted, _activeNode=$_activeNode. Data will not be fetched.',
          name: 'VolumePage');
      return;
    }

    setState(() {
      _isLoading = true;
      _hasData = false;
      _currentWaterLevel = -1.0;
      _waterLevelCategory = 'UNKNOWN';
      _statusColor = Colors.grey;
    });

    try {
      _dataSubscription?.cancel();
      final nodeDataPath = '$_lastDataPath/$_activeNode';
      developer.log('Attempting to fetch data from Firebase path: $nodeDataPath',
          name: 'VolumePage');

      _dataSubscription =
          _databaseRef.child(nodeDataPath).onValue.listen((event) {
        if (mounted) {
          if (event.snapshot.exists && event.snapshot.value != null) {
            final data = event.snapshot.value as Map<dynamic, dynamic>?;
            developer.log(
                'Successfully received data for path $nodeDataPath: $data',
                name: 'VolumePage');

            double? level;
            if (data != null && data['tinggi_cm'] != null) {
              try {
                String? rawValue = data['tinggi_cm']?.toString();
                if (rawValue != null) {
                  level = double.tryParse(rawValue);
                  if (level == null) {
                    developer.log(
                        'Failed to parse "tinggi_cm" string "$rawValue" to double.',
                        name: 'VolumePage');
                  }
                } else {
                  developer.log(
                      'Raw value for "tinggi_cm" is null after toString().',
                      name: 'VolumePage');
                }
              } catch (e) {
                developer.log(
                    'Error parsing "tinggi_cm" to double: $e. Raw value: ${data['tinggi_cm']}',
                    name: 'VolumePage');
                level = null;
              }
            } else {
              developer.log(
                  'Key "tinggi_cm" not found or its value is null in received data at path: $nodeDataPath',
                  name: 'VolumePage');
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
              setState(() {
                _currentWaterLevel = -1.0;
                _waterLevelCategory = 'UNKNOWN';
                _statusColor = Colors.grey;
                _hasData = false;
                _isLoading = false;
              });
              developer.log(
                  'Water level data (tinggi_cm) is null or unparseable. Status set to UNKNOWN.',
                  name: 'VolumePage');
            }
          } else {
            setState(() {
              _currentWaterLevel = -1.0;
              _waterLevelCategory = 'UNKNOWN';
              _statusColor = Colors.grey;
              _hasData = false;
              _isLoading = false;
            });
            developer.log(
                'Firebase snapshot does not exist or value is null at path: $nodeDataPath',
                name: 'VolumePage');
            _showErrorDialog(
                'Tidak ada data level air untuk node ini atau format data salah.');
          }
        }
      }, onError: (error) {
        if (mounted) {
          developer.log(
              'Firebase data fetching error for path $nodeDataPath: $error',
              name: 'VolumePage');
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
      });
    } catch (e) {
      if (mounted) {
        developer.log(
            'Exception caught during data fetch initiation for path $_lastDataPath/$_activeNode: $e',
            name: 'VolumePage');
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

  void _updateWaterLevelCategory() {
    if (_currentWaterLevel >= 201 && _currentWaterLevel <= 300) {
      _waterLevelCategory = 'FULL';
      _statusColor = const Color(0xFF17778F);
      _isLowNotificationSent = false;
    } else if (_currentWaterLevel >= 101 && _currentWaterLevel <= 200) {
      _waterLevelCategory = 'MEDIUM';
      _statusColor = Colors.orange;
      _isLowNotificationSent = false;
    } else if (_currentWaterLevel >= 0 && _currentWaterLevel <= 100) {
      _waterLevelCategory = 'LOW';
      _statusColor = Colors.red;
      if (!_isLowNotificationSent) {
        NotificationService.showNotification(
          title: '💧 Level Air Rendah',
          body: 'Level air di bak penyimpanan rendah. Segera isi ulang!',
        );
        _isLowNotificationSent = true;
      }
    } else {
      _waterLevelCategory = 'UNKNOWN';
      _statusColor = Colors.grey;
      _isLowNotificationSent = false;
    }
  }

  void _refreshData() {
    developer.log('Refreshing data...', name: 'VolumePage');
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
            Padding(
              padding:
                  EdgeInsets.fromLTRB(20.0, dynamicTopPadding, 20.0, 20),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back,
                        color: Colors.white, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh,
                        color: Colors.white, size: 28),
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
                  "Pantau Status\nKetinggian Tandon",
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
            Expanded(
              child: SingleChildScrollView(
                child: Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
                          final availableWidth = constraints.maxWidth;
                          final isSmallScreen = availableWidth < 350;
                          final double tankHeight = screenHeight * (isSmallScreen ? 0.35 : 0.4);

                          return Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Flexible(
                                flex: 5,
                                child: Image.asset(
                                  'images/tank3.png',
                                  height: tankHeight,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
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
                              SizedBox(width: isSmallScreen ? 5 : 10),
                              Flexible(
                                flex: 4,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.center,
                                  children: [
                                    if (_isLoading ||
                                        !_hasData ||
                                        _currentWaterLevel == -1.0)
                                      SizedBox(
                                        width: isSmallScreen ? 25 : 30,
                                        height: isSmallScreen ? 25 : 30,
                                        child:
                                            const CircularProgressIndicator(
                                          color: Color(0xFF17778F),
                                          strokeWidth: 3,
                                        ),
                                      )
                                    else
                                      _buildCategoryStatusRow(
                                        _waterLevelCategory,
                                        true, 
                                        isSmallScreen,
                                      ),
                                  ],
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

  Widget _buildCategoryStatusRow(String statusText, bool isCurrentStatus, bool isSmallScreen) {
    final double baseFontSize = isSmallScreen ? 25 : 30;

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
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              statusText,
              style: TextStyle(
                fontSize: baseFontSize,
                color: _statusColor,
              ),
            ),
          ),
        ),
      ],
    );
  }
}