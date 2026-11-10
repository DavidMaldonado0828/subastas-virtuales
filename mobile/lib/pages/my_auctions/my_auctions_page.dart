import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../bloc/my_auctions/my_auctions_bloc.dart';
import '../../core/auth/auth_session.dart';
import '../../models/my_auctions/my_auction.dart';
import '../../repositories/my_auctions/my_auctions_repository.dart';
import '../../widgets/shared/auction_status_badge.dart';
import '../../widgets/shared/cop_format.dart';
import '../../widgets/shared/participation_badge.dart';

class MyAuctionsPage extends StatelessWidget {
  const MyAuctionsPage({required this.session, super.key});
  final AuthSession session;
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (context) =>
        MyAuctionsBloc(context.read<MyAuctionsRepository>())
          ..add(const MyAuctionsLoadRequested()),
    child: const _MyAuctionsContent(),
  );
}

class _MyAuctionsContent extends StatefulWidget {
  const _MyAuctionsContent();
  @override
  State<_MyAuctionsContent> createState() => _MyAuctionsContentState();
}

class _MyAuctionsContentState extends State<_MyAuctionsContent> {
  final _scroll = ScrollController();
  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scroll.hasClients && _scroll.position.extentAfter < 300) {
      context.read<MyAuctionsBloc>().add(const MyAuctionsLoadMoreRequested());
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Mis subastas'),
      leading: IconButton(
        tooltip: 'Volver',
        icon: const Icon(Icons.arrow_back),
        onPressed: () => context.pop(),
      ),
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: BlocBuilder<MyAuctionsBloc, MyAuctionsState>(
          builder: (context, state) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _filter(context, state, MyAuctionsFilter.all, 'Todas'),
                      const SizedBox(width: 8),
                      _filter(
                        context,
                        state,
                        MyAuctionsFilter.active,
                        'Activas',
                      ),
                      const SizedBox(width: 8),
                      _filter(
                        context,
                        state,
                        MyAuctionsFilter.closed,
                        'Cerradas',
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      final bloc = context.read<MyAuctionsBloc>();
                      bloc.add(const MyAuctionsRefreshRequested());
                      await bloc.stream.firstWhere(
                        (s) => s.view != MyAuctionsView.loading,
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
  );

  Widget _filter(
    BuildContext context,
    MyAuctionsState state,
    MyAuctionsFilter filter,
    String label,
  ) => ChoiceChip(
    label: Text(label),
    selected: state.filter == filter,
    onSelected: (_) =>
        context.read<MyAuctionsBloc>().add(MyAuctionsFilterChanged(filter)),
    selectedColor: const Color(0xFFDBEAFE),
  );

  Widget _body(BuildContext context, MyAuctionsState state) {
    if (state.view == MyAuctionsView.loading && state.items.isEmpty) {
      return ListView(
        physics: AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: 220,
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
      );
    }
    if (state.view == MyAuctionsView.error && state.items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 110),
          _ErrorPanel(
            message:
                state.errorMessage ?? 'No se pudieron cargar tus subastas.',
            retry: () => context.read<MyAuctionsBloc>().add(
              const MyAuctionsLoadRequested(),
            ),
          ),
        ],
      );
    }
    if (state.view == MyAuctionsView.empty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 140),
          const Center(
            child: Text('Aún no has participado en ninguna subasta'),
          ),
          const SizedBox(height: 16),
          Center(
            child: OutlinedButton(
              onPressed: () => context.go('/inicio'),
              child: const Text('Ir al inicio'),
            ),
          ),
        ],
      );
    }
    return ListView.builder(
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount:
          state.items.length +
          (state.loadingMore || state.errorMessage != null || state.hasMore
              ? 1
              : 0),
      itemBuilder: (context, index) {
        if (index < state.items.length) {
          final item = state.items[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _AuctionTile(
              item: item,
              onTap: item.status == 'CANCELADA'
                  ? null
                  : () async {
                      await context.push<bool>('/subasta/${item.auctionId}');
                      if (context.mounted) {
                        context.read<MyAuctionsBloc>().add(
                          const MyAuctionsRefreshRequested(),
                        );
                      }
                    },
            ),
          );
        }
        if (state.errorMessage != null) {
          return _ErrorPanel(
            message: state.errorMessage!,
            retry: () => context.read<MyAuctionsBloc>().add(
              const MyAuctionsLoadMoreRequested(),
            ),
          );
        }
        return const Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}

class _AuctionTile extends StatelessWidget {
  const _AuctionTile({required this.item, this.onTap});
  final MyAuction item;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    elevation: .8,
    shadowColor: Colors.black.withValues(alpha: .06),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: const BorderSide(color: Color(0xFFD1D5DB)),
    ),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.productName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                AuctionStatusBadge(status: item.status),
              ],
            ),
            const SizedBox(height: 8),
            _amountRow('Mi puja más alta', cop(item.myHighestBid)),
            _amountRow(
              'Líder actual',
              item.leaderAmount == null ? 'Sin pujas' : cop(item.leaderAmount!),
            ),
            if (item.status == 'CANCELADA' && item.cancelledByAdmin) ...[
              const SizedBox(height: 8),
              const Text(
                'Cancelada por la administración',
                style: TextStyle(
                  color: Color(0xFFB42318),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ] else if (item.status == 'ACTIVA' || item.status == 'CERRADA') ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: ParticipationBadge(
                  status: item.status,
                  isLeader: item.isLeader,
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
  Widget _amountRow(String label, String amount) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13),
        ),
        Text(
          amount,
          style: const TextStyle(
            color: Color(0xFF1F2937),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.retry});
  final String message;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Padding(
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
        OutlinedButton(onPressed: retry, child: const Text('Reintentar')),
      ],
    ),
  );
}
