import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Import this

final _fireAuth = FirebaseAuth.instance;
final _fireStore = FirebaseFirestore.instance;

class AuthProvider extends ChangeNotifier {
  final form = GlobalKey<FormState>();

  var islogin = true;
  var enteredEmail = '';
  var enteredPassword = '';
  var enteredUsername = '';

  bool showTopError = false;
  String topErrorMessage = '';

  // New: "Remember Me" state
  bool _rememberMe = false;
  bool get rememberMe => _rememberMe;

  // New: SharedPreferences instance
  late SharedPreferences _prefs;

  AuthProvider() {
    _initPrefs(); // Call initialization in the constructor
  }

  // New: Initialize SharedPreferences and load saved state
  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    _loadRememberMeState();
    _loadSavedCredentials(); // Load saved credentials on startup
  }

  // New: Load the last saved "remember me" preference
  void _loadRememberMeState() {
    _rememberMe = _prefs.getBool('remember_me') ?? false;
    notifyListeners(); // Notify listeners that rememberMe state might have changed
  }

  // New: Set "remember me" preference and save it
  void setRememberMe(bool value) {
    _rememberMe = value;
    _prefs.setBool('remember_me', value);
    notifyListeners();
  }

  // New: Save email and password to SharedPreferences
  // IMPORTANT: For production, consider storing a secure token, not raw password.
  Future<void> _saveCredentials(String email, String password) async {
    await _prefs.setString('saved_email', email);
    await _prefs.setString('saved_password', password);
  }

  // New: Load saved credentials from SharedPreferences
  Future<void> _loadSavedCredentials() async {
    _rememberMe = _prefs.getBool('remember_me') ?? false;
    if (_rememberMe) {
      final savedEmail = _prefs.getString('saved_email');
      final savedPassword = _prefs.getString('saved_password');
      if (savedEmail != null && savedPassword != null) {
        enteredEmail = savedEmail;
        enteredPassword = savedPassword;
        // Do NOT automatically log in here. Let the UI trigger the login.
        notifyListeners(); // Update UI with pre-filled fields
      }
    }
  }

  // New: Clear saved credentials from SharedPreferences
  Future<void> clearSavedCredentials() async {
    await _prefs.remove('saved_email');
    await _prefs.remove('saved_password');
    await _prefs.setBool('remember_me', false); // Reset the checkbox state
    enteredEmail = ''; // Clear the in-memory values too
    enteredPassword = '';
    _rememberMe = false;
    notifyListeners();
  }

  void clearTopError() {
    showTopError = false;
    topErrorMessage = '';
    notifyListeners();
  }

  Future<void> submit({
    required Function onSuccess,
    required Function(String message) onError,
  }) async {
    final isvalid = form.currentState?.validate() ?? false;
    if (!isvalid) return;

    form.currentState?.save();
    clearTopError(); // Clear previous errors

    try {
      final userCredential = await _fireAuth.signInWithEmailAndPassword(
        email: enteredEmail,
        password: enteredPassword,
      );

      final user = userCredential.user;

      if (user != null && !user.emailVerified) {
        await _fireAuth.signOut(); // Ensure user is logged out if email not verified
        showTopError = true;
        topErrorMessage = 'Aktivasi Akun Terlebih Dahulu';
        notifyListeners();
        return;
      }

      // New: Save credentials if "remember me" is checked
      if (_rememberMe) {
        await _saveCredentials(enteredEmail, enteredPassword);
      } else {
        await clearSavedCredentials(); // Clear if it was unchecked
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
      }
      showTopError = true;
      topErrorMessage = errorMessage;
      notifyListeners();
      onError(errorMessage);
    } catch (e) {
      showTopError = true;
      topErrorMessage = 'Terjadi kesalahan tidak diketahui: $e';
      notifyListeners();
      onError('Terjadi kesalahan tidak diketahui: $e');
    }
  }

  Future<void> register({
    required Function(String message) onError,
  }) async {
    final isvalid = form.currentState?.validate() ?? false;
    if (!isvalid) return;

    form.currentState?.save();
    clearTopError(); // Clear previous errors

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
      });

      await userCredential.user!.sendEmailVerification();
      await _fireAuth.signOut(); // Logout after registration

      // New: If rememberMe is checked during registration, save credentials
      // This might be useful if you want to auto-fill the login screen after registration
      if (_rememberMe) {
        await _saveCredentials(enteredEmail, enteredPassword);
      } else {
        await clearSavedCredentials();
      }

      onError('Registrasi berhasil! Silakan aktivasi email sebelum login.');
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Terjadi kesalahan saat pendaftaran.';
      if (e.code == 'email-already-in-use') {
        errorMessage = 'Email ini sudah terdaftar.';
      } else if (e.code == 'weak-password') {
        errorMessage = 'Password terlalu lemah.';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'Format email tidak valid.';
      }
      showTopError = true;
      topErrorMessage = errorMessage;
      notifyListeners();
      onError(errorMessage);
    } catch (e) {
      showTopError = true;
      topErrorMessage = 'Terjadi kesalahan tidak diketahui: $e';
      notifyListeners();
      onError('Terjadi kesalahan tidak diketahui: $e');
    }
  }

  Future<void> resendVerification({
    required Function(String message) onFeedback,
  }) async {
    final isValid = form.currentState?.validate() ?? false;
    if (!isValid) return;

    form.currentState?.save();
    clearTopError(); // Clear previous errors

    try {
      // Temporarily sign in to get the user object for verification
      final userCredential = await _fireAuth.signInWithEmailAndPassword(
        email: enteredEmail,
        password: enteredPassword,
      );

      if (!userCredential.user!.emailVerified) {
        await userCredential.user!.sendEmailVerification();
        await _fireAuth.signOut(); // Logout again after sending
        onFeedback("Link verifikasi telah dikirim ulang ke email Anda.");
      } else {
        await _fireAuth.signOut(); // Logout if already verified
        onFeedback("Email sudah diverifikasi, silakan login.");
      }
    } on FirebaseAuthException catch (e) {
      String feedbackMessage = "Gagal mengirim ulang verifikasi: ";
      if (e.code == 'user-not-found' || e.code == 'wrong-password') {
        feedbackMessage += 'Email atau password salah.';
      } else if (e.code == 'invalid-email') {
        feedbackMessage += 'Format email tidak valid.';
      } else if (e.code == 'too-many-requests') {
        feedbackMessage += 'Terlalu banyak percobaan. Coba lagi nanti.';
      } else {
        feedbackMessage += e.message ?? 'Terjadi kesalahan.';
      }
      showTopError = true;
      topErrorMessage = feedbackMessage;
      notifyListeners();
      onFeedback(feedbackMessage);
    } catch (e) {
      showTopError = true;
      topErrorMessage = 'Terjadi kesalahan tidak diketahui: $e';
      notifyListeners();
      onFeedback("Terjadi kesalahan tidak diketahui saat mengirim ulang verifikasi: $e");
    }
  }

  // Add a signOut method to clear credentials on explicit logout
  Future<void> signOut() async {
    await _fireAuth.signOut();
    await clearSavedCredentials(); // Clear saved data on logout
    notifyListeners();
  }
}