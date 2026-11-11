import 'dart:async';

import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/detail/auction_detail.dart';
import '../../models/seller_auctions/seller_auction.dart';
import '../../repositories/detail/detail_repository.dart';
import '../../repositories/seller_auctions/seller_auctions_repository.dart';

enum SellerBidHistoryView { loading, success, empty, error }

sealed class SellerBidHistoryEvent extends Equatable {
  const SellerBidHistoryEvent();
  @override
  List<Object?> get props => [];
}

class SellerBidHistoryLoadRequested extends SellerBidHistoryEvent {
  const SellerBidHistoryLoadRequested(this.auctionId, {this.initialAuction});
  final int auctionId;
  final SellerAuction? initialAuction;
  @override
  List<Object?> get props => [auctionId, initialAuction];
}

class SellerBidHistoryLoadMoreRequested extends SellerBidHistoryEvent {
  const SellerBidHistoryLoadMoreRequested();
}

class SellerBidHistoryRefreshRequested extends SellerBidHistoryEvent {
  const SellerBidHistoryRefreshRequested();
}

class SellerBidHistoryState extends Equatable {
  const SellerBidHistoryState({
    this.view = SellerBidHistoryView.loading,
    this.auctionId = 0,
    this.initialAuction,
    this.detail,
    this.summaryUnavailable = false,
    this.items = const [],
    this.offset = 0,
    this.hasMore = true,
    this.loadingMore = false,
    this.refreshing = false,
    this.error,
  });
  final SellerBidHistoryView view;
  final int auctionId, offset;
  final SellerAuction? initialAuction;
  final AuctionDetail? detail;
  final bool summaryUnavailable;
  final List<SellerBid> items;
  final bool hasMore, loadingMore, refreshing;
  final String? error;

  String get productName =>
      detail?.auction.productName ?? initialAuction?.productName ?? '';
  String? get status => detail?.auction.status ?? initialAuction?.status;

  @override
  List<Object?> get props => [
    view,
    auctionId,
    initialAuction,
    detail,
    summaryUnavailable,
    items,
    offset,
    hasMore,
    loadingMore,
    refreshing,
    error,
  ];
}

class SellerBidHistoryBloc
    extends Bloc<SellerBidHistoryEvent, SellerBidHistoryState> {
  SellerBidHistoryBloc(this.repository, this.detailRepository)
    : super(const SellerBidHistoryState()) {
    on<SellerBidHistoryLoadRequested>(_load);
    on<SellerBidHistoryRefreshRequested>(
      (event, emit) => _fetch(emit, reset: true),
    );
    on<SellerBidHistoryLoadMoreRequested>(
      (event, emit) => _fetch(emit, more: true),
    );
  }
  final SellerAuctionsRepository repository;
  final DetailRepository detailRepository;
  static const pageSize = 20;
  bool _inFlight = false;
  Completer<void>? _requestCompleted;

  Future<void> _load(
    SellerBidHistoryLoadRequested event,
    Emitter<SellerBidHistoryState> emit,
  ) async {
    emit(
      SellerBidHistoryState(
        view: SellerBidHistoryView.loading,
        auctionId: event.auctionId,
        initialAuction: event.initialAuction,
      ),
    );
    await _fetch(emit, reset: true);
  }

  Future<void> _fetch(
    Emitter<SellerBidHistoryState> emit, {
    bool reset = false,
    bool more = false,
  }) async {
    if (more && !state.hasMore) return;
    while (_inFlight) {
      if (!reset) return;
      await _requestCompleted!.future;
    }
    if (more && !state.hasMore) return;
    _inFlight = true;
    final requestCompleted = Completer<void>();
    _requestCompleted = requestCompleted;
    final offset = reset ? 0 : state.offset;
    final oldState = state;
    emit(
      SellerBidHistoryState(
        view: state.items.isEmpty ? SellerBidHistoryView.loading : state.view,
        auctionId: state.auctionId,
        initialAuction: state.initialAuction,
        detail: reset ? null : state.detail,
        summaryUnavailable: reset ? false : state.summaryUnavailable,
        items: state.items,
        offset: offset,
        hasMore: state.hasMore,
        loadingMore: more,
        refreshing: reset,
      ),
    );

    final summaryFuture =
        reset && oldState.initialAuction?.status != 'CANCELADA'
        ? _readSummary(oldState.auctionId)
        : Future.value((oldState.detail, oldState.summaryUnavailable));
    final bidsFuture = _readBids(oldState.auctionId, offset);
    final (loadedDetail, unavailable) = await summaryFuture;
    final detail = reset ? loadedDetail : oldState.detail;
    final summaryUnavailable = reset
        ? unavailable
        : oldState.summaryUnavailable;

    try {
      final (page, bidError) = await bidsFuture;
      if (bidError != null) throw bidError;
      final loadedPage = page!;
      final items = reset
          ? loadedPage.items
          : [...oldState.items, ...loadedPage.items];
      emit(
        SellerBidHistoryState(
          view: items.isEmpty
              ? SellerBidHistoryView.empty
              : SellerBidHistoryView.success,
          auctionId: oldState.auctionId,
          initialAuction: oldState.initialAuction,
          detail: detail,
          summaryUnavailable: summaryUnavailable,
          items: List.unmodifiable(items),
          offset: offset + loadedPage.items.length,
          hasMore: loadedPage.items.length == pageSize,
        ),
      );
    } catch (error) {
      emit(
        SellerBidHistoryState(
          view: oldState.items.isEmpty
              ? SellerBidHistoryView.error
              : oldState.view,
          auctionId: oldState.auctionId,
          initialAuction: oldState.initialAuction,
          detail: detail,
          summaryUnavailable: summaryUnavailable,
          items: oldState.items,
          offset: oldState.offset,
          hasMore: oldState.hasMore,
          error: _message(error),
        ),
      );
    } finally {
      _inFlight = false;
      if (identical(_requestCompleted, requestCompleted)) {
        _requestCompleted = null;
      }
      requestCompleted.complete();
    }
  }

  Future<(AuctionDetail?, bool)> _readSummary(int auctionId) async {
    try {
      return (await detailRepository.fetchDetail(auctionId), false);
    } on DioException catch (error) {
      final status =
          error.response?.statusCode ?? error.requestOptions.extra['apiStatus'];
      return (null, status != 404);
    } catch (_) {
      return (null, true);
    }
  }

  Future<(SellerBidPage?, Object?)> _readBids(int auctionId, int offset) async {
    try {
      return (
        await repository.bids(id: auctionId, limit: pageSize, offset: offset),
        null,
      );
    } catch (error) {
      return (null, error);
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
    return 'No se pudo cargar el historial de pujas.';
  }
}
