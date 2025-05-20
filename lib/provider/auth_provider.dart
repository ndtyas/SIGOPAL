import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

final _fireAuth = FirebaseAuth.instance;

class AuthProvider extends ChangeNotifier {
  final form = GlobalKey<FormState>();

  var islogin = true;
  var enteredEmail = '';
  var enteredPassword = '';
  var enteredUsername = ''; // ✅ Tambahan username saat register

  // Untuk error pop-up atas
  bool showTopError = false;
  String topErrorMessage = '';

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

    try {
      final userCredential = await _fireAuth.signInWithEmailAndPassword(
        email: enteredEmail,
        password: enteredPassword,
      );

      final user = userCredential.user;

      if (user != null && !user.emailVerified) {
        await _fireAuth.signOut();
        showTopError = true;
        topErrorMessage = 'Aktivasi Akun Terlebih Dahulu';
        notifyListeners();
        return;
      }

      clearTopError();
      onSuccess();
    } catch (e) {
      if (e is FirebaseAuthException) {
        onError(e.message ?? 'Terjadi kesalahan.');
      } else {
        onError('Terjadi kesalahan tidak diketahui.');
      }
    }

    notifyListeners();
  }

  Future<void> register({
    required Function(String message) onError,
  }) async {
    final isvalid = form.currentState?.validate() ?? false;
    if (!isvalid) return;

    form.currentState?.save();

    try {
      final userCredential = await _fireAuth.createUserWithEmailAndPassword(
        email: enteredEmail,
        password: enteredPassword,
      );

      // ✅ Simpan username ke Firebase Auth profile
      await userCredential.user!.updateDisplayName(enteredUsername);

      // ✅ Kirim email verifikasi
      await userCredential.user!.sendEmailVerification();

      await _fireAuth.signOut(); // Logout setelah registrasi

      onError('Registrasi berhasil! Silakan aktivasi email sebelum login.');
    } catch (e) {
      if (e is FirebaseAuthException) {
        onError(e.message ?? 'Terjadi kesalahan.');
      } else {
        onError('Terjadi kesalahan tidak diketahui.');
      }
    }
  }

  Future<void> resendVerification({
    required Function(String message) onFeedback,
  }) async {
    final isValid = form.currentState?.validate() ?? false;
    if (!isValid) return;

    form.currentState?.save();

    try {
      final userCredential = await _fireAuth.signInWithEmailAndPassword(
        email: enteredEmail,
        password: enteredPassword,
      );

      if (!userCredential.user!.emailVerified) {
        await userCredential.user!.sendEmailVerification();
        await _fireAuth.signOut();
        onFeedback("Link verifikasi telah dikirim ulang ke email Anda.");
      } else {
        onFeedback("Email sudah diverifikasi, silakan login.");
      }
    } catch (e) {
      onFeedback("Gagal mengirim ulang verifikasi. Periksa kembali email dan password.");
    }
  }
}
