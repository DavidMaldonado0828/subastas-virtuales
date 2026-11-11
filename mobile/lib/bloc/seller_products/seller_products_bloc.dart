import 'dart:async';

import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/seller_products/seller_product.dart';
import '../../repositories/seller_products/seller_products_repository.dart';

enum SellerProductFilter { all, active, disabled }

enum SellerProductsView { loading, success, empty, error }

sealed class SellerProductsEvent extends Equatable {
  const SellerProductsEvent();
  @override
  List<Object?> get props => [];
}

class SellerProductsLoadRequested extends SellerProductsEvent {
  const SellerProductsLoadRequested();
}

class SellerProductsRefreshRequested extends SellerProductsEvent {
  const SellerProductsRefreshRequested();
}

class SellerProductsNameChanged extends SellerProductsEvent {
  const SellerProductsNameChanged(this.value);
  final String value;
  @override
  List<Object?> get props => [value];
}

class SellerProductsFilterChanged extends SellerProductsEvent {
  const SellerProductsFilterChanged(this.filter);
  final SellerProductFilter filter;
  @override
  List<Object?> get props => [filter];
}

class SellerProductDeleteRequested extends SellerProductsEvent {
  const SellerProductDeleteRequested(this.id);
  final int id;
  @override
  List<Object?> get props => [id];
}

class SellerProductReactivateRequested extends SellerProductsEvent {
  const SellerProductReactivateRequested(this.id);
  final int id;
  @override
  List<Object?> get props => [id];
}

class SellerProductsState extends Equatable {
  const SellerProductsState({
    this.view = SellerProductsView.loading,
    this.products = const [],
    this.filter = SellerProductFilter.all,
    this.query = '',
    this.error,
    this.message,
    this.busy = false,
  });
  final SellerProductsView view;
  final List<SellerProduct> products;
  final SellerProductFilter filter;
  final String query;
  final String? error, message;
  final bool busy;
  List<SellerProduct> get visibleProducts => products
      .where(
        (p) =>
            (filter == SellerProductFilter.all ||
                (filter == SellerProductFilter.active
                    ? p.status == 'ACTIVO'
                    : p.status == 'DESACTIVADO')) &&
            _normalize(p.name).contains(_normalize(query)),
      )
      .toList();
  static String _normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[áàäâã]'), 'a')
      .replaceAll(RegExp(r'[éèëê]'), 'e')
      .replaceAll(RegExp(r'[íìïî]'), 'i')
      .replaceAll(RegExp(r'[óòöôõ]'), 'o')
      .replaceAll(RegExp(r'[úùüû]'), 'u')
      .replaceAll('ñ', 'n');
  @override
  List<Object?> get props => [
    view,
    products,
    filter,
    query,
    error,
    message,
    busy,
  ];
}

class SellerProductsBloc
    extends Bloc<SellerProductsEvent, SellerProductsState> {
  int _filterSequence = 0;
  SellerProductsBloc(this.repository) : super(const SellerProductsState()) {
    on<SellerProductsLoadRequested>((e, emit) => _load(emit));
    on<SellerProductsRefreshRequested>((e, emit) => _load(emit));
    on<SellerProductsNameChanged>((e, emit) async {
      final sequence = ++_filterSequence;
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (sequence == _filterSequence && !emit.isDone) {
        emit(_copy(query: e.value, message: null));
      }
    });
    on<SellerProductsFilterChanged>(
      (e, emit) => emit(_copy(filter: e.filter, message: null)),
    );
    on<SellerProductDeleteRequested>(_delete);
    on<SellerProductReactivateRequested>(_reactivate);
  }
  final SellerProductsRepository repository;
  SellerProductsState _copy({
    SellerProductsView? view,
    List<SellerProduct>? products,
    SellerProductFilter? filter,
    String? query,
    String? error,
    String? message,
    bool? busy,
    bool clearError = false,
  }) => SellerProductsState(
    view: view ?? state.view,
    products: products ?? state.products,
    filter: filter ?? state.filter,
    query: query ?? state.query,
    error: clearError ? null : error ?? state.error,
    message: message,
    busy: busy ?? state.busy,
  );
  Future<void> _load(Emitter<SellerProductsState> emit) async {
    emit(
      _copy(view: SellerProductsView.loading, clearError: true, message: null),
    );
    try {
      final products = await repository.list();
      emit(
        _copy(
          view: products.isEmpty
              ? SellerProductsView.empty
              : SellerProductsView.success,
          products: products,
          clearError: true,
        ),
      );
    } catch (e) {
      emit(_copy(view: SellerProductsView.error, error: _message(e)));
    }
  }

  Future<void> _delete(
    SellerProductDeleteRequested e,
    Emitter<SellerProductsState> emit,
  ) async {
    emit(_copy(busy: true, message: null));
    try {
      final result = await repository.delete(e.id);
      final deleted = result['result'] == 'DELETED';
      final next = deleted
          ? state.products.where((p) => p.id != e.id).toList()
          : state.products
                .map((p) => p.id == e.id ? _withStatus(p, 'DESACTIVADO') : p)
                .toList();
      emit(
        _copy(
          products: next,
          view: next.isEmpty
              ? SellerProductsView.empty
              : SellerProductsView.success,
          busy: false,
          message: deleted
              ? 'Producto eliminado.'
              : 'Producto desactivado porque tiene historial',
        ),
      );
    } catch (e) {
      emit(_copy(busy: false, error: _message(e)));
    }
  }

  Future<void> _reactivate(
    SellerProductReactivateRequested e,
    Emitter<SellerProductsState> emit,
  ) async {
    emit(_copy(busy: true, message: null));
    try {
      final p = await repository.reactivate(e.id);
      final next = state.products.map((x) => x.id == e.id ? p : x).toList();
      emit(_copy(products: next, busy: false, message: 'Producto reactivado.'));
    } catch (e) {
      emit(_copy(busy: false, error: _message(e)));
    }
  }

  SellerProduct _withStatus(SellerProduct p, String status) => SellerProduct(
    id: p.id,
    categoryId: p.categoryId,
    categoryName: p.categoryName,
    status: status,
    name: p.name,
    description: p.description,
    brand: p.brand,
    imageUrl: p.imageUrl,
  );
  String _message(Object e) {
    if (e is DioException) {
      final detail = e.requestOptions.extra['apiDetail'];
      if (detail is String && detail.isNotEmpty) return detail;
      if ([
        DioExceptionType.connectionError,
        DioExceptionType.connectionTimeout,
        DioExceptionType.receiveTimeout,
      ].contains(e.type)) {
        return 'No se pudo conectar con el servidor';
      }
    }
    return 'No se pudo completar la solicitud.';
  }
}
