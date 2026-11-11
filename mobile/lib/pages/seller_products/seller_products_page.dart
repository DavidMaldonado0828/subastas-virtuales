import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../bloc/seller_products/seller_products_bloc.dart';
import '../../core/network/public_image_url.dart';
import '../../models/seller_products/seller_product.dart';
import '../../repositories/seller_products/seller_products_repository.dart';
import '../../widgets/shared/auth_snackbar.dart';
import '../../widgets/shared/primary_action_button.dart';
import '../../widgets/seller_products/product_status_badge.dart';

class SellerProductsPage extends StatelessWidget {
  const SellerProductsPage({required this.repository, super.key});
  final SellerProductsRepository repository;
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) =>
        SellerProductsBloc(repository)
          ..add(const SellerProductsLoadRequested()),
    child: const _SellerProductsView(),
  );
}

class _SellerProductsView extends StatefulWidget {
  const _SellerProductsView();
  @override
  State<_SellerProductsView> createState() => _SellerProductsViewState();
}

class _SellerProductsViewState extends State<_SellerProductsView> {
  final _search = TextEditingController();
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocListener<SellerProductsBloc, SellerProductsState>(
    listener: (context, state) {
      if (state.message != null) showAuthSnackbar(context, state.message!);
      if (state.error != null && state.view != SellerProductsView.error) {
        showAuthSnackbar(context, state.error!);
      }
    },
    child: Scaffold(
      appBar: AppBar(title: const Text('Mis productos')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: BlocBuilder<SellerProductsBloc, SellerProductsState>(
            builder: (context, state) {
              final bloc = context.read<SellerProductsBloc>();
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Mis productos',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        PrimaryActionButton(
                          label: 'Registrar producto',
                          onPressed: () async {
                            final saved = await context.push<bool>(
                              '/vendedor/productos/nuevo',
                            );
                            if (saved == true && context.mounted) {
                              bloc.add(const SellerProductsRefreshRequested());
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _search,
                          decoration: InputDecoration(
                            labelText: 'Buscar por nombre',
                            suffixIcon: IconButton(
                              tooltip: 'Limpiar',
                              onPressed: () {
                                _search.clear();
                                bloc.add(const SellerProductsNameChanged(''));
                                bloc.add(
                                  const SellerProductsFilterChanged(
                                    SellerProductFilter.all,
                                  ),
                                );
                              },
                              icon: const Icon(Icons.close),
                            ),
                          ),
                          onChanged: (value) =>
                              bloc.add(SellerProductsNameChanged(value)),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            for (final entry in const [
                              (SellerProductFilter.all, 'Todos'),
                              (SellerProductFilter.active, 'Activos'),
                              (SellerProductFilter.disabled, 'Desactivados'),
                            ])
                              ChoiceChip(
                                label: Text(entry.$2),
                                selected: state.filter == entry.$1,
                                onSelected: (_) => bloc.add(
                                  SellerProductsFilterChanged(entry.$1),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(child: _body(context, state)),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
  Widget _body(BuildContext context, SellerProductsState state) {
    final bloc = context.read<SellerProductsBloc>();
    if (state.view == SellerProductsView.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.view == SellerProductsView.error) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              state.error ?? 'No se pudo cargar productos',
              textAlign: TextAlign.center,
            ),
            TextButton(
              onPressed: () => bloc.add(const SellerProductsLoadRequested()),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }
    if (state.view == SellerProductsView.empty) {
      return RefreshIndicator(
        onRefresh: () async {
          bloc.add(const SellerProductsRefreshRequested());
          await bloc.stream.firstWhere(
            (s) => s.view != SellerProductsView.loading,
          );
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 70),
            const Center(child: Text('Aún no tienes productos')),
            Padding(
              padding: const EdgeInsets.all(24),
              child: PrimaryActionButton(
                label: 'Registrar producto',
                onPressed: () async {
                  final saved = await context.push<bool>(
                    '/vendedor/productos/nuevo',
                  );
                  if (saved == true && context.mounted) {
                    bloc.add(const SellerProductsRefreshRequested());
                  }
                },
              ),
            ),
          ],
        ),
      );
    }
    final products = state.visibleProducts;
    return RefreshIndicator(
      onRefresh: () async {
        bloc.add(const SellerProductsRefreshRequested());
        await bloc.stream.firstWhere(
          (s) => s.view != SellerProductsView.loading,
        );
      },
      child: products.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 80),
                Center(
                  child: Text(
                    'No hay productos para mostrar con estos filtros.',
                  ),
                ),
              ],
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              itemCount: products.length,
              itemBuilder: (context, i) => _ProductTile(
                product: products[i],
                onEdit: () async {
                  final saved = await context.push<bool>(
                    '/vendedor/productos/${products[i].id}/editar',
                  );
                  if (saved == true && context.mounted) {
                    bloc.add(const SellerProductsRefreshRequested());
                  }
                },
                onDelete: () => _confirmDelete(context, products[i]),
                onReactivate: () =>
                    bloc.add(SellerProductReactivateRequested(products[i].id)),
              ),
            ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    SellerProduct product,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar producto'),
        content: const Text(
          '¿Eliminar este producto? Si tiene historial de subastas se desactivará en lugar de borrarse.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Color(0xFFB42318)),
            ),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      context.read<SellerProductsBloc>().add(
        SellerProductDeleteRequested(product.id),
      );
    }
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({
    required this.product,
    required this.onEdit,
    required this.onDelete,
    required this.onReactivate,
  });
  final SellerProduct product;
  final VoidCallback onEdit, onDelete, onReactivate;
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
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 76,
                  height: 76,
                  child: product.imageUrl == null
                      ? const ColoredBox(
                          color: Color(0xFFE5E7EB),
                          child: Center(
                            child: Text(
                              'Sin imagen',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 10,
                                color: Color(0xFF667085),
                              ),
                            ),
                          ),
                        )
                      : Image.network(
                          publicImageUrl(product.imageUrl)!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              const ColoredBox(color: Color(0xFFE5E7EB)),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      product.categoryName,
                      style: const TextStyle(color: Color(0xFF667085)),
                    ),
                    if (product.brand?.isNotEmpty == true)
                      Text(
                        product.brand!,
                        style: const TextStyle(color: Color(0xFF667085)),
                      ),
                    const SizedBox(height: 6),
                    ProductStatusBadge(status: product.status),
                  ],
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: 12,
              children: [
                TextButton(onPressed: onEdit, child: const Text('Editar')),
                TextButton(
                  onPressed: onDelete,
                  child: const Text(
                    'Eliminar',
                    style: TextStyle(color: Color(0xFFB42318)),
                  ),
                ),
                if (product.status == 'DESACTIVADO')
                  TextButton(
                    onPressed: onReactivate,
                    child: const Text('Reactivar'),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
