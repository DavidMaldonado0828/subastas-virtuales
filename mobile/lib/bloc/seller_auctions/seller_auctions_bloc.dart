import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/seller_auctions/seller_auction.dart';
import '../../repositories/seller_auctions/seller_auctions_repository.dart';

enum SellerAuctionsFilter { all, active, scheduled, closed }

enum SellerAuctionsView { loading, success, empty, error }

extension SellerAuctionsFilterStatus on SellerAuctionsFilter {
  String? get status => switch (this) {
    SellerAuctionsFilter.all => null,
    SellerAuctionsFilter.active => 'ACTIVA',
    SellerAuctionsFilter.scheduled => 'PROGRAMADA',
    SellerAuctionsFilter.closed => 'CERRADA',
  };
  bool matches(SellerAuction auction) => switch (this) {
    SellerAuctionsFilter.all => true,
    SellerAuctionsFilter.active => auction.status == 'ACTIVA',
    SellerAuctionsFilter.scheduled => auction.status == 'PROGRAMADA',
    SellerAuctionsFilter.closed =>
      auction.status == 'CERRADA' || auction.status == 'FINALIZADA_SIN_GANADOR',
  };
}

sealed class SellerAuctionsEvent extends Equatable {
  const SellerAuctionsEvent();
  @override
  List<Object?> get props => [];
}

class SellerAuctionsLoadRequested extends SellerAuctionsEvent {
  const SellerAuctionsLoadRequested();
}

class SellerAuctionsRefreshRequested extends SellerAuctionsEvent {
  const SellerAuctionsRefreshRequested();
}

class SellerAuctionsFilterChanged extends SellerAuctionsEvent {
  const SellerAuctionsFilterChanged(this.filter);
  final SellerAuctionsFilter filter;
  @override
  List<Object?> get props => [filter];
}

class SellerAuctionsState extends Equatable {
  const SellerAuctionsState({
    this.view = SellerAuctionsView.loading,
    this.items = const [],
    this.filter = SellerAuctionsFilter.all,
    this.error,
    this.message,
    this.refreshing = false,
  });
  final SellerAuctionsView view;
  final List<SellerAuction> items;
  final SellerAuctionsFilter filter;
  final String? error, message;
  final bool refreshing;
  List<SellerAuction> get visibleItems =>
      items.where(filter.matches).toList(growable: false);
  @override
  List<Object?> get props => [view, items, filter, error, message, refreshing];
}

class SellerAuctionsBloc
    extends Bloc<SellerAuctionsEvent, SellerAuctionsState> {
  SellerAuctionsBloc(this.repository) : super(const SellerAuctionsState()) {
    on<SellerAuctionsLoadRequested>(
      (event, emit) => _load(emit, refresh: false),
    );
    on<SellerAuctionsRefreshRequested>(
      (event, emit) => _load(emit, refresh: true),
    );
    on<SellerAuctionsFilterChanged>(
      (event, emit) => emit(_copy(filter: event.filter, message: null)),
    );
  }
  final SellerAuctionsRepository repository;
  SellerAuctionsState _copy({
    SellerAuctionsView? view,
    List<SellerAuction>? items,
    SellerAuctionsFilter? filter,
    String? error,
    String? message,
    bool? refreshing,
    bool clearError = false,
  }) => SellerAuctionsState(
    view: view ?? state.view,
    items: items ?? state.items,
    filter: filter ?? state.filter,
    error: clearError ? null : error ?? state.error,
    message: message,
    refreshing: refreshing ?? state.refreshing,
  );
  Future<void> _load(
    Emitter<SellerAuctionsState> emit, {
    required bool refresh,
  }) async {
    emit(
      _copy(
        view: state.items.isEmpty ? SellerAuctionsView.loading : state.view,
        refreshing: refresh,
        clearError: true,
        message: null,
      ),
    );
    try {
      const pageSize = 100;
      var offset = 0;
      final items = <SellerAuction>[];
      while (true) {
        final page = await repository.fetch(limit: pageSize, offset: offset);
        items.addAll(page.items);
        offset += page.items.length;
        if (page.items.length < pageSize) break;
      }
      emit(
        _copy(
          view: items.isEmpty
              ? SellerAuctionsView.empty
              : SellerAuctionsView.success,
          items: List.unmodifiable(items),
          refreshing: false,
          clearError: true,
        ),
      );
    } catch (error) {
      emit(
        _copy(
          view: state.items.isEmpty
              ? SellerAuctionsView.error
              : SellerAuctionsView.success,
          refreshing: false,
          error: _message(error),
        ),
      );
    }
  }

  String _message(Object error) {
    if (error is DioException) {
      if ([
        DioExceptionType.connectionError,
        DioExceptionType.connectionTimeout,
        DioExceptionType.receiveTimeout,
      ].contains(error.type)) {
        return 'No se pudo conectar con el servidor';
      }
      final detail = error.requestOptions.extra['apiDetail'];
      if (detail is String && detail.isNotEmpty) return detail;
    }
    return 'No se pudieron cargar tus subastas.';
  }
}
