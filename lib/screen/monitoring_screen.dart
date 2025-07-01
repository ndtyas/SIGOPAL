import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';
import 'dart:developer' as developer;
import 'package:provider/provider.dart';
import 'package:sigopal/provider/auth_provider.dart';

class MonitoringScreen extends StatefulWidget {
  const MonitoringScreen({super.key});

  @override
  State<MonitoringScreen> createState() => _MonitoringScreenState();
}

class _MonitoringScreenState extends State<MonitoringScreen> {
  static const String _lastDataPath = 'last_data';

  String _tdsValue = 'N/A';
  String _phValue = 'N/A';
  bool _isLoading = true;

  late DatabaseReference _databaseRef;
  StreamSubscription<DatabaseEvent>? _dataSubscription;

  String? _activeNode;

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
        _fetchWaterQualityData();
      } else {
        setState(() {
          _tdsValue = 'N/A';
          _phValue = 'N/A';
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

  Future<void> _fetchWaterQualityData() async {
    if (_activeNode == null) {
      setState(() {
        _isLoading = false;
        _tdsValue = 'N/A';
        _phValue = 'N/A';
      });
      return;
    }

    try {
      _dataSubscription?.cancel();

      final nodeDataPath = '$_lastDataPath/$_activeNode';
      developer.log('Fetching data from: $nodeDataPath', name: 'MonitoringScreen');

      _dataSubscription = _databaseRef.child(nodeDataPath).onValue.listen(
        (event) {
          if (mounted) {
            if (event.snapshot.exists) {
              final data = event.snapshot.value as Map<dynamic, dynamic>?;
              if (data != null) {
                setState(() {
                  _tdsValue = data['tds']?.toString() ?? 'N/A';
                  _phValue = data['ph']?.toString() ?? 'N/A';
                  _isLoading = false;
                });
                developer.log('Data updated - TDS: $_tdsValue, pH: $_phValue', name: 'MonitoringScreen');
              } else {
                setState(() {
                  _tdsValue = 'N/A';
                  _phValue = 'N/A';
                  _isLoading = false;
                });
                developer.log('Data is null at path: $nodeDataPath', name: 'MonitoringScreen');
              }
            } else {
              setState(() {
                _tdsValue = 'N/A';
                _phValue = 'N/A';
                _isLoading = false;
              });
              developer.log('No data exists at path: $nodeDataPath', name: 'MonitoringScreen');
              _showErrorDialog('Tidak ada data untuk node ini.');
            }
          }
        },
        onError: (error) {
          if (mounted) {
            developer.log('Error fetching data: $error', name: 'MonitoringScreen');
            _showErrorDialog('Error fetching data: $error');
            setState(() {
              _isLoading = false;
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        developer.log('Error initializing data fetch: $e', name: 'MonitoringScreen');
        _showErrorDialog('Error initializing data fetch: $e');
        setState(() {
          _isLoading = false;
        });
      }
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
            child: const Text('Okay'),
          ),
        ],
      ),
    );
  }

  void _logout(BuildContext context) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      await auth.signOut();
      if (context.mounted) {
        Navigator.pushReplacementNamed(context, '/checkauth');
      }
    } catch (e) {
      _showErrorDialog('Error during logout: $e');
    }
  }

  void _refreshData() {
    setState(() {
      _isLoading = true;
    });
    _fetchWaterQualityData();
  }

  Widget _dataBox(String imagePath, String value, String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            imagePath,
            width: 50,
            height: 50,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Icon(
                Icons.image_not_supported,
                size: 50,
                color: const Color(0xB3FFFFFF),
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
              return Icon(
                Icons.verified,
                size: 60,
                color: const Color(0xB3FFFFFF),
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
                      ": 1000 mg/L",
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
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.0,
                      children: [
                        _dataBox("images/tds.png", _tdsValue, "Kadar TDS"),
                        _dataBox("images/ph.png", _phValue, "Kadar pH"),
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