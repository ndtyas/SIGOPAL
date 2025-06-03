import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sigopal/provider/auth_provider.dart';
import 'package:sigopal/widget/textfield/textfield_pass_widget.dart'; // Assuming this widget exists

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final usernameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Use addPostFrameCallback to ensure context is available after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      // Pre-fill controllers if rememberMe is true and credentials are loaded
      if (auth.rememberMe) {
        emailController.text = auth.enteredEmail;
        passwordController.text = auth.enteredPassword;
      }
    });
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Listen to AuthProvider changes to update UI
    final auth = Provider.of<AuthProvider>(context);

    // Ensure controllers are updated when AuthProvider state changes (e.g., after loading)
    // This is important to reflect the pre-filled values
    if (auth.rememberMe && emailController.text.isEmpty && passwordController.text.isEmpty) {
        emailController.text = auth.enteredEmail;
        passwordController.text = auth.enteredPassword;
    }


    return Scaffold(
      backgroundColor: const Color(0xFF62C3D0),
      body: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.3,
              child: Image.asset(
                'images/air.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Tombol kembali
                    Align(
                      alignment: Alignment.topLeft,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () {
                          // Optional: Clear credentials if the user goes back from login
                          // auth.clearSavedCredentials();
                          Navigator.pushReplacementNamed(context, '/welcome');
                        },
                      ),
                    ),
                    const SizedBox(height: 10),

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
                        key: auth.form,
                        child: Column(
                          children: [
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
                                      hintStyle: TextStyle(color: Color(0xE617778F).withOpacity(0.6)),
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
                                    hintStyle: TextStyle(color: Color(0xE617778F).withOpacity(0.6)),
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
                            TextfieldPasswordWidget(
                              controller: passwordController,
                              textColor: Color(0xE617778F),
                              iconColor: const Color(0xFF62C3D0),
                            ),
                            const SizedBox(height: 10), // Adjusted space
                            // New: "Remember Me" Checkbox
                            if (auth.islogin) // Only show this for login mode
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
                            const SizedBox(height: 20), // Adjusted space
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () {
                                  FocusScope.of(context).unfocus();
                                  // Make sure the provider's variables are up-to-date with controllers
                                  auth.enteredEmail = emailController.text.trim();
                                  auth.enteredPassword = passwordController.text.trim();
                                  if (!auth.islogin) {
                                    auth.enteredUsername = usernameController.text.trim();
                                  }

                                  if (auth.islogin) {
                                    auth.submit(
                                      onSuccess: () {
                                        if (!context.mounted) return;
                                        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
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
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF62C3D0),
                                  foregroundColor: Colors.white,
                                ),
                                child: Text(auth.islogin ? 'Masuk' : 'Daftar'),
                              ),
                            ),
                            const SizedBox(height: 5),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  auth.islogin = !auth.islogin;
                                  auth.clearTopError();
                                  // Clear controllers when switching mode, to avoid carrying over values
                                  emailController.clear();
                                  passwordController.clear();
                                  usernameController.clear();
                                  // Also reset rememberMe when switching from login to register
                                  if (!auth.islogin) {
                                    auth.setRememberMe(false);
                                  }
                                });
                              },
                              child: Text(
                                auth.islogin ? 'Buat Akun' : 'Sudah Punya Akun',
                                style: const TextStyle(color: Colors.black),
                              ),
                            ),
                            const SizedBox(height: 10),
                            if (!auth.islogin)
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