import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../bloc/detail/detail_bloc.dart';
import '../../models/detail/auction_detail.dart';
import '../../models/detail/auction_detail_data.dart';
import '../../models/detail/bid_history_item.dart';
import '../../widgets/shared/auction_status_badge.dart';
import '../../widgets/shared/cop_format.dart';

class AuctionDetailPage extends StatefulWidget {
  const AuctionDetailPage({required this.auctionId, super.key});
  final int auctionId;

  @override
  State<AuctionDetailPage> createState() => _AuctionDetailPageState();
}

class _AuctionDetailPageState extends State<AuctionDetailPage> {
  Timer? _timer;
  int _remainingSeconds = 0;
  bool _countdownEventSent = false;

  @override
  void initState() {
    super.initState();
    context.read<DetailBloc>().add(DetailLoadRequested(widget.auctionId));
  }

  void _startCountdown(AuctionDetail detail) {
    _timer?.cancel();
    _remainingSeconds = detail.remainingSeconds;
    _countdownEventSent = false;
    if (detail.remainingSeconds <= 0 ||
        !{'PROGRAMADA', 'ACTIVA'}.contains(detail.auction.status)) {
      return;
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _remainingSeconds = (_remainingSeconds - 1).clamp(0, 1 << 31);
      });
      if (_remainingSeconds == 0) {
        timer.cancel();
        if (!_countdownEventSent) {
          _countdownEventSent = true;
          context.read<DetailBloc>().add(const DetailCountdownFinished());
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocListener<DetailBloc, DetailState>(
    listenWhen: (previous, current) =>
        current is DetailSuccess &&
        (previous is! DetailSuccess || previous.data != current.data),
    listener: (context, state) {
      if (state is DetailSuccess) {
        setState(() => _startCountdown(state.detail));
      }
    },
    child: Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Volver',
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Detalle de subasta'),
        actions: [
          BlocBuilder<DetailBloc, DetailState>(
            builder: (context, state) {
              if (state is! DetailSuccess ||
                  !{'PROGRAMADA', 'ACTIVA'}.contains(state.detail.auction.status)) {
                return const SizedBox.shrink();
              }
              return IconButton(
                tooltip: 'Actualizar',
                onPressed: state is DetailLoading
                    ? null
                    : () => context
                        .read<DetailBloc>()
                        .add(const DetailRefreshRequested()),
                icon: const Icon(Icons.refresh),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: BlocBuilder<DetailBloc, DetailState>(
            builder: (context, state) {
              if (state is DetailInitial ||
                  (state is DetailLoading && state.previousData == null)) {
                return const Center(child: CircularProgressIndicator());
              }
              if (state is DetailNotFound) {
                return _MessageView(
                  message: 'Subasta no encontrada',
                  action: 'Volver',
                  onPressed: () => context.pop(),
                );
              }
              if (state is DetailError) {
                return _MessageView(
                  message: state.message,
                  action: 'Reintentar',
                  onPressed: () => context
                      .read<DetailBloc>()
                      .add(DetailLoadRequested(widget.auctionId)),
                );
              }
              final data = switch (state) {
                DetailSuccess(:final data) => data,
                DetailLoading(previousData: final data?) => data,
                _ => null,
              };
              if (data == null) return const SizedBox.shrink();
              return RefreshIndicator(
                onRefresh: () async {
                  final bloc = context.read<DetailBloc>();
                  bloc.add(const DetailRefreshRequested());
                  await bloc.stream.firstWhere((next) => next is! DetailLoading);
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                  children: [
                    _DetailContent(
                      data: data,
                      remainingSeconds: _remainingSeconds,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
}

class _DetailContent extends StatelessWidget {
  const _DetailContent({
    required this.data,
    required this.remainingSeconds,
  });

  final AuctionDetailData data;
  final int remainingSeconds;

  @override
  Widget build(BuildContext context) {
    final detail = data.detail;
    final auction = detail.auction;
    final showCountdown =
        (auction.status == 'PROGRAMADA' || auction.status == 'ACTIVA') &&
        remainingSeconds > 0;
    final sellerLine = auction.brand?.trim().isNotEmpty == true
        ? '${auction.brand} · Vendedor: ${auction.sellerAlias}'
        : 'Vendedor: ${auction.sellerAlias}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DetailCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: AspectRatio(
                  aspectRatio: 4 / 3,
                  child: auction.imageUrl?.isNotEmpty == true
                      ? Image.network(
                          auction.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const _NoImage(),
                        )
                      : const _NoImage(),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                auction.category,
                style: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                auction.productName,
                style: const TextStyle(
                  color: Color(0xFF1F2937),
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                sellerLine,
                style: const TextStyle(color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  AuctionStatusBadge(status: auction.status),
                  if (showCountdown)
                    _CountdownChip(
                      label: auction.status == 'PROGRAMADA'
                          ? 'Inicia en'
                          : 'Cierra en',
                      remainingSeconds: remainingSeconds,
                    ),
                ],
              ),
              const SizedBox(height: 18),
              _DetailCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _Metric(
                            label: 'Precio base',
                            value: cop(auction.basePrice),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _Metric(
                            label: 'Incremento mínimo',
                            value: cop(auction.minimumIncrement),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _Metric(
                            label: 'Puja líder actual',
                            value: detail.leaderBid == null
                                ? 'Sin pujas'
                                : cop(detail.leaderBid!.amount),
                            valueColor: detail.leaderBid == null
                                ? const Color(0xFF1F2937)
                                : const Color(0xFFFF6B35),
                            bold: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _Metric(
                            label: 'Alias líder',
                            value: detail.leaderBid?.bidderAlias ?? '—',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (auction.status == 'CERRADA' && detail.winner != null) ...[
                const SizedBox(height: 14),
                _ResultBanner(
                  text:
                      'Ganador: ${detail.winner!.alias} con ${cop(detail.winner!.amount)}',
                ),
              ] else if (auction.status == 'FINALIZADA_SIN_GANADOR') ...[
                const SizedBox(height: 14),
                const _ResultBanner(
                  text: 'La subasta terminó sin ganador',
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        _DetailCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Top 5 de pujas',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (data.bidsError != null) ...[
                const SizedBox(height: 10),
                Text(
                  data.bidsError!,
                  style: const TextStyle(color: Color(0xFFB42318)),
                ),
              ],
              if (data.bids.isEmpty) ...[
                const SizedBox(height: 12),
                const Text('Aún no hay pujas'),
              ] else ...[
                const SizedBox(height: 8),
                for (final bid in data.bids) _BidRow(bid: bid),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.child, this.padding = const EdgeInsets.all(16)});
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFD1D5DB)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: .04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: child,
  );
}

class _NoImage extends StatelessWidget {
  const _NoImage();

  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: Color(0xFFE5E7EB),
    child: Center(
      child: Text(
        'Sin imagen',
        style: TextStyle(color: Color(0xFF6B7280)),
      ),
    ),
  );
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    this.valueColor = const Color(0xFF1F2937),
    this.bold = false,
  });

  final String label;
  final String value;
  final Color valueColor;
  final bool bold;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
      ),
      const SizedBox(height: 4),
      Text(
        value,
        style: TextStyle(
          color: valueColor,
          fontSize: 15,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
        ),
      ),
    ],
  );
}

class _CountdownChip extends StatelessWidget {
  const _CountdownChip({required this.label, required this.remainingSeconds});
  final String label;
  final int remainingSeconds;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: const Color(0xFF1F2937),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      '$label: ${_formatCountdown(remainingSeconds)}',
      style: const TextStyle(color: Colors.white, fontSize: 13),
    ),
  );
}

String _formatCountdown(int seconds) {
  final days = seconds ~/ 86400;
  final hours = (seconds % 86400) ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  final remainder = seconds % 60;
  final time = '${hours.toString().padLeft(2, '0')}:'
      '${minutes.toString().padLeft(2, '0')}:'
      '${remainder.toString().padLeft(2, '0')}';
  return days > 0 ? '$days d $time' : time;
}

class _ResultBanner extends StatelessWidget {
  const _ResultBanner({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFF3F4F6),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      text,
      style: const TextStyle(color: Color(0xFF1F2937)),
    ),
  );
}

class _BidRow extends StatelessWidget {
  const _BidRow({required this.bid});
  final BidHistoryItem bid;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                bid.bidderAlias,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFF1F2937)),
              ),
              Text(
                _formatLocalDate(bid.bidDate),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          cop(bid.amount),
          textAlign: TextAlign.end,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

String _formatLocalDate(DateTime value) {
  const months = [
    'ene', 'feb', 'mar', 'abr', 'may', 'jun',
    'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
  ];
  final local = value.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour < 12 ? 'a.\u00A0m.' : 'p.\u00A0m.';
  return '${local.day} ${months[local.month - 1]} ${local.year}, '
      '$hour:$minute $period';
}

class _MessageView extends StatelessWidget {
  const _MessageView({
    required this.message,
    required this.action,
    required this.onPressed,
  });

  final String message;
  final String action;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFB42318)),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onPressed,
            style: TextButton.styleFrom(foregroundColor: const Color(0xFF1A73E8)),
            child: Text(action),
          ),
        ],
      ),
    ),
  );
}
