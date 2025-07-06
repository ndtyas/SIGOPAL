import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
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
  bool _isLoading = true;

  String _debitAirValue = '...';
  String _teganganValue = '...';
  String _arusValue = '...';

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
          _isLoading = false;
          // Set to default loading indicators when no node is selected
          _debitAirValue = '...';
          _teganganValue = '...';
          _arusValue = '...';
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

  // Helper function to safely convert dynamic value to double
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

  // Helper function to safely convert dynamic value to boolean
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

  Future<void> _fetchControlData() async {
    if (!mounted || _activeNode == null) return;

    setState(() {
      _isLoading = true;
      _debitAirValue = '...';
      _teganganValue = '...';
      _arusValue = '...';
    });

    try {
      _dataSubscription?.cancel();

      final nodeDataPath = '$_lastDataPath/$_activeNode';
      developer.log('Fetching control data from: $nodeDataPath', name: 'ControllingScreen');

      _dataSubscription = _databaseRef.child(nodeDataPath).onValue.listen(
        (event) {
          if (mounted) {
            if (event.snapshot.exists && event.snapshot.value != null) {
              final data = event.snapshot.value as Map<dynamic, dynamic>?;
              if (data != null) {
                setState(() {
                  // Use _formatValue which now incorporates _convertToDouble
                  _teganganValue = _formatValue(data['tegangan'], 2); // 2 decimal places for voltage
                  _arusValue = _formatValue(data['arus'], 2);
                  _debitAirValue = _formatValue(data['debit_air'], 2);
                  
                  // Use _convertToBool for valveOpen
                  valveOpen = _convertToBool(data['valve_open']);
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
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _showErrorDialog('Error mengambil data pengawasan: $error');
              }
            });
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

  // Refined _formatValue to use _convertToDouble for robust parsing
  String _formatValue(dynamic value, int decimalPlaces) {
    if (value == null) return '...';
    
    // Safely convert to double first
    double numValue = _convertToDouble(value);
    
    // Check if the value is essentially an integer
    if (decimalPlaces == 0 || numValue == numValue.toInt()) {
      return numValue.toInt().toString();
    }
    return numValue.toStringAsFixed(decimalPlaces);
  }

  void _setDefaultValuesToLoading() {
    setState(() {
      _teganganValue = '...';
      _arusValue = '...';
      _debitAirValue = '...';
      valveOpen = false;
      _isLoading = true;
    });
  }

  void _refreshData() {
    _fetchControlData();
  }

  void _logout(BuildContext context) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      await auth.signOut();
      if (context.mounted) {
        Navigator.pushReplacementNamed(context, '/checkauth');
      }
    } catch (e) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showErrorDialog('Error saat logout: $e');
        }
      });
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

  Widget _buildInfoCard(IconData icon, String value, String label) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        padding: const EdgeInsets.symmetric(vertical: 20),
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
          children: [
            Icon(icon, size: 30, color: const Color(0xFF17778F)),
            const SizedBox(height: 10),
            value == '...'
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Color(0xFF17778F),
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    value,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF17778F),
                    ),
                  ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
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
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final double topPadding = screenHeight * 0.03;

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
                    Row(
                      children: [
                        _buildInfoCard(Icons.water_drop, _debitAirValue, "Debit Air\n(L/min)"),
                        _buildInfoCard(Icons.flash_on, _teganganValue, "Tegangan\n(V)"),
                        _buildInfoCard(Icons.swap_vert, _arusValue, "Arus\n(A)"),
                      ],
                    ),
                    const SizedBox(height: 30),
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
                            "Pantau Status Meteran Air",
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
                              color: valveOpen ? Colors.red.shade100 : Colors.green.shade100,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _isLoading && _debitAirValue == '...'
                                  ? 'Memuat...'
                                  : 'Status: ${valveOpen ? "TERBUKA" : "TERTUTUP"}',
                              style: TextStyle(
                                color: valveOpen ? Colors.red.shade700 : Colors.green.shade700,
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
                              color: valveOpen ? Colors.red : const Color(0xFF17778F),
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
                                  _isLoading && _debitAirValue == '...'
                                      ? const SizedBox(
                                          width: 40,
                                          height: 40,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 3,
                                          ),
                                        )
                                      : Icon(
                                          valveOpen ? Icons.water_drop_outlined : Icons.cancel_outlined,
                                          color: Colors.white,
                                          size: 40,
                                        ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _isLoading && _debitAirValue == '...'
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