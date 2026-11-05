import '../models/auction.dart';
import '../services/auction_service.dart';
import 'auction_repository.dart';

class AuctionRepositoryImpl implements AuctionRepository {
  AuctionRepositoryImpl(this.service);
  final AuctionService service;

  @override
  Future<AuctionPage> fetch({required int limit, required int offset, bool closed = false}) =>
      service.fetch(limit: limit, offset: offset, closed: closed);
}
