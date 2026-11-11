import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/seller_auctions/seller_auction.dart';
import '../../models/seller_products/seller_product.dart';
import '../../repositories/seller_auctions/seller_auctions_repository.dart';

enum SellerAuctionFormView { loading, ready, saving, error }

sealed class SellerAuctionFormEvent extends Equatable {
  const SellerAuctionFormEvent();
  @override
  List<Object?> get props => [];
}

class SellerAuctionFormLoadRequested extends SellerAuctionFormEvent {
  const SellerAuctionFormLoadRequested(this.id);
  final int? id;
  @override
  List<Object?> get props => [id];
}

class SellerAuctionFormSaveRequested extends SellerAuctionFormEvent {
  const SellerAuctionFormSaveRequested({
    required this.id,
    required this.productId,
    required this.basePrice,
    required this.minimumIncrement,
    required this.startDate,
    required this.endDate,
    required this.original,
  });
  final int? id;
  final int productId, basePrice, minimumIncrement;
  final DateTime startDate, endDate;
  final SellerAuction? original;
  @override
  List<Object?> get props => [
    id,
    productId,
    basePrice,
    minimumIncrement,
    startDate,
    endDate,
    original,
  ];
}

class SellerAuctionFormState extends Equatable {
  const SellerAuctionFormState({
    this.view = SellerAuctionFormView.loading,
    this.products = const [],
    this.auction,
    this.error,
    this.fieldErrors = const {},
    this.message,
    this.saved = false,
  });
  final SellerAuctionFormView view;
  final List<SellerProduct> products;
  final SellerAuction? auction;
  final String? error, message;
  final Map<String, String> fieldErrors;
  final bool saved;
  @override
  List<Object?> get props => [
    view,
    products,
    auction,
    error,
    fieldErrors,
    message,
    saved,
  ];
}

class SellerAuctionFormBloc
    extends Bloc<SellerAuctionFormEvent, SellerAuctionFormState> {
  SellerAuctionFormBloc(this.repository)
    : super(const SellerAuctionFormState()) {
    on<SellerAuctionFormLoadRequested>(_load);
    on<SellerAuctionFormSaveRequested>(_save);
  }
  final SellerAuctionsRepository repository;
  Future<void> _load(
    SellerAuctionFormLoadRequested event,
    Emitter<SellerAuctionFormState> emit,
  ) async {
    try {
      final products = event.id == null
          ? await repository.products()
          : <SellerProduct>[];
      SellerAuction? auction;
      if (event.id != null) {
        final items = await repository.fetchAll();
        auction = items.where((item) => item.id == event.id).firstOrNull;
        if (auction == null ||
            auction.bidCount != 0 ||
            !['PROGRAMADA', 'ACTIVA'].contains(auction.status)) {
          emit(
            SellerAuctionFormState(
              view: SellerAuctionFormView.error,
              error: 'Esta subasta no se puede editar.',
            ),
          );
          return;
        }
      }
      emit(
        SellerAuctionFormState(
          view: SellerAuctionFormView.ready,
          products: products
              .where((product) => product.status == 'ACTIVO')
              .toList(growable: false),
          auction: auction,
        ),
      );
    } catch (error) {
      emit(
        SellerAuctionFormState(
          view: SellerAuctionFormView.error,
          error: _message(error),
        ),
      );
    }
  }

  Future<void> _save(
    SellerAuctionFormSaveRequested event,
    Emitter<SellerAuctionFormState> emit,
  ) async {
    emit(
      SellerAuctionFormState(
        view: SellerAuctionFormView.saving,
        products: state.products,
        auction: state.auction,
      ),
    );
    try {
      if (event.id == null) {
        await repository.create({
          'product_id': event.productId,
          'base_price': event.basePrice,
          'minimum_increment': event.minimumIncrement,
          'start_date': event.startDate.toUtc().toIso8601String(),
          'end_date': event.endDate.toUtc().toIso8601String(),
        });
      } else {
        final old = event.original!;
        final patch = <String, dynamic>{};
        if (event.basePrice != old.basePrice) {
          patch['base_price'] = event.basePrice;
        }
        if (event.minimumIncrement != old.minimumIncrement) {
          patch['minimum_increment'] = event.minimumIncrement;
        }
        if (event.startDate.toUtc() != old.startDate.toUtc()) {
          patch['start_date'] = event.startDate.toUtc().toIso8601String();
        }
        if (event.endDate.toUtc() != old.endDate.toUtc()) {
          patch['end_date'] = event.endDate.toUtc().toIso8601String();
        }
        if (patch.isNotEmpty) await repository.update(event.id!, patch);
      }
      emit(
        SellerAuctionFormState(
          view: SellerAuctionFormView.ready,
          products: state.products,
          auction: state.auction,
          message: event.id == null
              ? 'Subasta creada.'
              : 'Subasta actualizada.',
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
        SellerAuctionFormState(
          view: SellerAuctionFormView.ready,
          products: state.products,
          auction: state.auction,
          error: _message(error),
          fieldErrors: fields,
        ),
      );
    }
  }

  String _message(Object error) {
    if (error is DioException) {
      final detail = error.requestOptions.extra['apiDetail'];
      if (detail is String && detail.isNotEmpty) return detail;
      if ([
        DioExceptionType.connectionError,
        DioExceptionType.connectionTimeout,
        DioExceptionType.receiveTimeout,
      ].contains(error.type)) {
        return 'No se pudo conectar con el servidor';
      }
    }
    return 'No se pudo guardar la subasta.';
  }
}
