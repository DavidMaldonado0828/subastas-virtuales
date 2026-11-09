import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../repositories/detail/detail_repository.dart';

sealed class BidEvent extends Equatable {
  const BidEvent();

  @override
  List<Object?> get props => [];
}

final class BidConfigured extends BidEvent {
  const BidConfigured({required this.auctionId, required this.minimumAmount});
  final int auctionId;
  final int? minimumAmount;

  @override
  List<Object?> get props => [auctionId, minimumAmount];
}

final class BidAmountChanged extends BidEvent {
  const BidAmountChanged(this.value);
  final String value;

  @override
  List<Object?> get props => [value];
}

final class BidAmountAdjusted extends BidEvent {
  const BidAmountAdjusted(this.delta);
  final int delta;

  @override
  List<Object?> get props => [delta];
}

final class BidSubmitRequested extends BidEvent {
  const BidSubmitRequested();
}

sealed class BidState extends Equatable {
  const BidState({
    this.auctionId,
    this.minimumAmount,
    this.amountText = '',
    this.hasEdited = false,
  });

  final int? auctionId;
  final int? minimumAmount;
  final String amountText;
  final bool hasEdited;

  bool get isSubmitting => this is BidSending;
  int? get parsedAmount =>
      RegExp(r'^\d+$').hasMatch(amountText) ? int.tryParse(amountText) : null;
  bool get isValid {
    final amount = parsedAmount;
    final minimum = minimumAmount;
    return auctionId != null &&
        amount != null &&
        minimum != null &&
        amount >= minimum;
  }

  String? get validationMessage {
    if (!hasEdited) return null;
    if (amountText.isEmpty) return 'Ingresa el monto de tu puja.';
    if (parsedAmount == null) {
      return 'Ingresa el monto en pesos enteros, sin centavos.';
    }
    if (minimumAmount != null && parsedAmount! < minimumAmount!) {
      return 'La puja debe ser igual o superior al mínimo sugerido.';
    }
    return null;
  }

  @override
  List<Object?> get props => [auctionId, minimumAmount, amountText, hasEdited];
}

final class BidInitial extends BidState {
  const BidInitial({
    super.auctionId,
    super.minimumAmount,
    super.amountText,
    super.hasEdited,
  });
}

final class BidSending extends BidState {
  const BidSending({
    required super.auctionId,
    required super.minimumAmount,
    required super.amountText,
    required super.hasEdited,
  });
}

final class BidSucceeded extends BidState {
  const BidSucceeded({
    required super.auctionId,
    required super.minimumAmount,
    required super.amountText,
    required super.hasEdited,
  });
}

final class BidFailed extends BidState {
  const BidFailed({
    required super.auctionId,
    required super.minimumAmount,
    required super.amountText,
    required super.hasEdited,
    required this.message,
    this.shouldRefresh = false,
  });

  final String message;
  final bool shouldRefresh;

  @override
  List<Object?> get props => [...super.props, message, shouldRefresh];
}

class BidBloc extends Bloc<BidEvent, BidState> {
  BidBloc(this.repository) : super(const BidInitial()) {
    on<BidConfigured>(_configure);
    on<BidAmountChanged>(_amountChanged);
    on<BidAmountAdjusted>(_amountAdjusted);
    on<BidSubmitRequested>(_submit);
  }

  final DetailRepository repository;

  void _configure(BidConfigured event, Emitter<BidState> emit) {
    final currentAmount = state.parsedAmount;
    final canKeep =
        currentAmount != null &&
        event.minimumAmount != null &&
        currentAmount >= event.minimumAmount!;
    emit(
      BidInitial(
        auctionId: event.auctionId,
        minimumAmount: event.minimumAmount,
        amountText: canKeep
            ? state.amountText
            : event.minimumAmount?.toString() ?? '',
      ),
    );
  }

  void _amountChanged(BidAmountChanged event, Emitter<BidState> emit) {
    if (state.isSubmitting) return;
    emit(
      BidInitial(
        auctionId: state.auctionId,
        minimumAmount: state.minimumAmount,
        amountText: event.value,
        hasEdited: true,
      ),
    );
  }

  void _amountAdjusted(BidAmountAdjusted event, Emitter<BidState> emit) {
    if (state.isSubmitting || state.minimumAmount == null) return;
    final minimum = state.minimumAmount!;
    final current = state.parsedAmount ?? minimum;
    final candidate = current + event.delta;
    final adjusted = candidate < minimum ? minimum : candidate;
    emit(
      BidInitial(
        auctionId: state.auctionId,
        minimumAmount: minimum,
        amountText: adjusted.toString(),
        hasEdited: true,
      ),
    );
  }

  Future<void> _submit(BidSubmitRequested event, Emitter<BidState> emit) async {
    final current = state;
    if (current.isSubmitting || !current.isValid) return;
    final auctionId = current.auctionId!;
    final amount = current.parsedAmount!;
    emit(
      BidSending(
        auctionId: auctionId,
        minimumAmount: current.minimumAmount!,
        amountText: current.amountText,
        hasEdited: current.hasEdited,
      ),
    );
    try {
      await repository.placeBid(auctionId, amount);
      emit(
        BidSucceeded(
          auctionId: auctionId,
          minimumAmount: current.minimumAmount!,
          amountText: current.amountText,
          hasEdited: current.hasEdited,
        ),
      );
    } catch (error) {
      final status = error is DioException
          ? error.response?.statusCode ??
                error.requestOptions.extra['apiStatus'] as int?
          : null;
      final apiMessage = error is DioException
          ? error.requestOptions.extra['apiDetail'] as String?
          : null;
      final isConnectionError =
          error is DioException &&
          {
            DioExceptionType.connectionError,
            DioExceptionType.connectionTimeout,
            DioExceptionType.receiveTimeout,
            DioExceptionType.sendTimeout,
          }.contains(error.type);
      emit(
        BidFailed(
          auctionId: auctionId,
          minimumAmount: current.minimumAmount,
          amountText: current.amountText,
          hasEdited: current.hasEdited,
          message: isConnectionError
              ? 'No se pudo conectar con el servidor'
              : apiMessage ?? 'No se pudo registrar la puja. Intenta de nuevo.',
          shouldRefresh: status == 409 || status == 422,
        ),
      );
    }
  }
}
