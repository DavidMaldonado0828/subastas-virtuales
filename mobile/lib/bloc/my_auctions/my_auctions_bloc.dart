import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/my_auctions/my_auction.dart';
import '../../repositories/my_auctions/my_auctions_repository.dart';

enum MyAuctionsFilter { all, active, closed }

enum MyAuctionsView { initial, loading, success, empty, error }

extension MyAuctionsFilterStatus on MyAuctionsFilter {
  String? get status => switch (this) {
    MyAuctionsFilter.all => null,
    MyAuctionsFilter.active => 'ACTIVA',
    MyAuctionsFilter.closed => 'CERRADA',
  };
}

sealed class MyAuctionsEvent extends Equatable {
  const MyAuctionsEvent();
  @override
  List<Object?> get props => [];
}

class MyAuctionsLoadRequested extends MyAuctionsEvent {
  const MyAuctionsLoadRequested();
}

class MyAuctionsLoadMoreRequested extends MyAuctionsEvent {
  const MyAuctionsLoadMoreRequested();
}

class MyAuctionsRefreshRequested extends MyAuctionsEvent {
  const MyAuctionsRefreshRequested();
}

class MyAuctionsFilterChanged extends MyAuctionsEvent {
  const MyAuctionsFilterChanged(this.filter);
  final MyAuctionsFilter filter;
  @override
  List<Object?> get props => [filter];
}

class MyAuctionsState extends Equatable {
  const MyAuctionsState({
    this.view = MyAuctionsView.initial,
    this.filter = MyAuctionsFilter.all,
    this.lists = const {},
    this.hasMoreByFilter = const {},
    this.loadedFilters = const {},
    this.loadingMore = false,
    this.errorMessage,
  });
  final MyAuctionsView view;
  final MyAuctionsFilter filter;
  final Map<MyAuctionsFilter, List<MyAuction>> lists;
  final Map<MyAuctionsFilter, bool> hasMoreByFilter;
  final Set<MyAuctionsFilter> loadedFilters;
  final bool loadingMore;
  final String? errorMessage;
  List<MyAuction> get items => lists[filter] ?? const [];
  bool get hasMore => hasMoreByFilter[filter] ?? true;
  @override
  List<Object?> get props => [
    view,
    filter,
    lists,
    hasMoreByFilter,
    loadedFilters,
    loadingMore,
    errorMessage,
  ];
}

class MyAuctionsBloc extends Bloc<MyAuctionsEvent, MyAuctionsState> {
  MyAuctionsBloc(this.repository) : super(const MyAuctionsState()) {
    on<MyAuctionsLoadRequested>(
      (event, emit) => _fetch(emit, state.filter, reset: true),
    );
    on<MyAuctionsLoadMoreRequested>(
      (event, emit) => _fetch(emit, state.filter, more: true),
    );
    on<MyAuctionsRefreshRequested>(
      (event, emit) => _fetch(emit, state.filter, reset: true),
    );
    on<MyAuctionsFilterChanged>(_changeFilter);
  }
  final MyAuctionsRepository repository;
  static const pageSize = 10;
  final Set<MyAuctionsFilter> _inFlight = {};

  Future<void> _changeFilter(
    MyAuctionsFilterChanged event,
    Emitter<MyAuctionsState> emit,
  ) async {
    final filter = event.filter;
    emit(
      _copy(
        state,
        filter: filter,
        view: state.loadedFilters.contains(filter)
            ? (state.lists[filter]?.isEmpty ?? true
                  ? MyAuctionsView.empty
                  : MyAuctionsView.success)
            : MyAuctionsView.loading,
        loadingMore: false,
        clearError: true,
      ),
    );
    if (!state.loadedFilters.contains(filter) && !_inFlight.contains(filter)) {
      await _fetch(emit, filter, reset: true);
    }
  }

  Future<void> _fetch(
    Emitter<MyAuctionsState> emit,
    MyAuctionsFilter filter, {
    bool reset = false,
    bool more = false,
  }) async {
    if (_inFlight.contains(filter)) return;
    final existing = state.lists[filter] ?? const <MyAuction>[];
    if (more &&
        (!(state.hasMoreByFilter[filter] ?? true) ||
            existing.isEmpty && !state.loadedFilters.contains(filter))) {
      return;
    }
    _inFlight.add(filter);
    if (filter == state.filter) {
      emit(
        _copy(
          state,
          view: reset
              ? MyAuctionsView.loading
              : existing.isEmpty
              ? MyAuctionsView.loading
              : MyAuctionsView.success,
          loadingMore: more,
          clearError: true,
        ),
      );
    }
    final offset = reset ? 0 : existing.length;
    try {
      final page = await repository.fetch(
        limit: pageSize,
        offset: offset,
        status: filter.status,
      );
      final current = state.lists[filter] ?? const <MyAuction>[];
      final next = reset ? page.items : [...current, ...page.items];
      final lists = Map<MyAuctionsFilter, List<MyAuction>>.from(state.lists)
        ..[filter] = List.unmodifiable(next);
      final moreMap = Map<MyAuctionsFilter, bool>.from(state.hasMoreByFilter)
        ..[filter] = page.items.length == pageSize;
      final loaded = {...state.loadedFilters, filter};
      emit(
        _copy(
          state,
          lists: lists,
          hasMoreByFilter: moreMap,
          loadedFilters: loaded,
          filter: state.filter,
          view: filter == state.filter
              ? (next.isEmpty ? MyAuctionsView.empty : MyAuctionsView.success)
              : state.view,
          loadingMore: false,
          clearError: true,
        ),
      );
    } catch (error) {
      if (filter == state.filter) {
        emit(
          _copy(
            state,
            view: existing.isEmpty
                ? MyAuctionsView.error
                : MyAuctionsView.success,
            loadingMore: false,
            errorMessage: _message(error),
          ),
        );
      }
    } finally {
      _inFlight.remove(filter);
    }
  }

  MyAuctionsState _copy(
    MyAuctionsState current, {
    MyAuctionsView? view,
    MyAuctionsFilter? filter,
    Map<MyAuctionsFilter, List<MyAuction>>? lists,
    Map<MyAuctionsFilter, bool>? hasMoreByFilter,
    Set<MyAuctionsFilter>? loadedFilters,
    bool? loadingMore,
    String? errorMessage,
    bool clearError = false,
  }) => MyAuctionsState(
    view: view ?? current.view,
    filter: filter ?? current.filter,
    lists: lists ?? current.lists,
    hasMoreByFilter: hasMoreByFilter ?? current.hasMoreByFilter,
    loadedFilters: loadedFilters ?? current.loadedFilters,
    loadingMore: loadingMore ?? current.loadingMore,
    errorMessage: clearError ? null : errorMessage ?? current.errorMessage,
  );

  String _message(Object error) {
    if (error is DioException &&
        (error.type == DioExceptionType.connectionError ||
            error.type == DioExceptionType.connectionTimeout ||
            error.type == DioExceptionType.receiveTimeout)) {
      return 'No se pudo conectar con el servidor';
    }
    if (error is DioException &&
        error.requestOptions.extra['apiStatus'] == 401) {
      return 'Tu sesión expiró. Inicia sesión nuevamente.';
    }
    return 'No se pudieron cargar tus subastas.';
  }
}
