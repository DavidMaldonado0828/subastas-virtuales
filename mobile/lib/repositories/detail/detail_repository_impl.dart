import '../../models/detail/auction_detail.dart';
import '../../models/detail/bid_history_item.dart';
import '../../services/detail/detail_service.dart';
import 'detail_repository.dart';

class DetailRepositoryImpl implements DetailRepository {
  DetailRepositoryImpl(this.service);

  final DetailService service;

  @override
  Future<AuctionDetail> fetchDetail(int auctionId) =>
      service.fetchDetail(auctionId);

  @override
  Future<List<BidHistoryItem>> fetchBids(int auctionId) =>
      service.fetchBids(auctionId);

  @override
  Future<void> placeBid(int auctionId, int amount) =>
      service.placeBid(auctionId, amount);
}
