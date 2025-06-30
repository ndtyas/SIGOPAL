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

  // "Remember Me" state
  bool _rememberMe = false;

  // SharedPreferences instance
  late SharedPreferences _prefs;

  AuthProvider() {
    _initPrefs();
  }

  // Public getters for UI to consume
  bool get showTopError => _showTopError;
  String get topErrorMessage => _topErrorMessage;
  bool get rememberMe => _rememberMe;

  // Initialize SharedPreferences and load saved state
  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    _loadRememberMeState();
    _loadSavedCredentials();
  }

  // Load the last saved "remember me" preference
  void _loadRememberMeState() {
    _rememberMe = _prefs.getBool('remember_me') ?? false;
  }

  // Set "remember me" preference and save it
  void setRememberMe(bool value) async {
    _rememberMe = value;
    await _prefs.setBool('remember_me', value);
    notifyListeners();
  }

  // Save email and password to SharedPreferences
  Future<void> _saveCredentials(String email, String password) async {
    await _prefs.setString('saved_email', email);
    await _prefs.setString('saved_password', password);
  }

  // Load saved credentials from SharedPreferences
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

  // Clear saved credentials from SharedPreferences
  Future<void> clearSavedCredentials() async {
    await _prefs.remove('saved_email');
    await _prefs.remove('saved_password');
    await _prefs.setBool('remember_me', false);
    enteredEmail = '';
    enteredPassword = '';
    _rememberMe = false;
    notifyListeners();
  }

  // Public method to set top error message and notify listeners
  void setTopError(String message) {
    _showTopError = true;
    _topErrorMessage = message;
    notifyListeners();
  }

  // Public method to clear top error and notify listeners
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

      // Check for email verification before allowing login
      if (user != null && !user.emailVerified) {
        await _fireAuth.signOut();
        setTopError('Aktivasi Akun Terlebih Dahulu. Silakan cek email Anda.');
        onError(topErrorMessage);
        return;
      }

      // Save credentials if "remember me" is checked
      if (_rememberMe) {
        await _saveCredentials(enteredEmail, enteredPassword);
      } else {
        await clearSavedCredentials();
      }

      clearTopError(); // Clear any error after successful login
      onSuccess(); // Now onSuccess will navigate to NodeScreen or HomePage
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
      setTopError(errorMessage); // Use new method
      onError(errorMessage);
    } catch (e) {
      setTopError('Terjadi kesalahan tidak diketahui: $e'); // Use new method
      onError('Terjadi kesalahan tidak diketahui: $e');
    }
  }

  Future<void> register({
    required Function(String message) onError,
    required Function onSuccess,
  }) async {
    // Dismiss keyboard
    FocusManager.instance.primaryFocus?.unfocus();

    final isValid = form.currentState?.validate() ?? false;
    if (!isValid) {
      setTopError('Harap lengkapi semua bidang yang diperlukan dengan benar.');
      return;
    }

    form.currentState?.save();
    clearTopError();

    try {
      // 1. Create user with Firebase Authentication
      final userCredential = await _fireAuth.createUserWithEmailAndPassword(
        email: enteredEmail,
        password: enteredPassword,
      );

      // 2. Update user's display name in Firebase Auth
      await userCredential.user!.updateDisplayName(enteredUsername);

      // 3. Store user data to Firestore (without node yet)
      await _fireStore.collection('users').doc(userCredential.user!.uid).set({
        'username': enteredUsername,
        'email': enteredEmail,
        'node': null,
        'createdAt': Timestamp.now(),
        'uid': userCredential.user!.uid,
      });

      // 4. Send email verification
      await userCredential.user!.sendEmailVerification();
      await _fireAuth.signOut();

      // If rememberMe is checked during registration, save credentials
      if (_rememberMe) {
        await _saveCredentials(enteredEmail, enteredPassword);
      } else {
        // If not remembering, ensure previous saved credentials are cleared
        await clearSavedCredentials();
      }

      onSuccess(); // Indicate successful registration to move to login screen
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

  // New method to save user's node after login
  Future<void> saveUserNode({
    required String node,
    required Function onSuccess,
    required Function(String message) onError,
  }) async {
    FocusManager.instance.primaryFocus?.unfocus();

    if (node.trim().isEmpty) {
      setTopError('Node tidak boleh kosong.'); // Use new method
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
      // 1. Check if the node exists in Realtime Database
      final nodeRef = _fireRealtimeDb.ref('last_data').child(node);
      final snapshot = await nodeRef.get();

      if (!snapshot.exists || snapshot.value == null) {
        setTopError('Node "$node" tidak ditemukan di database. Harap masukkan node yang valid.');
        onError(topErrorMessage);
        return;
      }

      // 2. Check if the node is already associated with another user in Firestore
      final existingNodeUserQuery = await _fireStore
          .collection('users')
          .where('node', isEqualTo: node)
          .limit(1)
          .get();

      if (existingNodeUserQuery.docs.isNotEmpty) {
        // Allow the current user to re-save their *own* existing node, but prevent assigning a node already taken by someone else
        final existingNodeDoc = existingNodeUserQuery.docs.first;
        if (existingNodeDoc.id != user.uid) {
          setTopError('Node "$node" sudah digunakan oleh pengguna lain. Silakan pilih node lain.'); 
          onError(topErrorMessage);
          return;
        }
      }

      // 3. Update user data in Firestore with the node
      await _fireStore.collection('users').doc(user.uid).update({
        'node': node,
      });

      enteredNode = node;
      onSuccess();
    } on FirebaseException catch (e) {
      String errorMessage = 'Terjadi kesalahan saat menyimpan node.';
      if (e.code == 'network-request-failed') {
        errorMessage = 'Tidak ada koneksi internet. Silakan coba lagi.';
      }
      setTopError(errorMessage);
      onError(errorMessage);
    } catch (e) {
      setTopError('Terjadi kesalahan tidak diketahui: $e'); 
      onError('Terjadi kesalahan tidak diketahui: $e');
    }
  }

  Future<void> resendVerification({
    required Function(String message) onFeedback,
  }) async {
    FocusManager.instance.primaryFocus?.unfocus();

    clearTopError();

    try {
      User? currentUser = _fireAuth.currentUser;

      // If current user is null or doesn't match the entered email, try to sign in
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

  // Add a signOut method to clear credentials on explicit logout
  Future<void> signOut() async {
    await _fireAuth.signOut();
    await clearSavedCredentials();
    notifyListeners();
  }

  // Get user's node from Firestore
  Future<String?> getUserNode() async {
    final user = _fireAuth.currentUser;
    if (user != null) {
      try {
        final doc = await _fireStore.collection('users').doc(user.uid).get();
        if (doc.exists) {
          return doc.data()?['node'];
        }
      } catch (e) {
        debugPrint('Error getting user node: $e');
      }
    }
    return null;
  }
}
