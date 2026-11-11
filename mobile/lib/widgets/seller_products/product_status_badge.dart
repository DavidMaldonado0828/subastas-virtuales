import 'package:flutter/material.dart';

class ProductStatusBadge extends StatelessWidget {
  const ProductStatusBadge({required this.status, super.key});
  final String status;
  @override
  Widget build(BuildContext context) {
    final active = status == 'ACTIVO';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFDCFCE7) : const Color(0xFFEAECF0),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: active ? const Color(0xFF166534) : const Color(0xFF475467),
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
