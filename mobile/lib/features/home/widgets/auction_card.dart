import 'package:flutter/material.dart';

import '../models/auction.dart';

class AuctionCard extends StatelessWidget {
  const AuctionCard({required this.auction, super.key});
  final Auction auction;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    elevation: 1.5,
    shadowColor: Colors.black.withValues(alpha: .10),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: Color(0xFFD1D5DB), width: 1),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AspectRatio(
        aspectRatio: 16 / 10,
        child: auction.imageUrl == null || auction.imageUrl!.isEmpty
            ? const ColoredBox(color: Color(0xFFE5E7EB), child: Center(child: Text('Sin imagen', style: TextStyle(color: Color(0xFF6B7280)))))
            : Image.network(
                auction.imageUrl!, fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFFE5E7EB), child: Center(child: Text('Sin imagen', style: TextStyle(color: Color(0xFF6B7280))))),
              ),
      ),
      Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Expanded(child: Text(auction.category, style: const TextStyle(color: Color(0xFF667085), fontSize: 13))),
            _StatusBadge(status: auction.status),
          ]),
          const SizedBox(height: 8),
          Text(auction.productName, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
          if (auction.brand?.isNotEmpty == true) ...[
            const SizedBox(height: 3),
            Text(auction.brand!, style: const TextStyle(color: Color(0xFF667085))),
          ],
          const SizedBox(height: 14),
          _AmountLine(label: 'Precio base', amount: auction.basePrice),
          const SizedBox(height: 8),
          _AmountLine(label: 'Líder actual', amount: auction.currentLeaderAmount, noBids: auction.currentLeaderAmount == null),
        ]),
      ),
    ]),
  );
}

class _AmountLine extends StatelessWidget {
  const _AmountLine({required this.label, required this.amount, this.noBids = false});
  final String label;
  final num? amount;
  final bool noBids;

  @override
  Widget build(BuildContext context) {
    final highlighted = label != 'Precio base';
    final style = TextStyle(
      color: highlighted ? const Color(0xFF1F2937) : const Color(0xFF6B7280),
      fontWeight: highlighted ? FontWeight.w700 : FontWeight.normal,
      fontSize: 14,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
        Text(noBids ? 'Sin pujas' : cop(amount!), style: style),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
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
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(color: foreground, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }
}

String cop(num value) {
  final digits = value.round().toString();
  final grouped = digits.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');
  return '\$ $grouped';
}
