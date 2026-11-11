import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_session.dart';
import '../../bloc/home/home_bloc.dart';
import '../../widgets/home/auction_card.dart';
import '../../widgets/shared/account_menu_button.dart';

class HomePage extends StatelessWidget {
  const HomePage({required this.session, super.key});
  final AuthSession session;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => HomeBloc(
        context.read(),
        loadParticipation: session.user?.role == 'POSTOR',
      )..add(const HomeLoadRequested()),
      child: _HomeContent(session: session),
    );
  }
}

class _HomeContent extends StatefulWidget {
  const _HomeContent({required this.session});
  final AuthSession session;

  @override
  State<_HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<_HomeContent>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this, initialIndex: 0);
    _tabs.addListener(_onTabChanged);
    _scroll.addListener(_onScroll);
  }

  void _onTabChanged() {
    if (_tabs.indexIsChanging) return;
    context.read<HomeBloc>().add(
      HomeTabChanged(_tabs.index == 0 ? HomeTab.available : HomeTab.closed),
    );
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _onScroll() {
    if (_scroll.hasClients && _scroll.position.extentAfter < 280) {
      context.read<HomeBloc>().add(const HomeLoadMoreRequested());
    }
  }

  @override
  void dispose() {
    _tabs.removeListener(_onTabChanged);
    _tabs.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.session.user;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        scrolledUnderElevation: 0,
        title: Image.asset(
          'assets/branding/subastax_logo.png',
          width: 128,
          height: 90,
          fit: BoxFit.contain,
          alignment: Alignment.centerLeft,
          semanticLabel: 'SubastaX',
        ),
        actions: [
          AccountMenuButton(
            alias: user?.alias ?? '',
            role: user?.role ?? '',
            onMyAuctions: () => context.push('/mis-subastas'),
            onMyProducts: () => context.push('/vendedor/productos'),
            onLogout: () async {
              await widget.session.clear();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              children: [
                TabBar(
                  controller: _tabs,
                  labelColor: const Color(0xFF1A73E8),
                  indicatorColor: const Color(0xFF1A73E8),
                  tabs: const [
                    Tab(text: 'Disponibles'),
                    Tab(text: 'Cerradas'),
                  ],
                ),
                Expanded(
                  child: BlocBuilder<HomeBloc, HomeState>(
                    builder: (context, state) {
                      if (state is HomeLoading && state.items.isEmpty) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final list = ListView.builder(
                        controller: _scroll,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                        itemCount:
                            state.items.length +
                            (state is HomeLoading || state is HomeError
                                ? 1
                                : 0),
                        itemBuilder: (context, index) {
                          if (index < state.items.length) {
                            final auction = state.items[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () async {
                                  final bidPlaced = await context.push<bool>(
                                    '/subasta/${auction.id}',
                                  );
                                  if (bidPlaced == true && context.mounted) {
                                    context.read<HomeBloc>().add(
                                      const HomeRefreshRequested(),
                                    );
                                  }
                                },
                                child: AuctionCard(
                                  auction: auction,
                                  participation:
                                      state.participation[auction.id],
                                ),
                              ),
                            );
                          }
                          if (state is HomeLoading) {
                            return const Padding(
                              padding: EdgeInsets.all(20),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          if (state is HomeError) {
                            return _ErrorPanel(
                              message: state.message!,
                              onRetry: () => context.read<HomeBloc>().add(
                                const HomeLoadMoreRequested(),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      );
                      return RefreshIndicator(
                        onRefresh: () async {
                          final bloc = context.read<HomeBloc>();
                          bloc.add(const HomeRefreshRequested());
                          await bloc.stream.firstWhere(
                            (next) => next is! HomeLoading,
                          );
                        },
                        child: state is HomeEmpty
                            ? ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: const [
                                  SizedBox(height: 180),
                                  Center(
                                    child: Text('No hay subastas para mostrar'),
                                  ),
                                ],
                              )
                            : state is HomeError && state.items.isEmpty
                            ? ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: [
                                  const SizedBox(height: 120),
                                  _ErrorPanel(
                                    message: state.message!,
                                    onRetry: () => context.read<HomeBloc>().add(
                                      const HomeLoadRequested(),
                                    ),
                                  ),
                                ],
                              )
                            : list,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
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
        OutlinedButton(onPressed: onRetry, child: const Text('Reintentar')),
      ],
    ),
  );
}
