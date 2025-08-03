import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:async';
import 'dart:developer' as developer;
import 'package:provider/provider.dart';
import 'package:sigopal/provider/auth_provider.dart';

class ControllingScreen extends StatefulWidget {
  const ControllingScreen({super.key});

  @override
  State<ControllingScreen> createState() => _ControllingScreenState();
}

class _ControllingScreenState extends State<ControllingScreen> {
  static const String _lastDataPath = 'last_data';

  bool valveOpen = false;
  String pompaStatus = '00';
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
        _fetchControlData();
      } else {
        setState(() {
          valveOpen = false;
          pompaStatus = '00';
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
      developer.log('Firebase initialized successfully using default instance',
          name: 'ControllingScreen');
    } catch (e) {
      developer.log('Error initializing Firebase: $e', name: 'ControllingScreen');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showErrorDialog('Gagal menginisialisasi Firebase: $e');
        }
      });
    }
  }

  bool _convertToBool(dynamic value) {
    if (value == null) {
      return false;
    }
    if (value is bool) {
      return value;
    }
    if (value is int) {
      return value != 0;
    }
    if (value is String) {
      final lowerCaseValue = value.toLowerCase();
      if (lowerCaseValue == 'true' || lowerCaseValue == '1' || lowerCaseValue == 'open') {
        return true;
      }
      if (lowerCaseValue == 'false' || lowerCaseValue == '0' || lowerCaseValue == 'closed') {
        return false;
      }
    }
    return false;
  }

  String _convertToString(dynamic value) {
    if (value == null) {
      return '00';
    }
    return value.toString();
  }

  Map<String, dynamic> _getPumpStatusDetails(String status) {
    final newActiveColor = const Color(0xFF17778F);

    switch (status) {
      case '00':
        return {
          'text': 'MATI LISTRIK',
          'color': Colors.orange,
          'icon': Icons.power_off,
          'bgColor': Colors.orange.shade100,
          'textColor': Colors.orange.shade700,
        };
      case '01':
        return {
          'text': 'RUSAK',
          'color': Colors.blueGrey,
          'icon': Icons.build,
          'bgColor': Colors.blueGrey.shade100,
          'textColor': Colors.blueGrey.shade700,
        };
      case '10':
        return {
          'text': 'OFF',
          'color': Colors.red,
          'icon': Icons.stop_circle_outlined,
          'bgColor': Colors.red.shade100,
          'textColor': Colors.red.shade700,
        };
      case '11':
        return {
          'text': 'ON',
          'color': newActiveColor,
          'icon': Icons.play_circle_outline,
          'bgColor': newActiveColor.withAlpha(26),
          'textColor': newActiveColor,
        };
      default:
        return {
          'text': 'UNKNOWN',
          'color': Colors.grey,
          'icon': Icons.help_outline,
          'bgColor': Colors.grey.shade100,
          'textColor': Colors.grey.shade700,
        };
    }
  }

  Future<void> _fetchControlData() async {
    if (!mounted || _activeNode == null) return;

    setState(() {
      _isLoading = true;
      pompaStatus = '00';
    });

    try {
      await _dataSubscription?.cancel();

      final nodeDataPath = '$_lastDataPath/$_activeNode';
      developer.log('Fetching control data from: $nodeDataPath', name: 'ControllingScreen');

      _dataSubscription = _databaseRef.child(nodeDataPath).onValue.listen(
        (event) {
          if (mounted) {
            if (event.snapshot.exists && event.snapshot.value != null) {
              final data = event.snapshot.value as Map<dynamic, dynamic>?;
              if (data != null) {
                setState(() {
                  valveOpen = _convertToBool(data['valve_open']);
                  pompaStatus = _convertToString(data['pompa']);
                  _isLoading = false;
                });
              } else {
                _setDefaultValuesToLoading();
                developer.log('Data is null for node: $_activeNode', name: 'ControllingScreen');
              }
            } else {
              _setDefaultValuesToLoading();
              developer.log('Snapshot does not exist or value is null for node: $_activeNode', name: 'ControllingScreen');
            }
          }
        },
        onError: (error) {
          if (mounted) {
            developer.log('Error fetching control data: $error',
                name: 'ControllingScreen');
            if (error is FirebaseException && error.code == 'permission-denied') {
              developer.log("Permission denied, likely due to logout. Ignoring dialog.", name: "ControllingScreen");
            } else {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  _showErrorDialog('Error mengambil data pengawasan: $error');
                }
              });
            }
            _setDefaultValuesToLoading();
          }
        },
      );
    } catch (e) {
      if (mounted) {
        developer.log('Error initiating control data fetch: $e',
            name: 'ControllingScreen');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _showErrorDialog('Error inisialisasi data pengawasan: $e');
          }
        });
        _setDefaultValuesToLoading();
      }
    }
  }

  void _setDefaultValuesToLoading() {
    setState(() {
      valveOpen = false;
      pompaStatus = '00';
      _isLoading = true;
    });
  }

  void _refreshData() {
    _fetchControlData();
  }

  void _logout(BuildContext context) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      // 1. Batalkan listener data terlebih dahulu
      await _dataSubscription?.cancel();
      developer.log('Data subscription cancelled before logout.', name: 'ControllingScreen');
      
      // 2. Baru lakukan proses logout
      await auth.signOut();
      
      // 3. Pindah halaman setelah semua beres
      if (context.mounted) {
        Navigator.pushReplacementNamed(context, '/checkauth');
      }
    } catch (e) {
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _showErrorDialog('Error saat logout: $e');
          }
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
    final double topPadding = screenHeight * 0.03;

    final pumpDetails = _getPumpStatusDetails(pompaStatus);
    
    final activeColor = const Color(0xE617778F); 
    final activeColorForText = const Color(0xFF17778F);
    final activeColorBackground = const Color(0xFF17778F).withAlpha(26);
    final inactiveColor = Colors.red;

    return Scaffold(
      backgroundColor: const Color(0xFF62C3D0),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(20, topPadding, 20, 40),
              child: Row(
                children: [
                  const Text(
                    "Pengawasan",
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
                    // Valve Status Box
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                      decoration: const BoxDecoration(
                        color: Color(0xF2FFFFFF),
                        borderRadius: BorderRadius.all(Radius.circular(20)),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x33000000),
                            blurRadius: 12,
                            spreadRadius: 3,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            "Status Kran Node",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 22,
                              color: Color(0xFF17778F),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 25),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: valveOpen ? activeColorBackground : inactiveColor.shade100,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _isLoading
                                  ? 'Memuat...'
                                  : 'Status: ${valveOpen ? "TERBUKA" : "TERTUTUP"}',
                              style: TextStyle(
                                color: valveOpen ? activeColorForText : inactiveColor.shade700,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Container(
                            width: screenWidth * 0.45,
                            height: screenWidth * 0.45,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: valveOpen ? activeColor : inactiveColor,
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x4C000000),
                                  blurRadius: 10,
                                  offset: Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _isLoading
                                      ? const SizedBox(
                                          width: 40,
                                          height: 40,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 3,
                                          ),
                                        )
                                      : Icon(
                                          valveOpen ? Icons.water_drop : Icons.water_drop_outlined,
                                          color: Colors.white,
                                          size: 40,
                                        ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _isLoading
                                        ? "Memuat..."
                                        : (valveOpen ? "TERBUKA" : "TERTUTUP"),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                    // Pump Status Box
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                      decoration: const BoxDecoration(
                        color: Color(0xF2FFFFFF),
                        borderRadius: BorderRadius.all(Radius.circular(20)),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x33000000),
                            blurRadius: 12,
                            spreadRadius: 3,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            "Status Pompa Tandon",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 22,
                              color: Color(0xFF17778F),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 25),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: pumpDetails['bgColor'],
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _isLoading
                                  ? 'Memuat...'
                                  : 'Status: ${pumpDetails['text']}',
                              style: TextStyle(
                                color: pumpDetails['textColor'],
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Container(
                            width: screenWidth * 0.45,
                            height: screenWidth * 0.45,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: pumpDetails['color'],
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x4C000000),
                                  blurRadius: 10,
                                  offset: Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _isLoading
                                      ? const SizedBox(
                                          width: 40,
                                          height: 40,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 3,
                                          ),
                                        )
                                      : Icon(
                                          pumpDetails['icon'],
                                          color: Colors.white,
                                          size: 40,
                                        ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _isLoading
                                        ? "Memuat..."
                                        : pumpDetails['text'],
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
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