import 'package:flutter/material.dart';

class AuthInput extends StatelessWidget {
  const AuthInput({
    required this.controller,
    required this.label,
    this.errorText,
    this.maxLength,
    this.hintText,
    this.keyboardType,
    this.autofillHints,
    this.obscureText = false,
    this.suffixIcon,
    this.onChanged,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final String? errorText;
  final int? maxLength;
  final String? hintText;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final bool obscureText;
  final Widget? suffixIcon;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextField(
      controller: controller,
      onChanged: onChanged,
      keyboardType: keyboardType,
      obscureText: obscureText,
      maxLength: maxLength,
      decoration: InputDecoration(
        labelText: label,
        errorText: errorText,
        hintText: hintText,
        counterText: '',
        suffixIcon: suffixIcon,
      ),
      autofillHints: autofillHints,
    ),
  );
}
