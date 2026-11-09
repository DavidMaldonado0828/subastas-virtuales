import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/detail/auction_detail.dart';
import '../../models/detail/auction_detail_data.dart';
import '../../models/detail/bid_history_item.dart';
import '../../repositories/detail/detail_repository.dart';

sealed class DetailEvent extends Equatable {
  const DetailEvent();

  @override
  List<Object?> get props => [];
}

final class DetailLoadRequested extends DetailEvent {
  const DetailLoadRequested(this.auctionId);
  final int auctionId;

  @override
  List<Object?> get props => [auctionId];
}

final class DetailRefreshRequested extends DetailEvent {
  const DetailRefreshRequested();
}

final class DetailCountdownFinished extends DetailEvent {
  const DetailCountdownFinished();
}

sealed class DetailState extends Equatable {
  const DetailState();

  @override
  List<Object?> get props => [];
}

final class DetailInitial extends DetailState {
  const DetailInitial();
}

final class DetailLoading extends DetailState {
  const DetailLoading({this.previousData});
  final AuctionDetailData? previousData;

  @override
  List<Object?> get props => [previousData];
}

final class DetailSuccess extends DetailState {
  const DetailSuccess(this.data);
  final AuctionDetailData data;

  AuctionDetail get detail => data.detail;
  List<BidHistoryItem> get bids => data.bids;
  String? get bidsError => data.bidsError;

  @override
  List<Object?> get props => [data];
}

final class DetailNotFound extends DetailState {
  const DetailNotFound();
}

final class DetailError extends DetailState {
  const DetailError(this.message);
  final String message;

  @override
  List<Object?> get props => [message];
}

class DetailBloc extends Bloc<DetailEvent, DetailState> {
  DetailBloc(this.repository) : super(const DetailInitial()) {
    on<DetailLoadRequested>((event, emit) async {
      _countdownRefreshTriggered = false;
      await _load(event, emit);
    });
    on<DetailRefreshRequested>((event, emit) async {
      _countdownRefreshTriggered = false;
      final data = switch (state) {
        DetailSuccess(:final data) => data,
        DetailLoading(previousData: final data?) => data,
        _ => null,
      };
      if (data == null) return;
      await _fetch(data.detail.auction.id, emit, previousData: data);
    });
    on<DetailCountdownFinished>((event, emit) async {
      final current = state;
      if (!_countdownRefreshTriggered && current is DetailSuccess) {
        _countdownRefreshTriggered = true;
        await _fetch(
          current.detail.auction.id,
          emit,
          previousData: current.data,
        );
      }
    });
  }

  final DetailRepository repository;
  bool _countdownRefreshTriggered = false;

  Future<void> _load(
    DetailLoadRequested event,
    Emitter<DetailState> emit,
  ) async {
    if (event.auctionId < 1) {
      emit(const DetailNotFound());
      return;
    }
    await _fetch(event.auctionId, emit);
  }

  Future<void> _fetch(
    int auctionId,
    Emitter<DetailState> emit, {
    AuctionDetailData? previousData,
  }) async {
    emit(DetailLoading(previousData: previousData));
    try {
      final detail = await repository.fetchDetail(auctionId);
      if (detail.auction.status == 'CANCELADA') {
        emit(const DetailNotFound());
        return;
      }

      List<BidHistoryItem> bids = const [];
      String? bidsError;
      try {
        bids = await repository.fetchBids(auctionId);
      } catch (error) {
        bids = previousData?.bids ?? const [];
        bidsError = _errorMessage(error, bids: true);
      }

      emit(
        DetailSuccess(
          AuctionDetailData(
            detail: detail,
            bids: List.unmodifiable(bids),
            bidsError: bidsError,
          ),
        ),
      );
    } catch (error) {
      if (error is DioException && error.response?.statusCode == 404) {
        emit(const DetailNotFound());
      } else {
        emit(DetailError(_errorMessage(error)));
      }
    }
  }

  String _errorMessage(Object error, {bool bids = false}) {
    if (error is DioException &&
        {
          DioExceptionType.connectionError,
          DioExceptionType.connectionTimeout,
          DioExceptionType.receiveTimeout,
        }.contains(error.type)) {
      return 'No se pudo conectar con el servidor';
    }
    if (bids) return 'No se pudieron cargar las pujas. Intenta actualizar.';
    return 'No se pudo cargar el detalle de la subasta. Intenta de nuevo.';
  }
}
