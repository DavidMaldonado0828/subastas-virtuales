import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movil/bloc/detail/bid_bloc.dart';
import 'package:movil/bloc/detail/detail_bloc.dart';
import 'package:movil/models/detail/auction_detail.dart';
import 'package:movil/models/detail/bid_history_item.dart';
import 'package:movil/models/home/auction.dart';
import 'package:movil/pages/detail/auction_detail_page.dart';
import 'package:movil/repositories/detail/detail_repository.dart';

class FakeDetailRepository implements DetailRepository {
  FakeDetailRepository(this.auctionDetail);
  final AuctionDetail auctionDetail;

  @override
  Future<AuctionDetail> fetchDetail(int auctionId) async => auctionDetail;

  @override
  Future<List<BidHistoryItem>> fetchBids(int auctionId) async => const [];

  @override
  Future<void> placeBid(int auctionId, int amount) async {}
}

AuctionDetail detail({String status = 'ACTIVA', String? leaderAlias}) =>
    AuctionDetail(
      auction: Auction(
        id: 12,
        productName: 'Cámara',
        category: 'Electrónica',
        basePrice: 100000,
        minimumIncrement: 5000,
        startDate: DateTime.utc(2026, 1),
        endDate: DateTime.utc(2027, 1),
        status: status,
        sellerAlias: 'vendedor',
        currentLeaderAmount: leaderAlias == null ? null : 130000,
      ),
      remainingSeconds: 60,
      minimumBid: 100000,
      leaderBid: leaderAlias == null
          ? null
          : LeaderBid(amount: 130000, bidderAlias: leaderAlias),
    );

Future<void> pumpDetail(
  WidgetTester tester, {
  required String role,
  String status = 'ACTIVA',
  String userAlias = 'postor',
  String? leaderAlias,
}) async {
  final repository = FakeDetailRepository(
    detail(status: status, leaderAlias: leaderAlias),
  );
  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => DetailBloc(repository)),
        BlocProvider(create: (_) => BidBloc(repository)),
      ],
      child: MaterialApp(
        home: AuctionDetailPage(
          auctionId: 12,
          role: role,
          userAlias: userAlias,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('no muestra el formulario a VENDEDOR', (tester) async {
    await pumpDetail(tester, role: 'VENDEDOR');
    expect(find.text('Ingresa tu puja'), findsNothing);
    await pumpDetail(tester, role: 'ADMIN');
    expect(find.text('Ingresa tu puja'), findsNothing);
  });

  testWidgets('no muestra el formulario si la subasta no está ACTIVA', (
    tester,
  ) async {
    await pumpDetail(tester, role: 'POSTOR', status: 'PROGRAMADA');
    expect(find.text('Ingresa tu puja'), findsNothing);
  });

  testWidgets(
    'muestra el recuadro y no el formulario cuando el usuario lidera',
    (tester) async {
      await pumpDetail(tester, role: 'POSTOR', leaderAlias: 'postor');
      expect(find.text('Ingresa tu puja'), findsNothing);
      expect(find.text('Vas ganando con \$ 130.000'), findsOneWidget);
    },
  );

  testWidgets('muestra el formulario a POSTOR cuando no lidera', (
    tester,
  ) async {
    await pumpDetail(tester, role: 'POSTOR');
    expect(find.text('Ingresa tu puja'), findsOneWidget);
    expect(
      find.text('Las pujas son vinculantes y no se pueden retirar.'),
      findsOneWidget,
    );
    expect(find.text('Mínimo: \$ 100.000'), findsOneWidget);
  });
}
