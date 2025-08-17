import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:async';
import 'dart:developer' as developer;
import 'package:provider/provider.dart';
import 'package:sigopal/provider/auth_provider.dart';
import 'package:sigopal/notification_service.dart';

class MonitoringScreen extends StatefulWidget {
  const MonitoringScreen({super.key});

  @override
  State<MonitoringScreen> createState() => _MonitoringScreenState();
}

class _MonitoringScreenState extends State<MonitoringScreen> {
  static const String _lastDataPath = 'last_data';

  String _tdsValue = 'N/A';
  String _phValue = 'N/A';
  String _debitAirValue = '...';
  bool _isLoading = true;

  late DatabaseReference _databaseRef;
  StreamSubscription<DatabaseEvent>? _dataSubscription;

  String? _activeNode;

  // State untuk melacak status notifikasi
  bool _isHighTdsNotificationSent = false;
  bool _isBadPhNotificationSent = false;


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

    if (newNode != _activeNode) {
      _activeNode = newNode;
      if (_activeNode != null) {
        _resetNotificationFlags();
        _fetchWaterQualityData();
      } else {
        setState(() {
          _tdsValue = 'N/A';
          _phValue = 'N/A';
          _debitAirValue = '...';
          _isLoading = false;
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
      developer.log('Firebase Database initialized successfully', name: 'MonitoringScreen');
    } catch (e) {
      developer.log('Error initializing Firebase: $e', name: 'MonitoringScreen');
    }
  }

  double _convertToDouble(dynamic value) {
    if (value == null) {
      return 0.0;
    }
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  String _formatValue(dynamic value, int decimalPlaces) {
    if (value == null) return '...';
    
    double numValue = _convertToDouble(value);
    
    if (decimalPlaces == 0 || numValue == numValue.toInt()) {
      return numValue.toInt().toString();
    }
    return numValue.toStringAsFixed(decimalPlaces);
  }

  // Fungsi untuk menentukan apakah TDS melebihi standar SNI
  bool _isTdsOutOfRange() {
    if (_tdsValue == 'N/A') return false;
    final currentTds = _convertToDouble(_tdsValue);
    return currentTds >= 1000; // Berdasarkan logika notifikasi yang ada
  }

  // Fungsi untuk menentukan apakah pH melebihi standar SNI
  bool _isPhOutOfRange() {
    if (_phValue == 'N/A') return false;
    final currentPh = _convertToDouble(_phValue);
    return currentPh != 0 && (currentPh < 6 || currentPh > 9); // Berdasarkan logika notifikasi yang ada
  }

  Future<void> _fetchWaterQualityData() async {
    if (_activeNode == null) {
      setState(() {
        _isLoading = false;
        _tdsValue = 'N/A';
        _phValue = 'N/A';
        _debitAirValue = '...';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _tdsValue = 'N/A';
      _phValue = 'N/A';
      _debitAirValue = '...';
    });

    try {
      await _dataSubscription?.cancel();

      final nodeDataPath = '$_lastDataPath/$_activeNode';
      developer.log('Fetching data from: $nodeDataPath', name: 'MonitoringScreen');

      _dataSubscription = _databaseRef.child(nodeDataPath).onValue.listen(
        (event) {
          if (mounted) {
            if (event.snapshot.exists && event.snapshot.value != null) {
              final data = event.snapshot.value as Map<dynamic, dynamic>?;
              if (data != null) {
                setState(() {
                  _tdsValue = data['tds']?.toString() ?? 'N/A';
                  _phValue = data['ph']?.toString() ?? 'N/A';
                  _debitAirValue = _formatValue(data['debit_air'], 3);
                  _isLoading = false;
                });
                _checkAndSendNotifications();
                developer.log('Data updated - TDS: $_tdsValue, pH: $_phValue, Debit Air: $_debitAirValue', name: 'MonitoringScreen');
              } else {
                _setDefaultValues();
                developer.log('Data is null at path: $nodeDataPath', name: 'MonitoringScreen');
              }
            } else {
              _setDefaultValues();
              developer.log('No data exists at path: $nodeDataPath', name: 'MonitoringScreen');
              _showErrorDialog('Tidak ada data untuk node ini.');
            }
          }
        },
        onError: (error) {
          if (mounted) {
            developer.log('Error fetching data: $error', name: 'MonitoringScreen');
            if (error is FirebaseException && error.code == 'permission-denied') {
              developer.log("Permission denied, likely due to logout. Ignoring dialog.", name: "MonitoringScreen");
            } else {
              _showErrorDialog('Error fetching data: $error');
            }
            _setDefaultValues();
          }
        },
      );
    } catch (e) {
      if (mounted) {
        developer.log('Error initializing data fetch: $e', name: 'MonitoringScreen');
        _showErrorDialog('Error initializing data fetch: $e');
        _setDefaultValues();
      }
    }
  }
  
  void _checkAndSendNotifications() {
    if (_tdsValue == 'N/A' || _phValue == 'N/A') return;

    final currentTds = _convertToDouble(_tdsValue);
    final currentPh = _convertToDouble(_phValue);

    if (currentTds >= 1000 && !_isHighTdsNotificationSent) {
      NotificationService.showNotification(
        title: '⚠️ Peringatan Kualitas Air',
        body: 'Kadar TDS tinggi: ${currentTds.toStringAsFixed(0)} ppm. Ambang batas adalah 1000 ppm.',
      );
      _isHighTdsNotificationSent = true;
    } else if (currentTds <= 950 && _isHighTdsNotificationSent) {
      _isHighTdsNotificationSent = false;
    }

    if (currentPh != 0 && (currentPh < 6 || currentPh > 9) && !_isBadPhNotificationSent) {
       String phStatus = currentPh < 6 ? 'terlalu asam' : 'terlalu basa';
       NotificationService.showNotification(
        title: '🧪 Peringatan Kualitas Air',
        body: 'Kadar pH tidak normal: ${currentPh.toStringAsFixed(1)} ($phStatus). Rentang aman: 6 - 9',
      );
      // Mengunci notifikasi agar tidak dikirim berulang kali
      _isBadPhNotificationSent = true;
    } else if ((currentPh >= 6.8 && currentPh <= 8.2) && _isBadPhNotificationSent) {
       _isBadPhNotificationSent = false;
    }
  }

  void _resetNotificationFlags() {
    _isHighTdsNotificationSent = false;
    _isBadPhNotificationSent = false;
  }

  void _setDefaultValues() {
    setState(() {
      _tdsValue = 'N/A';
      _phValue = 'N/A';
      _debitAirValue = '...';
      _isLoading = false;
      _resetNotificationFlags();
    });
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
            child: const Text('Okay'),
          ),
        ],
      ),
    );
  }

