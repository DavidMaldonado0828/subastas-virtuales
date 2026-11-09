import 'package:flutter/material.dart';

class AuctionStatusBadge extends StatelessWidget {
  const AuctionStatusBadge({required this.status, super.key});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, foreground, background) = switch (status) {
      'ACTIVA' => ('ACTIVA', const Color(0xFF166534), const Color(0xFFDCFCE7)),
      'PROGRAMADA' => ('PROGRAMADA', const Color(0xFF1D4ED8), const Color(0xFFDBEAFE)),
      'CANCELADA' => ('CANCELADA', const Color(0xFFB42318), const Color(0xFFFEE4E2)),
      'FINALIZADA_SIN_GANADOR' => (status, const Color(0xFF475467), const Color(0xFFEAECF0)),
      _ => ('CERRADA', const Color(0xFF475467), const Color(0xFFEAECF0)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: foreground,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
