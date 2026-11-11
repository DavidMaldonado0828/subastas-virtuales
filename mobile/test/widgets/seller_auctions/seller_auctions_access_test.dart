import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movil/models/detail/auction_detail.dart';
import 'package:movil/models/detail/bid_history_item.dart';
import 'package:movil/models/home/auction.dart';
import 'package:movil/models/seller_auctions/seller_auction.dart';
import 'package:movil/models/seller_products/seller_product.dart';
import 'package:movil/pages/seller_auctions/seller_auction_form_page.dart';
import 'package:movil/pages/seller_auctions/seller_auctions_page.dart';
import 'package:movil/pages/seller_auctions/seller_bid_history_page.dart';
import 'package:movil/repositories/detail/detail_repository.dart';
import 'package:movil/repositories/seller_auctions/seller_auctions_repository.dart';
import 'package:movil/widgets/shared/account_menu_button.dart';

class _Repo implements SellerAuctionsRepository {
  int bidCountToReturn = 0;
  @override
  Future<SellerAuctionPage> fetch({
    required int limit,
    required int offset,
  }) async => SellerAuctionPage(
    items: [
      _auction(1, 'ACTIVA', 2),
      _auction(2, 'CERRADA', 0),
      _auction(3, 'PROGRAMADA', 0),
    ],
    limit: limit,
    offset: offset,
    total: 3,
  );
  @override
  Future<List<SellerAuction>> fetchAll() async => [];
  @override
  Future<List<SellerProduct>> products() async => const [
    SellerProduct(
      id: 1,
      categoryId: 1,
      categoryName: 'Hogar',
      status: 'ACTIVO',
      name: 'Producto de prueba',
      description: '',
    ),
  ];
  @override
  Future<void> create(Map<String, dynamic> payload) async {}
  @override
  Future<void> update(int id, Map<String, dynamic> payload) async {}
  @override
  Future<SellerBidPage> bids({
    required int id,
    required int limit,
    required int offset,
  }) async => SellerBidPage(
    items: List.generate(
      bidCountToReturn,
      (index) => SellerBid(
        alias: 'postor-$index',
        amount: 100000 + index,
        date: DateTime.utc(2030).add(Duration(minutes: index)),
      ),
    ),
    limit: limit,
    offset: offset,
  );
}

class _DetailRepo implements DetailRepository {
  _DetailRepo({required this.status, this.winner});
  final String status;
  final AuctionWinner? winner;

  @override
  Future<AuctionDetail> fetchDetail(int auctionId) async => AuctionDetail(
    auction: Auction(
      id: auctionId,
      productName: 'Producto $auctionId',
      category: 'Hogar',
      basePrice: 100000,
      minimumIncrement: 5000,
      startDate: DateTime.utc(2030),
      endDate: DateTime.utc(2030, 2),
      status: status,
      sellerAlias: 'vendedor',
    ),
    remainingSeconds: 0,
    winner: winner,
  );

  @override
  Future<List<BidHistoryItem>> fetchBids(int auctionId) async => [];
  @override
  Future<void> placeBid(int auctionId, int amount) async {}
}

SellerAuction _auction(int id, String status, int bidCount) => SellerAuction(
  id: id,
  productId: id,
  productName: 'Producto $id',
  category: 'Hogar',
  basePrice: 100000,
  minimumIncrement: 5000,
  startDate: DateTime.utc(2030),
  endDate: DateTime.utc(2030, 2),
  status: status,
  bidCount: bidCount,
);

void main() {
  testWidgets('la etiqueta Ganador solo aparece en la primera puja cerrada', (
    tester,
  ) async {
    final repo = _Repo()..bidCountToReturn = 3;
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    await tester.pumpWidget(
      MaterialApp(
        home: SellerBidHistoryPage(
          repository: repo,
          detailRepository: _DetailRepo(
            status: 'CERRADA',
            winner: const AuctionWinner(alias: 'ganador', amount: 120000),
          ),
          auctionId: 1,
          initialAuction: _auction(1, 'CERRADA', 3),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final winnerRow = find.ancestor(
      of: find.text('postor-0'),
      matching: find.byType(Card),
    );
    final secondRow = find.ancestor(
      of: find.text('postor-1'),
      matching: find.byType(Card),
    );
    expect(
      find.descendant(of: winnerRow, matching: find.text('Ganador')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: secondRow, matching: find.text('Ganador')),
      findsNothing,
    );
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('el selector de fecha se abre sin error', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: SellerAuctionFormPage(repository: _Repo())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Seleccionar fecha').first);
    await tester.pumpAndSettle();

    expect(find.byType(DatePickerDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Editar solo aparece sin pujas y en estados editables', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    await tester.pumpWidget(
      MaterialApp(home: SellerAuctionsPage(repository: _Repo())),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ver pujas'), findsNWidgets(3));
    expect(find.text('Editar'), findsOneWidget);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets(
    'La opción de subastas del vendedor solo invoca su ruta para VENDEDOR',
    (tester) async {
      var sellerAuctionsOpened = 0;
      var participantAuctionsOpened = 0;
      Future<void> showMenu(String role) async => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              actions: [
                AccountMenuButton(
                  alias: 'Cuenta',
                  role: role,
                  onLogout: () {},
                  onMyAuctions: () => participantAuctionsOpened++,
                  onSellerAuctions: () => sellerAuctionsOpened++,
                ),
              ],
            ),
          ),
        ),
      );
      await showMenu('VENDEDOR');
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mis subastas'));
      await tester.pumpAndSettle();
      expect(sellerAuctionsOpened, 1);
      expect(participantAuctionsOpened, 0);
      await showMenu('POSTOR');
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mis subastas'));
      await tester.pumpAndSettle();
      expect(sellerAuctionsOpened, 1);
      expect(participantAuctionsOpened, 1);
    },
  );
}
