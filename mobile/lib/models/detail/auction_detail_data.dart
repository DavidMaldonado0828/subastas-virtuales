import 'package:equatable/equatable.dart';

import 'auction_detail.dart';
import 'bid_history_item.dart';

class AuctionDetailData extends Equatable {
  const AuctionDetailData({
    required this.detail,
    required this.bids,
    this.bidsError,
  });

  final AuctionDetail detail;
  final List<BidHistoryItem> bids;
  final String? bidsError;

  @override
  List<Object?> get props => [detail, bids, bidsError];
}
