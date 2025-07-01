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
          name: 'SupervisionScreen');
    } catch (e) {
      developer.log('Error initializing Firebase: $e', name: 'SupervisionScreen');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showErrorDialog('Gagal menginisialisasi Firebase: $e');
        }
      });
    }
  }

  Future<void> _fetchControlData() async {
    if (!mounted || _activeNode == null) return;

    setState(() {
      _isLoading = true;
      _debitAirValue = '...'; // Set to loading indicator
      _teganganValue = '...'; // Set to loading indicator
      _arusValue = '...'; // Set to loading indicator
    });

    try {
      _dataSubscription?.cancel();

      final nodeDataPath = '$_lastDataPath/$_activeNode';
      developer.log('Fetching control data from: $nodeDataPath', name: 'SupervisionScreen');

      _dataSubscription = _databaseRef.child(nodeDataPath).onValue.listen(
        (event) {
          if (mounted) {
            if (event.snapshot.exists && event.snapshot.value != null) {
              final data = event.snapshot.value as Map<dynamic, dynamic>?;
              if (data != null) {
                setState(() {
                  _teganganValue = _formatValue(data['tegangan'], 0);
                  _arusValue = _formatValue(data['arus'], 1);
                  _debitAirValue = _formatValue(data['debit_air'], 1);
                  valveOpen = data['valve_open'] as bool? ?? false;
                  _isLoading = false;
                });
              } else {
                _setDefaultValuesToLoading(); // Set to loading indicators if data is null but snapshot exists
              }
            } else {
              _setDefaultValuesToLoading(); // Set to loading indicators if snapshot does not exist
            }
          }
        },
        onError: (error) {
          if (mounted) {
            developer.log('Error fetching control data: $error',
                name: 'SupervisionScreen');
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _showErrorDialog('Error mengambil data pengawasan: $error');
              }
            });
            _setDefaultValuesToLoading(); // Set to loading indicators on error
          }
        },
      );
    } catch (e) {
      if (mounted) {
        developer.log('Error initiating control data fetch: $e',
            name: 'SupervisionScreen');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _showErrorDialog('Error inisialisasi data pengawasan: $e');
          }
        });
        _setDefaultValuesToLoading(); // Set to loading indicators on exception
      }
    }
  }

  String _formatValue(dynamic value, int decimalPlaces) {
    if (value == null) return '...'; // Return loading indicator for null values

    try {
      double numValue = double.parse(value.toString());
      return numValue.toStringAsFixed(decimalPlaces);
    } catch (e) {
      return '...'; // Return loading indicator if parsing fails
    }
  }

  void _setDefaultValuesToLoading() {
    setState(() {
      _teganganValue = '...';
      _arusValue = '...';
      _debitAirValue = '...';
      valveOpen = false; // Valve status might default to closed or unknown
      _isLoading = true; // Still loading if data is not available
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
            // Display CircularProgressIndicator if value is '...' (our loading indicator)
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
                              // Display '...' if still loading or no data, otherwise display status
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
                                  // Show CircularProgressIndicator for the main status if loading
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
                                  // Show 'Memuat...' for the main status text if loading
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