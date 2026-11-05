import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/auction.dart';
import '../repositories/auction_repository.dart';

const homePageSize = 10;

enum HomeTab { available, closed }

sealed class HomeEvent extends Equatable {
  const HomeEvent();
  @override
  List<Object?> get props => [];
}

final class HomeLoadRequested extends HomeEvent { const HomeLoadRequested(); }
final class HomeLoadMoreRequested extends HomeEvent { const HomeLoadMoreRequested(); }
final class HomeRefreshRequested extends HomeEvent { const HomeRefreshRequested(); }
final class HomeTabChanged extends HomeEvent {
  const HomeTabChanged(this.tab);
  final HomeTab tab;
  @override
  List<Object?> get props => [tab];
}

sealed class HomeState extends Equatable {
  const HomeState({required this.tab, required this.items, required this.hasMore, this.message});
  final HomeTab tab;
  final List<Auction> items;
  final bool hasMore;
  final String? message;
  @override
  List<Object?> get props => [tab, items, hasMore, message];
}

final class HomeInitial extends HomeState {
  const HomeInitial({super.tab = HomeTab.available, super.items = const [], super.hasMore = true});
}
final class HomeLoading extends HomeState {
  const HomeLoading({required super.tab, required super.items, required super.hasMore});
}
final class HomeSuccess extends HomeState {
  const HomeSuccess({required super.tab, required super.items, required super.hasMore});
}
final class HomeEmpty extends HomeState {
  const HomeEmpty({required super.tab}) : super(items: const [], hasMore: false);
}
final class HomeError extends HomeState {
  const HomeError({required super.tab, required super.items, required super.hasMore, required String error}) : super(message: error);
}

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  HomeBloc(this.repository) : super(const HomeInitial()) {
    on<HomeLoadRequested>(_load);
    on<HomeLoadMoreRequested>(_loadMore);
    on<HomeRefreshRequested>(_refresh);
    on<HomeTabChanged>(_changeTab);
  }

  final AuctionRepository repository;
  final Map<HomeTab, List<Auction>> _items = {for (final tab in HomeTab.values) tab: []};
  final Map<HomeTab, bool> _hasMore = {for (final tab in HomeTab.values) tab: true};
  final Map<HomeTab, bool> _loaded = {for (final tab in HomeTab.values) tab: false};
  final Map<HomeTab, String?> _errors = {for (final tab in HomeTab.values) tab: null};

  bool _isClosed(HomeTab tab) => tab == HomeTab.closed;

  Future<void> _load(HomeLoadRequested event, Emitter<HomeState> emit) async {
    if (_loaded[state.tab] == true) return;
    await _fetchPage(state.tab, emit, reset: true);
  }

  Future<void> _refresh(HomeRefreshRequested event, Emitter<HomeState> emit) async {
    await _fetchPage(state.tab, emit, reset: true);
  }

  Future<void> _loadMore(HomeLoadMoreRequested event, Emitter<HomeState> emit) async {
    final tab = state.tab;
    if (!_loaded[tab]! || !_hasMore[tab]! || state is HomeLoading) return;
    await _fetchPage(tab, emit, reset: false);
  }

  Future<void> _changeTab(HomeTabChanged event, Emitter<HomeState> emit) async {
    final tab = event.tab;
    if (tab == state.tab) return;
    if (_loaded[tab]!) {
      _emitContent(emit, tab);
    } else {
      await _fetchPage(tab, emit, reset: true);
    }
  }

  Future<void> _fetchPage(HomeTab tab, Emitter<HomeState> emit, {required bool reset}) async {
    final currentItems = List<Auction>.of(_items[tab]!);
    _errors[tab] = null;
    emit(HomeLoading(tab: tab, items: currentItems, hasMore: _hasMore[tab]!));
    try {
      final page = await repository.fetch(
        limit: homePageSize,
        offset: reset ? 0 : currentItems.length,
        closed: _isClosed(tab),
      );
      final updated = reset ? page.items : [...currentItems, ...page.items];
      _items[tab] = updated;
      _hasMore[tab] = page.items.length == homePageSize;
      _loaded[tab] = true;
      _emitContent(emit, tab);
    } catch (error) {
      _errors[tab] = _errorMessage(error);
      emit(HomeError(tab: tab, items: List.unmodifiable(currentItems), hasMore: _hasMore[tab]!, error: _errors[tab]!));
    }
  }

  void _emitContent(Emitter<HomeState> emit, HomeTab tab) {
    final items = List<Auction>.unmodifiable(_items[tab]!);
    if (_errors[tab] != null) {
      emit(HomeError(tab: tab, items: items, hasMore: _hasMore[tab]!, error: _errors[tab]!));
    } else if (items.isEmpty) {
      emit(HomeEmpty(tab: tab));
    } else {
      emit(HomeSuccess(tab: tab, items: items, hasMore: _hasMore[tab]!));
    }
  }

  String _errorMessage(Object error) {
    if (error is DioException &&
        {
          DioExceptionType.connectionError,
          DioExceptionType.connectionTimeout,
          DioExceptionType.receiveTimeout,
        }.contains(error.type)) {
      return 'No se pudo conectar con el servidor';
    }
    if (error is DioException && error.requestOptions.extra['apiDetail'] is String) {
      return error.requestOptions.extra['apiDetail'] as String;
    }
    return 'No se pudieron cargar las subastas. Intenta de nuevo.';
  }
}