  void _logout(BuildContext context) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      await _dataSubscription?.cancel();
      developer.log('Data subscription cancelled before logout.', name: 'MonitoringScreen');
      await auth.signOut();
      if (context.mounted) {
        Navigator.pushReplacementNamed(context, '/checkauth');
      }
    } catch (e) {
      if (mounted) {
         _showErrorDialog('Error during logout: $e');
      }
    }
  }

  void _refreshData() {
    _resetNotificationFlags();
    setState(() {
      _isLoading = true;
    });
    _fetchWaterQualityData();
  }
  
  Widget _dataBox(String imagePath, String value, String title, {bool isOutOfRange = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isOutOfRange ? const Color(0xE6D32F2F) : const Color(0xE617778F), // Merah jika out of range
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0x42000000),
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
            errorBuilder: (context, error, stackTrace) {
              return const Icon(
                Icons.image_not_supported,
                size: 50,
                color: Color(0xB3FFFFFF),
              );
            },
          ),
          const SizedBox(height: 6),
          (_isLoading || value == 'N/A')
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Text(
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

  Widget _debitAirBox() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xE617778F),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0x42000000),
            blurRadius: 12,
            spreadRadius: 3,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(
            Icons.water_drop,
            size: 60,
            color: Color(0xB3FFFFFF),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "Debit Air",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text(
                      "Flow Rate: ",
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    (_isLoading || _debitAirValue == '...')
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            "$_debitAirValue L/min",
                            style: const TextStyle(
                              fontSize: 18,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
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

  Widget _sniBox() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xE617778F),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0x42000000),
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
            errorBuilder: (context, error, stackTrace) {
              return const Icon(
                Icons.verified,
                size: 60,
                color: Color(0xB3FFFFFF),
              );
            },
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  "Standar SNI",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    SizedBox(
                      width: 50,
                      child: Text(
                        "TDS",
                        style: TextStyle(fontSize: 17, color: Colors.white),
                      ),
                    ),
                    Text(
                      ": 1 - 1500 mg/L",
                      style: TextStyle(fontSize: 17, color: Colors.white),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Row(
                  children: [
                    SizedBox(
                      width: 50,
                      child: Text(
                        "pH",
                        style: TextStyle(fontSize: 17, color: Colors.white),
                      ),
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
      backgroundColor: const Color(0xFF62C3D0),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(20, topPadding, 20, 30),
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
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white, size: 28),
                    onPressed: _refreshData,
                    tooltip: 'Refresh Data',
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout, color: Colors.white, size: 28),
                    onPressed: () => _logout(context),
                    tooltip: 'Logout',
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _debitAirBox(),
                    const SizedBox(height: 15),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.0,
                      children: [
                        _dataBox("images/tds.png", _tdsValue, "Kadar TDS", isOutOfRange: _isTdsOutOfRange()),
                        _dataBox("images/ph.png", _phValue, "Kadar pH", isOutOfRange: _isPhOutOfRange()),
                      ],
                    ),
                    const SizedBox(height: 15),
                    _sniBox(),
                    const SizedBox(height: 15),
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
                                color: const Color(0x4D000000),
                                blurRadius: 15,
                                spreadRadius: 3,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Text(
                              "Cek\nKetinggian\nTandon",
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