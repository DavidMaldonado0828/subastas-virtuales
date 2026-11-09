import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/home/auction.dart';
import '../../repositories/home/auction_repository.dart';

const homePageSize = 10;
const participationPageSize = 100;

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
  const HomeState({
    required this.tab,
    required this.itemsByTab,
    required this.hasMore,
    this.participation = const {},
    this.message,
  });

  final HomeTab tab;
  final Map<HomeTab, List<Auction>> itemsByTab;
  final bool hasMore;
  final Map<int, AuctionParticipation> participation;
  final String? message;
  List<Auction> get items => itemsByTab[tab] ?? const [];

  @override
  List<Object?> get props => [tab, itemsByTab, hasMore, participation, message];
}

final class HomeInitial extends HomeState {
  const HomeInitial({
    super.tab = HomeTab.available,
    super.itemsByTab = const {},
    super.hasMore = true,
    super.participation,
  });
}

final class HomeLoading extends HomeState {
  const HomeLoading({
    required super.tab,
    required super.itemsByTab,
    required super.hasMore,
    super.participation,
  });
}

final class HomeSuccess extends HomeState {
  const HomeSuccess({
    required super.tab,
    required super.itemsByTab,
    required super.hasMore,
    super.participation,
  });
}

final class HomeEmpty extends HomeState {
  const HomeEmpty({
    required super.tab,
    required super.itemsByTab,
    super.participation,
  }) : super(hasMore: false);
}

final class HomeError extends HomeState {
  const HomeError({
    required super.tab,
    required super.itemsByTab,
    required super.hasMore,
    required String error,
    super.participation,
  }) : super(message: error);
}

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  HomeBloc(this.repository, {this.loadParticipation = false})
    : super(const HomeInitial()) {
    on<HomeLoadRequested>(_load);
    on<HomeLoadMoreRequested>(_loadMore);
    on<HomeRefreshRequested>(_refresh);
    on<HomeTabChanged>(_changeTab);
  }

  final AuctionRepository repository;
  final bool loadParticipation;
  HomeTab _activeTab = HomeTab.available;
  final Map<HomeTab, List<Auction>> _items = {for (final tab in HomeTab.values) tab: []};
  final Map<HomeTab, bool> _hasMore = {for (final tab in HomeTab.values) tab: true};
  final Map<HomeTab, bool> _loaded = {for (final tab in HomeTab.values) tab: false};
  final Map<HomeTab, bool> _loading = {for (final tab in HomeTab.values) tab: false};
  final Map<HomeTab, String?> _errors = {for (final tab in HomeTab.values) tab: null};
  Map<int, AuctionParticipation> _participation = const {};
  int _participationRequest = 0;

  bool _isClosed(HomeTab tab) => tab == HomeTab.closed;

  Future<void> _load(HomeLoadRequested event, Emitter<HomeState> emit) async {
    final active = _activeTab;
    if (!_loaded[active]!) await _fetchPage(active, emit, reset: true);
    if (loadParticipation) await _fetchParticipation(emit);
  }

  Future<void> _refresh(HomeRefreshRequested event, Emitter<HomeState> emit) async {
    final participationFuture = loadParticipation
        ? _fetchParticipation(emit)
        : Future<void>.value();
    await _fetchPage(_activeTab, emit, reset: true);
    await participationFuture;
  }

  Future<void> _loadMore(HomeLoadMoreRequested event, Emitter<HomeState> emit) async {
    final tab = _activeTab;
    if (!_loaded[tab]! || !_hasMore[tab]! || _loading[tab]!) return;
    await _fetchPage(tab, emit, reset: false);
  }

  Future<void> _changeTab(HomeTabChanged event, Emitter<HomeState> emit) async {
    final tab = event.tab;
    if (tab == _activeTab) return;
    _activeTab = tab;
    if (_loaded[tab]!) {
      _emitActive(emit);
      return;
    }
    if (_loading[tab]!) {
      _emitActive(emit);
      return;
    }
    await _fetchPage(tab, emit, reset: true);
  }

  Future<void> _fetchPage(
    HomeTab tab,
    Emitter<HomeState> emit, {
    required bool reset,
  }) async {
    if (_loading[tab]!) {
      if (tab == _activeTab) _emitActive(emit);
      return;
    }
    final currentItems = List<Auction>.of(_items[tab]!);
    _errors[tab] = null;
    _loading[tab] = true;
    _emitActive(emit);
    try {
      final page = await repository.fetch(
        limit: homePageSize,
        offset: reset ? 0 : currentItems.length,
        closed: _isClosed(tab),
      );
      _items[tab] = List<Auction>.unmodifiable(
        reset ? page.items : [...currentItems, ...page.items],
      );
      _hasMore[tab] = page.items.length == homePageSize;
      _loaded[tab] = true;
    } catch (error) {
      _errors[tab] = _errorMessage(error);
    } finally {
      _loading[tab] = false;
      _emitActive(emit);
    }
  }

  Future<void> _fetchParticipation(Emitter<HomeState> emit) async {
    final requestId = ++_participationRequest;
    final result = <int, AuctionParticipation>{};
    try {
      var offset = 0;
      while (true) {
        final page = await repository.fetchMyAuctions(
          limit: participationPageSize,
          offset: offset,
        );
        for (final item in page.items) {
          result[item.auctionId] = AuctionParticipation(
            status: item.status,
            isLeader: item.isLeader,
          );
        }
        if (page.items.length < participationPageSize) break;
        offset += page.items.length;
      }
      if (requestId == _participationRequest) {
        _participation = Map.unmodifiable(result);
        _emitActive(emit);
      }
    } catch (_) {
      if (requestId == _participationRequest) {
        _participation = const {};
        _emitActive(emit);
      }
    }
  }

  void _emitActive(Emitter<HomeState> emit) {
    final itemsByTab = Map<HomeTab, List<Auction>>.unmodifiable({
      for (final tab in HomeTab.values)
        tab: List<Auction>.unmodifiable(_items[tab]!),
    });
    final hasMore = _hasMore[_activeTab]!;
    if (_loading[_activeTab]!) {
      emit(HomeLoading(
        tab: _activeTab,
        itemsByTab: itemsByTab,
        hasMore: hasMore,
        participation: _participation,
      ));
    } else if (_errors[_activeTab] != null) {
      emit(HomeError(
        tab: _activeTab,
        itemsByTab: itemsByTab,
        hasMore: hasMore,
        participation: _participation,
        error: _errors[_activeTab]!,
      ));
    } else if (_loaded[_activeTab]! && _items[_activeTab]!.isEmpty) {
      emit(HomeEmpty(
        tab: _activeTab,
        itemsByTab: itemsByTab,
        participation: _participation,
      ));
    } else if (_loaded[_activeTab]!) {
      emit(HomeSuccess(
        tab: _activeTab,
        itemsByTab: itemsByTab,
        hasMore: hasMore,
        participation: _participation,
      ));
    } else {
      emit(HomeInitial(
        tab: _activeTab,
        itemsByTab: itemsByTab,
        hasMore: hasMore,
        participation: _participation,
      ));
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
