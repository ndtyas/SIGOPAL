import 'package:flutter/material.dart';

class TextfieldNodeWidget extends StatelessWidget {
  final TextEditingController controller;
  final Color textColor;

  const TextfieldNodeWidget({
    super.key,
    required this.controller,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Node",
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
              return 'Node tidak boleh kosong';
            }
            if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(value.trim())) {
              return 'Node hanya boleh berisi huruf, angka, underscore, dan dash';
            }
            return null;
          },
          decoration: InputDecoration(
            hintText: "Masukkan Node...", 
            hintStyle: TextStyle(color: textColor.withAlpha((textColor.alpha * 0.6).round())),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(color: Color(0xE617778F)), 
            ),
            focusedBorder: OutlineInputBorder( 
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(color: Colors.green), 
            ),
            suffixIcon: const Icon(Icons.menu, color: Color(0xFF62C3D0)),
          ),
        ),
      ],
    );
  }
}