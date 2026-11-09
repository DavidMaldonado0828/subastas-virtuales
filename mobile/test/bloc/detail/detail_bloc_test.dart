import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movil/bloc/detail/detail_bloc.dart';
import 'package:movil/models/detail/auction_detail.dart';
import 'package:movil/models/detail/bid_history_item.dart';
import 'package:movil/models/home/auction.dart';
import 'package:movil/repositories/detail/detail_repository.dart';

class FakeDetailRepository implements DetailRepository {
  Future<AuctionDetail> Function(int) detailCall = (_) async => activeDetail;
  Future<List<BidHistoryItem>> Function(int) bidsCall = (_) async => [bid];
  Future<void> Function(int, int) placeBidCall = (_, _) async {};
  int detailRequests = 0;
  int bidRequests = 0;

  @override
  Future<AuctionDetail> fetchDetail(int auctionId) {
    detailRequests++;
    return detailCall(auctionId);
  }

  @override
  Future<List<BidHistoryItem>> fetchBids(int auctionId) {
    bidRequests++;
    return bidsCall(auctionId);
  }

  @override
  Future<void> placeBid(int auctionId, int amount) =>
      placeBidCall(auctionId, amount);
}

AuctionDetail detail({String status = 'ACTIVA', int remainingSeconds = 60}) =>
    AuctionDetail(
      auction: Auction(
        id: 12,
        productName: 'Cámara',
        category: 'Electrónica',
        brand: 'Marca',
        imageUrl: null,
        basePrice: 120000,
        minimumIncrement: 5000,
        startDate: DateTime.utc(2026, 10),
        endDate: DateTime.utc(2026, 11),
        status: status,
        currentLeaderAmount: 130000,
        sellerAlias: 'seller',
      ),
      remainingSeconds: remainingSeconds,
      leaderBid: const LeaderBid(amount: 130000, bidderAlias: 'leader'),
    );

final activeDetail = detail();
final bid = BidHistoryItem(
  bidderAlias: 'leader',
  amount: 130000,
  bidDate: DateTime.utc(2026, 10, 8, 14, 46),
);

DioException apiError(int status) => DioException(
  requestOptions: RequestOptions(path: '/auctions/12'),
  response: Response(
    requestOptions: RequestOptions(path: '/auctions/12'),
    statusCode: status,
  ),
  type: DioExceptionType.badResponse,
);

void main() {
  late FakeDetailRepository repository;
  setUp(() => repository = FakeDetailRepository());

  blocTest<DetailBloc, DetailState>(
    'carga detalle y pujas exitosamente',
    build: () => DetailBloc(repository),
    act: (bloc) => bloc.add(const DetailLoadRequested(12)),
    expect: () => [
      isA<DetailLoading>(),
      isA<DetailSuccess>()
          .having((state) => state.detail.auction.id, 'auction id', 12)
          .having((state) => state.bids, 'bids', [bid]),
    ],
    verify: (_) {
      expect(repository.detailRequests, 1);
      expect(repository.bidRequests, 1);
    },
  );

  blocTest<DetailBloc, DetailState>(
    '404 emite no encontrado',
    build: () {
      repository.detailCall = (_) async => throw apiError(404);
      return DetailBloc(repository);
    },
    act: (bloc) => bloc.add(const DetailLoadRequested(12)),
    expect: () => [isA<DetailLoading>(), isA<DetailNotFound>()],
    verify: (_) => expect(repository.bidRequests, 0),
  );

  blocTest<DetailBloc, DetailState>(
    'error al cargar detalle emite error de pantalla',
    build: () {
      repository.detailCall = (_) async => throw apiError(500);
      return DetailBloc(repository);
    },
    act: (bloc) => bloc.add(const DetailLoadRequested(12)),
    expect: () => [
      isA<DetailLoading>(),
      isA<DetailError>().having(
        (state) => state.message,
        'message',
        'No se pudo cargar el detalle de la subasta. Intenta de nuevo.',
      ),
    ],
  );

  blocTest<DetailBloc, DetailState>(
    'error en pujas conserva detalle y muestra aviso local',
    build: () {
      repository.bidsCall = (_) async => throw apiError(500);
      return DetailBloc(repository);
    },
    act: (bloc) => bloc.add(const DetailLoadRequested(12)),
    expect: () => [
      isA<DetailLoading>(),
      isA<DetailSuccess>()
          .having((state) => state.detail.auction.id, 'auction id', 12)
          .having((state) => state.bids, 'bids', isEmpty)
          .having(
            (state) => state.bidsError,
            'bids error',
            'No se pudieron cargar las pujas. Intenta actualizar.',
          ),
    ],
  );

  blocTest<DetailBloc, DetailState>(
    'refresca detalle y pujas',
    build: () => DetailBloc(repository),
    act: (bloc) async {
      bloc.add(const DetailLoadRequested(12));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const DetailRefreshRequested());
    },
    expect: () => [
      isA<DetailLoading>(),
      isA<DetailSuccess>(),
      isA<DetailLoading>(),
      isA<DetailSuccess>(),
    ],
    verify: (_) {
      expect(repository.detailRequests, 2);
      expect(repository.bidRequests, 2);
    },
  );

  blocTest<DetailBloc, DetailState>(
    'al terminar cuenta regresiva recarga una sola vez',
    build: () => DetailBloc(repository),
    act: (bloc) async {
      bloc.add(const DetailLoadRequested(12));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const DetailCountdownFinished());
      bloc.add(const DetailCountdownFinished());
    },
    expect: () => [
      isA<DetailLoading>(),
      isA<DetailSuccess>(),
      isA<DetailLoading>(),
      isA<DetailSuccess>(),
    ],
    verify: (_) {
      expect(repository.detailRequests, 2);
      expect(repository.bidRequests, 2);
    },
  );
}
