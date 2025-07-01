import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _fireAuth = FirebaseAuth.instance;
final _fireStore = FirebaseFirestore.instance;
final _fireRealtimeDb = FirebaseDatabase.instance;

class AuthProvider extends ChangeNotifier {
  final form = GlobalKey<FormState>();

  bool islogin = true;
  String enteredEmail = '';
  String enteredPassword = '';
  String enteredUsername = '';
  String enteredNode = ''; 

  bool _showTopError = false;
  String _topErrorMessage = '';

  bool _rememberMe = false;
  late SharedPreferences _prefs;

  AuthProvider() {
    _initPrefs();
  }

  bool get showTopError => _showTopError;
  String get topErrorMessage => _topErrorMessage;
  bool get rememberMe => _rememberMe;

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

  Future<void> submit({
    required Function onSuccess,
    required Function(String message) onError,
  }) async {
    FocusManager.instance.primaryFocus?.unfocus();

    final isValid = form.currentState?.validate() ?? false;
    if (!isValid) {
      setTopError('Masukkan email dan password yang valid.');
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
    }
  }

  Future<void> register({
    required Function(String message) onError,
    required Function onSuccess,
  }) async {
    FocusManager.instance.primaryFocus?.unfocus();

    final isValid = form.currentState?.validate() ?? false;
    if (!isValid) {
      setTopError('Harap lengkapi semua bidang yang diperlukan dengan benar.');
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
    }
  }

  Future<void> verifyNodeExistInRealtimeDb({
    required String node,
    required Function onSuccess,
    required Function(String message) onError,
  }) async {
    FocusManager.instance.primaryFocus?.unfocus();

    if (node.trim().isEmpty) {
      setTopError('Node tidak boleh kosong.');
      onError(topErrorMessage);
      return;
    }

    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(node.trim())) {
      setTopError('Node hanya boleh berisi huruf, angka, underscore, dan dash');
      onError(topErrorMessage);
      return;
    }

    clearTopError();

    final user = _fireAuth.currentUser;
    if (user == null) {
      setTopError('Tidak ada pengguna yang masuk.');
      onError(topErrorMessage);
      return;
    }

    try {
      final nodeRef = _fireRealtimeDb.ref('last_data').child(node);
      final snapshot = await nodeRef.get();

      if (snapshot.exists && snapshot.value != null) {
        enteredNode = node; 
        onSuccess();
      } else {
        setTopError('Node "$node" tidak ditemukan di database atau tidak memiliki data.');
        onError(topErrorMessage);
      }
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
    }
  }

  String? getCurrentNode() {
    return enteredNode.isNotEmpty ? enteredNode : null;
  }

  Future<void> resendVerification({
    required Function(String message) onFeedback,
  }) async {
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
    }
  }

  Future<void> signOut() async {
    await _fireAuth.signOut();
    await clearSavedCredentials();
    enteredNode = '';
    notifyListeners();
  }
}