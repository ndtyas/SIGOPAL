import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;

final _fireAuth = FirebaseAuth.instance;
final _fireStore = FirebaseFirestore.instance;
final _fireRealtimeDb = FirebaseDatabase.instance;

class AuthProvider extends ChangeNotifier {
  final form = GlobalKey<FormState>();

  bool islogin = true;
  String enteredEmail = '';
  String enteredPassword = '';
  String enteredUsername = '';

  bool _showTopError = false;
  String _topErrorMessage = '';

  bool _rememberMe = false;
  late SharedPreferences _prefs;

  String? _currentNodeId;
  bool _isLoading = false;

  AuthProvider() {
    _initPrefs();
    _fireAuth.authStateChanges().listen((user) {
      if (user != null) {
        initializeUserNode(); 
      } else {
        _currentNodeId = null;
        notifyListeners();
      }
    });
  }

  bool get showTopError => _showTopError;
  String get topErrorMessage => _topErrorMessage;
  bool get rememberMe => _rememberMe;
  bool get isLoading => _isLoading;
  String? getCurrentNode() => _currentNodeId;

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    _loadRememberMeState();
    _loadSavedCredentials();
  }

  void _loadRememberMeState() {
    _rememberMe = _prefs.getBool('remember_me') ?? false;
  }

  void setRememberMe(bool value) async {
    _rememberMe = value;
    await _prefs.setBool('remember_me', value);
    notifyListeners();
  }

  Future<void> _saveCredentials(String email, String password) async {
    await _prefs.setString('saved_email', email);
    await _prefs.setString('saved_password', password);
  }

  Future<void> _loadSavedCredentials() async {
    _rememberMe = _prefs.getBool('remember_me') ?? false;
    if (_rememberMe) {
      final savedEmail = _prefs.getString('saved_email');
      final savedPassword = _prefs.getString('saved_password');
      if (savedEmail != null && savedPassword != null) {
        enteredEmail = savedEmail;
        enteredPassword = savedPassword;
      }
    }
    notifyListeners();
  }

  Future<void> clearSavedCredentials() async {
    await _prefs.remove('saved_email');
    await _prefs.remove('saved_password');
    await _prefs.setBool('remember_me', false);
    enteredEmail = '';
    enteredPassword = '';
    _rememberMe = false;
    notifyListeners();
  }

  void setTopError(String message) {
    _showTopError = true;
    _topErrorMessage = message;
    notifyListeners();
  }

  void clearTopError() {
    _showTopError = false;
    _topErrorMessage = '';
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  Future<void> submit({
    required Function onSuccess,
    required Function(String message) onError,
  }) async {
    _setLoading(true);
    FocusManager.instance.primaryFocus?.unfocus();

    final isValid = form.currentState?.validate() ?? false;
    if (!isValid) {
      setTopError('Masukkan email dan password yang valid.');
      _setLoading(false);
      return;
    }

    form.currentState?.save();
    clearTopError();

    try {
      final userCredential = await _fireAuth.signInWithEmailAndPassword(
        email: enteredEmail,
        password: enteredPassword,
      );

      final user = userCredential.user;

      if (user != null && !user.emailVerified) {
        await _fireAuth.signOut();
        setTopError('Aktivasi Akun Terlebih Dahulu. Silakan cek email Anda.');
        onError(topErrorMessage);
        return;
      }

      if (_rememberMe) {
        await _saveCredentials(enteredEmail, enteredPassword);
      } else {
        await clearSavedCredentials();
      }

      clearTopError();
      onSuccess(); 
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Terjadi kesalahan saat masuk.';
      if (e.code == 'user-not-found' || e.code == 'wrong-password') {
        errorMessage = 'Email atau password salah.';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'Format email tidak valid.';
      } else if (e.code == 'too-many-requests') {
        errorMessage = 'Terlalu banyak percobaan login. Coba lagi nanti.';
      } else if (e.code == 'network-request-failed') {
        errorMessage = 'Tidak ada koneksi internet. Silakan coba lagi.';
      }
      setTopError(errorMessage);
      onError(errorMessage);
    } catch (e) {
      setTopError('Terjadi kesalahan tidak diketahui: $e');
      onError('Terjadi kesalahan tidak diketahui: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> register({
    required Function(String message) onError,
    required Function onSuccess,
  }) async {
    _setLoading(true);
    FocusManager.instance.primaryFocus?.unfocus();

    final isValid = form.currentState?.validate() ?? false;
    if (!isValid) {
      setTopError('Harap lengkapi semua bidang yang diperlukan dengan benar.');
      _setLoading(false);
      return;
    }

    form.currentState?.save();
    clearTopError();

    try {
      final userCredential = await _fireAuth.createUserWithEmailAndPassword(
        email: enteredEmail,
        password: enteredPassword,
      );

      await userCredential.user!.updateDisplayName(enteredUsername);

      await _fireStore.collection('users').doc(userCredential.user!.uid).set({
        'username': enteredUsername,
        'email': enteredEmail,
        'createdAt': Timestamp.now(),
        'uid': userCredential.user!.uid,
      });

      await userCredential.user!.sendEmailVerification();
      await _fireAuth.signOut();

      if (_rememberMe) {
        await _saveCredentials(enteredEmail, enteredPassword);
      } else {
        await clearSavedCredentials();
      }

      onSuccess();
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Terjadi kesalahan saat pendaftaran.';
      if (e.code == 'email-already-in-use') {
        errorMessage = 'Email ini sudah terdaftar.';
      } else if (e.code == 'weak-password') {
        errorMessage = 'Kata sandi terlalu lemah.';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'Format email tidak valid.';
      } else if (e.code == 'network-request-failed') {
        errorMessage = 'Tidak ada koneksi internet. Silakan coba lagi.';
      }
      setTopError(errorMessage);
      onError(errorMessage);
    } catch (e) {
      setTopError('Terjadi kesalahan tidak diketahui: $e');
      onError('Terjadi kesalahan tidak diketahui: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> verifyNodeAndSaveToFirestore({
    required String node,
    required VoidCallback onSuccess,
    required Function(String message) onError,
  }) async {
    _setLoading(true);
    FocusManager.instance.primaryFocus?.unfocus();
    clearTopError();

    if (node.trim().isEmpty) {
      setTopError('Node tidak boleh kosong.');
      onError(topErrorMessage);
      _setLoading(false);
      return;
    }

    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(node.trim())) {
      setTopError('Node hanya boleh berisi huruf, angka, underscore, dan dash');
      onError(topErrorMessage);
      _setLoading(false);
      return;
    }

    final user = _fireAuth.currentUser;
    if (user == null) {
      setTopError('Tidak ada pengguna yang masuk. Harap login kembali.');
      onError(topErrorMessage);
      _setLoading(false);
      return;
    }

    try {
      final nodeRef = _fireRealtimeDb.ref('last_data').child(node);
      final snapshot = await nodeRef.get();

      if (!snapshot.exists || snapshot.value == null) {
        setTopError('Node "$node" tidak ditemukan di database atau tidak memiliki data.');
        onError(topErrorMessage);
        return;
      }
      
      // Simpan node_id ke dokumen pengguna di Firestore
      await _fireStore.collection('users').doc(user.uid).set(
        {'node_id': node},
        SetOptions(merge: true),
      );

      // Simpan node_id ke state AuthProvider
      _currentNodeId = node;
      notifyListeners();

      onSuccess();
    } on FirebaseException catch (e) {
      String errorMessage = 'Terjadi kesalahan saat memverifikasi node.';
      if (e.code == 'permission-denied') {
        errorMessage = 'Akses ditolak ke Realtime Database. Pastikan Anda memiliki izin.';
      } else if (e.code == 'network-request-failed') {
        errorMessage = 'Tidak ada koneksi internet. Silakan coba lagi.';
      }
      setTopError(errorMessage);
      onError(errorMessage);
    } catch (e) {
      setTopError('Terjadi kesalahan tidak diketahui: $e');
      onError('Terjadi kesalahan tidak diketahui: $e');
    } finally {
      _setLoading(false);
    }
  }

  // --- Initialize User Node (read from Firestore) ---
  Future<void> initializeUserNode() async {
    final user = _fireAuth.currentUser;
    if (user != null) {
      try {
        final userDoc = await _fireStore.collection('users').doc(user.uid).get();
        if (userDoc.exists && userDoc.data() != null) {
          _currentNodeId = userDoc.data()!['node_id'] as String?;
          developer.log('Node ID initialized from Firestore: $_currentNodeId', name: 'AuthProvider');
        } else {
          _currentNodeId = null;
          developer.log('User document or node_id not found for ${user.uid} in Firestore.', name: 'AuthProvider');
        }
      } catch (e) {
        developer.log('Error initializing user node from Firestore: $e', name: 'AuthProvider');
        _currentNodeId = null;
      }
    } else {
      _currentNodeId = null;
    }
    notifyListeners();
  }

  Future<void> resendVerification({
    required Function(String message) onFeedback,
  }) async {
    _setLoading(true);
    FocusManager.instance.primaryFocus?.unfocus();
    clearTopError();

    try {
      User? currentUser = _fireAuth.currentUser;

      if (currentUser == null || currentUser.email != enteredEmail) {
        final userCredential = await _fireAuth.signInWithEmailAndPassword(
          email: enteredEmail,
          password: enteredPassword,
        );
        currentUser = userCredential.user;
      }

      if (currentUser != null) {
        if (!currentUser.emailVerified) {
          await currentUser.sendEmailVerification();
          await _fireAuth.signOut();
          onFeedback("Link verifikasi telah dikirim ulang ke email Anda.");
        } else {
          await _fireAuth.signOut();
          onFeedback("Email sudah diverifikasi, silakan login.");
        }
      } else {
        String message = "Tidak dapat mengirim ulang verifikasi. Harap masukkan email dan password yang benar.";
        onFeedback(message);
        setTopError(message);
      }
    } on FirebaseAuthException catch (e) {
      String feedbackMessage = "Gagal mengirim ulang verifikasi: ";
      if (e.code == 'user-not-found' || e.code == 'wrong-password') {
        feedbackMessage += 'Email atau password salah.';
      } else if (e.code == 'invalid-email') {
        feedbackMessage += 'Format email tidak valid.';
      } else if (e.code == 'too-many-requests') {
        feedbackMessage += 'Terlalu banyak percobaan. Coba lagi nanti.';
      } else if (e.code == 'network-request-failed') {
        feedbackMessage += 'Tidak ada koneksi internet. Silakan coba lagi.';
      } else {
        feedbackMessage += e.message ?? 'Terjadi kesalahan.';
      }
      setTopError(feedbackMessage);
      onFeedback(feedbackMessage);
    } catch (e) {
      setTopError('Terjadi kesalahan tidak diketahui: $e');
      onFeedback("Terjadi kesalahan tidak diketahui saat mengirim ulang verifikasi: $e");
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signOut() async {
    _setLoading(true);
    try {
      await _fireAuth.signOut();
      await clearSavedCredentials();
      _currentNodeId = null;
      enteredEmail = '';
      enteredPassword = '';
    } catch (e) {
      developer.log('Error during sign out: $e', name: 'AuthProvider');
      setTopError("Gagal keluar: $e");
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }
}