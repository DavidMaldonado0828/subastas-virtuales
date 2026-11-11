import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../bloc/seller_auctions/seller_auction_form_bloc.dart';
import '../../models/seller_auctions/seller_auction.dart';
import '../../repositories/seller_auctions/seller_auctions_repository.dart';
import '../../widgets/shared/auth_snackbar.dart';
import '../../widgets/shared/primary_action_button.dart';
import '../../widgets/seller_auctions/local_date_format.dart';

class SellerAuctionFormPage extends StatelessWidget {
  const SellerAuctionFormPage({
    required this.repository,
    this.auctionId,
    super.key,
  });
  final SellerAuctionsRepository repository;
  final int? auctionId;
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) =>
        SellerAuctionFormBloc(repository)
          ..add(SellerAuctionFormLoadRequested(auctionId)),
    child: _SellerAuctionFormView(auctionId: auctionId),
  );
}

class _SellerAuctionFormView extends StatefulWidget {
  const _SellerAuctionFormView({required this.auctionId});
  final int? auctionId;
  @override
  State<_SellerAuctionFormView> createState() => _SellerAuctionFormViewState();
}

class _SellerAuctionFormViewState extends State<_SellerAuctionFormView> {
  final _form = GlobalKey<FormState>();
  final _basePrice = TextEditingController();
  final _increment = TextEditingController();
  int? _productId;
  DateTime? _startDate, _endDate;
  TimeOfDay? _startTime, _endTime;
  bool _initialized = false;
  @override
  void dispose() {
    _basePrice.dispose();
    _increment.dispose();
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocListener<SellerAuctionFormBloc, SellerAuctionFormState>(
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
          widget.auctionId == null ? 'Nueva subasta' : 'Editar subasta',
        ),
        leading: IconButton(
          onPressed: () => context.pop(false),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: BlocBuilder<SellerAuctionFormBloc, SellerAuctionFormState>(
        builder: (context, state) {
          if (state.view == SellerAuctionFormView.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.view == SellerAuctionFormView.error) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    state.error ?? 'No se pudo cargar el formulario',
                    textAlign: TextAlign.center,
                  ),
                  TextButton(
                    onPressed: () => context.read<SellerAuctionFormBloc>().add(
                      SellerAuctionFormLoadRequested(widget.auctionId),
                    ),
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            );
          }
          if (!_initialized) {
            _initialized = true;
            final auction = state.auction;
            _basePrice.text = auction?.basePrice.toInt().toString() ?? '';
            _increment.text =
                auction?.minimumIncrement.toInt().toString() ?? '';
            _productId = auction?.productId;
            if (auction != null) {
              final start = auction.startDate.toLocal(),
                  end = auction.endDate.toLocal();
              _startDate = DateTime(start.year, start.month, start.day);
              _endDate = DateTime(end.year, end.month, end.day);
              _startTime = TimeOfDay.fromDateTime(start);
              _endTime = TimeOfDay.fromDateTime(end);
            }
          }
          final busy = state.view == SellerAuctionFormView.saving;
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
                    if (state.auction == null)
                      DropdownButtonFormField<int>(
                        initialValue: _productId,
                        decoration: InputDecoration(
                          labelText: 'Producto activo',
                          errorText: state.fieldErrors['product_id'],
                        ),
                        items: state.products
                            .map(
                              (product) => DropdownMenuItem(
                                value: product.id,
                                child: Text(
                                  product.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: busy
                            ? null
                            : (value) => setState(() => _productId = value),
                        validator: (value) => value == null
                            ? 'Selecciona un producto activo.'
                            : null,
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          'Producto: ${state.auction!.productName}',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _basePrice,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: 'Precio base (COP)',
                        errorText: state.fieldErrors['base_price'],
                      ),
                      validator: (value) => value == null || value.isEmpty
                          ? 'El precio base es obligatorio.'
                          : (int.tryParse(value) == null ||
                                    int.parse(value) <= 0
                                ? 'Ingresa un monto entero mayor que cero.'
                                : null),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _increment,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: 'Incremento mínimo (COP)',
                        errorText: state.fieldErrors['minimum_increment'],
                      ),
                      validator: (value) => value == null || value.isEmpty
                          ? 'El incremento mínimo es obligatorio.'
                          : (int.tryParse(value) == null ||
                                    int.parse(value) <= 0
                                ? 'Ingresa un monto entero mayor que cero.'
                                : null),
                    ),
                    const SizedBox(height: 16),
                    _dateField(
                      context,
                      label: 'Fecha de inicio',
                      value: _startDate,
                      errorText: state.fieldErrors['start_date'],
                      onTap: () => _pickDate(context, isStart: true),
                    ),
                    const SizedBox(height: 12),
                    _timeField(
                      context,
                      label: 'Hora de inicio',
                      value: _startTime,
                      errorText: state.fieldErrors['start_date'],
                      onTap: () => _pickTime(context, isStart: true),
                    ),
                    const SizedBox(height: 16),
                    _dateField(
                      context,
                      label: 'Fecha de cierre',
                      value: _endDate,
                      errorText: state.fieldErrors['end_date'],
                      onTap: () => _pickDate(context, isStart: false),
                    ),
                    const SizedBox(height: 12),
                    _timeField(
                      context,
                      label: 'Hora de cierre',
                      value: _endTime,
                      errorText: state.fieldErrors['end_date'],
                      onTap: () => _pickTime(context, isStart: false),
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
                          : () => _save(context, state.auction),
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
  Widget _dateField(
    BuildContext context, {
    required String label,
    required DateTime? value,
    required String? errorText,
    required VoidCallback onTap,
  }) => InkWell(
    onTap: onTap,
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        errorText: errorText,
        suffixIcon: const Icon(Icons.calendar_month_outlined),
      ),
      child: Text(value == null ? 'Seleccionar fecha' : _dateOnly(value)),
    ),
  );
  Widget _timeField(
    BuildContext context, {
    required String label,
    required TimeOfDay? value,
    required String? errorText,
    required VoidCallback onTap,
  }) => InkWell(
    onTap: onTap,
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        errorText: errorText,
        suffixIcon: const Icon(Icons.access_time),
      ),
      child: Text(value?.format(context) ?? 'Seleccionar hora'),
    ),
  );
  String _dateOnly(DateTime value) => formatSellerDate(value);
  Future<void> _pickDate(BuildContext context, {required bool isStart}) async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: (isStart ? _startDate : _endDate) ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
    );
    if (selected != null && mounted) {
      setState(() {
        if (isStart) {
          _startDate = DateTime(selected.year, selected.month, selected.day);
        } else {
          _endDate = DateTime(selected.year, selected.month, selected.day);
        }
      });
    }
  }

  Future<void> _pickTime(BuildContext context, {required bool isStart}) async {
    final selected = await showTimePicker(
      context: context,
      initialTime: (isStart ? _startTime : _endTime) ?? TimeOfDay.now(),
    );
    if (selected != null && mounted) {
      setState(() {
        if (isStart) {
          _startTime = selected;
        } else {
          _endTime = selected;
        }
      });
    }
  }

  DateTime? _combine(DateTime? date, TimeOfDay? time) =>
      date == null || time == null
      ? null
      : DateTime(date.year, date.month, date.day, time.hour, time.minute);
  void _save(BuildContext context, SellerAuction? original) {
    if (!_form.currentState!.validate()) return;
    final start = _combine(_startDate, _startTime),
        end = _combine(_endDate, _endTime);
    if (start == null || end == null) {
      showAuthSnackbar(
        context,
        'Selecciona la fecha y hora de inicio y cierre.',
      );
      return;
    }
    if (!start.isAfter(DateTime.now())) {
      showAuthSnackbar(
        context,
        'La fecha y hora de inicio deben ser posteriores a ahora.',
      );
      return;
    }
    if (!end.isAfter(start)) {
      showAuthSnackbar(context, 'El cierre debe ser posterior al inicio.');
      return;
    }
    final product = _productId;
    if (product == null) return;
    context.read<SellerAuctionFormBloc>().add(
      SellerAuctionFormSaveRequested(
        id: widget.auctionId,
        productId: product,
        basePrice: int.parse(_basePrice.text),
        minimumIncrement: int.parse(_increment.text),
        startDate: start,
        endDate: end,
        original: original,
      ),
    );
  }
}
