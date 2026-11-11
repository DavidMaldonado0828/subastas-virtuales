import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../bloc/seller_products/seller_product_form_bloc.dart';
import '../../models/seller_products/seller_product.dart';
import '../../repositories/seller_products/seller_products_repository.dart';
import '../../widgets/shared/auth_snackbar.dart';
import '../../widgets/shared/primary_action_button.dart';

class SellerProductFormPage extends StatelessWidget {
  const SellerProductFormPage({
    required this.repository,
    this.productId,
    super.key,
  });

  final SellerProductsRepository repository;
  final int? productId;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) =>
        SellerProductFormBloc(repository)
          ..add(SellerProductFormLoadRequested(productId)),
    child: _ProductFormView(id: productId),
  );
}

class _ProductFormView extends StatefulWidget {
  const _ProductFormView({required this.id});
  final int? id;

  @override
  State<_ProductFormView> createState() => _ProductFormViewState();
}

class _ProductFormViewState extends State<_ProductFormView> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _brand = TextEditingController();
  int? _categoryId;
  bool _initialized = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _brand.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      BlocListener<SellerProductFormBloc, SellerProductFormState>(
        listener: (context, state) {
          if (state.error != null) showAuthSnackbar(context, state.error!);
          if (state.saved) {
            showAuthSnackbar(context, state.message!);
            context.pop(true);
          }
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(
              widget.id == null ? 'Registrar producto' : 'Editar producto',
            ),
            leading: IconButton(
              onPressed: () => context.pop(false),
              icon: const Icon(Icons.arrow_back),
            ),
          ),
          body: BlocBuilder<SellerProductFormBloc, SellerProductFormState>(
            builder: (context, state) {
              if (state.view == SellerProductFormView.loading) {
                return const Center(child: CircularProgressIndicator());
              }
              if (state.view == SellerProductFormView.error) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(state.error ?? 'No se pudo cargar el formulario'),
                      TextButton(
                        onPressed: () => context
                            .read<SellerProductFormBloc>()
                            .add(SellerProductFormLoadRequested(widget.id)),
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                );
              }
              if (!_initialized) {
                _initialized = true;
                final product = state.product;
                _name.text = product?.name ?? '';
                _description.text = product?.description ?? '';
                _brand.text = product?.brand ?? '';
                _categoryId = product?.categoryId;
              }
              final busy = state.view == SellerProductFormView.saving;
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Form(
                    key: _form,
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        20,
                        20,
                        MediaQuery.viewInsetsOf(context).bottom + 30,
                      ),
                      children: [
                        TextFormField(
                          controller: _name,
                          maxLength: 100,
                          decoration: InputDecoration(
                            labelText: 'Nombre',
                            counterText: '${_name.text.length}/100',
                            errorText: state.fieldErrors['name'],
                          ),
                          validator: (value) => (value?.trim().isEmpty ?? true)
                              ? 'Ingresa un nombre válido.'
                              : (value!.length > 100
                                    ? 'Máximo 100 caracteres.'
                                    : null),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _description,
                          maxLength: 400,
                          maxLines: 4,
                          decoration: InputDecoration(
                            labelText: 'Descripción',
                            errorText: state.fieldErrors['description'],
                          ),
                          validator: (value) => (value?.trim().isEmpty ?? true)
                              ? 'Ingresa una descripción válida.'
                              : (value!.length > 400
                                    ? 'Máximo 400 caracteres.'
                                    : null),
                        ),
                        const SizedBox(height: 18),
                        DropdownButtonFormField<int>(
                          initialValue: _categoryId,
                          decoration: InputDecoration(
                            labelText: 'Categoría',
                            errorText: state.fieldErrors['category_id'],
                          ),
                          items: state.categories
                              .map(
                                (category) => DropdownMenuItem(
                                  value: category.id,
                                  child: Text(category.name),
                                ),
                              )
                              .toList(),
                          onChanged: busy
                              ? null
                              : (id) => setState(() => _categoryId = id),
                          validator: (value) => value == null
                              ? 'Selecciona una categoría activa.'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _brand,
                          decoration: InputDecoration(
                            labelText: 'Marca (opcional)',
                            errorText: state.fieldErrors['brand'],
                          ),
                        ),
                        if (state.error != null && state.fieldErrors.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              state.error!,
                              style: const TextStyle(color: Color(0xFFB42318)),
                            ),
                          ),
                        const SizedBox(height: 20),
                        PrimaryActionButton(
                          label: 'Guardar',
                          busy: busy,
                          onPressed: busy
                              ? null
                              : () => _submit(context, state.product),
                        ),
                        Center(
                          child: TextButton(
                            onPressed: busy ? null : () => context.pop(false),
                            child: const Text('Cancelar'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );

  void _submit(BuildContext context, SellerProduct? original) {
    if (!_form.currentState!.validate()) return;
    final category = _categoryId;
    if (category == null) return;
    context.read<SellerProductFormBloc>().add(
      SellerProductFormSaveRequested(
        id: widget.id,
        name: _name.text,
        description: _description.text,
        categoryId: category,
        brand: _brand.text,
        original: original,
      ),
    );
  }
}
