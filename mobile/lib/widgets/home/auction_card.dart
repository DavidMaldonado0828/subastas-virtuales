import 'package:flutter/material.dart';

import '../../models/home/auction.dart';

class AuctionCard extends StatelessWidget {
  const AuctionCard({required this.auction, super.key});
  final Auction auction;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    clipBehavior: Clip.antiAlias,
    elevation: 0.8,
    shadowColor: Colors.black.withValues(alpha: .06),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: const BorderSide(color: Color(0xFFD1D5DB), width: 1),
    ),
    child: Padding(
      padding: const EdgeInsets.all(7),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox.square(
              dimension: 96,
              child: auction.imageUrl == null || auction.imageUrl!.isEmpty
                  ? const _NoAuctionImage()
                  : Image.network(
                      auction.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const _NoAuctionImage(),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 96,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          auction.category,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(child: _StatusBadge(status: auction.status)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        auction.productName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.05,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  _AmountLine(label: 'Precio base', amount: auction.basePrice),
                  const SizedBox(height: 1),
                  _AmountLine(
                    label: 'L\u00edder actual',
                    amount: auction.currentLeaderAmount,
                    noBids: auction.currentLeaderAmount == null,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _NoAuctionImage extends StatelessWidget {
  const _NoAuctionImage();

  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: Color(0xFFE5E7EB),
    child: Center(
      child: Icon(
        Icons.image_not_supported_outlined,
        size: 20,
        color: Color(0xFF6B7280),
      ),
    ),
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
      fontSize: 12,
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
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: foreground, fontSize: 10, fontWeight: FontWeight.w700),
      ),
    );
  }
}

String cop(num value) {
  final digits = value.round().toString();
  final grouped = digits.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');
  return '\$ $grouped';
}
