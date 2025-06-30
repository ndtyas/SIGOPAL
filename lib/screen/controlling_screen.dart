import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';
import 'dart:developer' as developer;

class ControllingScreen extends StatefulWidget {
  const ControllingScreen({super.key});

  @override
  State<ControllingScreen> createState() => _ControllingScreenState();
}

class _ControllingScreenState extends State<ControllingScreen> {
  static const String _controlDataPath = 'control_data';
  static const String _valveControlPath = 'valve_control';

  // State variables
  bool valveOpen = false;
  bool _isLoading = true;

  // State variables to hold fetched data for info cards
  String _debitAirValue = 'N/A';
  String _teganganValue = 'N/A';
  String _arusValue = 'N/A';

  // Firebase Realtime Database reference
  late DatabaseReference _databaseRef;
  StreamSubscription<DatabaseEvent>? _controlDataSubscription;
  StreamSubscription<DatabaseEvent>? _valveControlSubscription;

  @override
  void initState() {
    super.initState();
    _initializeFirebase();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isLoading) {
      _fetchControlData();
      _fetchValveControlData();
    }
  }

  @override
  void dispose() {
    _controlDataSubscription?.cancel();
    _valveControlSubscription?.cancel();
    super.dispose();
  }

  // Initialize Firebase Database reference using default instance
  void _initializeFirebase() {
    try {
      // Use the default Firebase instance that's already configured
      _databaseRef = FirebaseDatabase.instance.ref();
      developer.log('Firebase initialized successfully using default instance',
          name: 'ControllingScreen');
    } catch (e) {
      developer.log('Error initializing Firebase: $e', name: 'ControllingScreen');
      // Tunda error dialog sampai context tersedia
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showErrorDialog('Gagal menginisialisasi Firebase: $e');
        }
      });
    }
  }

  // Function to fetch control data (tegangan, arus) from Firebase
  Future<void> _fetchControlData() async {
    if (!mounted) return;
    
    try {
      // Cancel existing subscription to prevent multiple listeners
      _controlDataSubscription?.cancel();

      // Listen to real-time updates from Firebase for control_data
      _controlDataSubscription = _databaseRef.child(_controlDataPath).onValue.listen(
        (event) {
          if (mounted) {
            if (event.snapshot.exists) {
              final data = event.snapshot.value as Map<dynamic, dynamic>?;
              if (data != null) {
                setState(() {
                  // Extract and format the control data (tegangan, arus)
                  _teganganValue = _formatValue(data['tegangan'], 0);
                  _arusValue = _formatValue(data['arus'], 1);
                  _updateLoadingState();
                });
              } else {
                _setDefaultControlValues();
              }
            } else {
              _setDefaultControlValues();
            }
          }
        },
        onError: (error) {
          if (mounted) {
            developer.log('Error fetching control data: $error',
                name: 'ControllingScreen');
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _showErrorDialog('Error mengambil data kontrol: $error');
              }
            });
            _setDefaultControlValues();
          }
        },
      );
    } catch (e) {
      if (mounted) {
        developer.log('Error initializing control data fetch: $e',
            name: 'ControllingScreen');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _showErrorDialog('Error inisialisasi data kontrol: $e');
          }
        });
        _setDefaultControlValues();
      }
    }
  }

  // Function to fetch valve control data (debit_air, valve_open) from Firebase
  Future<void> _fetchValveControlData() async {
    if (!mounted) return;
    
    try {
      // Cancel existing subscription to prevent multiple listeners
      _valveControlSubscription?.cancel();

      // Listen to real-time valve control updates
      _valveControlSubscription = _databaseRef.child(_valveControlPath).onValue.listen(
        (event) {
          if (mounted) {
            if (event.snapshot.exists) {
              final data = event.snapshot.value as Map<dynamic, dynamic>?;
              if (data != null) {
                setState(() {
                  // Extract debit_air from valve_control
                  _debitAirValue = _formatValue(data['debit_air'], 1);

                  // Extract valve state
                  if (data.containsKey('valve_open')) {
                    valveOpen = data['valve_open'] as bool? ?? false;
                  }

                  _updateLoadingState();
                });
              } else {
                _setDefaultValveValues();
              }
            } else {
              _setDefaultValveValues();
            }
          }
        },
        onError: (error) {
          if (mounted) {
            developer.log('Error fetching valve data: $error',
                name: 'ControllingScreen');
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _showErrorDialog('Error mengambil data kran: $error');
              }
            });
            _setDefaultValveValues();
          }
        },
      );
    } catch (e) {
      if (mounted) {
        developer.log('Error initializing valve data fetch: $e',
            name: 'ControllingScreen');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _showErrorDialog('Error inisialisasi data kran: $e');
          }
        });
        _setDefaultValveValues();
      }
    }
  }

  // Helper function to format numeric values
  String _formatValue(dynamic value, int decimalPlaces) {
    if (value == null) return 'N/A';

    try {
      double numValue = double.parse(value.toString());
      return numValue.toStringAsFixed(decimalPlaces);
    } catch (e) {
      return value.toString();
    }
  }

  // Helper function to set default values for control data when no data is available
  void _setDefaultControlValues() {
    setState(() {
      _teganganValue = 'N/A';
      _arusValue = 'N/A';
      _updateLoadingState();
    });
  }

  // Helper function to set default values for valve data when no data is available
  void _setDefaultValveValues() {
    setState(() {
      _debitAirValue = 'N/A';
      _updateLoadingState();
    });
  }

  // Helper function to update loading state
  void _updateLoadingState() {
    if (_teganganValue != 'N/A' ||
        _arusValue != 'N/A' ||
        _debitAirValue != 'N/A' ||
        !_isLoading) {
      _isLoading = false;
    }
  }

  // Function to send valve state to Firebase
  Future<void> _sendValveState(bool isOpen) async {
    try {
      await _databaseRef.child(_valveControlPath).update({
        'valve_open': isOpen,
        'timestamp': ServerValue.timestamp,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kran berhasil ${isOpen ? "dibuka" : "ditutup"}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error mengontrol kran: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
        // Revert the state if Firebase update failed
        setState(() {
          valveOpen = !isOpen;
        });
      }
    }
  }

  // Toggle valve state
  void toggleValve() {
    final newState = !valveOpen;
    // Optimistic UI update
    setState(() {
      valveOpen = newState;
    });
    _sendValveState(newState);
  }

  // Refresh data manually
  void _refreshData() {
    setState(() {
      _isLoading = true;
      _debitAirValue = 'N/A';
      _teganganValue = 'N/A';
      _arusValue = 'N/A';
    });
    _fetchControlData();
    _fetchValveControlData();
  }

  // Logout function
  void _logout(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
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

  // Show error dialog
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

  // Build info card widget with loading state
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
            _isLoading
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
            // Header with refresh and logout buttons
            Padding(
              padding: EdgeInsets.fromLTRB(20, topPadding, 20, 40),
              child: Row(
                children: [
                  const Text(
                    "Pengontrolan",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  // Refresh button
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white, size: 28),
                    onPressed: _refreshData,
                    tooltip: 'Refresh Data',
                  ),
                  // Logout button
                  IconButton(
                    icon: const Icon(Icons.logout, color: Colors.white, size: 28),
                    onPressed: () => _logout(context),
                    tooltip: 'Logout',
                  ),
                ],
              ),
            ),
            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Info Cards
                    Row(
                      children: [
                        _buildInfoCard(Icons.water_drop, _debitAirValue, "Debit Air\n(L/min)"),
                        _buildInfoCard(Icons.flash_on, _teganganValue, "Tegangan\n(V)"),
                        _buildInfoCard(Icons.swap_vert, _arusValue, "Arus\n(A)"),
                      ],
                    ),
                    const SizedBox(height: 30),
                    // Valve Control Box
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
                            "Ketuk Tombol Untuk\nBuka Tutup Kran",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 22,
                              color: Color(0xFF17778F),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 25),
                          // Status indicator
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: valveOpen ? Colors.red.shade100 : Colors.green.shade100,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Status: ${valveOpen ? "TERBUKA" : "TERTUTUP"}',
                              style: TextStyle(
                                color: valveOpen ? Colors.red.shade700 : Colors.green.shade700,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Control button
                          GestureDetector(
                            onTap: toggleValve,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
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
                                    Icon(
                                      valveOpen ? Icons.close : Icons.power_settings_new,
                                      color: Colors.white,
                                      size: 40,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      valveOpen ? "TUTUP" : "BUKA",
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