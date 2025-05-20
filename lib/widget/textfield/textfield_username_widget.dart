import 'package:flutter/material.dart';
import 'package:sigopal/provider/auth_provider.dart';
import 'package:provider/provider.dart';

class TextfieldUsernameWidget extends StatelessWidget {
  final TextEditingController controller;
  final Color textColor;

  const TextfieldUsernameWidget({
    super.key,
    required this.controller,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    var auth = Provider.of<AuthProvider>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Masukkan Nama",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: textColor,
          ),
        ),
        const SizedBox(height: 15),
        TextFormField(
          controller: controller,
          style: TextStyle(
            color: textColor,
            fontSize: 14,
          ),
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Nama tidak boleh kosong';
            }
            return null;
          },
          onSaved: (value) {
            auth.enteredUsername = value!.trim();
          },
          decoration: InputDecoration(
            hintText: "Nama Pengguna",
            hintStyle: TextStyle(color: textColor.withOpacity(0.6)),
            filled: true,
            fillColor: const Color(0xFFF1F1F1),
            suffixIcon: const Icon(Icons.person, color: Colors.grey),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}
