import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/seller_products/seller_product.dart';
import '../../repositories/seller_products/seller_products_repository.dart';

enum SellerProductFormView { loading, ready, error, saving }

sealed class SellerProductFormEvent extends Equatable {
  const SellerProductFormEvent();
  @override
  List<Object?> get props => [];
}

class SellerProductFormLoadRequested extends SellerProductFormEvent {
  const SellerProductFormLoadRequested(this.id);
  final int? id;
  @override
  List<Object?> get props => [id];
}

class SellerProductFormSaveRequested extends SellerProductFormEvent {
  const SellerProductFormSaveRequested({
    required this.id,
    required this.name,
    required this.description,
    required this.categoryId,
    required this.brand,
    required this.original,
  });
  final int? id;
  final String name, description, brand;
  final int categoryId;
  final SellerProduct? original;
  @override
  List<Object?> get props => [
    id,
    name,
    description,
    categoryId,
    brand,
    original,
  ];
}

class SellerProductFormState extends Equatable {
  const SellerProductFormState({
    this.view = SellerProductFormView.loading,
    this.categories = const [],
    this.product,
    this.error,
    this.fieldErrors = const {},
    this.message,
    this.saved = false,
  });
  final SellerProductFormView view;
  final List<SellerCategory> categories;
  final SellerProduct? product;
  final String? error, message;
  final Map<String, String> fieldErrors;
  final bool saved;
  @override
  List<Object?> get props => [
    view,
    categories,
    product,
    error,
    fieldErrors,
    message,
    saved,
  ];
}

class SellerProductFormBloc
    extends Bloc<SellerProductFormEvent, SellerProductFormState> {
  SellerProductFormBloc(this.repository)
    : super(const SellerProductFormState()) {
    on<SellerProductFormLoadRequested>(_load);
    on<SellerProductFormSaveRequested>(_save);
  }
  final SellerProductsRepository repository;
  Future<void> _load(
    SellerProductFormLoadRequested e,
    Emitter<SellerProductFormState> emit,
  ) async {
    try {
      final categories = await repository.categories();
      final product = e.id == null ? null : await repository.get(e.id!);
      emit(
        SellerProductFormState(
          view: SellerProductFormView.ready,
          categories: categories,
          product: product,
        ),
      );
    } catch (e) {
      emit(
        SellerProductFormState(
          view: SellerProductFormView.error,
          error: _message(e),
        ),
      );
    }
  }

  Future<void> _save(
    SellerProductFormSaveRequested e,
    Emitter<SellerProductFormState> emit,
  ) async {
    emit(
      SellerProductFormState(
        view: SellerProductFormView.saving,
        categories: state.categories,
        product: state.product,
      ),
    );
    try {
      final payload = <String, dynamic>{};
      if (e.id == null) {
        payload.addAll({
          'name': e.name.trim(),
          'description': e.description.trim(),
          'category_id': e.categoryId,
          'brand': e.brand.trim().isEmpty ? null : e.brand.trim(),
          'image_url': null,
        });
        await repository.create(payload);
      } else {
        final old = e.original!;
        if (e.name.trim() != old.name) {
          payload['name'] = e.name.trim();
        }
        if (e.description.trim() != old.description) {
          payload['description'] = e.description.trim();
        }
        if (e.categoryId != old.categoryId) {
          payload['category_id'] = e.categoryId;
        }
        final brand = e.brand.trim().isEmpty ? null : e.brand.trim();
        if (brand != old.brand) payload['brand'] = brand;
        if (payload.isNotEmpty) await repository.update(e.id!, payload);
      }
      emit(
        SellerProductFormState(
          view: SellerProductFormView.ready,
          categories: state.categories,
          product: state.product,
          message: e.id == null
              ? 'Producto registrado.'
              : 'Producto actualizado.',
          saved: true,
        ),
      );
    } catch (error) {
      final fields = <String, String>{};
      if (error is DioException &&
          error.response?.statusCode == 422 &&
          error.response?.data is Map) {
        final detail = (error.response!.data as Map)['detail'];
        if (detail is List) {
          for (final issue in detail) {
            if (issue is Map &&
                issue['loc'] is List &&
                (issue['loc'] as List).isNotEmpty) {
              fields[(issue['loc'] as List).last.toString()] =
                  issue['msg']?.toString() ?? 'Valor inválido.';
            }
          }
        }
      }
      emit(
        SellerProductFormState(
          view: SellerProductFormView.ready,
          categories: state.categories,
          product: state.product,
          error: _message(error),
          fieldErrors: fields,
        ),
      );
    }
  }

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
