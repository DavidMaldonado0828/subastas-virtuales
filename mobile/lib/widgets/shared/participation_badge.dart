import 'package:flutter/material.dart';

class ParticipationBadge extends StatelessWidget {
  const ParticipationBadge({
    required this.status,
    required this.isLeader,
    super.key,
  });
  final String status;
  final bool isLeader;
  @override
  Widget build(BuildContext context) {
    final (label, foreground, background) = switch ((status, isLeader)) {
      ('ACTIVA', true) => (
        'Vas ganando',
        const Color(0xFF166534),
        const Color(0xFFDCFCE7),
      ),
      ('ACTIVA', false) => (
        'Te superaron',
        const Color(0xFFC2410C),
        const Color(0xFFFFEDD5),
      ),
      ('CERRADA', true) => (
        'Ganaste',
        const Color(0xFF166534),
        const Color(0xFFDCFCE7),
      ),
      ('CERRADA', false) => (
        'Perdiste',
        const Color(0xFFB42318),
        const Color(0xFFFEE4E2),
      ),
      _ => ('', const Color(0xFF475467), const Color(0xFFEAECF0)),
    };
    if (label.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
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
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
