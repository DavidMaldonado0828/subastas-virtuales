import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../bloc/seller_auctions/seller_bid_history_bloc.dart';
import '../../models/seller_auctions/seller_auction.dart';
import '../../repositories/detail/detail_repository.dart';
import '../../repositories/seller_auctions/seller_auctions_repository.dart';
import '../../widgets/shared/auction_status_badge.dart';
import '../../widgets/shared/cop_format.dart';
import '../../widgets/seller_auctions/local_date_format.dart';

class SellerBidHistoryPage extends StatelessWidget {
  const SellerBidHistoryPage({
    required this.repository,
    required this.detailRepository,
    required this.auctionId,
    this.initialAuction,
    super.key,
  });
  final SellerAuctionsRepository repository;
  final DetailRepository detailRepository;
  final int auctionId;
  final SellerAuction? initialAuction;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => SellerBidHistoryBloc(repository, detailRepository)
      ..add(
        SellerBidHistoryLoadRequested(
          auctionId,
          initialAuction: initialAuction,
        ),
      ),
    child: const _SellerBidHistoryView(),
  );
}

class _SellerBidHistoryView extends StatefulWidget {
  const _SellerBidHistoryView();
  @override
  State<_SellerBidHistoryView> createState() => _SellerBidHistoryViewState();
}

class _SellerBidHistoryViewState extends State<_SellerBidHistoryView> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_loadMore);
  }

  void _loadMore() {
    if (_scroll.hasClients && _scroll.position.extentAfter < 260) {
      context.read<SellerBidHistoryBloc>().add(
        const SellerBidHistoryLoadMoreRequested(),
      );
    }
  }

  Future<void> _refresh() async {
    final bloc = context.read<SellerBidHistoryBloc>();
    bloc.add(const SellerBidHistoryRefreshRequested());
    await bloc.stream.firstWhere((state) => !state.refreshing);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Pujas de la subasta'),
      leading: IconButton(
        onPressed: () => context.pop(),
        icon: const Icon(Icons.arrow_back),
      ),
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: BlocBuilder<SellerBidHistoryBloc, SellerBidHistoryState>(
          builder: (context, state) {
            final bloc = context.read<SellerBidHistoryBloc>();
            final count =
                1 +
                (state.items.isEmpty ? 1 : state.items.length) +
                (state.items.isNotEmpty &&
                        (state.loadingMore ||
                            state.error != null ||
                            state.hasMore)
                    ? 1
                    : 0);
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView.builder(
                controller: _scroll,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                itemCount: count,
                itemBuilder: (context, index) {
                  if (index == 0) return _summaryHeader(state);
                  final contentIndex = index - 1;
                  if (state.items.isEmpty) {
                    if (contentIndex == 0) {
                      if (state.view == SellerBidHistoryView.loading) {
                        return const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      if (state.view == SellerBidHistoryView.error) {
                        return Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              Text(
                                state.error ??
                                    'No se pudo cargar el historial.',
                                textAlign: TextAlign.center,
                              ),
                              TextButton(
                                onPressed: () => bloc.add(
                                  SellerBidHistoryLoadRequested(
                                    state.auctionId,
                                    initialAuction: state.initialAuction,
                                  ),
                                ),
                                child: const Text('Reintentar'),
                              ),
                            ],
                          ),
                        );
                      }
                      return const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: Text('Aún no hay pujas')),
                      );
                    }
                    return const SizedBox.shrink();
                  }
                  if (contentIndex < state.items.length) {
                    final bid = state.items[contentIndex];
                    final tag = contentIndex == 0
                        ? switch (state.status) {
                            'CERRADA' => 'Ganador',
                            'ACTIVA' => 'Líder',
                            _ => null,
                          }
                        : null;
                    return Card(
                      color: Colors.white,
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                        side: const BorderSide(color: Color(0xFFD1D5DB)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          bid.alias,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (tag != null) ...[
                                        const SizedBox(width: 8),
                                        _ResultTag(label: tag),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    formatSellerDateTime(bid.date),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFF667085),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              cop(bid.amount),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  if (state.error != null) {
                    return Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Text(state.error!, textAlign: TextAlign.center),
                          TextButton(
                            onPressed: () => bloc.add(
                              const SellerBidHistoryLoadMoreRequested(),
                            ),
                            child: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    );
                  }
                  return const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: CircularProgressIndicator()),
                  );
                },
              ),
            );
          },
        ),
      ),
    ),
  );

  Widget _summaryHeader(SellerBidHistoryState state) {
    final status = state.status;
    final cancelled = state.initialAuction;
    final hasSummary =
        status == 'CANCELADA' ||
        (state.detail != null && !state.summaryUnavailable);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  state.productName.isEmpty ? 'Subasta' : state.productName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (status != null) ...[
                const SizedBox(width: 8),
                AuctionStatusBadge(status: status),
              ],
            ],
          ),
          if (hasSummary) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                border: Border.all(color: const Color(0xFFD1D5DB)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: _summaryText(state, cancelled),
            ),
          ],
          if (state.summaryUnavailable)
            const Padding(
              padding: EdgeInsets.only(top: 6, left: 2),
              child: Text(
                'No se pudo actualizar el resumen.',
                style: TextStyle(color: Color(0xFF667085), fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _summaryText(SellerBidHistoryState state, SellerAuction? cancelled) {
    switch (state.status) {
      case 'PROGRAMADA':
        return const Text('Aún no inicia');
      case 'ACTIVA':
        final leader = state.detail?.leaderBid;
        if (leader == null) return const Text('Aún no hay pujas');
        return Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'Va ganando: '),
              TextSpan(text: leader.bidderAlias),
              const TextSpan(text: ' con '),
              TextSpan(
                text: cop(leader.amount),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        );
      case 'CERRADA':
        final winner = state.detail?.winner;
        if (winner == null) return const SizedBox.shrink();
        return Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'Ganador: '),
              TextSpan(text: winner.alias),
              const TextSpan(text: ' con '),
              TextSpan(
                text: cop(winner.amount),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        );
      case 'FINALIZADA_SIN_GANADOR':
        return const Text('La subasta terminó sin ganador');
      case 'CANCELADA':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (cancelled?.cancellationReason != null)
              Text('Motivo: ${cancelled!.cancellationReason}'),
            if (cancelled?.cancelledAt != null)
              Text(
                'Fecha: ${formatSellerDateTime(cancelled!.cancelledAt!)}',
                style: const TextStyle(color: Color(0xFF667085), fontSize: 12),
              ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

class _ResultTag extends StatelessWidget {
  const _ResultTag({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final winner = label == 'Ganador';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: winner ? const Color(0xFFDCFCE7) : const Color(0xFFDBEAFE),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: winner ? const Color(0xFF166534) : const Color(0xFF1D4ED8),
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
