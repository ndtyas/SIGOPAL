import 'package:flutter/material.dart';
import 'package:sigopal/provider/auth_provider.dart';
import 'package:provider/provider.dart';

class TextfieldEmailWidget extends StatefulWidget {
  const TextfieldEmailWidget({
    super.key,
    required this.controller,
    this.textColor = Colors.black, // tambahkan textColor opsional
  });

  final TextEditingController controller;
  final Color textColor;

  @override
  State<TextfieldEmailWidget> createState() => _TextfieldEmailWidgetState();
}

class _TextfieldEmailWidgetState extends State<TextfieldEmailWidget> {
  @override
  Widget build(BuildContext context) {
    var loadAuth = Provider.of<AuthProvider>(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Email",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: widget.textColor, // <-- warna label
          ),
        ),
        const SizedBox(height: 15),
        TextFormField(
          controller: widget.controller,
          style: TextStyle(color: widget.textColor,
          fontSize: 14,
          ), // <-- warna teks input
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: (value) {
            if (value!.isEmpty) {
              return "Email tidak boleh kosong";
            } else if (!value.trim().contains("@")) {
              return "Email tidak valid";
            }
            return null;
          },
          onSaved: (value) {
            loadAuth.enteredEmail = value!;
          },
          decoration: InputDecoration(
            hintText: "Masukkan Email....",
            hintStyle: TextStyle(color: widget.textColor.withOpacity(0.6)), // <-- hint
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(color: widget.textColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(color: Colors.green),
            ),
          ),
        ),
      ],
    );
  }
}
