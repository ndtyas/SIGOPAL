import 'package:flutter/material.dart';
import 'package:sigopal/provider/auth_provider.dart';
import 'package:provider/provider.dart';

class TextfieldPasswordWidget extends StatefulWidget {
  const TextfieldPasswordWidget({
    super.key,
    required this.controller,
    this.textColor = Colors.black, // Tambahkan parameter opsional
    this.iconColor = Colors.black,
  });

  final TextEditingController controller;
  final Color textColor;
  final Color iconColor;

  @override
  State<TextfieldPasswordWidget> createState() => _TextfieldPasswordWidgetState();
}

class _TextfieldPasswordWidgetState extends State<TextfieldPasswordWidget> {
  bool obscureText = true;

  @override
  Widget build(BuildContext context) {
    var loadAuth = Provider.of<AuthProvider>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Password",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: widget.textColor,
          ),
        ),
        const SizedBox(height: 15),
        TextFormField(
          controller: widget.controller,
          obscureText: obscureText,
          style: TextStyle(color: widget.textColor,
          fontSize: 14,
          ),
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: (value) {
            if (value!.trim().isEmpty) {
              return "Password tidak boleh kosong";
            } else if (value.trim().length < 6) {
              return "Password harus lebih dari 6 karakter";
            }
            return null;
          },
          onSaved: (value) {
            loadAuth.enteredPassword = value!;
          },
          decoration: InputDecoration(
            hintText: "Masukkan Password....",
            hintStyle: TextStyle(color: widget.textColor.withOpacity(0.6)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(color: widget.textColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(color: Colors.green),
            ),
            suffixIcon: IconButton(
              onPressed: () {
                setState(() {
                  obscureText = !obscureText;
                });
              },
              icon: Icon(
                obscureText ? Icons.visibility_off : Icons.visibility,
                color: widget.iconColor,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
