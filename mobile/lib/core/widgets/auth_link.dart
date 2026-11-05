import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

class AuthLink extends StatefulWidget {
  const AuthLink({required this.label, required this.onPressed, super.key});

  final String label;
  final VoidCallback onPressed;

  @override
  State<AuthLink> createState() => _AuthLinkState();
}

class _AuthLinkState extends State<AuthLink> {
  late final TapGestureRecognizer _recognizer;

  @override
  void initState() {
    super.initState();
    _recognizer = TapGestureRecognizer()..onTap = () => widget.onPressed();
  }

  @override
  void didUpdateWidget(AuthLink oldWidget) {
    super.didUpdateWidget(oldWidget);
    _recognizer.onTap = widget.onPressed;
  }

  @override
  void dispose() {
    _recognizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    child: Text.rich(
      TextSpan(
        text: widget.label,
        style: const TextStyle(
          color: Color(0xFF1A73E8),
          decoration: TextDecoration.underline,
        ),
        recognizer: _recognizer,
      ),
    ),
  );
}
