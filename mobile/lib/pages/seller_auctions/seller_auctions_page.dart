import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../bloc/seller_auctions/seller_auctions_bloc.dart';
import '../../models/seller_auctions/seller_auction.dart';
import '../../repositories/seller_auctions/seller_auctions_repository.dart';
import '../../widgets/shared/auction_status_badge.dart';
import '../../widgets/shared/auth_snackbar.dart';
import '../../widgets/shared/cop_format.dart';
import '../../widgets/shared/primary_action_button.dart';
import '../../widgets/seller_auctions/local_date_format.dart';

class SellerAuctionsPage extends StatelessWidget {
  const SellerAuctionsPage({required this.repository, super.key});
  final SellerAuctionsRepository repository;
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) =>
        SellerAuctionsBloc(repository)
          ..add(const SellerAuctionsLoadRequested()),
    child: const _SellerAuctionsView(),
  );
}

class _SellerAuctionsView extends StatelessWidget {
  const _SellerAuctionsView();
  @override
  Widget build(BuildContext context) =>
      BlocListener<SellerAuctionsBloc, SellerAuctionsState>(
        listener: (context, state) {
          if (state.error != null && state.view != SellerAuctionsView.error) {
            showAuthSnackbar(context, state.error!);
          }
        },
        child: Scaffold(
          appBar: AppBar(title: const Text('Mis subastas')),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: BlocBuilder<SellerAuctionsBloc, SellerAuctionsState>(
                builder: (context, state) {
                  final bloc = context.read<SellerAuctionsBloc>();
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Mis subastas',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 12),
                            PrimaryActionButton(
                              label: 'Nueva subasta',
                              onPressed: () async {
                                final saved = await context.push<bool>(
                                  '/vendedor/subastas/nueva',
                                );
                                if (saved == true && context.mounted) {
                                  bloc.add(
                                    const SellerAuctionsRefreshRequested(),
                                  );
                                }
                              },
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                _filter(
                                  context,
                                  state,
                                  SellerAuctionsFilter.all,
                                  'Todas',
                                ),
                                _filter(
                                  context,
                                  state,
                                  SellerAuctionsFilter.active,
                                  'Activas',
                                ),
                                _filter(
                                  context,
                                  state,
                                  SellerAuctionsFilter.scheduled,
                                  'Programadas',
                                ),
                                _filter(
                                  context,
                                  state,
                                  SellerAuctionsFilter.closed,
                                  'Cerradas',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: () async {
                            bloc.add(const SellerAuctionsRefreshRequested());
                            await bloc.stream.firstWhere(
                              (next) =>
                                  !next.refreshing &&
                                  next.view != SellerAuctionsView.loading,
                            );
                          },
                          child: _body(context, state),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );

  Widget _filter(
    BuildContext context,
    SellerAuctionsState state,
    SellerAuctionsFilter filter,
    String label,
  ) => ChoiceChip(
    label: Text(label),
    selected: state.filter == filter,
    selectedColor: const Color(0xFFDBEAFE),
    onSelected: (_) => context.read<SellerAuctionsBloc>().add(
      SellerAuctionsFilterChanged(filter),
    ),
  );

  Widget _body(BuildContext context, SellerAuctionsState state) {
    final bloc = context.read<SellerAuctionsBloc>();
    if (state.view == SellerAuctionsView.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.view == SellerAuctionsView.error) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              state.error ?? 'No se pudieron cargar tus subastas.',
              textAlign: TextAlign.center,
            ),
            TextButton(
              onPressed: () => bloc.add(const SellerAuctionsLoadRequested()),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }
    final items = state.visibleItems;
    if (state.view == SellerAuctionsView.empty) {
      return _empty(context);
    }
    if (items.isEmpty) {
      return const Center(child: Text('No hay subastas para este estado.'));
    }
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: items.length,
      itemBuilder: (context, index) => _AuctionCard(
        auction: items[index],
        onEdit: () async {
          final saved = await context.push<bool>(
            '/vendedor/subastas/${items[index].id}/editar',
          );
          if (saved == true && context.mounted) {
            bloc.add(const SellerAuctionsRefreshRequested());
          }
        },
        onBids: () => context.push(
          '/vendedor/subastas/${items[index].id}/pujas',
          extra: items[index],
        ),
      ),
    );
  }

  Widget _empty(BuildContext context) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    children: [
      const SizedBox(height: 80),
      const Center(child: Text('Aún no tienes subastas')),
      Padding(
        padding: const EdgeInsets.all(24),
        child: PrimaryActionButton(
          label: 'Nueva subasta',
          onPressed: () async {
            final saved = await context.push<bool>('/vendedor/subastas/nueva');
            if (saved == true && context.mounted) {
              context.read<SellerAuctionsBloc>().add(
                const SellerAuctionsRefreshRequested(),
              );
            }
          },
        ),
      ),
    ],
  );
}

class _AuctionCard extends StatelessWidget {
  const _AuctionCard({
    required this.auction,
    required this.onEdit,
    required this.onBids,
  });
  final SellerAuction auction;
  final VoidCallback onBids;
  final VoidCallback onEdit;
  bool get canEdit =>
      auction.bidCount == 0 &&
      (auction.status == 'PROGRAMADA' || auction.status == 'ACTIVA');
  bool get isFinal =>
      auction.status == 'CERRADA' ||
      auction.status == 'FINALIZADA_SIN_GANADOR' ||
      auction.status == 'CANCELADA';
  @override
  Widget build(BuildContext context) => Card(
    color: Colors.white,
    elevation: 0,
    margin: const EdgeInsets.only(bottom: 10),
    shape: RoundedRectangleBorder(
      side: const BorderSide(color: Color(0xFFD1D5DB)),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      auction.productName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      auction.category,
                      style: const TextStyle(color: Color(0xFF667085)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AuctionStatusBadge(status: auction.status),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 22,
            runSpacing: 6,
            children: [
              Text('Precio base: ${cop(auction.basePrice)}'),
              Text('${auction.bidCount} pujas'),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            '${isFinal ? 'Cerró' : 'Cierra'}: ${formatSellerDateTime(auction.endDate)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF667085)),
          ),
          if (auction.status == 'CANCELADA' &&
              auction.cancellationReason != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Motivo: ${auction.cancellationReason}'),
                  if (auction.cancelledAt != null)
                    Text(
                      'Fecha: ${formatSellerDateTime(auction.cancelledAt!)}',
                      style: const TextStyle(
                        color: Color(0xFF667085),
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
          ],
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: 8,
              children: [
                TextButton(onPressed: onBids, child: const Text('Ver pujas')),
                if (canEdit)
                  TextButton(onPressed: onEdit, child: const Text('Editar')),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
