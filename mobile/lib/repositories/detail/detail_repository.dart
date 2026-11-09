import '../../models/detail/auction_detail.dart';
import '../../models/detail/bid_history_item.dart';

abstract interface class DetailRepository {
  Future<AuctionDetail> fetchDetail(int auctionId);
  Future<List<BidHistoryItem>> fetchBids(int auctionId);
  Future<void> placeBid(int auctionId, int amount);
}
