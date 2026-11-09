import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movil/bloc/detail/bid_bloc.dart';
import 'package:movil/bloc/detail/detail_bloc.dart';
import 'package:movil/models/detail/auction_detail.dart';
import 'package:movil/models/detail/bid_history_item.dart';
import 'package:movil/models/detail/bid_minimum.dart';
import 'package:movil/models/home/auction.dart';
import 'package:movil/repositories/detail/detail_repository.dart';

class FakeDetailRepository implements DetailRepository {
  Future<void> Function(int auctionId, int amount) placeBidCall = (
    _,
    _,
  ) async {};
  final placedAmounts = <int>[];
  int detailRequests = 0;
  int bidHistoryRequests = 0;

  @override
  Future<AuctionDetail> fetchDetail(int auctionId) async {
    detailRequests++;
    return testDetail;
  }

  @override
  Future<List<BidHistoryItem>> fetchBids(int auctionId) async {
    bidHistoryRequests++;
    return const [];
  }

  @override
  Future<void> placeBid(int auctionId, int amount) {
    placedAmounts.add(amount);
    return placeBidCall(auctionId, amount);
  }
}

final testDetail = AuctionDetail(
  auction: Auction(
    id: 12,
    productName: 'Producto',
    category: 'Categoría',
    basePrice: 100000,
    minimumIncrement: 10000,
    startDate: DateTime.utc(2026),
    endDate: DateTime.utc(2027),
    status: 'ACTIVA',
    sellerAlias: 'vendedor',
  ),
  remainingSeconds: 60,
  minimumBid: 100000,
);

DioException apiError(int status, {String detail = 'Error del servidor'}) =>
    DioException(
      requestOptions: RequestOptions(
        path: '/auctions/12/bids',
        extra: {'apiStatus': status, 'apiDetail': detail},
      ),
      response: Response(
        requestOptions: RequestOptions(path: '/auctions/12/bids'),
        statusCode: status,
      ),
      type: DioExceptionType.badResponse,
    );

BidInitial configuredBid() => const BidInitial(
  auctionId: 12,
  minimumAmount: 150000,
  amountText: '160000',
);

