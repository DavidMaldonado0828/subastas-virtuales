import 'package:flutter/material.dart';

class RegisterInput extends StatelessWidget {
  const RegisterInput({
    required this.controller,
    required this.label,
    required this.errorText,
    this.hasError = false,
    this.maxLength,
    this.keyboardType,
    this.autofillHints,
    this.obscureText = false,
    this.suffixIcon,
    this.hintText,
    this.onChanged,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final String? errorText;
  final bool hasError;
  final int? maxLength;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final bool obscureText;
  final Widget? suffixIcon;
  final String? hintText;
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
        hintText: hintText,
        counterText: '',
        suffixIcon: suffixIcon,
        errorText: errorText,
        error: hasError && errorText == null ? const SizedBox.shrink() : null,
      ),
      autofillHints: autofillHints,
    ),
  );
}
