import '../../models/home/auction.dart';

abstract interface class AuctionRepository {
  Future<AuctionPage> fetch({required int limit, required int offset, bool closed = false});
  Future<MyAuctionPage> fetchMyAuctions({required int limit, required int offset});
}