void main() {
  late FakeDetailRepository repository;
  setUp(() => repository = FakeDetailRepository());

  blocTest<BidBloc, BidState>(
    'envía una puja exitosa como entero',
    build: () => BidBloc(repository),
    seed: configuredBid,
    act: (bloc) => bloc.add(const BidSubmitRequested()),
    expect: () => [isA<BidSending>(), isA<BidSucceeded>()],
    verify: (_) => expect(repository.placedAmounts, [160000]),
  );

  blocTest<BidBloc, BidState>(
    '422 conserva el monto, expone el detalle y solicita recargar',
    build: () {
      repository.placeBidCall = (_, _) async =>
          throw apiError(422, detail: 'La puja debe ser de al menos 170000.');
      return BidBloc(repository);
    },
    seed: configuredBid,
    act: (bloc) => bloc.add(const BidSubmitRequested()),
    expect: () => [
      isA<BidSending>(),
      isA<BidFailed>()
          .having(
            (state) => state.message,
            'detalle API',
            'La puja debe ser de al menos 170000.',
          )
          .having((state) => state.shouldRefresh, 'recarga', isTrue)
          .having((state) => state.amountText, 'monto conservado', '160000'),
    ],
  );

  blocTest<BidBloc, BidState>(
    '422 recarga detalle y pujas y el nuevo mínimo ajusta el valor que quedó bajo',
    build: () {
      repository.placeBidCall = (_, _) async => throw apiError(422);
      return BidBloc(repository);
    },
    seed: configuredBid,
    act: (bloc) async {
      final detailBloc = DetailBloc(repository);
      final failureListener = bloc.stream.listen((state) {
        if (state is BidFailed && state.shouldRefresh) {
          detailBloc.add(const DetailRefreshRequested());
        }
      });
      detailBloc.add(const DetailLoadRequested(12));
      await detailBloc.stream.firstWhere((state) => state is DetailSuccess);
      bloc.add(const BidSubmitRequested());
      await bloc.stream.firstWhere((state) => state is BidFailed);
      await detailBloc.stream.firstWhere(
        (state) => state is DetailSuccess && repository.detailRequests == 2,
      );
      bloc.add(const BidConfigured(auctionId: 12, minimumAmount: 170000));
      await bloc.stream.firstWhere(
        (state) => state is BidInitial && state.minimumAmount == 170000,
      );
      await failureListener.cancel();
      await detailBloc.close();
    },
    expect: () => [
      isA<BidSending>(),
      isA<BidFailed>().having(
        (state) => state.shouldRefresh,
        'recarga',
        isTrue,
      ),
      isA<BidInitial>()
          .having((state) => state.minimumAmount, 'mínimo actualizado', 170000)
          .having(
            (state) => state.amountText,
            'ajustado al nuevo mínimo',
            '170000',
          ),
    ],
    verify: (_) {
      expect(repository.detailRequests, 2);
      expect(repository.bidHistoryRequests, 2);
    },
  );

  blocTest<BidBloc, BidState>(
    '409 muestra el detalle y solicita recargar',
    build: () {
      repository.placeBidCall = (_, _) async =>
          throw apiError(409, detail: 'La subasta cambió.');
      return BidBloc(repository);
    },
    seed: configuredBid,
    act: (bloc) => bloc.add(const BidSubmitRequested()),
    expect: () => [
      isA<BidSending>(),
      isA<BidFailed>()
          .having((state) => state.message, 'detalle API', 'La subasta cambió.')
          .having((state) => state.shouldRefresh, 'recarga', isTrue),
    ],
  );

  blocTest<BidBloc, BidState>(
    '403 presenta el detalle de permisos',
    build: () {
      repository.placeBidCall = (_, _) async =>
          throw apiError(403, detail: 'Cuenta bloqueada.');
      return BidBloc(repository);
    },
    seed: configuredBid,
    act: (bloc) => bloc.add(const BidSubmitRequested()),
    expect: () => [
      isA<BidSending>(),
      isA<BidFailed>()
          .having((state) => state.message, 'detalle API', 'Cuenta bloqueada.')
          .having((state) => state.shouldRefresh, 'recarga', isFalse),
    ],
  );

  blocTest<BidBloc, BidState>(
    '401 deja que el interceptor cierre sesión y muestra el detalle del API',
    build: () {
      repository.placeBidCall = (_, _) async =>
          throw apiError(401, detail: 'Sesión expirada.');
      return BidBloc(repository);
    },
    seed: configuredBid,
    act: (bloc) => bloc.add(const BidSubmitRequested()),
    expect: () => [
      isA<BidSending>(),
      isA<BidFailed>().having(
        (state) => state.message,
        'detalle API',
        'Sesión expirada.',
      ),
    ],
  );

  blocTest<BidBloc, BidState>(
    'error de red conserva el monto escrito',
    build: () {
      repository.placeBidCall = (_, _) async => throw DioException(
        requestOptions: RequestOptions(path: '/auctions/12/bids'),
        type: DioExceptionType.connectionError,
      );
      return BidBloc(repository);
    },
    seed: configuredBid,
    act: (bloc) => bloc.add(const BidSubmitRequested()),
    expect: () => [
      isA<BidSending>(),
      isA<BidFailed>()
          .having(
            (state) => state.message,
            'mensaje',
            'No se pudo conectar con el servidor',
          )
          .having((state) => state.amountText, 'monto conservado', '160000'),
    ],
  );

  test('calcula mínimos desde valores crudos de API', () {
    expect(
      calculateBidMinimum(
        basePrice: '950000.00',
        currentLeaderAmount: null,
        minimumIncrement: '10000.00',
      ),
      950000,
    );
    expect(
      calculateBidMinimum(
        basePrice: '950000.00',
        currentLeaderAmount: '1210000.00',
        minimumIncrement: '10000.00',
      ),
      1220000,
    );
    expect(
      calculateBidMinimum(
        basePrice: 'no es monto',
        currentLeaderAmount: null,
        minimumIncrement: '10000.00',
      ),
      isNull,
    );
    expect(
      calculateBidMinimum(
        basePrice: '950000.00',
        currentLeaderAmount: '1210000.00',
        minimumIncrement: 'inválido',
      ),
      isNull,
    );
  });
}
