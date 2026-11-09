import 'package:flutter/material.dart';

import 'auth_input.dart';

class PasswordAuthInput extends StatefulWidget {
  const PasswordAuthInput({
    required this.controller,
    required this.label,
    this.errorText,
    this.maxLength,
    this.hintText,
    this.keyboardType,
    this.autofillHints,
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
  final ValueChanged<String>? onChanged;

  @override
  State<PasswordAuthInput> createState() => _PasswordAuthInputState();
}

class _PasswordAuthInputState extends State<PasswordAuthInput> {
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_hideWhenEmpty);
  }

  @override
  void didUpdateWidget(covariant PasswordAuthInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_hideWhenEmpty);
      widget.controller.addListener(_hideWhenEmpty);
      _obscure = true;
    }
  }

  void _hideWhenEmpty() {
    if (widget.controller.text.isEmpty && !_obscure) {
      setState(() => _obscure = true);
    }
  }

  void _toggleVisibility() {
    final selection = widget.controller.selection;
    setState(() => _obscure = !_obscure);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          selection.isValid &&
          selection.start <= widget.controller.text.length &&
          selection.end <= widget.controller.text.length) {
        widget.controller.selection = selection;
      }
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_hideWhenEmpty);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<TextEditingValue>(
        valueListenable: widget.controller,
        builder: (context, value, child) => AuthInput(
          controller: widget.controller,
          label: widget.label,
          errorText: widget.errorText,
          maxLength: widget.maxLength,
          hintText: widget.hintText,
          keyboardType: widget.keyboardType,
          autofillHints: widget.autofillHints,
          obscureText: value.text.isEmpty || _obscure,
          suffixIcon: value.text.isEmpty
              ? null
              : IconButton(
                  tooltip: _obscure ? 'Mostrar contraseña' : 'Ocultar contraseña',
                  onPressed: _toggleVisibility,
                  icon: Icon(
                    _obscure ? Icons.visibility : Icons.visibility_off,
                  ),
                ),
          onChanged: widget.onChanged,
        ),
      );
}
