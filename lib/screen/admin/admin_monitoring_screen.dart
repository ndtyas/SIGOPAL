import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:sigopal/provider/auth_provider.dart';
import 'package:sigopal/notification_service.dart';

class AdminMonitoringScreen extends StatefulWidget {
  const AdminMonitoringScreen({super.key});

  @override
  State<AdminMonitoringScreen> createState() => _AdminMonitoringScreenState();
}

class _AdminMonitoringScreenState extends State<AdminMonitoringScreen> {
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _selectedNodeId;
  List<String> _availableNodes = [];
  bool _isLoadingNodes = true;

  // Monitoring data
  double _waterLevel = 0.0;
  double _tdsValue = 0.0;
  double _phValue = 0.0;
  String _pumpStatus = '00';
  double _flowRate = 0.0; 
  String _valveStatus = '00';
  bool _isConnected = false;

  StreamSubscription<DatabaseEvent>? _monitoringSubscription;
  bool _isLoadingData = false;
  String? _lastUpdate;

  // Notification states
  bool _isLowWaterNotificationSent = false;
  bool _isHighTdsNotificationSent = false;
  bool _isBadPhNotificationSent = false;

  @override
  void initState() {
    super.initState();
    _loadAvailableNodes();
  }

  @override
  void dispose() {
    _monitoringSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadAvailableNodes() async {
    setState(() {
      _isLoadingNodes = true;
    });

    try {
      final usersQuery = await _firestore.collection('users').get();
      final Set<String> nodeIds = {};

      for (var doc in usersQuery.docs) {
        final data = doc.data();
        if (data['node_id'] != null && data['node_id'].toString().isNotEmpty) {
          nodeIds.add(data['node_id'].toString());
        }
      }

      final lastDataRef = _database.ref('last_data');
      final snapshot = await lastDataRef.get();

      final List<String> validNodes = [];
      if (snapshot.exists && snapshot.value is Map) {
        final Map<dynamic, dynamic> data =
            snapshot.value as Map<dynamic, dynamic>;
        for (String nodeId in nodeIds) {
          if (data.containsKey(nodeId)) {
            validNodes.add(nodeId);
          }
        }
      }
      
      // Sort nodes alphabetically for consistency
      validNodes.sort();

      if (!mounted) return;

      setState(() {
        _availableNodes = validNodes;
        _isLoadingNodes = false;

        if (_availableNodes.isNotEmpty && _selectedNodeId == null) {
          _selectedNodeId = _availableNodes.first;
          _startMonitoring(_selectedNodeId!);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingNodes = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error memuat node: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _startMonitoring(String nodeId) {
    _monitoringSubscription?.cancel();

    // Reset notification states when switching nodes
    _isLowWaterNotificationSent = false;
    _isHighTdsNotificationSent = false;
    _isBadPhNotificationSent = false;

    setState(() {
      _isLoadingData = true;
    });

    final nodeRef = _database.ref('last_data/$nodeId');
    _monitoringSubscription = nodeRef.onValue.listen(
      (event) {
        if (!mounted) return;
        if (event.snapshot.exists && event.snapshot.value != null) {
          final data = event.snapshot.value as Map<dynamic, dynamic>;

          setState(() {
            _waterLevel = _parseDouble(data['tinggi_cm']);
            _tdsValue = _parseDouble(data['tds']);
            _phValue = _parseDouble(data['ph']);
            _pumpStatus = _convertToString(data['pompa']); 
            _flowRate = _parseDouble(data['debit_air']); 
            _valveStatus = _convertToString(data['valve_open']); 
            _isConnected = _parseInt(data['status']) == 1;
            _lastUpdate = _formatTimestamp(data['timestamp']);
            _isLoadingData = false;
          });

          // Check for notification triggers
          _checkNotifications();
        } else {
          setState(() {
            _waterLevel = 0.0;
            _tdsValue = 0.0;
            _phValue = 0.0;
            _pumpStatus = '00'; 
            _flowRate = 0.0;
            _valveStatus = '00';
            _isConnected = false;
            _lastUpdate = 'Data tidak ditemukan';
            _isLoadingData = false;
          });
        }
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _isLoadingData = false;
          _isConnected = false;
          _lastUpdate = 'Gagal memuat';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error monitoring: $error'),
            backgroundColor: Colors.red,
          ),
        );
      },
    );
  }

  void _checkNotifications() {
    // Water level notification (below 100 cm)
    if (_waterLevel < 100 && !_isLowWaterNotificationSent) {
      NotificationService.showNotification(
        title: '💧 Peringatan Admin - Level Air Rendah',
        body: 'Node $_selectedNodeId: Level air ${_waterLevel.toStringAsFixed(1)} cm - Sangat rendah!',
      );
      _isLowWaterNotificationSent = true;
    } else if (_waterLevel >= 20) {
      _isLowWaterNotificationSent = false;
    }

    // TDS notification (above 1000 ppm)
    if (_tdsValue > 1000 && !_isHighTdsNotificationSent) {
      NotificationService.showNotification(
        title: '⚠️ Peringatan Admin - TDS Tinggi',
        body: 'Node $_selectedNodeId: TDS ${_tdsValue.toStringAsFixed(0)} ppm - Perlu filter segera!',
      );
      _isHighTdsNotificationSent = true;
    } else if (_tdsValue <= 950) {
      _isHighTdsNotificationSent = false;
    }

    // pH notification (outside 6.5-8.5 range)
    if ((_phValue < 6.5 || _phValue > 8.5) && !_isBadPhNotificationSent) {
      String phStatus = _phValue < 6.5 ? 'terlalu asam' : 'terlalu basa';
      NotificationService.showNotification(
        title: '🧪 Peringatan Admin - pH Tidak Normal',
        body: 'Node $_selectedNodeId: pH ${_phValue.toStringAsFixed(1)} - Air $phStatus!',
      );
      _isBadPhNotificationSent = true;
    } else if (_phValue >= 6.8 && _phValue <= 8.2) {
      _isBadPhNotificationSent = false;
    }
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  // Added method to convert pump status to string (matching ControllingScreen)
  String _convertToString(dynamic value) {
    if (value == null) {
      return '00';
    }
    return value.toString();
  }

  // Added method to get pump status details (matching ControllingScreen)
  Map<String, dynamic> _getPumpStatusDetails(String status) {
    const activeColor = Color(0xFF17778F);

    switch (status) {
      case '00':
        return {
          'text': 'MATI LISTRIK',
          'color': Color(0xFFFF9800),
          'icon': Icons.power_off,
          'bgColor': Color(0xFFFFF3E0),
          'textColor': Color(0xFFE65100),
        };
      case '01':
        return {
          'text': 'RUSAK',
          'color': Color(0xFF90A4AE),
          'icon': Icons.build,
          'bgColor': Color(0xFFECEFF1),
          'textColor': Color(0xFF455A64),
        };
      case '10':
        return {
          'text': 'OFF',
          'color': Color(0xFFEF5350),
          'icon': Icons.stop_circle_outlined,
          'bgColor': Color(0xFFFFEBEE),
          'textColor': Color(0xFFC62828),
        };
      case '11':
        return {
          'text': 'ON',
          'color': const Color.fromARGB(255, 255, 255, 255),
          'icon': Icons.play_circle_outline,
          'bgColor': activeColor.withAlpha(26),
          'textColor': activeColor,
        };
      default:
        return {
          'text': 'UNKNOWN',
          'color': Color(0xFF9E9E9E),
          'icon': Icons.help_outline,
          'bgColor': Color(0xFFF5F5F5),
          'textColor': Color(0xFF424242),
        };
    }
  }

  // Method untuk mendapatkan detail status valve
  Map<String, dynamic> _getValveStatusDetails(String status) {
    const activeColor = Color(0xFF17778F);

    switch (status) {
      case '00':
        return {
          'text': 'MATI LISTRIK',
          'color': Color(0xFFFF9800),
          'icon': Icons.power_off,
          'bgColor': Color(0xFFFFF3E0),
          'textColor': Color(0xFFE65100),
        };
      case '01':
        return {
          'text': 'RUSAK',
          'color': Color(0xFF90A4AE),
          'icon': Icons.build,
          'bgColor': Color(0xFFECEFF1),
          'textColor': Color(0xFF455A64),
        };
      case '10':
        return {
          'text': 'TERTUTUP',
          'color': Color(0xFFEF5350),
          'icon': Icons.close,
          'bgColor': Color(0xFFFFEBEE),
          'textColor': Color(0xFFC62828),
        };
      case '11':
        return {
          'text': 'TERBUKA',
          'color': const Color.fromARGB(255, 255, 255, 255),
          'icon': Icons.check_circle_outline,
          'bgColor': activeColor.withAlpha(26),
          'textColor': activeColor,
        };
      default:
        return {
          'text': 'UNKNOWN',
          'color': Color(0xFF9E9E9E),
          'icon': Icons.help_outline,
          'bgColor': Color(0xFFF5F5F5),
          'textColor': Color(0xFF424242),
        };
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    try {
      if (timestamp is int) {
        final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
        return DateFormat('yyyy-MM-dd HH:mm:ss').format(date);
      }
      return timestamp.toString();
    } catch (e) {
      return 'N/A';
    }
  }

  void _logout() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      // 1. Cancel data subscription first
      await _monitoringSubscription?.cancel();

      // 2. Perform logout
      await auth.signOut();

      // 3. Check if the widget is still mounted AFTER the async gap
      if (!mounted) return; 
      
      // 4. Navigate using the State's context
      Navigator.pushReplacementNamed(context, '/checkauth');

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error during logout: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final double topPadding = screenHeight * 0.03;

    return Scaffold(
      backgroundColor: const Color(0xFF62C3D0),
      body: SafeArea(
        child: Column(
          children: [
            // Custom Header - simplified without back button
            Padding(
              padding: EdgeInsets.fromLTRB(20, topPadding, 20, 20),
              child: Row(
                children: [
                  const Text(
                    "Pemantauan Admin",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white, size: 28),
                    onPressed: () {
                        if (_selectedNodeId != null) {
                          _startMonitoring(_selectedNodeId!);
                        } else {
                          _loadAvailableNodes();
                        }
                    },
                    tooltip: 'Refresh Data',
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout, color: Colors.white, size: 28),
                    onPressed: _logout,
                    tooltip: 'Logout',
                  ),
                ],
              ),
            ),

            // Node Selector
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
              child: _buildNodeSelector(),
            ),

            // Monitoring Content
            Expanded(
              child: _isLoadingNodes
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                      ),
                    )
                  : _selectedNodeId == null
                      ? _buildEmptyState()
                      : _buildMonitoringContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNodeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Pilih Node untuk Monitoring:',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0x42000000),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedNodeId,
              hint: const Text('Pilih Node'),
              isExpanded: true,
              icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF62C3D0)),
              items: _availableNodes.map((nodeId) {
                return DropdownMenuItem<String>(
                  value: nodeId,
                  child: Text(
                    'Node: $nodeId',
                    style: const TextStyle(
                      color: Color(0xFF62C3D0), 
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null && newValue != _selectedNodeId) {
                  setState(() {
                    _selectedNodeId = newValue;
                  });
                  _startMonitoring(newValue);
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.device_hub, size: 64, color: Colors.white70),
          const SizedBox(height: 16),
          const Text(
            'Tidak ada node yang tersedia',
            style: TextStyle(fontSize: 18, color: Colors.white),
          ),
          const SizedBox(height: 8),
          const Text(
            'Pastikan ada user yang telah mendaftarkan node',
            style: TextStyle(fontSize: 14, color: Colors.white70),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMonitoringContent() {
    if (_isLoadingData) {
      return const Center(
        child: CircularProgressIndicator(
          color: Colors.white,
        ),
      );
    }

    final pumpDetails = _getPumpStatusDetails(_pumpStatus);
    final valveDetails = _getValveStatusDetails(_valveStatus);

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildConnectionStatus(),
          const SizedBox(height: 16),
          if (_lastUpdate != null) ...[
            _buildLastUpdateInfo(),
            const SizedBox(height: 16),
          ],
          _buildMonitoringCard(
            'Level Air',
            '${_waterLevel.toStringAsFixed(1)} cm',
            Icons.opacity,
            _getWaterLevelColor(_waterLevel),
            _getWaterLevelStatus(_waterLevel),
          ),
          const SizedBox(height: 16),
          _buildMonitoringCard(
            'TDS (Total Dissolved Solids)',
            '${_tdsValue.toStringAsFixed(0)} ppm',
            Icons.science_outlined,
            _getTdsColor(_tdsValue),
            _getTdsStatus(_tdsValue),
          ),
          const SizedBox(height: 16),
          _buildMonitoringCard(
            'pH (Tingkat Keasaman)',
            _phValue.toStringAsFixed(1),
            Icons.thermostat,
            _getPhColor(_phValue),
            _getPhStatus(_phValue),
          ),
          const SizedBox(height: 16),
          _buildMonitoringCard(
            'Debit Air',
            '${_flowRate.toStringAsFixed(1)} L/min',
            Icons.water_drop,
            _getFlowRateColor(_flowRate),
            _getFlowRateStatus(_flowRate),
          ),
          const SizedBox(height: 16),
          _buildMonitoringCard(
            'Status Pompa',
            pumpDetails['text'],
            pumpDetails['icon'],
            pumpDetails['color'],
            _getPumpStatusDescription(_pumpStatus),
          ),
          const SizedBox(height: 16),
          _buildMonitoringCard(
            'Status Kran Node',
            valveDetails['text'],
            valveDetails['icon'],
            valveDetails['color'],
            _getValveStatusDescription(_valveStatus),
          ),
        ],
      ),
    );
  }

  // Added method to get pump status description
  String _getPumpStatusDescription(String status) {
    switch (status) {
      case '00':
        return 'Pompa tidak mendapat aliran listrik';
      case '01':
        return 'Pompa mengalami kerusakan teknis';
      case '10':
        return 'Pompa dalam keadaan standby/mati';
      case '11':
        return 'Pompa sedang bekerja aktif';
      default:
        return 'Status pompa tidak diketahui';
    }
  }

  // Method untuk mendapatkan deskripsi status valve
  String _getValveStatusDescription(String status) {
    switch (status) {
      case '00':
        return 'Kran tidak mendapat aliran listrik';
      case '01':
        return 'Kran mengalami kerusakan teknis';
      case '10':
        return 'Kran dalam keadaan tertutup';
      case '11':
        return 'Kran dalam keadaan terbuka';
      default:
        return 'Status kran tidak diketahui';
    }
  }

  // Method untuk mendapatkan warna debit air
  Color _getFlowRateColor(double flowRate) {
    if (flowRate <= 0) return const Color(0xFFEF5350); 
    if (flowRate < 5) return const Color(0xFFFF9800); 
    return const Color(0xFF4FC3F7);
  }

  // Method untuk mendapatkan status debit air
  String _getFlowRateStatus(double flowRate) {
    if (flowRate <= 0) return 'Tidak ada aliran air';
    if (flowRate < 2) return 'Aliran sangat rendah';
    if (flowRate < 5) return 'Aliran rendah';
    if (flowRate < 10) return 'Aliran normal';
    return 'Aliran tinggi';
  }

  Widget _buildInfoBox(String text, IconData icon, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color == const Color(0xFF4CAF50)
            ? const Color(0xFFE8F5E8) 
            : color == const Color(0xFFEF5350)
                ? const Color(0xFFFFEBEE) 
                : const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color == const Color(0xFF4CAF50)
              ? const Color(0xFF81C784)
              : color == const Color(0xFFEF5350)
                  ? const Color(0xFFEF9A9A)
                  : const Color(0xFF90CAF9),
          width: 1
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionStatus() {
    final text = _isConnected ? 'Node Terhubung' : 'Node Terputus';
    final icon = _isConnected ? Icons.wifi : Icons.wifi_off;
    final color = _isConnected ? const Color(0xFF4CAF50) : const Color(0xFFEF5350);
    return _buildInfoBox(text, icon, color);
  }

  Widget _buildLastUpdateInfo() {
    return _buildInfoBox(
      'Terakhir diperbarui: $_lastUpdate', 
      Icons.access_time_filled, 
      const Color(0xFF2196F3) 
    );
  }

  Widget _buildMonitoringCard(
    String title, String value, IconData icon, Color valueColor, String status) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xE617778F),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0x42000000),
            blurRadius: 12,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 40),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: valueColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  status,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.white60,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getWaterLevelColor(double level) {
    if (level <= 100) return const Color(0xFFEF5350);
    if (level <= 200) return const Color(0xFFFF9800);
    return const Color(0xFF4FC3F7);
  }

  String _getWaterLevelStatus(double level) {
    if (level <= 100) return 'Level Rendah';
    if (level <= 200) return 'Level Sedang';
    return 'Level Penuh';
  }

  Color _getTdsColor(double tds) {
    if (tds > 1000) return const Color(0xFFEF5350);
    return const Color(0xFF66BB6A); 
  }

  String _getTdsStatus(double tds) {
    if (tds > 1000) return 'Peringatan: TDS terlalu tinggi!';
    return 'Aman';
  }

  Color _getPhColor(double ph) {
    if (ph < 6.5 || ph > 8.5) return const Color(0xFFEF5350);
    if (ph < 7.0 || ph > 8.0) return const Color(0xFFFF9800);
    return const Color(0xFF66BB6A);
  }

  String _getPhStatus(double ph) {
    if (ph < 6.5) return 'Air terlalu asam';
    if (ph > 8.5) return 'Air terlalu basa';
    if (ph < 7.0 || ph > 8.0) return 'pH dalam batas wajar';
    return 'pH optimal untuk minum';
  }
}