import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sigopal/provider/auth_provider.dart';
import 'package:sigopal/widget/textfield/textfield_node_widget.dart';
import 'package:sigopal/notification_service.dart';

class NodeScreen extends StatefulWidget {
  const NodeScreen({super.key});

  @override
  State<NodeScreen> createState() => _NodeScreenState();
}

class _NodeScreenState extends State<NodeScreen> {
  final nodeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  StreamSubscription<DatabaseEvent>? _statusSubscription;
  // Variabel untuk melacak status koneksi
  bool _isNodeDisconnected = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final auth = Provider.of<AuthProvider>(context, listen: false);
      await auth.initializeUserNode();

      if (!mounted) return;

      final currentNode = auth.getCurrentNode();
      if (currentNode != null && currentNode.isNotEmpty) {
        nodeController.text = currentNode;
        
        _setupNodeStatusListener(currentNode);
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      }
    });
  }

  void _setupNodeStatusListener(String nodeName) {
    _statusSubscription?.cancel();

    final dbRef = FirebaseDatabase.instance.ref('last_data/$nodeName/status');
    
    _statusSubscription = dbRef.onValue.listen((event) {
      final status = event.snapshot.value;
      
      if ((status == 0 || status == '0') && !_isNodeDisconnected) {
        NotificationService.showNotification(
          title: '⚠️ Peringatan Node',
          body: 'Koneksi node "$nodeName" terputus. Mohon segera dicek!',
        );
        setState(() {
          _isNodeDisconnected = true;
        });
      } 
      else if ((status == 1 || status == '1') && _isNodeDisconnected) {
        NotificationService.showNotification(
          title: '✅ Koneksi Pulih',
          body: 'Koneksi node "$nodeName" berhasil tersambung kembali.',
        );
        setState(() {
          _isNodeDisconnected = false;
        });
      }

    }, onError: (error) {
    });
  }

  void _verifyAndSaveNode() async {
    FocusScope.of(context).unfocus();
    final auth = Provider.of<AuthProvider>(context, listen: false);

    if (!_formKey.currentState!.validate()) {
      auth.setTopError('Harap masukkan node yang valid.');
      return;
    }
    auth.clearTopError();

    final node = nodeController.text.trim();
    await auth.verifyNodeAndSaveToFirestore(
      node: node,
      onSuccess: () {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Node berhasil diverifikasi!')),
        );
        _setupNodeStatusListener(node);
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      },
      onError: (msg) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      },
    );
  }

  @override
  void dispose() {
    nodeController.dispose();
    _statusSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF62C3D0),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'images/logoPutih.png',
                  width: 150,
                  height: 150,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Masukkan Node Anda',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                if (auth.showTopError)
                  Container(
                    width: MediaQuery.of(context).size.width * 0.7,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    margin: const EdgeInsets.only(bottom: 15),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      auth.topErrorMessage, 
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.all(35),
                  width: MediaQuery.of(context).size.width * 0.8,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                        color: Color.fromARGB(255, 98, 195, 208),
                        spreadRadius: 1,
                        blurRadius: 2,
                        offset: Offset(0, 3),
                      )
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextfieldNodeWidget(
                          controller: nodeController,
                          textColor: const Color(0xE617778F),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: auth.isLoading ? null : _verifyAndSaveNode,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF62C3D0),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: auth.isLoading
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 3,
                                    ),
                                  )
                                : const Text(
                                    'Masuk',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: auth.isLoading ? null : () {
                            auth.signOut();
                            if (!mounted) return;
                            Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                          },
                          child: const Text(
                            'Keluar',
                            style: TextStyle(color: Colors.black, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}