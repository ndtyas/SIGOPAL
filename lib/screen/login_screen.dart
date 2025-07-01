import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sigopal/provider/auth_provider.dart';
import 'package:sigopal/widget/textfield/textfield_pass_widget.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Controllers for text input fields
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final usernameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.rememberMe) {
        emailController.text = auth.enteredEmail;
        passwordController.text = auth.enteredPassword;
      }
    });
  }

  @override
  void dispose() {
    // Dispose all TextEditingControllers to prevent memory leaks
    emailController.dispose();
    passwordController.dispose();
    usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch AuthProvider for state changes (e.g., islogin, showTopError, rememberMe)
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF62C3D0),
      body: Stack(
        children: [
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Back button
                    Align(
                      alignment: Alignment.topLeft,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () {
                          // Navigate back to the welcome screen
                          Navigator.pushReplacementNamed(context, '/welcome');
                        },
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Logo display, only shown in login mode
                    if (auth.islogin)
                      Column(
                        children: [
                          Image.asset(
                            'images/logoPutih.png',
                            width: 150,
                            height: 150,
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),

                    // Top error message display
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

                    // Login/Register Form Container
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
                        key: auth.form,
                        child: Column(
                          children: [
                            // Username field, only shown in register mode
                            if (!auth.islogin)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Username",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: Color(0xE617778F),
                                    ),
                                  ),
                                  const SizedBox(height: 15),
                                  TextFormField(
                                    controller: usernameController,
                                    autovalidateMode: AutovalidateMode.onUserInteraction,
                                    validator: (value) {
                                      if (value == null || value.trim().isEmpty) {
                                        return 'Username tidak boleh kosong';
                                      }
                                      return null;
                                    },
                                    onSaved: (value) {
                                      auth.enteredUsername = value!.trim();
                                    },
                                    style: const TextStyle(color: Color(0xE617778F), fontSize: 14),
                                    decoration: InputDecoration(
                                      hintText: "Masukkan Nama....",
                                      // Ganti TextStyle().withOpacity(0.6) dengan Color ARGB
                                      hintStyle: const TextStyle(color: Color(0x9917778F)), // 0x99 = 60% dari 0xE6
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(15),
                                        borderSide: const BorderSide(color: Color(0xE617778F)),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(15),
                                        borderSide: const BorderSide(color: Colors.green),
                                      ),
                                      suffixIcon: const Icon(Icons.person, color: Color(0xFF62C3D0)),
                                    ),
                                  ),
                                  const SizedBox(height: 15),
                                ],
                              ),

                            // Email field (present in both login and register)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Email",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: Color(0xE617778F),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TextFormField(
                                  controller: emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  autovalidateMode: AutovalidateMode.onUserInteraction,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Email tidak boleh kosong';
                                    }
                                    if (!value.contains('@')) {
                                      return 'Format email tidak valid';
                                    }
                                    return null;
                                  },
                                  onSaved: (value) {
                                    auth.enteredEmail = value!.trim();
                                  },
                                  style: const TextStyle(color: Color(0xE617778F), fontSize: 14),
                                  decoration: InputDecoration(
                                    hintText: "Masukkan Email...",
                                    // Ganti TextStyle().withOpacity(0.6) dengan Color ARGB
                                    hintStyle: const TextStyle(color: Color(0x9917778F)),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(15),
                                      borderSide: const BorderSide(color: Color(0xE617778F)),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(15),
                                      borderSide: const BorderSide(color: Colors.green),
                                    ),
                                    suffixIcon: const Icon(Icons.email, color: Color(0xFF62C3D0)),
                                  ),
                                ),
                                const SizedBox(height: 15),
                              ],
                            ),

                            // Custom TextfieldPasswordWidget for the password field
                            TextfieldPasswordWidget(
                              controller: passwordController,
                              textColor: const Color(0xE617778F),
                              iconColor: const Color(0xFF62C3D0),
                            ),
                            const SizedBox(height: 10),

                            // "Remember Me" Checkbox, only shown for login mode
                            if (auth.islogin)
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Row(
                                  children: [
                                    Checkbox(
                                      value: auth.rememberMe,
                                      onChanged: (newValue) {
                                        auth.setRememberMe(newValue ?? false);
                                      },
                                      activeColor: const Color(0xFF62C3D0),
                                    ),
                                    const Text(
                                      'Ingat Saya',
                                      style: TextStyle(color: Colors.black),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 20),

                            // Login/Register Button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () {
                                  FocusScope.of(context).unfocus();

                                  // Update AuthProvider's variables with current controller values
                                  auth.enteredEmail = emailController.text.trim();
                                  auth.enteredPassword = passwordController.text.trim();
                                  if (!auth.islogin) {
                                    auth.enteredUsername = usernameController.text.trim();
                                  }

                                  // Call submit (login) or register method based on current mode
                                  if (auth.islogin) {
                                    auth.submit(
                                      onSuccess: () async {
                                        // Langsung navigasi ke NodeScreen setelah login berhasil
                                        if (!context.mounted) return;
                                        Navigator.pushNamedAndRemoveUntil(context, '/node_screen', (route) => false);
                                      },
                                      onError: (msg) {
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text(msg)),
                                        );
                                      },
                                    );
                                  } else {
                                    auth.register(
                                      onError: (msg) {
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text(msg)),
                                        );
                                      },
                                      onSuccess: () {
                                        if (!context.mounted) return;
                                        setState(() {
                                          auth.islogin = true;
                                          auth.clearTopError();
                                          emailController.clear();
                                          passwordController.clear();
                                          usernameController.clear();
                                        });
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Registrasi berhasil! Silakan aktivasi email Anda sebelum login.')),
                                        );
                                      },
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF62C3D0),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                child: Text(
                                  auth.islogin ? 'Masuk' : 'Daftar',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            const SizedBox(height: 5),

                            // Toggle between Login and Register modes
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  auth.islogin = !auth.islogin;
                                  auth.clearTopError();
                                  emailController.clear();
                                  passwordController.clear();
                                  usernameController.clear();
                                  if (!auth.islogin) {
                                    auth.setRememberMe(false);
                                  }
                                });
                              },
                              child: Text(
                                auth.islogin ? 'Buat Akun' : 'Sudah Punya Akun',
                                style: const TextStyle(color: Colors.black, fontSize: 14),
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Resend Email Verification button, only shown in login mode
                            if (auth.islogin)
                              TextButton(
                                onPressed: () async {
                                  // Ensure controller values are passed to provider before resending
                                  auth.enteredEmail = emailController.text.trim();
                                  auth.enteredPassword = passwordController.text.trim();

                                  await auth.resendVerification(
                                    onFeedback: (msg) {
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(msg)),
                                      );
                                    },
                                  );
                                },
                                child: const Text(
                                  'Kirim Ulang Email Verifikasi',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 12,
                                  ),
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
        ],
      ),
    );
  }
}